// Validation commands:
// /usr/libexec/PlistBuddy -c "Print :NSExtensionFileProviderDocumentGroup" \
//   "$(find ~/Library/Developer/Xcode/DerivedData -name 'Info.plist' \
//   -path '*StolityFileProvider*' 2>/dev/null | head -1)"
// # Expected output: group.com.stolity.fileprovider
// codesign -d --entitlements :- \
//   "$(find ~/Library/Developer/Xcode/DerivedData \
//   -name 'StolityFileProvider.appex' 2>/dev/null | head -1)"
// log stream --predicate 'subsystem == "com.apple.fileprovider"' --level debug
import FileProvider
import UniformTypeIdentifiers

// Stable 4-byte version marker used for both content and metadata.
private let kVersionData = Data([0, 0, 0, 1])

final class FileProviderItem: NSObject, NSFileProviderItem {

    // MARK: - Required NSFileProviderItem properties

    let itemIdentifier: NSFileProviderItemIdentifier
    let parentItemIdentifier: NSFileProviderItemIdentifier
    let filename: String
    let contentType: UTType
    
    let capabilities: NSFileProviderItemCapabilities
    let itemVersion: NSFileProviderItemVersion

    // MARK: - Factory

    /// Returns the single root-container item this provider exposes.
    static func rootContainerItem() -> FileProviderItem {
        FileProviderItem(
            itemIdentifier: .rootContainer,
            parentItemIdentifier: .rootContainer,
            filename: "/",
            contentType: .folder,
            capabilities: [.allowsReading, .allowsContentEnumerating],
            itemVersion: NSFileProviderItemVersion(
                contentVersion: kVersionData,
                metadataVersion: kVersionData
            )
        )
    }

    // MARK: - Init

    private init(
        itemIdentifier: NSFileProviderItemIdentifier,
        parentItemIdentifier: NSFileProviderItemIdentifier,
        filename: String,
        contentType: UTType,
        capabilities: NSFileProviderItemCapabilities,
        itemVersion: NSFileProviderItemVersion
    ) {
        self.itemIdentifier = itemIdentifier
        self.parentItemIdentifier = parentItemIdentifier
        self.filename = filename
        self.contentType = contentType
        self.capabilities = capabilities
        self.itemVersion = itemVersion
    }
}
