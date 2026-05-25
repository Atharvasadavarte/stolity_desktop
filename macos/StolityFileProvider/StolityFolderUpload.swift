import Foundation
import os.log
import UniformTypeIdentifiers

extension StolityUploadService {

    struct FolderFile {
        let url: URL
        let relativePath: String
    }

    // MARK: - Folder upload entry point

    private struct FolderScanResult {
        let files: [FolderFile]
        let folderStructure: [String: String]
    }

    static func uploadFolder(
        folderURL: URL,
        token: String?,
        folderPath: String,
        isPrivate: Bool
    ) async {
        guard let token = token, !token.isEmpty else {
            uploadLogger.error("Folder upload failed: no token — user not logged in")
            await notifyLoginRequiredFromExtension(filename: folderURL.lastPathComponent)
            return
        }

        do {
            let scanResult = try scanFolder(at: folderURL)
            await uploadFolderFiles(
                folderName: folderURL.lastPathComponent,
                files: scanResult.files,
                folderPath: folderPath,
                isPrivate: isPrivate,
                token: token
            )
        } catch let error as StolityUploadError {
            uploadLogger.error("Folder upload failed: \(error.localizedDescription, privacy: .public)")
        } catch {
            uploadLogger.error("Folder upload failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func uploadFolderFiles(
        folderName: String,
        files: [FolderFile],
        folderPath: String,
        isPrivate: Bool,
        token: String
    ) async {
        uploadLogger.info("Starting folder upload: \(folderName, privacy: .public)")

        let folderStructure = files.reduce(into: [String: String]()) { partialResult, file in
            let relativeComponents = file.relativePath.split(separator: "/")
            let fileName = file.url.lastPathComponent
            let parentFolderName: String
            if relativeComponents.count > 2 {
                parentFolderName = String(relativeComponents[relativeComponents.count - 2])
            } else {
                parentFolderName = folderName
            }
            partialResult[fileName] = parentFolderName
        }

        do {
            try await uploadFolderMultipart(
                folderStructure: folderStructure,
                files: files,
                folderPath: folderPath,
                isPrivate: isPrivate,
                token: token
            )
            uploadLogger.info("Folder upload complete: \(folderName, privacy: .public)")
        } catch let error as StolityUploadError {
            uploadLogger.error("Folder upload failed: \(error.localizedDescription, privacy: .public)")
        } catch {
            uploadLogger.error("Folder upload failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Folder scanning

    private static func scanFolder(at folderURL: URL) throws -> FolderScanResult {
        let rootURL = folderURL.standardizedFileURL
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw StolityUploadError.folderScanFailed(
                "Unable to enumerate folder contents for \(folderURL.lastPathComponent)"
            )
        }

        var files: [FolderFile] = []
        var folderStructure: [String: String] = [:]
        let rootPathComponentCount = rootURL.pathComponents.count

        for case let fileURL as URL in enumerator {
            let standardizedFileURL = fileURL.standardizedFileURL
            let values = try standardizedFileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else {
                continue
            }

            let relativeComponents = standardizedFileURL.pathComponents.dropFirst(rootPathComponentCount)
            guard !relativeComponents.isEmpty else {
                continue
            }

            let relativePath = relativeComponents.joined(separator: "/")
            let fileName = standardizedFileURL.lastPathComponent
            let parentFolderName = relativeComponents.count > 1
                ? String(relativeComponents[relativeComponents.count - 2])
                : rootURL.lastPathComponent

            files.append(FolderFile(url: standardizedFileURL, relativePath: relativePath))
            folderStructure[fileName] = parentFolderName
        }

        return FolderScanResult(files: files, folderStructure: folderStructure)
    }

    // MARK: - Multipart upload flow

    static func uploadFolderMultipart(
        folderStructure: [String: String],
        files: [FolderFile],
        folderPath: String,
        isPrivate: Bool,
        token: String
    ) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        let folderStructureJSON = try JSONSerialization.data(withJSONObject: folderStructure)
        guard let folderStructureString = String(data: folderStructureJSON, encoding: .utf8) else {
            throw StolityUploadError.folderUploadFailed("Unable to encode folderStructure")
        }

        uploadLogger.info(
            "POST upload-folder: \(files.count, privacy: .public) file(s) folderPath=\(folderPath, privacy: .public) folderStructure=\(folderStructureString, privacy: .public)"
        )

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"folderStructure\"\r\n\r\n")
        body.append("\(folderStructureString)\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"folderPath\"\r\n\r\n")
        body.append("\(folderPath)\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"storageClass\"\r\n\r\n")
        body.append("STANDARD_IA\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"isPrivate\"\r\n\r\n")
        body.append(isPrivate ? "private\r\n" : "public\r\n")

        for file in files {
            guard let fileData = try? Data(contentsOf: file.url) else {
                uploadLogger.error("Skipping unreadable folder file: \(file.relativePath, privacy: .public)")
                continue
            }

            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(file.relativePath)\"\r\n")
            body.append("Content-Type: \(mimeTypeForURL(file.url))\r\n\r\n")
            body.append(fileData)
            body.append("\r\n")
        }

        body.append("--\(boundary)--\r\n")

        let url = URL(string: "\(apiBaseURL)/upload-folder")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResp = response as? HTTPURLResponse,
              (200..<300).contains(httpResp.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            uploadLogger.error("Folder upload failed at upload-folder: HTTP \(code, privacy: .public) — \(responseBody, privacy: .public)")
            throw StolityUploadError.uploadFailed("upload-folder failed (\(code)): \(responseBody)")
        }

                uploadLogger.info("upload-folder succeeded")
    }

    // MARK: - MIME types

    private static func mimeTypeForURL(_ url: URL) -> String {
        guard let type = UTType(filenameExtension: url.pathExtension),
              let mimeType = type.preferredMIMEType else {
            return "application/octet-stream"
        }
        return mimeType
    }
}

// MARK: - Multipart helpers

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}