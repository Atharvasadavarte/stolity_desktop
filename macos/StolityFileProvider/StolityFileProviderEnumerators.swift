import FileProvider

// Stable sync anchor shared by both enumerators.
let kSyncAnchor = NSFileProviderSyncAnchor(rawValue: Data([0, 0, 0, 1]))

// MARK: - Root container enumerator

/// Enumerates the root container. Returns an empty directory — no files yet.
final class RootEnumerator: NSObject, NSFileProviderEnumerator {

    func invalidate() {}

    func enumerateItems(
        for observer: NSFileProviderEnumerationObserver,
        startingAt page: NSFileProviderPage
    ) {
        observer.didEnumerate([])
        observer.finishEnumerating(upTo: nil)
    }
}

// MARK: - Trash container enumerator

/// Always-empty trash so macOS doesn't error looking for .trash.
final class TrashEnumerator: NSObject, NSFileProviderEnumerator {

    func invalidate() {}

    func enumerateItems(
        for observer: NSFileProviderEnumerationObserver,
        startingAt page: NSFileProviderPage
    ) {
        observer.didEnumerate([])
        observer.finishEnumerating(upTo: nil)
    }
}

// MARK: - Working set enumerator

/// Working-set enumerator required by NSFileProviderReplicatedExtension.
/// Reports a stable, empty working set so fileproviderd stays satisfied.
final class WorkingSetEnumerator: NSObject, NSFileProviderEnumerator {

    func invalidate() {}

    func enumerateItems(
        for observer: NSFileProviderEnumerationObserver,
        startingAt page: NSFileProviderPage
    ) {
        observer.didEnumerate([])
        observer.finishEnumerating(upTo: nil)
    }

    func enumerateChanges(
        for observer: NSFileProviderChangeObserver,
        from anchor: NSFileProviderSyncAnchor
    ) {
        // No changes ever — always report up-to-date.
        observer.finishEnumeratingChanges(upTo: kSyncAnchor, moreComing: false)
    }

    func currentSyncAnchor(
        completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void
    ) {
        completionHandler(kSyncAnchor)
    }
}
