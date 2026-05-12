import Cocoa
import FileProvider
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    cleanUpStaleFileProviderDirectory()
    reRegisterFileProviderDomain()
    super.applicationDidFinishLaunching(aNotification)
  }

  // MARK: - FileProvider helpers

  private func cleanUpStaleFileProviderDirectory() {
    guard let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else { return }

    let staleDir = appSupport
      .appendingPathComponent("FileProvider")
      .appendingPathComponent("com.stolity.StolityFileProvider")

    if FileManager.default.fileExists(atPath: staleDir.path) {
      try? FileManager.default.removeItem(at: staleDir)
    }
  }

  private func reRegisterFileProviderDomain() {
    let targetID = NSFileProviderDomainIdentifier("com.stolity.main")

    NSFileProviderManager.getDomainsWithCompletionHandler { domains, _ in
      let existingDomains = domains.filter { $0.identifier == targetID }

      let group = DispatchGroup()
      for domain in existingDomains {
        group.enter()
        NSFileProviderManager.remove(domain) { _ in
          group.leave()
        }
      }

      group.notify(queue: .main) {
        let domain = NSFileProviderDomain(
          identifier: targetID,
          displayName: "Stolity"
        )
        NSFileProviderManager.add(domain) { _ in }
      }
    }
  }

  // MARK: - NSApplicationDelegate

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
