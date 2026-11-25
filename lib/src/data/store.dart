import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/device.dart';
import '../model/profile.dart';

class StoredConfig {
  StoredConfig({required this.profiles, required this.devices, this.enabled = true, this.italianLegends = true});

  final List<Profile> profiles;
  final List<DeviceConfig> devices;
  bool enabled;
  bool italianLegends;

  Map<String, Object?> toJson() => {
    'version': 2,
    'enabled': enabled,
    'italianLegends': italianLegends,
    'devices': [for (final d in devices) d.toJson()],
    'profiles': [for (final pr in profiles) pr.toJson()],
  };
}

/// Salva tutto in un JSON leggibile:
/// ~/Library/Application Support/Tocco/tocco.json
class Store {
  Store({String? path}) : _path = path ?? _defaultPath();

  final String _path;

  String get path => _path;

  static String _defaultPath() {
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    if (Platform.isMacOS) return p.join(home, 'Library', 'Application Support', 'Tocco', 'tocco.json');
    return p.join(home, '.tocco', 'tocco.json');
  }

  /// null = primo avvio (o file di una versione vecchia): si riparte dagli esempi.
  Future<StoredConfig?> load() async {
    final f = File(_path);
    if (!await f.exists()) return null;
    try {
      final j = (jsonDecode(await f.readAsString()) as Map).cast<String, Object?>();
      if ((j['version'] as num?) != 2) return null;
      final profiles = [
        for (final pr in (j['profiles'] as List?) ?? const []) Profile.fromJson((pr as Map).cast<String, Object?>()),
      ];
      if (!profiles.any((pr) => pr.global)) profiles.insert(0, Profile(id: 'globale', name: 'Globale', global: true));
      return StoredConfig(
        profiles: profiles,
        devices: [
          for (final d in (j['devices'] as List?) ?? const [])
            DeviceConfig.fromJson((d as Map).cast<String, Object?>()),
        ],
        enabled: j['enabled'] as bool? ?? true,
        italianLegends: j['italianLegends'] as bool? ?? true,
      );
    } catch (_) {
      // File rovinato: lo tengo da parte e riparto dagli esempi.
      await f.copy('$_path.bak');
      return null;
    }
  }

  Future<void> save(StoredConfig config) async {
    final f = File(_path);
    await f.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await f.writeAsString(encoder.convert(config.toJson()));
  }
}
