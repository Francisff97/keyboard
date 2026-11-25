import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tocco/src/data/store.dart';
import 'package:tocco/src/model/actions.dart';
import 'package:tocco/src/model/device.dart';
import 'package:tocco/src/model/keyboard.dart';
import 'package:tocco/src/model/profile.dart';
import 'package:tocco/src/model/seed.dart';

double _rowWidth(Layout l, double y) =>
    l.keys.where((k) => k.y == y).fold<double>(0, (s, k) => s + k.w) +
    // Nella standard i tasti alti due righe (+ e Invio del tastierino) occupano spazio anche sotto.
    l.keys.where((k) => k.h > 1 && k.y < y && k.y + k.h > y).fold<double>(0, (s, k) => s + k.w);

void main() {
  test('la SOLIDEE ha 68 tasti e ogni riga è larga 16 unità', () {
    final l = Layouts.solidee65;
    expect(l.keys.length, 68);
    for (var y = 0; y < 5; y++) {
      expect(_rowWidth(l, y.toDouble()), 16, reason: 'riga $y');
    }
  });

  test('la tastiera standard ha 104 tasti e nessuno si sovrappone', () {
    final l = Layouts.ansi;
    expect(l.keys.length, 104);
    for (final a in l.keys) {
      for (final b in l.keys) {
        if (identical(a, b)) continue;
        expect(a.rect.deflate(0.01).overlaps(b.rect.deflate(0.01)), isFalse, reason: '${a.id} / ${b.id}');
      }
      expect(a.x + a.w, lessThanOrEqualTo(l.width));
      expect(a.y + a.h, lessThanOrEqualTo(l.height));
    }
  });

  test('id e codici non si ripetono in nessun layout', () {
    for (final l in Layouts.all) {
      expect(l.keys.map((k) => k.id).toSet().length, l.keys.length, reason: l.id);
      final codes = l.keys.where((k) => k.hid != 0).map((k) => k.mac).toSet();
      expect(codes.length, l.keys.where((k) => k.hid != 0).length, reason: l.id);
    }
  });

  test('riconoscimento automatico di tastiere e mouse', () {
    DeviceConfig auto(String name, {bool kb = true, bool mouse = false}) =>
        DeviceConfig.auto(DetectedDevice(name: name, vendorId: 1, productId: 2, keyboard: kb, mouse: mouse));

    expect(auto('SOLIDEE 68 Gaming Keyboard', mouse: true).layoutId, 'solidee65');
    expect(auto('Keychron K6 65%').layoutId, 'solidee65');
    expect(auto('Apple Magic Keyboard').layoutId, 'ansi');
    expect(auto('Generic USB Keyboard').layoutId, 'ansi');
    expect(auto('G502 HERO Gaming Mouse', mouse: true).kind, DeviceKind.mouse);
    expect(auto('Gaming Mouse G502', kb: false, mouse: true).kind, DeviceKind.mouse);
    expect(auto('USB Receiver', mouse: true).kind, DeviceKind.keyboard);
  });

  test('dal tasto fisico di Flutter al tasto del layout', () {
    expect(Layouts.byFlutterUsage(0x00070039)?.id, 'caps');
    expect(Layouts.byFlutterUsage(0x0007003A)?.id, 'f1');
    expect(Layouts.byFlutterUsage(0x00070059)?.id, 'kp1');
  });

  test('i profili tornano uguali dal JSON', () {
    for (final p in seedProfiles(keyboard: 'AAAA:0001', mouse: 'BBBB:0002')) {
      final back = Profile.fromJson(p.toJson());
      expect(back.toJson(), p.toJson());
    }
  });

  test('il motore riceve keycode per le tastiere e pulsanti per i mouse', () {
    final kb = DeviceConfig(
      vendorId: 0xAAAA,
      productId: 1,
      name: 'SOLIDEE',
      kind: DeviceKind.keyboard,
      layoutId: 'solidee65',
    );
    final mouse = DeviceConfig(vendorId: 0xBBBB, productId: 2, name: 'G502', kind: DeviceKind.mouse, layoutId: 'mouse');
    final global = seedProfiles(keyboard: kb.id, mouse: mouse.id).first;
    final engine = global.toEngine([kb, mouse]);
    final devices = engine['devices'] as Map;

    final kbBase = (devices[kb.id] as List).first as Map;
    expect((kbBase['57'] as Map)['tap'], {'kind': 'remap', 'mac': 53});
    expect((kbBase['57'] as Map)['hold'], {'kind': 'layer', 'layer': 1});

    // Indietro (pulsante 3) → ⌘[ (keycode 33).
    final mouseBase = (devices[mouse.id] as List).first as Map;
    expect((mouseBase['3'] as Map)['tap'], {
      'kind': 'shortcut',
      'mods': ['cmd'],
      'mac': 33,
    });
  });

  test('i dispositivi non gestiti non arrivano al motore', () {
    final kb = DeviceConfig(vendorId: 1, productId: 1, name: 'x', kind: DeviceKind.keyboard, layoutId: 'ansi');
    final global = seedProfiles(keyboard: kb.id).first;
    expect((global.toEngine([])['devices'] as Map), isEmpty);
  });

  test('Fn e click sinistro non vanno mai al motore', () {
    final kb = DeviceConfig(vendorId: 1, productId: 1, name: 'x', kind: DeviceKind.keyboard, layoutId: 'solidee65');
    final mouse = DeviceConfig(vendorId: 2, productId: 2, name: 'y', kind: DeviceKind.mouse, layoutId: 'mouse');
    final p = Profile(id: 'x', name: 'x')
      ..setBinding(kb.id, 0, 'fn', const KeyBinding(tap: DisabledAction()))
      ..setBinding(mouse.id, 0, 'm-left', const KeyBinding(tap: DisabledAction()));
    final devices = p.toEngine([kb, mouse])['devices'] as Map;
    expect(((devices[kb.id] as List).first as Map).containsKey('63'), isFalse);
    expect(((devices[mouse.id] as List).first as Map).containsKey('0'), isFalse);
  });

  test('salva e ricarica', () async {
    final dir = Directory.systemTemp.createTempSync('tocco-test');
    final store = Store(path: '${dir.path}/tocco.json');
    expect(await store.load(), isNull);
    final config = StoredConfig(
      profiles: seedProfiles(keyboard: 'AAAA:0001'),
      devices: [
        DeviceConfig(vendorId: 0xAAAA, productId: 1, name: 'SOLIDEE', kind: DeviceKind.keyboard, layoutId: 'solidee65'),
      ],
    );
    config.profiles[1].name = 'Figma Pro';
    await store.save(config);
    final again = (await store.load())!;
    expect(again.profiles[1].name, 'Figma Pro');
    expect(again.devices.single.id, 'AAAA:0001');
    expect(again.profiles.first.binding('AAAA:0001', 0, 'caps')?.hold, isA<LayerAction>());
  });
}
