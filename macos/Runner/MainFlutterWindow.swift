import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Finestra scura senza barra del titolo visibile, come il sito e come Snella.
    self.title = "Tocco"
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true
    self.backgroundColor = NSColor(red: 13 / 255, green: 13 / 255, blue: 13 / 255, alpha: 1)
    self.appearance = NSAppearance(named: .darkAqua)

    self.minSize = NSSize(width: 1200, height: 760)
    self.setContentSize(NSSize(width: 1440, height: 900))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    KeyEngine.shared.register(with: flutterViewController.engine.binaryMessenger)
    (NSApp.delegate as? AppDelegate)?.setupStatusItem()

    super.awakeFromNib()
  }
}
