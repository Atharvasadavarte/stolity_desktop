import Cocoa
import FileProvider
import FlutterMacOS
import os.log

@main
class AppDelegate: FlutterAppDelegate {

  private let logger = Logger(
    subsystem: "com.stolity",
    category: "AppDelegate"
  )

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    registerFileProviderDomainIfNeeded()
    super.applicationDidFinishLaunching(aNotification)
  }

  // MARK: - FileProvider

  /// Registers the File Provider domain exactly once, then signals the working set
  /// so fileproviderd completes the FPFS mount and Finder shows it under Locations.
  ///
  /// - Domain is never removed/re-added (that corrupts fileproviderd state).
  /// - Working set is signalled on every launch — this re-attaches the FPFS mount
  ///   if macOS dropped it between runs (e.g. after a reboot).
  private func registerFileProviderDomainIfNeeded() {
    let targetID = NSFileProviderDomainIdentifier("com.stolity.main")

    NSFileProviderManager.getDomainsWithCompletionHandler { [weak self] domains, error in
      if let error = error {
        self?.logger.error("getDomainsWithCompletionHandler failed: \(error.localizedDescription, privacy: .public)")
        return
      }

      if let existing = domains.first(where: { $0.identifier == targetID }) {
        self?.logger.info("File Provider domain already registered — signalling working set")
        self?.signalWorkingSet(for: existing)
        return
      }

      let domain = NSFileProviderDomain(
        identifier: targetID,
        displayName: "Stolity"
      )
      NSFileProviderManager.add(domain) { [weak self] error in
        if let error = error {
          self?.logger.error("NSFileProviderManager.add failed: \(error.localizedDescription, privacy: .public)")
        } else {
          self?.logger.info("File Provider domain registered — signalling working set")
          self?.signalWorkingSet(for: domain)
        }
      }
    }
  }

  /// Signals fileproviderd to fully mount the FPFS, which causes Finder to
  /// promote the provider into the sidebar under Locations.
  private func signalWorkingSet(for domain: NSFileProviderDomain) {
    guard let manager = NSFileProviderManager(for: domain) else {
      logger.error("NSFileProviderManager(for:) returned nil — check entitlements/bundle ID")
      return
    }
    manager.signalEnumerator(for: .workingSet) { [weak self] error in
      if let error = error {
        self?.logger.error("signalEnumerator(.workingSet) failed: \(error.localizedDescription, privacy: .public)")
      } else {
        self?.logger.info("signalEnumerator(.workingSet) succeeded — FPFS mount triggered")
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
