import FileProvider
import UniformTypeIdentifiers

// NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).FileProviderExtension
final class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension {

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
        if identifier == .rootContainer {
            completionHandler(FileProviderItem.rootContainerItem(), nil)
        } else {
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
        let contentType = itemTemplate.contentType ?? .data
        let newItem = StolityFileItem(
            identifier: NSFileProviderItemIdentifier(UUID().uuidString),
            parentIdentifier: itemTemplate.parentItemIdentifier,
            filename: itemTemplate.filename,
            contentType: contentType
        )
        completionHandler(newItem, [], false, nil)
        return Progress(totalUnitCount: 1)
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
