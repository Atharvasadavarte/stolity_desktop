import FileProvider
import UniformTypeIdentifiers
import os.log


// NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).FileProviderExtension
final class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension {

    private let logger = Logger(
        subsystem: "com.stolity.StolityFileProvider",
        category: "extension"
    )

    private let domain: NSFileProviderDomain

    // MARK: - Lifecycle

    required init(domain: NSFileProviderDomain) {
        self.domain = domain
        super.init()
    }

    private func getToken() -> String? {
        return domain.userInfo?["auth_token"] as? String
    }

    func invalidate() {}

    // MARK: - Item lookup

    func item(
        for identifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        let item: NSFileProviderItem?
        switch identifier {
        case .rootContainer:
            item = RootItem()
        case .trashContainer:
            item = FileProviderItem.trashContainerItem()
        default:
            if identifier == FileProviderWellKnownItems.welcomeIdentifier {
                item = DummyItem.welcome
            } else {
                item = nil
            }
        }
        completionHandler(item, item == nil ? NSFileProviderError(.noSuchItem) : nil)
        return Progress(totalUnitCount: 1)
    }

    // MARK: - Enumeration

    func enumerator(
        for containerItemIdentifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest
    ) throws -> NSFileProviderEnumerator {
        switch containerItemIdentifier {
        case .rootContainer:
            return RootEnumerator()
        case .trashContainer:
            return TrashEnumerator()
        case .workingSet:
            return WorkingSetEnumerator()
        default:
            throw NSFileProviderError(.noSuchItem)
        }
    }

    // MARK: - Content fetching (files only — this provider has none)

    func fetchContents(
        for itemIdentifier: NSFileProviderItemIdentifier,
        version requestedVersion: NSFileProviderItemVersion?,
        request: NSFileProviderRequest,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        guard itemIdentifier == FileProviderWellKnownItems.welcomeIdentifier else {
            completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
            return Progress(totalUnitCount: 1)
        }

        let body = """
        Welcome to Stolity.

        Your cloud files will appear here once syncing is enabled.
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("welcome-\(UUID().uuidString).txt")
        do {
            try body.write(to: url, atomically: true, encoding: .utf8)
            completionHandler(url, DummyItem.welcome, nil)
        } catch {
            completionHandler(nil, nil, error)
        }
        return Progress(totalUnitCount: 1)
    }

    // MARK: - Mutations (read-only provider — all rejected)

    func createItem(
        basedOn itemTemplate: NSFileProviderItem,
        fields: NSFileProviderItemFields,
        contents url: URL?,
        options: NSFileProviderCreateItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) -> Progress {
        logger.info("createItem called: \(itemTemplate.filename, privacy: .public)")
        logger.info("Content URL present: \(url != nil, privacy: .public)")

        let itemId: NSFileProviderItemIdentifier
        if itemTemplate.itemIdentifier == .rootContainer
            || itemTemplate.itemIdentifier.rawValue.isEmpty {
            itemId = NSFileProviderItemIdentifier(UUID().uuidString)
        } else {
            itemId = itemTemplate.itemIdentifier
        }

        let newItem = StolityFileItem(
            identifier: itemId,
            parentIdentifier: itemTemplate.parentItemIdentifier,
            filename: itemTemplate.filename,
            contentType: itemTemplate.contentType ?? .data
        )

        guard let token = getToken(), !token.isEmpty else {
            completionHandler(nil, [], false, NSFileProviderError(.notAuthenticated))
            Task {
                await StolityUploadService.notifyLoginRequiredFromExtension(
                    filename: itemTemplate.filename
                )
            }
            return Progress()
        }

        // Metadata-only create (no file bytes) — acknowledge so fileproviderd stops retrying.
        guard let sourceURL = url else {
            completionHandler(newItem, [], false, nil)
            return Progress()
        }

        // Copy before completionHandler; staging URL is reclaimed when we return.
        var stableURL: URL?
        var fileSize = 0
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "_" + itemTemplate.filename)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            stableURL = dest
            fileSize = try dest.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            logger.info("Copied to stable path: \(dest.lastPathComponent, privacy: .public)")
        } catch {
            logger.error("Failed to copy file to stable path: \(error.localizedDescription, privacy: .public)")
            completionHandler(nil, [], false, error)
            return Progress()
        }

        // Success stops fileproviderd from retrying create-item (which re-triggered uploads).
        completionHandler(newItem, [], false, nil)

        if let uploadURL = stableURL {
            let dedupeKey = StolityUploadService.uploadDedupeKey(
                itemIdentifier: itemId.rawValue,
                filename: itemTemplate.filename,
                fileSize: fileSize
            )
            Task {
                await StolityUploadService.uploadIfNeeded(
                    dedupeKey: dedupeKey,
                    fileURL: uploadURL,
                    filename: itemTemplate.filename,
                    token: token
                )
                try? FileManager.default.removeItem(at: uploadURL)
            }
        }

        return Progress()
    }

    func modifyItem(
        _ item: NSFileProviderItem,
        baseVersion version: NSFileProviderItemVersion,
        changedFields: NSFileProviderItemFields,
        contents newContents: URL?,
        options: NSFileProviderModifyItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) -> Progress {
        // Acknowledge the modification silently. Returning a server error here
        // blocks fileproviderd reconciliation and prevents FPFS mount.
        logger.info("modifyItem: \(item.filename, privacy: .public) — acknowledged")
        completionHandler(item, [], false, nil)
        return Progress(totalUnitCount: 1)
    }

    func deleteItem(
        identifier: NSFileProviderItemIdentifier,
        baseVersion version: NSFileProviderItemVersion,
        options: NSFileProviderDeleteItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (Error?) -> Void
    ) -> Progress {
        // Acknowledge deletion silently. Returning a server error here causes
        // fileproviderd to retry indefinitely, stalling the FPFS mount and
        // generating the repeated -1004 errors seen in logs.
        logger.info("deleteItem: \(identifier.rawValue, privacy: .public) — acknowledged")
        completionHandler(nil)
        return Progress(totalUnitCount: 1)
    }
}
