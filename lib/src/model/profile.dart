import 'actions.dart';
import 'device.dart';

/// Un'app del Mac a cui legare un profilo.
class AppRef {
  const AppRef({required this.name, required this.bundleId, this.path = ''});

  final String name;
  final String bundleId;
  final String path;

  Map<String, Object?> toJson() => {'name': name, 'bundleId': bundleId, 'path': path};

  static AppRef fromJson(Map<String, Object?> j) => AppRef(
    name: j['name'] as String? ?? '',
    bundleId: j['bundleId'] as String? ?? '',
    path: j['path'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) => other is AppRef && other.bundleId == bundleId;

  @override
  int get hashCode => bundleId.hashCode;
}

/// Quanti livelli ha ogni profilo: base + 2.
const layerCount = 3;
const layerNames = ['Base', 'Livello 1', 'Livello 2'];

typedef Layers = List<Map<String, KeyBinding>>;

Layers _emptyLayers() => List.generate(layerCount, (_) => <String, KeyBinding>{});

class Profile {
  Profile({required this.id, required this.name, this.global = false, List<AppRef>? apps, Map<String, Layers>? devices})
    : apps = apps ?? [],
      devices = devices ?? {};

  final String id;
  String name;

  /// Il profilo globale vale ovunque, gli altri solo nelle loro app
  /// (e quello che non toccano lo prendono dal globale).
  final bool global;
  final List<AppRef> apps;

  /// devices[idDispositivo][livello][idTasto]
  final Map<String, Layers> devices;

  Map<String, KeyBinding> layer(String device, int layer) => devices[device]?[layer] ?? const {};

  KeyBinding? binding(String device, int layer, String keyId) => devices[device]?[layer][keyId];

  void setBinding(String device, int layer, String keyId, KeyBinding b) {
    final layers = devices.putIfAbsent(device, _emptyLayers);
    if (b.isEmpty) {
      layers[layer].remove(keyId);
    } else {
      layers[layer][keyId] = b;
    }
  }

  int changesFor(String device) => devices[device]?.fold<int>(0, (s, l) => s + l.length) ?? 0;

  int get changeCount => devices.values.fold(0, (s, ls) => s + ls.fold<int>(0, (t, l) => t + l.length));

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'global': global,
    'apps': [for (final a in apps) a.toJson()],
    'devices': {
      for (final d in devices.entries)
        d.key: [
          for (final l in d.value) {for (final e in l.entries) e.key: e.value.toJson()},
        ],
    },
  };

  /// Per il motore: per ogni dispositivo gestito, chiavi = keycode del Mac
  /// (tastiere) o numero del pulsante (mouse).
  Map<String, Object?> toEngine(List<DeviceConfig> managed) => {
    'name': name,
    'global': global,
    'bundleIds': [for (final a in apps) a.bundleId],
    'devices': {
      for (final dev in managed)
        if (devices[dev.id] case final layers?)
          dev.id: [
            for (final l in layers)
              {
                for (final e in l.entries)
                  if (dev.layout.byId(e.key) case final k? when !k.firmware && !k.unsupported)
                    '${k.mac}': e.value.toEngine(),
              },
          ],
    },
  };

  static Profile fromJson(Map<String, Object?> j) {
    final raw = (j['devices'] as Map?)?.cast<String, Object?>() ?? const {};
    return Profile(
      id: j['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: j['name'] as String? ?? 'Profilo',
      global: j['global'] as bool? ?? false,
      apps: [for (final a in (j['apps'] as List?) ?? const []) AppRef.fromJson((a as Map).cast<String, Object?>())],
      devices: {
        for (final d in raw.entries)
          d.key: List.generate(layerCount, (i) {
            final list = d.value as List? ?? const [];
            if (i >= list.length) return <String, KeyBinding>{};
            final m = (list[i] as Map).cast<String, Object?>();
            return {for (final e in m.entries) e.key: KeyBinding.fromJson((e.value as Map).cast<String, Object?>())};
          }),
      },
    );
  }
}
