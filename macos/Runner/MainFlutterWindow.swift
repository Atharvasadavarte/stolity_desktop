import Cocoa
import FileProvider
import FlutterMacOS
import os.log

class MainFlutterWindow: NSWindow {

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(NSSize(width: 1280, height: 800))
    self.title = "Stolity"
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerTokenChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  // MARK: - Domain Token Bridge
  // Passes the bearer token from Flutter to the File Provider extension via
  // NSFileProviderDomain.userInfo — Apple's designed mechanism for host-to-
  // extension config. No Keychain, no prompts.

  private func registerTokenChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.stolity/app_group_token",
      binaryMessenger: messenger
    )
    let log = Logger(subsystem: "com.stolity", category: "host-bridge")

    channel.setMethodCallHandler { call, result in
      switch call.method {

      case "updateDomainToken":
        guard let token = call.arguments as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "token required", details: nil))
          return
        }
        if let appDelegate = NSApp.delegate as? AppDelegate {
          appDelegate.updateDomainWithToken(token)
          log.info("updateDomainToken forwarded to AppDelegate")
        }
        result(nil)

      case "clearDomainToken":
        let targetID = NSFileProviderDomainIdentifier("com.stolity.main")
        NSFileProviderManager.getDomainsWithCompletionHandler { domains, _ in
          if let existing = domains.first(where: { $0.identifier == targetID }) {
            NSFileProviderManager.remove(existing) { _ in
              let domain = NSFileProviderDomain(
                identifier: targetID,
                displayName: "Stolity"
              )
              // Re-add without userInfo so the extension sees no token
              NSFileProviderManager.add(domain) { error in
                if let error = error {
                  log.error("clearDomainToken re-add failed: \(error.localizedDescription, privacy: .public)")
                } else {
                  log.info("domain re-registered without token (logout)")
                }
              }
            }
          }
        }
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
