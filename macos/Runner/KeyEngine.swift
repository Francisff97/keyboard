import ApplicationServices
import Cocoa
import FlutterMacOS
import IOKit.hid

// MARK: - Configurazione (arriva da Flutter con "apply")

/// Un'azione già tradotta in keycode del Mac.
struct ActionCfg {
  let kind: String
  let mac: Int64?
  let mods: [String]
  let text: String
  let path: String
  let url: String
  let media: String
  let layer: Int

  init?(_ any: Any?) {
    guard let d = any as? [String: Any], let kind = d["kind"] as? String else { return nil }
    self.kind = kind
    mac = (d["mac"] as? NSNumber)?.int64Value
    mods = d["mods"] as? [String] ?? []
    text = d["text"] as? String ?? ""
    path = d["path"] as? String ?? ""
    url = d["url"] as? String ?? ""
    media = d["media"] as? String ?? ""
    layer = (d["layer"] as? NSNumber)?.intValue ?? 1
  }

  var flags: CGEventFlags { KeyEngine.flags(for: mods) }
}

struct BindingCfg {
  let tap: ActionCfg?
  let hold: ActionCfg?
}

/// Livelli di un dispositivo: layers[livello][codice].
/// Codice = keycode del Mac per le tastiere, numero del pulsante per i mouse.
typealias LayersCfg = [[Int64: BindingCfg]]

struct ProfileCfg {
  let global: Bool
  let bundleIds: [String]
  /// devices[idDispositivo] = livelli
  let devices: [String: LayersCfg]

  init(_ d: [String: Any]) {
    global = d["global"] as? Bool ?? false
    bundleIds = d["bundleIds"] as? [String] ?? []
    var out: [String: LayersCfg] = [:]
    for (id, raw) in d["devices"] as? [String: Any] ?? [:] {
      let layers = (raw as? [[String: Any]] ?? []).map { layer -> [Int64: BindingCfg] in
        var m: [Int64: BindingCfg] = [:]
        for (key, value) in layer {
          guard let code = Int64(key), let b = value as? [String: Any] else { continue }
          m[code] = BindingCfg(tap: ActionCfg(b["tap"]), hold: ActionCfg(b["hold"]))
        }
        return m
      }
      out[id] = layers
    }
    devices = out
  }

  func binding(device: String, layer: Int, code: Int64) -> BindingCfg? {
    guard let layers = devices[device], layer < layers.count else { return nil }
    return layers[layer][code]
  }
}

struct DeviceCfg {
  let id: String
  let isMouse: Bool
  let vendorId: Int
  let productId: Int
}

struct EngineConfig {
  var enabled = false
  var devices: [DeviceCfg] = []
  var profiles: [ProfileCfg] = []
  /// Codice HID (pagina 0x07) → keycode del Mac, per riconoscere da quale
  /// tastiera arriva un tasto.
  var hidToMac: [Int: Int64] = [:]

  /// Per ogni tastiera, i tasti "speciali" (Caps Lock e modificatori di destra)
  /// usati in qualche profilo: vanno trasformati in un tasto F con hidutil.
  var specialKeys: [(DeviceCfg, [SpecialKey])] {
    devices.compactMap { dev in
      guard !dev.isMouse else { return nil }
      let used = SpecialKey.all.filter { key in
        profiles.contains { p in p.devices[dev.id]?.contains { $0[key.mac] != nil } ?? false }
      }
      return used.isEmpty ? nil : (dev, used)
    }
  }
}

/// Tasti che macOS non manda come tasti normali (Caps Lock è un interruttore,
/// Shift/Ctrl/Alt/⌘ sono modificatori). Per usarli in Tocco, hidutil li
/// trasforma in tasti F che nessuna tastiera ha (F16–F20) e il motore li
/// riporta al tasto originale. Finché Tocco è attivo, perdono la loro funzione.
struct SpecialKey {
  /// keycode Mac del tasto vero e di quello in cui viene trasformato
  let mac: Int64
  let asMac: Int64
  /// codici HID per hidutil
  let hid: Int
  let asHid: Int

  static let all = [
    SpecialKey(mac: 57, asMac: 79, hid: 0x39, asHid: 0x6D),  // Caps Lock → F18
    SpecialKey(mac: 60, asMac: 80, hid: 0xE5, asHid: 0x6E),  // Shift destro → F19
    SpecialKey(mac: 62, asMac: 90, hid: 0xE4, asHid: 0x6F),  // Ctrl destro → F20
    SpecialKey(mac: 61, asMac: 64, hid: 0xE6, asHid: 0x6C),  // Alt destro → F17
    SpecialKey(mac: 54, asMac: 106, hid: 0xE7, asHid: 0x6B),  // ⌘ destro → F16
  ]

  static let byMac = Dictionary(uniqueKeysWithValues: all.map { ($0.mac, $0) })
  static let byAsMac = Dictionary(uniqueKeysWithValues: all.map { ($0.asMac, $0) })
}

/// Un tasto con la funzione "tenuto premuto", mentre è giù.
private struct HeldKey {
  let tap: ActionCfg?
  let hold: ActionCfg
  var used = false
}

/// L'ultima pressione vista da IOHID: da quale dispositivo e quando.
private struct Seen {
  let device: String
  let time: TimeInterval
}

// MARK: - Motore

/// Il cuore di Tocco: legge tasti e pulsanti con un event tap e li cambia
/// secondo i profili, dispositivo per dispositivo.
///
/// Parla con Flutter su due canali:
/// - "tocco/engine" (metodi): status, requestPermissions, openPrivacySettings,
///   listDevices, listApps, frontApp, apply
/// - "tocco/events" (eventi): frontApp, devices, permissions
final class KeyEngine: NSObject, FlutterStreamHandler {
  static let shared = KeyEngine()


  /// Segno sugli eventi creati da Tocco, per non rielaborarli.
  private static let marker: Int64 = 0x70CC0

  /// Entro quanto tempo un evento del Mac si considera "lo stesso" visto da IOHID.
  private static let matchWindow: TimeInterval = 0.25

  private var sink: FlutterEventSink?
  private var hid: IOHIDManager?
  private var tap: CFMachPort?
  private var tapSource: CFRunLoopSource?

  private(set) var config = EngineConfig()
  private var lastApp: NSRunningApplication?
  private var specialMapped = false
  /// Su quali tastiere i tasti speciali sono trasformati (id → keycode F → keycode vero).
  private var specialByDevice: [String: [Int64: Int64]] = [:]

  private var held: [Int64: HeldKey] = [:]
  private var layerStack: [Int] = []
  private var extraFlags: CGEventFlags = []
  private var remapped: [Int64: Int64] = [:]
  private var swallowed: Set<Int64> = []
  private var swallowedButtons: Set<Int64> = []

  /// Ultime pressioni viste da IOHID, per tasto (keycode Mac) e per pulsante.
  private var lastKey: [Int64: Seen] = [:]
  private var lastButton: [Int64: Seen] = [:]
  private var lastInputDevice = ""

  // MARK: Avvio

  func register(with messenger: FlutterBinaryMessenger) {
    let methods = FlutterMethodChannel(name: "tocco/engine", binaryMessenger: messenger)
    methods.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    FlutterEventChannel(name: "tocco/events", binaryMessenger: messenger).setStreamHandler(self)

    startHID()

    let own = Bundle.main.bundleIdentifier
    if let front = NSWorkspace.shared.frontmostApplication, front.bundleIdentifier != own {
      lastApp = front
    }
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(appActivated(_:)),
      name: NSWorkspace.didActivateApplicationNotification, object: nil)
    // Quando torni su Tocco (es. dopo aver dato i permessi) ricontrolla tutto.
    NotificationCenter.default.addObserver(
      self, selector: #selector(toccoActivated),
      name: NSApplication.didBecomeActiveNotification, object: nil)
    // Chiudendo Tocco, Caps Lock torna normale.
    NotificationCenter.default.addObserver(
      self, selector: #selector(willQuit),
      name: NSApplication.willTerminateNotification, object: nil)
  }

  @objc private func willQuit() {
    shutdown()
  }

  func shutdown() {
    stopTap()
    clearSpecialKeys()
  }

  var isPaused: Bool { !config.enabled }

  /// Freno d'emergenza dalla barra dei menu: ferma tutto e lo dice a Flutter.
  func setPaused(_ paused: Bool) {
    config.enabled = !paused
    if paused {
      stopTap()
      clearSpecialKeys()
    } else {
      mapSpecialKeys()
      startTap()
    }
    send(["type": "enabled", "enabled": !paused])
    send(statusMap())
  }

  // MARK: Canale metodi

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      result(statusMap())
    case "requestPermissions":
      let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
      _ = AXIsProcessTrustedWithOptions(opts)
      _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
      result(nil)
    case "openPrivacySettings":
      let pane = (call.arguments as? [String: Any])?["pane"] as? String
      let anchor = pane == "inputMonitoring" ? "Privacy_ListenEvent" : "Privacy_Accessibility"
      if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
        NSWorkspace.shared.open(url)
      }
      result(nil)
    case "listDevices":
      result(devices())
    case "listApps":
      result(installedApps())
    case "frontApp":
      result(lastApp.map(appMap))
    case "apply":
      apply(call.arguments as? [String: Any] ?? [:])
      result(tap != nil || !config.enabled)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func statusMap() -> [String: Any] {
    [
      "type": "permissions",
      "accessibility": AXIsProcessTrusted(),
      "inputMonitoring": IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted,
      "running": tap != nil,
    ]
  }

  // MARK: Canale eventi

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func send(_ event: [String: Any]) {
    DispatchQueue.main.async { self.sink?(event) }
  }

  // MARK: App

  @objc private func appActivated(_ note: Notification) {
    guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
      app.bundleIdentifier != Bundle.main.bundleIdentifier
    else { return }
    lastApp = app
    // Cambiando app si azzerano i tasti tenuti premuti, per sicurezza.
    resetHeld()
    var m = appMap(app)
    m["type"] = "frontApp"
    send(m)
  }

  @objc private func toccoActivated() {
    if config.enabled && tap == nil { startTap() }
    send(statusMap())
  }

  private func appMap(_ app: NSRunningApplication) -> [String: Any] {
    [
      "name": app.localizedName ?? "",
      "bundleId": app.bundleIdentifier ?? "",
      "path": app.bundleURL?.path ?? "",
    ]
  }

  private func installedApps() -> [[String: Any]] {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser.path
    let dirs = [
      "/Applications", "/Applications/Utilities", "/System/Applications",
      "/System/Applications/Utilities", "\(home)/Applications",
    ]
    var seen = Set<String>()
    var out: [[String: Any]] = []
    for dir in dirs {
      guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
      for item in items where item.hasSuffix(".app") {
        let path = "\(dir)/\(item)"
        guard let id = Bundle(path: path)?.bundleIdentifier, !seen.contains(id) else { continue }
        seen.insert(id)
        let name = (fm.displayName(atPath: path) as NSString).deletingPathExtension
        out.append(["name": name, "bundleId": id, "path": path])
      }
    }
    return out.sorted {
      ($0["name"] as? String ?? "").localizedCaseInsensitiveCompare($1["name"] as? String ?? "") == .orderedAscending
    }
  }

  // MARK: Dispositivi (IOHIDManager)

  static func deviceId(_ vendor: Int, _ product: Int) -> String {
    String(format: "%04X:%04X", vendor, product)
  }

  private func startHID() {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    let matching: [[String: Any]] = [
      [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard],
      [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse],
    ]
    IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
    let ctx = Unmanaged.passUnretained(self).toOpaque()

    let changed: IOHIDDeviceCallback = { ctx, _, _, _ in
      guard let ctx else { return }
      let engine = Unmanaged<KeyEngine>.fromOpaque(ctx).takeUnretainedValue()
      engine.send(["type": "devices", "devices": engine.devices()])
    }
    IOHIDManagerRegisterDeviceMatchingCallback(manager, changed, ctx)
    IOHIDManagerRegisterDeviceRemovalCallback(manager, changed, ctx)

    // Ogni tasto e pulsante premuto, con il dispositivo da cui arriva.
    // Serve il permesso Monitoraggio input; senza, le regole valgono per
    // tutti i dispositivi dello stesso tipo.
    let input: IOHIDValueCallback = { ctx, _, _, value in
      guard let ctx else { return }
      let engine = Unmanaged<KeyEngine>.fromOpaque(ctx).takeUnretainedValue()
      engine.recordInput(value)
    }
    IOHIDManagerRegisterInputValueCallback(manager, input, ctx)
    // Solo tasti e pulsanti: il movimento del mouse e la rotella non servono
    // e arrivano centinaia di volte al secondo.
    let inputMatching: [[String: Any]] = [
      [kIOHIDElementUsagePageKey: kHIDPage_KeyboardOrKeypad],
      [kIOHIDElementUsagePageKey: kHIDPage_Button],
    ]
    IOHIDManagerSetInputValueMatchingMultiple(manager, inputMatching as CFArray)

    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    hid = manager
  }

  private func recordInput(_ value: IOHIDValue) {
    guard IOHIDValueGetIntegerValue(value) != 0 else { return }  // solo le pressioni
    let element = IOHIDValueGetElement(value)
    let page = Int(IOHIDElementGetUsagePage(element))
    let usage = Int(IOHIDElementGetUsage(element))
    let device = IOHIDElementGetDevice(element)
    let vendor = (IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber)?.intValue ?? 0
    let product = (IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber)?.intValue ?? 0
    let id = Self.deviceId(vendor, product)
    let now = ProcessInfo.processInfo.systemUptime
    if page == kHIDPage_KeyboardOrKeypad, let mac = config.hidToMac[usage] {
      let seen = Seen(device: id, time: now)
      lastKey[mac] = seen
      // Tasto speciale trasformato: macOS manda il tasto F, IOHID vede quello vero.
      if let special = SpecialKey.byMac[mac] { lastKey[special.asMac] = seen }
    } else if page == kHIDPage_Button, usage >= 1 {
      // I mouse hanno ":M" in fondo all'id (vedi DeviceConfig.id in Flutter).
      lastButton[Int64(usage - 1)] = Seen(device: "\(id):M", time: now)
    } else {
      return
    }
    // Dico a Flutter da quale dispositivo stai scrivendo (solo quando cambia).
    let from = page == kHIDPage_Button ? "\(id):M" : id
    if from != lastInputDevice {
      lastInputDevice = from
      send(["type": "input", "device": from])
    }
  }

  /// Tastiere e mouse collegati, uno per VendorID:ProductID.
  func devices() -> [[String: Any]] {
    guard let hid, let list = IOHIDManagerCopyDevices(hid) as? Set<IOHIDDevice> else { return [] }
    var byId: [String: [String: Any]] = [:]
    for d in list {
      let vendor = (IOHIDDeviceGetProperty(d, kIOHIDVendorIDKey as CFString) as? NSNumber)?.intValue ?? 0
      let product = (IOHIDDeviceGetProperty(d, kIOHIDProductIDKey as CFString) as? NSNumber)?.intValue ?? 0
      let id = Self.deviceId(vendor, product)
      let isKeyboard = IOHIDDeviceConformsTo(d, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Keyboard))
      let isMouse = IOHIDDeviceConformsTo(d, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Mouse))
      // Le periferiche si presentano spesso come più dispositivi: li unisco.
      var entry =
        byId[id] ?? [
          "name": IOHIDDeviceGetProperty(d, kIOHIDProductKey as CFString) as? String ?? "",
          "vendorId": vendor,
          "productId": product,
          "builtIn": (IOHIDDeviceGetProperty(d, kIOHIDBuiltInKey as CFString) as? NSNumber)?.boolValue ?? false,
          "keyboard": false,
          "mouse": false,
        ]
      if isKeyboard { entry["keyboard"] = true }
      if isMouse { entry["mouse"] = true }
      byId[id] = entry
    }
    return Array(byId.values)
  }

  // MARK: Applica la configurazione

  private func apply(_ args: [String: Any]) {
    var c = EngineConfig()
    c.enabled = args["enabled"] as? Bool ?? false
    c.devices = (args["devices"] as? [[String: Any]] ?? []).compactMap { d in
      guard let id = d["id"] as? String else { return nil }
      return DeviceCfg(
        id: id,
        isMouse: d["kind"] as? String == "mouse",
        vendorId: (d["vendorId"] as? NSNumber)?.intValue ?? 0,
        productId: (d["productId"] as? NSNumber)?.intValue ?? 0)
    }
    c.profiles = (args["profiles"] as? [[String: Any]] ?? []).map(ProfileCfg.init)
    for (k, v) in args["hidToMac"] as? [String: Any] ?? [:] {
      if let usage = Int(k), let mac = (v as? NSNumber)?.int64Value { c.hidToMac[usage] = mac }
    }
    config = c
    resetHeld()
    clearSpecialKeys()
    if c.enabled {
      mapSpecialKeys()
      startTap()
    } else {
      stopTap()
    }
    send(statusMap())
  }

  /// Trasforma i tasti speciali usati nei profili, solo sulle tastiere interessate.
  /// La trasformazione sparisce al riavvio del Mac e quando Tocco si chiude.
  private func mapSpecialKeys() {
    specialByDevice = [:]
    for (dev, keys) in config.specialKeys {
      let entries = keys.map {
        "{\"HIDKeyboardModifierMappingSrc\":\(0x7_0000_0000 + $0.hid),\"HIDKeyboardModifierMappingDst\":\(0x7_0000_0000 + $0.asHid)}"
      }
      let mapping = "{\"UserKeyMapping\":[\(entries.joined(separator: ","))]}"
      let matching = "{\"VendorID\":\(dev.vendorId),\"ProductID\":\(dev.productId)}"
      if hidutil(["property", "--matching", matching, "--set", mapping]) {
        specialMapped = true
        specialByDevice[dev.id] = Dictionary(uniqueKeysWithValues: keys.map { ($0.asMac, $0.mac) })
      }
    }
  }

  /// Toglie le trasformazioni (e, attenzione, anche altre fatte a mano con hidutil).
  private func clearSpecialKeys() {
    specialByDevice = [:]
    guard specialMapped else { return }
    hidutil(["property", "--set", #"{"UserKeyMapping":[]}"#])
    specialMapped = false
  }

  @discardableResult
  private func hidutil(_ args: [String]) -> Bool {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
    task.arguments = args
    task.standardOutput = FileHandle.nullDevice
    do {
      try task.run()
      task.waitUntilExit()
      return task.terminationStatus == 0
    } catch {
      NSLog("Tocco: hidutil non riuscito: \(error)")
      return false
    }
  }

  // MARK: Event tap

  private func startTap() {
    guard tap == nil, AXIsProcessTrusted() else { return }
    let types: [CGEventType] = [.keyDown, .keyUp, .otherMouseDown, .otherMouseUp, .rightMouseDown, .rightMouseUp]
    let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
    let ctx = Unmanaged.passUnretained(self).toOpaque()
    guard
      let port = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
        eventsOfInterest: mask,
        callback: { _, type, event, ctx in
          guard let ctx else { return Unmanaged.passUnretained(event) }
          let engine = Unmanaged<KeyEngine>.fromOpaque(ctx).takeUnretainedValue()
          return engine.process(type: type, event: event)
        }, userInfo: ctx)
    else {
      NSLog("Tocco: event tap non creato (manca il permesso Accessibilità?)")
      return
    }
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: port, enable: true)
    tap = port
    tapSource = source
  }

  private func stopTap() {
    if let port = tap { CGEvent.tapEnable(tap: port, enable: false) }
    if let source = tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    tap = nil
    tapSource = nil
    resetHeld()
  }

  private func resetHeld() {
    held.removeAll()
    layerStack.removeAll()
    extraFlags = []
    remapped.removeAll()
    swallowed.removeAll()
    swallowedButtons.removeAll()
  }

  /// Da quale dispositivo arriva l'evento? Lo dice IOHID, se l'ha visto da poco.
  private func source(_ seen: Seen?) -> String? {
    guard let seen, ProcessInfo.processInfo.systemUptime - seen.time < Self.matchWindow else { return nil }
    return seen.device
  }

  /// Ogni tasto e pulsante passa da qui. nil = l'evento sparisce.
  private func process(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let port = tap { CGEvent.tapEnable(tap: port, enable: true) }
      return Unmanaged.passUnretained(event)
    }
    guard config.enabled, event.getIntegerValueField(.eventSourceUserData) != Self.marker else {
      return Unmanaged.passUnretained(event)
    }
    switch type {
    case .keyDown, .keyUp:
      return processKey(down: type == .keyDown, event: event)
    case .otherMouseDown, .otherMouseUp, .rightMouseDown, .rightMouseUp:
      return processButton(down: type == .otherMouseDown || type == .rightMouseDown, event: event)
    default:
      return Unmanaged.passUnretained(event)
    }
  }

  // MARK: Pulsanti del mouse

  private func processButton(down: Bool, event: CGEvent) -> Unmanaged<CGEvent>? {
    let button = event.getIntegerValueField(.mouseEventButtonNumber)
    if !down {
      return swallowedButtons.remove(button) != nil ? nil : Unmanaged.passUnretained(event)
    }
    let device = source(lastButton[button])
    guard let action = lookup(button, mouse: true, device: device)?.tap else {
      return Unmanaged.passUnretained(event)
    }
    swallowedButtons.insert(button)
    if action.kind == "remap", let mac = action.mac {
      postKey(mac, flags: extraFlags)
    } else {
      perform(action)
    }
    return nil
  }

  // MARK: Tasti

  private func processKey(down: Bool, event: CGEvent) -> Unmanaged<CGEvent>? {
    var code = event.getIntegerValueField(.keyboardEventKeycode)
    let device = source(lastKey[code])
    // Tasto speciale trasformato in un tasto F: torno al tasto vero.
    if let original = SpecialKey.byAsMac[code], specialMapped,
      device.map({ specialByDevice[$0]?[code] != nil }) ?? true
    {
      code = original.mac
    }
    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

    // --- Rilascio ---------------------------------------------------------
    if !down {
      if let h = held.removeValue(forKey: code) {
        release(h)
        if !h.used, let t = h.tap { perform(t) }
        return nil
      }
      if let target = remapped.removeValue(forKey: code) {
        event.setIntegerValueField(.keyboardEventKeycode, value: target)
        return Unmanaged.passUnretained(event)
      }
      if swallowed.remove(code) != nil { return nil }
      return withExtraFlags(event)
    }

    // --- Pressione --------------------------------------------------------
    if held[code] != nil { return nil }  // ripetizione di un tasto tenuto
    // Un altro tasto mentre ne tieni uno: quello tenuto vale come "tenuto".
    for k in held.keys { held[k]?.used = true }

    guard let binding = lookup(code, mouse: false, device: device) else {
      return withExtraFlags(event)
    }

    if let hold = binding.hold, !isRepeat {
      held[code] = HeldKey(tap: binding.tap, hold: hold)
      switch hold.kind {
      case "layer": layerStack.append(hold.layer)
      case "modifier": extraFlags.formUnion(hold.flags)
      case "shortcut":
        // Scorciatoia tenendo premuto: parte dopo 250 ms se il tasto è ancora giù.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
          guard let self, var h = self.held[code], !h.used else { return }
          h.used = true
          self.held[code] = h
          self.perform(hold)
        }
      default: break
      }
      return nil
    }

    guard let action = binding.tap else { return withExtraFlags(event) }
    switch action.kind {
    case "remap":
      guard let target = action.mac else { return Unmanaged.passUnretained(event) }
      event.setIntegerValueField(.keyboardEventKeycode, value: target)
      remapped[code] = target
      return withExtraFlags(event)
    case "disabled":
      swallowed.insert(code)
      return nil
    default:
      swallowed.insert(code)
      if !isRepeat || action.kind == "shortcut" { perform(action) }
      return nil
    }
  }

  private func release(_ h: HeldKey) {
    switch h.hold.kind {
    case "layer":
      if let i = layerStack.lastIndex(of: h.hold.layer) { layerStack.remove(at: i) }
    case "modifier":
      extraFlags.subtract(h.hold.flags)
    default: break
    }
  }

  private func withExtraFlags(_ event: CGEvent) -> Unmanaged<CGEvent> {
    if !extraFlags.isEmpty { event.flags.formUnion(extraFlags) }
    return Unmanaged.passUnretained(event)
  }

  /// Cerca cosa fa il tasto:
  /// dispositivo da cui arriva (o, se non si sa, tutti quelli dello stesso tipo),
  /// profilo dell'app e poi Globale, livello attivo e poi Base.
  /// Un dispositivo non gestito non è in config.devices: i suoi tasti restano normali.
  private func lookup(_ code: Int64, mouse: Bool, device: String?) -> BindingCfg? {
    let candidates: [String]
    if let device {
      guard config.devices.contains(where: { $0.id == device }) else { return nil }
      candidates = [device]
    } else {
      candidates = config.devices.filter { $0.isMouse == mouse }.map(\.id)
    }
    let bundle = lastApp?.bundleIdentifier ?? ""
    let appProfile = config.profiles.first { !$0.global && $0.bundleIds.contains(bundle) }
    let global = config.profiles.first { $0.global }
    let layer = layerStack.last ?? 0
    for dev in candidates {
      for l in Set([layer, 0]).sorted(by: >) {
        if let b = appProfile?.binding(device: dev, layer: l, code: code)
          ?? global?.binding(device: dev, layer: l, code: code)
        {
          return b
        }
      }
    }
    return nil
  }

  // MARK: Azioni

  private func perform(_ a: ActionCfg) {
    switch a.kind {
    case "shortcut", "remap":
      if let mac = a.mac { postKey(mac, flags: a.flags.union(extraFlags)) }
    case "text":
      typeText(a.text)
    case "app":
      NSWorkspace.shared.openApplication(
        at: URL(fileURLWithPath: a.path), configuration: NSWorkspace.OpenConfiguration())
    case "url":
      if let url = URL(string: a.url) { NSWorkspace.shared.open(url) }
    case "media":
      postMedia(a.media)
    case "webhook":
      guard let url = URL(string: a.url) else { return }
      var req = URLRequest(url: url)
      req.httpMethod = "POST"
      req.timeoutInterval = 5
      URLSession.shared.dataTask(with: req).resume()
    default:
      break
    }
  }

  private func postKey(_ mac: Int64, flags: CGEventFlags) {
    let src = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
      guard let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(mac), keyDown: down) else { continue }
      e.flags = flags
      e.setIntegerValueField(.eventSourceUserData, value: Self.marker)
      e.post(tap: .cgSessionEventTap)
    }
  }

  private func typeText(_ text: String) {
    let src = CGEventSource(stateID: .hidSystemState)
    let units = Array(text.utf16)
    // A pezzi da 20 caratteri: alcune app ignorano stringhe più lunghe.
    var i = 0
    while i < units.count {
      var chunk = Array(units[i..<min(i + 20, units.count)])
      for down in [true, false] {
        guard let e = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: down) else { continue }
        e.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
        e.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        e.post(tap: .cgSessionEventTap)
      }
      i += 20
    }
  }

  /// Tasti multimediali: si mandano come eventi di sistema (NX_KEYTYPE_*).
  private func postMedia(_ name: String) {
    let codes: [String: Int] = [
      "volumeUp": 0, "volumeDown": 1, "brightnessUp": 2, "brightnessDown": 3,
      "mute": 7, "playPause": 16, "next": 17, "previous": 18,
    ]
    guard let key = codes[name] else { return }
    for down in [true, false] {
      let state = down ? 0xA : 0xB
      let e = NSEvent.otherEvent(
        with: .systemDefined, location: .zero,
        modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
        timestamp: 0, windowNumber: 0, context: nil, subtype: 8,
        data1: (key << 16) | (state << 8), data2: -1)
      e?.cgEvent?.post(tap: .cghidEventTap)
    }
  }

  static func flags(for mods: [String]) -> CGEventFlags {
    var f: CGEventFlags = []
    for m in mods {
      switch m {
      case "cmd": f.insert(.maskCommand)
      case "opt": f.insert(.maskAlternate)
      case "ctrl": f.insert(.maskControl)
      case "shift": f.insert(.maskShift)
      default: break
      }
    }
    return f
  }
}
