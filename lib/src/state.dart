import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'engine/engine.dart';
import 'model/actions.dart';
import 'model/device.dart';
import 'model/keyboard.dart';
import 'model/profile.dart';
import 'model/seed.dart';

const toccoBundleId = 'me.francescoferri.tocco';

/// Una riga del registro, già tradotta in parole.
class LogEntry {
  LogEntry({required this.time, required this.key, required this.what, required this.where});

  final DateTime time;
  final String key;
  final String what;
  final String where;

  static LogEntry from(Fired f, AppState s) {
    final dev = s.devices.where((d) => d.id == f.device).firstOrNull;
    final key = dev?.layout.keys.where((k) => k.mac == f.code).firstOrNull;
    final profile = s.profiles.where((p) => p.name == f.profile).firstOrNull;
    final binding = (dev != null && key != null) ? profile?.binding(dev.id, f.layer, key.id) : null;
    final action = f.how == 'hold' ? binding?.hold : binding?.tap;
    return LogEntry(
      time: f.time,
      key: key == null ? '#${f.code}' : (key.label.isEmpty ? 'Spazio' : key.label),
      what: '${f.how == 'hold' ? 'tenuto: ' : ''}${action?.describe ?? f.kind}',
      where: [
        dev?.shortName ?? f.device,
        f.profile,
        if (f.layer > 0) layerNames[f.layer],
        if (f.app.isNotEmpty) 'in ${f.app}',
      ].join(' · '),
    );
  }
}

/// Tutto lo stato dell'app in un posto solo.
class AppState extends ChangeNotifier {
  AppState({Store? store, Engine? engine}) : store = store ?? Store(), engine = engine ?? Engine();

  final Store store;
  final Engine engine;

  StoredConfig? _config;
  bool get loaded => _config != null;

  List<Profile> get profiles => _config?.profiles ?? const [];
  Profile get globalProfile => profiles.firstWhere((p) => p.global);

  String _profileId = 'globale';
  Profile get profile => profiles.firstWhere((p) => p.id == _profileId, orElse: () => globalProfile);

  // ---------------------------------------------------------------------------
  // Dispositivi
  // ---------------------------------------------------------------------------

  /// Tutti i dispositivi conosciuti (collegati ora o in passato).
  List<DeviceConfig> get devices => _config?.devices ?? const [];

  /// Quelli che Tocco gestisce: diventano le schede sopra il disegno.
  List<DeviceConfig> get managedDevices => devices.where((d) => d.managed).toList();

  /// Quelli collegati adesso, come li vede macOS.
  List<DetectedDevice> connected = const [];

  bool isConnected(DeviceConfig d) => connected.any((c) => c.id == d.baseId);

  String? _deviceId;

  /// Il dispositivo mostrato: quello scelto nelle schede, altrimenti la prima
  /// tastiera collegata (a casa la SOLIDEE, al lavoro quella che c'è).
  DeviceConfig? get device {
    final managed = managedDevices;
    if (managed.isEmpty) return null;
    final chosen = managed.where((d) => d.id == _deviceId).firstOrNull;
    if (chosen != null) return chosen;
    final online = managed.where(isConnected).toList();
    return online.where((d) => !d.isMouse).firstOrNull ?? online.firstOrNull ?? managed.first;
  }

  Layout get layout => device?.layout ?? Layouts.ansi;

  void selectDevice(String id) {
    _deviceId = id;
    _selectedKey = null;
    notifyListeners();
  }

  void setManaged(DeviceConfig d, bool v) {
    d.managed = v;
    if (v) _deviceId = d.id;
    _selectedKey = null;
    _changed();
  }

  void setKind(DeviceConfig d, DeviceKind kind) {
    d.kind = kind;
    d.layoutId = kind == DeviceKind.mouse ? 'mouse' : Layouts.guess(d.name).id;
    _selectedKey = null;
    _changed();
  }

  void setLayout(DeviceConfig d, String layoutId) {
    d.layoutId = layoutId;
    _selectedKey = null;
    _changed();
  }

  /// Aggiunge i dispositivi nuovi appena collegati.
  void _mergeConnected({required bool firstRun}) {
    final c = _config;
    if (c == null) return;
    for (final d in connected) {
      final configs = DeviceConfig.fromDetected(d, managed: !d.builtIn);
      for (final cfg in configs) {
        // Un dispositivo solo: lo riconosco anche se ne hai cambiato il tipo.
        final known = c.devices
            .where((k) => k.id == cfg.id || (configs.length == 1 && k.baseId == cfg.baseId))
            .firstOrNull;
        if (known == null) {
          // Tastiere e mouse esterni nuovi compaiono subito come schede: finché
          // non cambi un tasto restano come sono. Quelli integrati del Mac no.
          c.devices.add(cfg);
        } else if (known.name.isEmpty) {
          known.name = d.name;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------

  int _layer = 0;
  int get layer => _layer;

  String? _selectedKey;
  KeyDef? get selectedKey => _selectedKey == null ? null : layout.byId(_selectedKey!);

  bool get italianLegends => _config?.italianLegends ?? true;
  bool get enabled => _config?.enabled ?? true;

  /// Tasti e pulsanti premuti adesso (per la prova dal vivo).
  final pressed = <String>{};

  EngineStatus status = const EngineStatus();

  /// Le ultime azioni fatte scattare dal motore, la più recente per prima.
  final log = <LogEntry>[];

  bool _showLog = false;
  bool get showLog => _showLog;
  void setShowLog(bool v) {
    _showLog = v;
    notifyListeners();
  }

  /// Id del dispositivo da cui è arrivato l'ultimo tasto (dal motore).
  String? lastInputId;

  /// Il dispositivo da cui stai scrivendo, se Tocco lo conosce.
  DeviceConfig? get lastInputDevice => devices.where((d) => d.id == lastInputId).firstOrNull;
  List<AppRef> installedApps = const [];
  AppRef? frontApp;

  bool _dirty = false;
  bool get dirty => _dirty;
  DateTime? lastApplied;

  StreamSubscription<EngineEvent>? _sub;

  Future<void> init() async {
    final stored = await store.load();
    status = await engine.status();
    connected = await engine.devices();
    if (stored == null) {
      // Primo avvio: riconosco i dispositivi e lego gli esempi al primo di ogni tipo.
      // Il motore parte in pausa: lo accendi tu quando hai visto che è tutto a posto.
      final c = StoredConfig(profiles: [], devices: [], enabled: false);
      _config = c;
      _mergeConnected(firstRun: true);
      final kb = c.devices.where((d) => d.managed && !d.isMouse).firstOrNull;
      final mouse = c.devices.where((d) => d.managed && d.isMouse).firstOrNull;
      c.profiles.addAll(seedProfiles(keyboard: kb?.id, mouse: mouse?.id));
    } else {
      _config = stored;
      _mergeConnected(firstRun: false);
    }
    notifyListeners();

    HardwareKeyboard.instance.addHandler(_onKey);
    // Gli eventi arrivano solo se il motore Swift c'è.
    if (status.native) _sub = engine.events.listen(_onEngineEvent);
    // Tocco stesso non si può legare a un profilo: quando sei in Tocco vale l'app di prima.
    installedApps = (await engine.installedApps()).where((a) => a.bundleId != toccoBundleId).toList();
    frontApp = await engine.frontApp();
    notifyListeners();
    await apply();
  }

  Future<void> refreshEngine() async {
    status = await engine.status();
    connected = await engine.devices();
    _mergeConnected(firstRun: false);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _onEngineEvent(EngineEvent e) {
    switch (e) {
      case FrontAppChanged(:final app):
        // Tocco stesso non conta: altrimenti aprendo l'app cambierebbe sempre profilo.
        if (app.bundleId != toccoBundleId) frontApp = app;
      case DevicesChanged(:final devices):
        connected = devices;
        _mergeConnected(firstRun: false);
      case PermissionsChanged(:final status):
        this.status = status;
      case Fired():
        log.insert(0, LogEntry.from(e, this));
        if (log.length > 40) log.removeLast();
      case InputFrom(:final deviceId):
        lastInputId = deviceId;
        // Un tasto da un dispositivo mai visto (es. interfaccia nascosta di un
        // ricevitore): aggiorno la lista.
        if (lastInputDevice == null) refreshEngine();
      case EnabledChanged(:final enabled):
        _config?.enabled = enabled;
        _saveSoon();
    }
    notifyListeners();
  }

  /// Accende i tasti disegnati mentre li premi davvero.
  bool _onKey(KeyEvent event) {
    final key = Layouts.byFlutterUsage(event.physicalKey.usbHidUsage);
    if (key == null) return false;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (pressed.add(key.id)) notifyListeners();
    } else if (event is KeyUpEvent) {
      if (pressed.remove(key.id)) notifyListeners();
    }
    return false;
  }

  /// Accende i pulsanti del mouse disegnato. [buttons] è la maschera di Flutter:
  /// il bit n corrisponde al pulsante n del Mac (0 sinistro, 3 indietro…).
  void mouseButtons(int buttons) {
    final ids = {
      for (final b in Layouts.mouse.keys)
        if (buttons & (1 << b.mac) != 0) b.id,
    };
    final before = pressed.where((id) => id.startsWith('m-')).toSet();
    if (setEquals(before, ids)) return;
    pressed
      ..removeAll(before)
      ..addAll(ids);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Profili
  // ---------------------------------------------------------------------------

  /// Il profilo che il motore sta usando adesso, in base all'app in primo piano.
  Profile get activeProfile {
    final bundle = frontApp?.bundleId;
    if (bundle == null) return globalProfile;
    return profiles.firstWhere(
      (p) => !p.global && p.apps.any((a) => a.bundleId == bundle),
      orElse: () => globalProfile,
    );
  }

  void selectProfile(String id) {
    _profileId = id;
    _layer = 0;
    notifyListeners();
  }

  void addProfile() {
    final id = 'profilo-${DateTime.now().millisecondsSinceEpoch}';
    profiles.add(Profile(id: id, name: 'Nuovo profilo'));
    _profileId = id;
    _layer = 0;
    _selectedKey = null;
    _changed();
  }

  void renameProfile(String name) {
    if (name.trim().isEmpty) return;
    profile.name = name.trim();
    _changed();
  }

  void deleteProfile() {
    if (profile.global) return;
    profiles.remove(profile);
    _profileId = globalProfile.id;
    _changed();
  }

  void addApp(AppRef app) {
    if (profile.global || profile.apps.contains(app) || app.bundleId == toccoBundleId) return;
    // Un'app appartiene a un profilo solo.
    for (final p in profiles) {
      p.apps.remove(app);
    }
    profile.apps.add(app);
    _changed();
  }

  void removeApp(AppRef app) {
    profile.apps.remove(app);
    _changed();
  }

  /// Quale profilo usa già quest'app (per avvisare prima di spostarla).
  Profile? ownerOf(AppRef app) => profiles.where((p) => p.apps.contains(app)).firstOrNull;

  // ---------------------------------------------------------------------------
  // Tasti
  // ---------------------------------------------------------------------------

  void setLayer(int l) {
    _layer = l;
    notifyListeners();
  }

  void selectKey(String? id) {
    _selectedKey = _selectedKey == id ? null : id;
    notifyListeners();
  }

  String get _dev => device?.id ?? '';

  Map<String, KeyBinding> currentLayer() => profile.layer(_dev, _layer);

  KeyBinding? bindingFor(String keyId, {int? layer}) => profile.binding(_dev, layer ?? _layer, keyId);

  /// Nei profili per app, quello che non è toccato arriva dal Globale.
  KeyBinding? inheritedFor(String keyId) {
    if (profile.global) return null;
    return globalProfile.binding(_dev, _layer, keyId);
  }

  /// Il tasto apre, tenuto premuto, il livello che stai guardando?
  bool opensCurrentLayer(String keyId) {
    if (_layer == 0) return false;
    return [profile, globalProfile].any((p) {
      final hold = p.binding(_dev, 0, keyId)?.hold;
      return hold is LayerAction && hold.layer == _layer;
    });
  }

  void setTap(KeyAction? action) {
    final key = selectedKey;
    if (key == null || device == null) return;
    final current = bindingFor(key.id) ?? const KeyBinding();
    profile.setBinding(
      _dev,
      _layer,
      key.id,
      action == null ? current.copyWith(clearTap: true) : current.copyWith(tap: action),
    );
    _changed();
  }

  void setHold(KeyAction? action) {
    final key = selectedKey;
    if (key == null || device == null) return;
    final current = bindingFor(key.id) ?? const KeyBinding();
    profile.setBinding(
      _dev,
      _layer,
      key.id,
      action == null ? current.copyWith(clearHold: true) : current.copyWith(hold: action),
    );
    _changed();
  }

  void resetKey() {
    final key = selectedKey;
    if (key == null || device == null) return;
    profile.setBinding(_dev, _layer, key.id, const KeyBinding());
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Impostazioni
  // ---------------------------------------------------------------------------

  void setItalianLegends(bool v) {
    _config?.italianLegends = v;
    _changed(applyToo: false);
  }

  void setEnabled(bool v) {
    _config?.enabled = v;
    _changed();
    apply();
  }

  void _changed({bool applyToo = true}) {
    if (applyToo) _dirty = true;
    notifyListeners();
    _saveSoon(applyToo: applyToo);
  }

  Timer? _saveTimer;

  /// Ogni modifica viene salvata e mandata al motore da sola, dopo un attimo.
  void _saveSoon({bool applyToo = false}) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      final c = _config;
      if (c == null) return;
      if (applyToo) {
        apply();
      } else {
        store.save(c);
      }
    });
  }

  /// Salva e manda tutto al motore.
  Future<void> apply() async {
    final c = _config;
    if (c == null) return;
    await store.save(c);
    await engine.apply(profiles: c.profiles, devices: c.devices, enabled: c.enabled);
    status = await engine.status();
    _dirty = false;
    lastApplied = DateTime.now();
    notifyListeners();
  }
}
