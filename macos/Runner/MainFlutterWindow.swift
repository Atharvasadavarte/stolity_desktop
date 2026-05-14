import Cocoa
import FlutterMacOS
import Security
import os.log

class MainFlutterWindow: NSWindow {

  private static let keychainService     = "com.stolity.token"
  private static let keychainAccount     = "bearer"
  private static let keychainAccessGroup = "ZLL9J8KZ7J.com.stolity.shared"

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

  // MARK: - Keychain Token Bridge
  // Shares the bearer token with the File Provider extension via the
  // macOS Keychain using a shared access group. This is the only
  // reliable cross-process sharing mechanism on sandboxed macOS.

  private func registerTokenChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.stolity/app_group_token",
      binaryMessenger: messenger
    )
    let log = Logger(subsystem: "com.stolity.StolityFileProvider", category: "host-bridge")

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "writeToken":
        guard let token = call.arguments as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "token argument required", details: nil))
          return
        }

        SecItemDelete([
          kSecClass:           kSecClassGenericPassword,
          kSecAttrService:     Self.keychainService,
          kSecAttrAccessGroup: Self.keychainAccessGroup,
        ] as CFDictionary)

        let status = SecItemAdd([
          kSecClass:           kSecClassGenericPassword,
          kSecAttrService:     Self.keychainService,
          kSecAttrAccount:     Self.keychainAccount,
          kSecAttrAccessGroup: Self.keychainAccessGroup,
          kSecValueData:       token.data(using: .utf8)!,
          kSecAttrAccessible:  kSecAttrAccessibleAfterFirstUnlock,
        ] as CFDictionary, nil)

        log.info("Keychain write status: \(status, privacy: .public) (0 = success)")
        if status == errSecSuccess {
          result(nil)
        } else {
          result(FlutterError(code: "KEYCHAIN_WRITE_FAILED",
                              message: "SecItemAdd status: \(status)", details: nil))
        }

      case "deleteToken":
        SecItemDelete([
          kSecClass:           kSecClassGenericPassword,
          kSecAttrService:     Self.keychainService,
          kSecAttrAccessGroup: Self.keychainAccessGroup,
        ] as CFDictionary)
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
