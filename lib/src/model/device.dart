import 'keyboard.dart';

/// Un dispositivo visto da macOS (IOHIDManager), così come arriva dal motore.
class DetectedDevice {
  const DetectedDevice({
    required this.name,
    required this.vendorId,
    required this.productId,
    this.keyboard = false,
    this.mouse = false,
    this.builtIn = false,
  });

  final String name;
  final int vendorId;
  final int productId;

  /// Si presenta a macOS come tastiera / come mouse (spesso entrambe le cose).
  final bool keyboard;
  final bool mouse;
  final bool builtIn;

  String get id => deviceId(vendorId, productId);

  static DetectedDevice fromMap(Map<Object?, Object?> m) => DetectedDevice(
    name: (m['name'] as String?)?.trim().isNotEmpty == true ? (m['name'] as String).trim() : 'Dispositivo USB',
    vendorId: (m['vendorId'] as num?)?.toInt() ?? 0,
    productId: (m['productId'] as num?)?.toInt() ?? 0,
    keyboard: m['keyboard'] == true,
    mouse: m['mouse'] == true,
    builtIn: m['builtIn'] == true,
  );
}

/// "046D:C08B": VendorID e ProductID in esadecimale. È l'id che usa anche il motore.
String deviceId(int vendor, int product) =>
    '${vendor.toRadixString(16).padLeft(4, '0')}:${product.toRadixString(16).padLeft(4, '0')}'.toUpperCase();

/// Un dispositivo che Tocco conosce, con le scelte dell'utente.
class DeviceConfig {
  DeviceConfig({
    required this.vendorId,
    required this.productId,
    required this.name,
    required this.kind,
    required this.layoutId,
    this.managed = true,
    this.builtIn = false,
  });

  final int vendorId;
  final int productId;
  String name;
  DeviceKind kind;

  /// Solo per le tastiere: 'solidee65' o 'ansi'.
  String layoutId;

  /// Tocco cambia i suoi tasti. Se false, il dispositivo resta com'è.
  bool managed;
  final bool builtIn;

  /// VendorID:ProductID, come lo vede macOS.
  String get baseId => deviceId(vendorId, productId);

  /// Id usato nei profili e dal motore. Il mouse ha ":M" in fondo: così un
  /// ricevitore che porta sia tastiera sia mouse (Logitech Unifying/Bolt)
  /// diventa due dispositivi separati.
  String get id => isMouse ? '$baseId:M' : baseId;
  bool get isMouse => kind == DeviceKind.mouse;
  Layout get layout => isMouse ? Layouts.mouse : Layouts.byId(layoutId);

  /// Nome corto per le schede (senza "Gaming Keyboard", "USB" e simili).
  String get shortName {
    if (_receiver.hasMatch(name)) {
      final brand = vendorId == 0x046D ? 'Logitech ' : '';
      return isMouse ? '${brand}mouse' : '${brand}tastiera';
    }
    var n = name.replaceAll(RegExp(r'\b(gaming|wireless|usb|keyboard|mouse|receiver)\b', caseSensitive: false), '');
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (n.isEmpty) n = isMouse ? 'Mouse' : 'Tastiera';
    return n;
  }

  static final _mouseName = RegExp(
    r'mouse|\bg ?[3-9]\d\d\b|mx ?master|mx ?anywhere|superlight|deathadder|viper|basilisk|trackball|\blift\b|pulsefire',
    caseSensitive: false,
  );

  static final _receiver = RegExp(r'receiver|unifying|\bbolt\b|lightspeed|nano', caseSensitive: false);

  /// Ricevitore senza fili che porta tastiera e mouse insieme?
  static bool isReceiver(DetectedDevice d) => d.keyboard && d.mouse && _receiver.hasMatch(d.name);

  /// Uno o due dispositivi per ogni periferica collegata: i ricevitori diventano
  /// una tastiera e un mouse, tutto il resto un dispositivo solo.
  static List<DeviceConfig> fromDetected(DetectedDevice d, {bool managed = true}) {
    if (!isReceiver(d)) return [auto(d, managed: managed)];
    DeviceConfig make(DeviceKind kind) => DeviceConfig(
      vendorId: d.vendorId,
      productId: d.productId,
      name: d.name,
      kind: kind,
      layoutId: kind == DeviceKind.mouse ? 'mouse' : 'ansi',
      managed: managed,
      builtIn: d.builtIn,
    );
    return [make(DeviceKind.keyboard), make(DeviceKind.mouse)];
  }

  /// Riconoscimento automatico: mouse o tastiera, e quale tastiera.
  /// Molti mouse da gioco si presentano anche come tastiera (per le macro) e
  /// molte tastiere anche come mouse (per la manopola): decide il nome.
  static DeviceConfig auto(DetectedDevice d, {bool managed = true}) {
    final isMouse = d.mouse && (!d.keyboard || _mouseName.hasMatch(d.name));
    return DeviceConfig(
      vendorId: d.vendorId,
      productId: d.productId,
      name: d.name,
      kind: isMouse ? DeviceKind.mouse : DeviceKind.keyboard,
      layoutId: isMouse ? 'mouse' : Layouts.guess(d.name).id,
      managed: managed,
      builtIn: d.builtIn,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'vendorId': vendorId,
    'productId': productId,
    'kind': kind.name,
    'layout': layoutId,
    'managed': managed,
    'builtIn': builtIn,
  };

  Map<String, Object?> toEngine() => {'id': id, 'kind': kind.name, 'vendorId': vendorId, 'productId': productId};

  static DeviceConfig fromJson(Map<String, Object?> j) => DeviceConfig(
    name: j['name'] as String? ?? '',
    vendorId: (j['vendorId'] as num?)?.toInt() ?? 0,
    productId: (j['productId'] as num?)?.toInt() ?? 0,
    kind: j['kind'] == 'mouse' ? DeviceKind.mouse : DeviceKind.keyboard,
    layoutId: j['layout'] as String? ?? 'ansi',
    managed: j['managed'] as bool? ?? true,
    builtIn: j['builtIn'] as bool? ?? false,
  );
}
