import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    let phoneWidth: CGFloat = 430
    self.contentMinSize = NSSize(width: phoneWidth, height: 640)
    self.contentMaxSize = NSSize(width: phoneWidth, height: 1000)
    self.setContentSize(NSSize(width: phoneWidth, height: 820))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
