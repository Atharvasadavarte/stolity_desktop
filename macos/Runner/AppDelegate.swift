import Cocoa
import FileProvider
import FlutterMacOS
import os.log
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate {

  private let logger = Logger(
    subsystem: "com.stolity",
    category: "AppDelegate"
  )

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    requestNotificationPermissionIfNeeded()
    registerFileProviderDomainIfNeeded()
    super.applicationDidFinishLaunching(aNotification)
  }

  /// Registers Stolity in System Settings → Notifications and prompts on first launch.
  private func requestNotificationPermissionIfNeeded() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
      [weak self] granted, error in
      if let error = error {
        self?.logger.error(
          "Notification permission request failed: \(error.localizedDescription, privacy: .public)"
        )
      } else {
        self?.logger.info("Notification permission granted: \(granted, privacy: .public)")
      }
    }
  }

  // MARK: - FileProvider

  /// Registers the File Provider domain exactly once, then signals the working set
  /// so fileproviderd completes the FPFS mount and Finder shows it under Locations.
  ///
  /// - Domain is never removed/re-added on first launch (that corrupts fileproviderd state).
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

  /// Called by MainFlutterWindow after Flutter delivers a token (on login or app launch).
  /// Re-registers the domain with userInfo["auth_token"] set so the File Provider
  /// extension can read it without any Keychain access.
  func updateDomainWithToken(_ token: String) {
    let targetID = NSFileProviderDomainIdentifier("com.stolity.main")
    NSFileProviderManager.getDomainsWithCompletionHandler { [weak self] domains, _ in
      if let existing = domains.first(where: { $0.identifier == targetID }) {
        NSFileProviderManager.remove(existing) { [weak self] _ in
          self?.addDomain(id: targetID, token: token)
        }
      } else {
        self?.addDomain(id: targetID, token: token)
      }
    }
  }

  private func addDomain(id: NSFileProviderDomainIdentifier, token: String) {
    let domain = NSFileProviderDomain(identifier: id, displayName: "Stolity")
    domain.userInfo = ["auth_token": token]
    NSFileProviderManager.add(domain) { [weak self] error in
      if let error = error {
        self?.logger.error("domain registration failed: \(error.localizedDescription, privacy: .public)")
      } else {
        self?.logger.info("domain registered with token")
        self?.resetLoginNotificationFlag()
        self?.signalWorkingSet(for: domain)
      }
    }
  }

  /// Clears per-file login alerts and upload dedupe state after sign-in.
  private func resetLoginNotificationFlag() {
    let defaults = UserDefaults(suiteName: "group.com.stolity.fileprovider")
    defaults?.removeObject(forKey: "loginNotifiedFilenames")
    defaults?.removeObject(forKey: "completedUploadKeys")
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
