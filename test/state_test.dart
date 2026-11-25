import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tocco/src/data/store.dart';
import 'package:tocco/src/engine/engine.dart';
import 'package:tocco/src/model/device.dart';
import 'package:tocco/src/model/keyboard.dart';
import 'package:tocco/src/state.dart';

/// Motore finto: decide il test quali dispositivi sono collegati.
class _FakeEngine extends Engine {
  _FakeEngine(this.list);
  List<DetectedDevice> list;

  @override
  Future<List<DetectedDevice>> devices() async => list;
}

const _solidee = DetectedDevice(name: 'SOLIDEE 68', vendorId: 0x258A, productId: 0x49, keyboard: true);
const _mxKeys = DetectedDevice(name: 'MX Keys', vendorId: 0x046D, productId: 0xB35B, keyboard: true);
const _mxMaster = DetectedDevice(
  name: 'MX Master 3S',
  vendorId: 0x046D,
  productId: 0xB034,
  keyboard: true,
  mouse: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a casa la SOLIDEE con la sua grafica, al lavoro la tastiera standard', () async {
    final path = '${Directory.systemTemp.createTempSync('tocco').path}/t.json';

    // Casa: c'è la SOLIDEE.
    final home = AppState(
      store: Store(path: path),
      engine: _FakeEngine([_solidee]),
    );
    await home.init();
    expect(home.device?.name, 'SOLIDEE 68');
    expect(home.layout.id, 'solidee65');

    // Lavoro: stessa configurazione, la SOLIDEE non c'è, ci sono MX Keys e MX Master.
    final work = AppState(
      store: Store(path: path),
      engine: _FakeEngine([_mxKeys, _mxMaster]),
    );
    await work.init();
    expect(work.device?.name, 'MX Keys');
    expect(work.layout, Layouts.ansi);
    expect(work.devices.firstWhere((d) => d.name == 'MX Master 3S').kind, DeviceKind.mouse);
  });

  test('una SOLIDEE con nome generico si sceglie una volta e resta', () async {
    final path = '${Directory.systemTemp.createTempSync('tocco').path}/t.json';
    const generic = DetectedDevice(name: 'Gaming Keyboard', vendorId: 0x258A, productId: 0x49, keyboard: true);
    final s = AppState(
      store: Store(path: path),
      engine: _FakeEngine([generic]),
    );
    await s.init();
    expect(s.layout.id, 'ansi');
    s.setLayout(s.device!, 'solidee65');
    await s.apply();

    final again = AppState(
      store: Store(path: path),
      engine: _FakeEngine([generic]),
    );
    await again.init();
    expect(again.layout.id, 'solidee65');
  });

  test('un ricevitore Logitech diventa una tastiera e un mouse', () async {
    final path = '${Directory.systemTemp.createTempSync('tocco').path}/t.json';
    const receiver = DetectedDevice(
      name: 'USB Receiver',
      vendorId: 0x046D,
      productId: 0xC52B,
      keyboard: true,
      mouse: true,
    );
    final s = AppState(
      store: Store(path: path),
      engine: _FakeEngine([receiver]),
    );
    await s.init();
    final ids = s.managedDevices.map((d) => d.id).toList();
    expect(ids, containsAll(['046D:C52B', '046D:C52B:M']));
    expect(s.managedDevices.map((d) => d.shortName), containsAll(['Logitech tastiera', 'Logitech mouse']));
    expect(s.device?.isMouse, isFalse);
    expect(s.managedDevices.every(s.isConnected), isTrue);
  });
}
