import 'dart:async';

import 'package:flutter/services.dart';

import '../model/device.dart';
import '../model/keyboard.dart';
import '../model/profile.dart';

/// Lo stato del motore Swift che gira nell'app.
class EngineStatus {
  const EngineStatus({
    this.native = false,
    this.accessibility = false,
    this.inputMonitoring = false,
    this.running = false,
  });

  /// false = il motore Swift non risponde (anteprima, test, altro sistema).
  final bool native;

  /// Accessibilità: serve per modificare i tasti (event tap).
  final bool accessibility;

  /// Monitoraggio input: serve per riconoscere da quale tastiera arriva il tasto.
  final bool inputMonitoring;

  /// L'event tap è attivo.
  final bool running;

  bool get permissionsOk => accessibility && inputMonitoring;

  static EngineStatus fromMap(Map<Object?, Object?> m) => EngineStatus(
    native: true,
    accessibility: m['accessibility'] == true,
    inputMonitoring: m['inputMonitoring'] == true,
    running: m['running'] == true,
  );
}

/// Eventi che arrivano dal motore.
sealed class EngineEvent {}

class FrontAppChanged extends EngineEvent {
  FrontAppChanged(this.app);
  final AppRef app;
}

class DevicesChanged extends EngineEvent {
  DevicesChanged(this.devices);
  final List<DetectedDevice> devices;
}

/// Il motore è stato messo in pausa (o ripreso) dalla barra dei menu.
class EnabledChanged extends EngineEvent {
  EnabledChanged(this.enabled);
  final bool enabled;
}

class PermissionsChanged extends EngineEvent {
  PermissionsChanged(this.status);
  final EngineStatus status;
}

/// Ponte verso il codice Swift in macos/Runner/KeyEngine.swift.
///
/// Se il lato nativo non c'è (anteprima, test), risponde con dati finti
/// così l'interfaccia si può provare lo stesso.
class Engine {
  static const _methods = MethodChannel('tocco/engine');
  static const _events = EventChannel('tocco/events');

  Stream<EngineEvent>? _stream;

  Stream<EngineEvent> get events => _stream ??= _events
      .receiveBroadcastStream()
      .map<EngineEvent?>((raw) {
        final m = raw as Map<Object?, Object?>;
        switch (m['type']) {
          case 'frontApp':
            return FrontAppChanged(
              AppRef(
                name: m['name'] as String? ?? '',
                bundleId: m['bundleId'] as String? ?? '',
                path: m['path'] as String? ?? '',
              ),
            );
          case 'devices':
            return DevicesChanged([
              for (final d in (m['devices'] as List?) ?? const []) DetectedDevice.fromMap(d as Map<Object?, Object?>),
            ]);
          case 'enabled':
            return EnabledChanged(m['enabled'] == true);
          case 'permissions':
            return PermissionsChanged(EngineStatus.fromMap(m));
        }
        return null;
      })
      .where((e) => e != null)
      .cast<EngineEvent>()
      .handleError((Object _) {});

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _methods.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<EngineStatus> status() async {
    final m = await _call<Map<Object?, Object?>>('status');
    return m == null ? const EngineStatus() : EngineStatus.fromMap(m);
  }

  /// Chiede i permessi (fa comparire gli avvisi di macOS).
  Future<void> requestPermissions() => _call<void>('requestPermissions');

  /// Apre Impostazioni di Sistema → Privacy e sicurezza → [pane].
  Future<void> openPrivacySettings(String pane) => _call<void>('openPrivacySettings', {'pane': pane});

  /// Tastiere e mouse collegati.
  Future<List<DetectedDevice>> devices() async {
    final list = await _call<List<Object?>>('listDevices');
    if (list == null) return demoDevices;
    return [for (final d in list) DetectedDevice.fromMap(d as Map<Object?, Object?>)];
  }

  Future<List<AppRef>> installedApps() async {
    final list = await _call<List<Object?>>('listApps');
    if (list == null) return demoApps;
    return [
      for (final a in list)
        AppRef(
          name: (a as Map)['name'] as String? ?? '',
          bundleId: a['bundleId'] as String? ?? '',
          path: a['path'] as String? ?? '',
        ),
    ];
  }

  Future<AppRef?> frontApp() async {
    final m = await _call<Map<Object?, Object?>>('frontApp');
    if (m == null) return demoApps.first;
    return AppRef(
      name: m['name'] as String? ?? '',
      bundleId: m['bundleId'] as String? ?? '',
      path: m['path'] as String? ?? '',
    );
  }

  /// Manda al motore i dispositivi gestiti e tutti i profili, già tradotti
  /// in keycode del Mac (tastiere) e numeri di pulsante (mouse).
  Future<bool> apply({
    required List<Profile> profiles,
    required List<DeviceConfig> devices,
    required bool enabled,
  }) async {
    final managed = devices.where((d) => d.managed).toList();
    final ok = await _call<bool>('apply', {
      'enabled': enabled,
      'devices': [for (final d in managed) d.toEngine()],
      'hidToMac': Layouts.hidToMac,
      'profiles': [for (final p in profiles) p.toEngine(managed)],
    });
    return ok ?? false;
  }

  // ---------------------------------------------------------------------------
  // Dati finti per l'anteprima
  // ---------------------------------------------------------------------------

  static const demoDevices = [
    DetectedDevice(
      name: 'SOLIDEE 68 Gaming Keyboard',
      vendorId: 0x258A,
      productId: 0x0049,
      keyboard: true,
      mouse: true,
    ),
    DetectedDevice(name: 'G502 HERO Gaming Mouse', vendorId: 0x046D, productId: 0xC08B, keyboard: true, mouse: true),
    DetectedDevice(
      name: 'Apple Internal Keyboard / Trackpad',
      vendorId: 0x05AC,
      productId: 0x0342,
      keyboard: true,
      mouse: true,
      builtIn: true,
    ),
  ];

  static const demoApps = [
    AppRef(name: 'Figma', bundleId: 'com.figma.Desktop', path: '/Applications/Figma.app'),
    AppRef(name: 'Visual Studio Code', bundleId: 'com.microsoft.VSCode', path: '/Applications/Visual Studio Code.app'),
    AppRef(name: 'Safari', bundleId: 'com.apple.Safari', path: '/Applications/Safari.app'),
    AppRef(name: 'Mail', bundleId: 'com.apple.mail', path: '/System/Applications/Mail.app'),
    AppRef(name: 'Adobe XD', bundleId: 'com.adobe.xd', path: '/Applications/Adobe XD/Adobe XD.app'),
    AppRef(
      name: 'Adobe Photoshop 2026',
      bundleId: 'com.adobe.Photoshop',
      path: '/Applications/Adobe Photoshop 2026.app',
    ),
    AppRef(name: 'Terminale', bundleId: 'com.apple.Terminal', path: '/System/Applications/Utilities/Terminal.app'),
    AppRef(name: 'WhatsApp', bundleId: 'net.whatsapp.WhatsApp', path: '/Applications/WhatsApp.app'),
    AppRef(name: 'Steam', bundleId: 'com.valvesoftware.steam', path: '/Applications/Steam.app'),
    AppRef(name: 'Xcode', bundleId: 'com.apple.dt.Xcode', path: '/Applications/Xcode.app'),
  ];
}
