import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var statusItem: NSStatusItem?

  /// Chiudendo la finestra Tocco resta attivo nella barra dei menu:
  /// i tasti devono continuare a funzionare.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // MARK: Barra dei menu

  func setupStatusItem() {
    guard statusItem == nil else { return }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Tocco")
    let menu = NSMenu()
    let open = NSMenuItem(title: "Apri Tocco", action: #selector(openFromMenu), keyEquivalent: "")
    open.target = self
    menu.addItem(open)
    let pause = NSMenuItem(title: "Metti in pausa", action: #selector(togglePause(_:)), keyEquivalent: "")
    pause.target = self
    menu.addItem(pause)
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "Esci da Tocco", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    item.menu = menu
    statusItem = item
  }

  @objc private func togglePause(_ sender: NSMenuItem) {
    let paused = !KeyEngine.shared.isPaused
    KeyEngine.shared.setPaused(paused)
    sender.title = paused ? "Riprendi" : "Metti in pausa"
  }

  @objc private func openFromMenu() {
    NSApp.activate(ignoringOtherApps: true)
    mainFlutterWindow?.makeKeyAndOrderFront(nil)
  }
}
