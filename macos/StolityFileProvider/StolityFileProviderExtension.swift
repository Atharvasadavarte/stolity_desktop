import FileProvider
import UniformTypeIdentifiers
import os.log


// NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).FileProviderExtension
final class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension {

    private let logger = Logger(
        subsystem: "com.stolity.StolityFileProvider",
        category: "extension"
    )

    // MARK: - Lifecycle

    init(domain: NSFileProviderDomain) {
        super.init()
    }

    func invalidate() {}

    // MARK: - Item lookup

    func item(
        for identifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        switch identifier {
        case .rootContainer:
            completionHandler(FileProviderItem.rootContainerItem(), nil)
        case .trashContainer:
            completionHandler(FileProviderItem.trashContainerItem(), nil)
        default:
            completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
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
        completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
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

        let contentType = itemTemplate.contentType ?? .data
        let newItem = StolityFileItem(
            identifier: NSFileProviderItemIdentifier(UUID().uuidString),
            parentIdentifier: itemTemplate.parentItemIdentifier,
            filename: itemTemplate.filename,
            contentType: contentType
        )

        // Copy to a stable temp location BEFORE calling completionHandler.
        // The url from fileproviderd is a temporary staging file that gets
        // reclaimed the moment completionHandler returns.
        var stableURL: URL? = nil
        if let sourceURL = url {
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "_" + itemTemplate.filename)
            do {
                try FileManager.default.copyItem(at: sourceURL, to: dest)
                stableURL = dest
                logger.info("Copied to stable path: \(dest.lastPathComponent, privacy: .public)")
            } catch {
                logger.error("Failed to copy file to stable path: \(error.localizedDescription, privacy: .public)")
            }
        }

        completionHandler(newItem, [], false, nil)
        logger.info("completionHandler called, starting background upload")

        if let uploadURL = stableURL {
            Task {
                await StolityUploadService.upload(
                    fileURL: uploadURL,
                    filename: itemTemplate.filename,
                    token: KeychainHelper.readToken()
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
        completionHandler(nil, [], false, NSFileProviderError(.serverUnreachable))
        return Progress(totalUnitCount: 1)
    }

    func deleteItem(
        identifier: NSFileProviderItemIdentifier,
        baseVersion version: NSFileProviderItemVersion,
        options: NSFileProviderDeleteItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (Error?) -> Void
    ) -> Progress {
        completionHandler(NSFileProviderError(.serverUnreachable))
        return Progress(totalUnitCount: 1)
    }
}
