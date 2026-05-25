import Foundation
import os.log
import UserNotifications

enum StolityUploadError: Error, LocalizedError {
    case missingToken
    case invalidStartResponse
    case missingETag(partNumber: Int)
    case folderScanFailed(String)
    case folderUploadFailed(String)
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "No bearer token available"
        case .invalidStartResponse:
            return "Invalid start-multipart response (missing key or uploadId)"
        case .missingETag(let n):
            return "No ETag returned for uploaded part \(n)"
        case .folderScanFailed(let msg):
            return msg
        case .folderUploadFailed(let msg):
            return msg
        case .uploadFailed(let msg):
            return msg
        }
    }
}

let uploadLogger = Logger(
    subsystem: "com.stolity.StolityFileProvider",
    category: "upload"
)

enum StolityUploadService {

    static let apiBaseURL = "https://stolityapi.infomanav.in/api/aws"
    private static let defaultPartSize = 10 * 1024 * 1024 // 10 MB — same as DEFAULT_PART_SIZE in JS

    /// One notification per dropped filename (fileproviderd retries are deduped).
    static let loginNotificationIdentifierPrefix = "stolity.login.required"
    static let loginNotifiedFilenamesKey = "loginNotifiedFilenames"
    static let completedUploadKeysKey = "completedUploadKeys"
    static let appGroupId = "group.com.stolity.fileprovider"
    @MainActor private static var loginNotificationInFlightFilenames = Set<String>()
    @MainActor private static var uploadsInProgress = Set<String>()

    /// Call from the main app after login so each file can alert again if still logged out.
    static func resetLoginNotificationFlag() {
        let defaults = UserDefaults(suiteName: appGroupId)
        defaults?.removeObject(forKey: loginNotifiedFilenamesKey)
        defaults?.removeObject(forKey: completedUploadKeysKey)
    }

    static func uploadDedupeKey(itemIdentifier: String, filename: String, fileSize: Int) -> String {
        "\(itemIdentifier)|\(filename)|\(fileSize)"
    }

    /// Entry point for FileProviderExtension when there is no auth token (no file copy).
    static func notifyLoginRequiredFromExtension(filename: String) async {
        await notifyLoginRequired(filename: filename)
    }

    // MARK: - Public entry point

    /// Uploads once per dedupe key; skips retries from fileproviderd for the same item.
    static func uploadIfNeeded(
        dedupeKey: String,
        fileURL: URL,
        filename: String,
        token: String
    ) async {
        if completedUploadKeys().contains(dedupeKey) {
            uploadLogger.info("Upload skipped (already completed): \(dedupeKey, privacy: .public)")
            return
        }

        let shouldStart: Bool = await MainActor.run {
            if uploadsInProgress.contains(dedupeKey) { return false }
            uploadsInProgress.insert(dedupeKey)
            return true
        }
        guard shouldStart else {
            uploadLogger.info("Upload skipped (in progress): \(dedupeKey, privacy: .public)")
            return
        }

        defer {
            Task { @MainActor in uploadsInProgress.remove(dedupeKey) }
        }

        do {
            uploadLogger.info("Starting upload: \(filename, privacy: .public) key=\(dedupeKey, privacy: .public)")
            try await uploadFileMultipart(fileURL: fileURL, filename: filename, token: token)
            markUploadCompleted(dedupeKey)
            uploadLogger.info("Upload complete: \(filename, privacy: .public)")
        } catch {
            uploadLogger.error("Upload failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func upload(fileURL: URL, filename: String, token: String?) async {
        guard let token = token, !token.isEmpty else {
            uploadLogger.error("Upload failed: no token — user not logged in")
            await notifyLoginRequired(filename: filename)
            return
        }
        let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let dedupeKey = uploadDedupeKey(
            itemIdentifier: UUID().uuidString,
            filename: filename,
            fileSize: fileSize
        )
        await uploadIfNeeded(
            dedupeKey: dedupeKey,
            fileURL: fileURL,
            filename: filename,
            token: token
        )
    }

    private static func completedUploadKeys() -> Set<String> {
        Set(UserDefaults(suiteName: appGroupId)?.stringArray(forKey: completedUploadKeysKey) ?? [])
    }

    private static func markUploadCompleted(_ key: String) {
        var keys = Array(completedUploadKeys())
        if !keys.contains(key) {
            keys.append(key)
            UserDefaults(suiteName: appGroupId)?.set(keys, forKey: completedUploadKeysKey)
        }
    }

    // MARK: - Multipart upload flow (mirrors uploadFilesMultipart in JS)

    private static func uploadFileMultipart(
        fileURL: URL,
        filename: String,
        token: String,
        visibility: String = "private",
        folderPath: String? = nil
    ) async throws {
        var uploadId: String?
        var key: String?

        do {
            // 1. Start multipart upload
            let startResp = try await startMultipartUpload(
                fileName: filename,
                visibility: visibility,
                folderPath: folderPath,
                token: token
            )

            key = startResp["key"] as? String
                ?? (startResp["data"] as? [String: Any])?["key"] as? String
            uploadId = startResp["uploadId"] as? String
                ?? (startResp["data"] as? [String: Any])?["uploadId"] as? String

            guard let key = key, let uploadId = uploadId else {
                uploadLogger.error("Upload failed at startMultipart: missing key or uploadId")
                throw StolityUploadError.invalidStartResponse
            }

            uploadLogger.info("Got uploadId: \(uploadId, privacy: .public) key: \(key, privacy: .public)")

            // 2. Split file into chunks
            let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            let chunks = buildChunks(fileSize: fileSize, partSize: defaultPartSize)

            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            defer { try? fileHandle.close() }

            var parts: [[String: Any]] = []

            // 3. Upload each part
            for (index, chunk) in chunks.enumerated() {
                let partNumber = index + 1

                try fileHandle.seek(toOffset: UInt64(chunk.start))
                guard let data = try fileHandle.read(upToCount: chunk.size) else {
                    throw StolityUploadError.uploadFailed("Failed to read chunk \(partNumber)")
                }

                let partResp = try await uploadPart(
                    partNumber: partNumber,
                    uploadId: uploadId,
                    key: key,
                    data: data,
                    token: token
                )

                // Handle both "ETag" and "etag" — same fallback as JS
                guard let etag = partResp["ETag"] as? String
                    ?? partResp["etag"] as? String
                    ?? (partResp["data"] as? [String: Any])?["ETag"] as? String
                    ?? (partResp["data"] as? [String: Any])?["etag"] as? String
                else {
                    throw StolityUploadError.missingETag(partNumber: partNumber)
                }

                uploadLogger.info("Part \(partNumber, privacy: .public) uploaded, ETag: \(etag, privacy: .public)")
                parts.append(["ETag": etag, "PartNumber": partNumber])
            }

            // 4. Complete multipart upload
            do {
                try await completeMultipartUpload(key: key, uploadId: uploadId, parts: parts, token: token)
            } catch {
                uploadLogger.warning("Aborting upload for: \(filename, privacy: .public)")
                try? await abortMultipartUpload(key: key, uploadId: uploadId, token: token)
                throw error
            }

        } catch let error as StolityUploadError where error.errorDescription == StolityUploadError.invalidStartResponse.errorDescription {
            // start failed before we got key/uploadId — nothing to abort
            throw error
        } catch {
            uploadLogger.error("Upload failed at multipart flow: \(error.localizedDescription, privacy: .public)")
            if let k = key, let u = uploadId {
                uploadLogger.warning("Aborting upload for: \(filename, privacy: .public)")
                try? await abortMultipartUpload(key: k, uploadId: u, token: token)
            }
            throw error
        }
    }

    // MARK: - Chunk helpers

    private struct ChunkMeta {
        let start: Int
        let end: Int
        var size: Int { end - start }
    }

    private static func buildChunks(fileSize: Int, partSize: Int) -> [ChunkMeta] {
        var chunks: [ChunkMeta] = []
        var start = 0
        while start < fileSize {
            let end = min(start + partSize, fileSize)
            chunks.append(ChunkMeta(start: start, end: end))
            start = end
        }
        return chunks
    }

    // MARK: - API calls

    /// POST /start-multipart-upload  body: { fileName, visibility, folderPath? }
    private static func startMultipartUpload(
        fileName: String,
        visibility: String,
        folderPath: String?,
        token: String
    ) async throws -> [String: Any] {
        var body: [String: Any] = [
            "fileName": fileName,
            "visibility": visibility,
        ]
        if let fp = folderPath, !fp.isEmpty {
            body["folderPath"] = fp
        }
        return try await jsonRequest(
            endpoint: "start-multipart-upload",
            body: body,
            token: token
        )
    }

    /// POST /upload-part?partNumber=N&uploadId=X&key=Y  body: raw binary
    private static func uploadPart(
        partNumber: Int,
        uploadId: String,
        key: String,
        data: Data,
        token: String
    ) async throws -> [String: Any] {
        let encodedUploadId = uploadId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uploadId
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
        let endpoint = "upload-part?partNumber=\(partNumber)&uploadId=\(encodedUploadId)&key=\(encodedKey)"

        let url = URL(string: "\(apiBaseURL)/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResp = response as? HTTPURLResponse,
              (200..<300).contains(httpResp.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            uploadLogger.error("Upload failed at uploadPart \(partNumber, privacy: .public): HTTP \(code, privacy: .public)")
            throw StolityUploadError.uploadFailed("Upload part \(partNumber) failed with status \(code)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw StolityUploadError.uploadFailed("Upload part \(partNumber) returned invalid JSON")
        }
        return json
    }

    /// POST /complete-multipart-upload  body: { key, uploadId, parts }
    private static func completeMultipartUpload(
        key: String,
        uploadId: String,
        parts: [[String: Any]],
        token: String
    ) async throws {
        _ = try await jsonRequest(
            endpoint: "complete-multipart-upload",
            body: ["key": key, "uploadId": uploadId, "parts": parts],
            token: token
        )
    }

    /// POST /abort-multipart-upload  body: { key, uploadId }
    private static func abortMultipartUpload(
        key: String,
        uploadId: String,
        token: String
    ) async throws {
        _ = try await jsonRequest(
            endpoint: "abort-multipart-upload",
            body: ["key": key, "uploadId": uploadId],
            token: token
        )
    }

    // MARK: - Shared JSON request helper

    @discardableResult
    private static func jsonRequest(
        endpoint: String,
        body: [String: Any],
        token: String
    ) async throws -> [String: Any] {
        let url = URL(string: "\(apiBaseURL)/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResp = response as? HTTPURLResponse,
              (200..<300).contains(httpResp.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            uploadLogger.error("Upload failed at \(endpoint, privacy: .public): HTTP \(code, privacy: .public) — \(responseBody, privacy: .public)")
            throw StolityUploadError.uploadFailed("\(endpoint) failed (\(code)): \(responseBody)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    @MainActor
    private static func hasNotifiedForFilename(_ filename: String) -> Bool {
        let notified = UserDefaults(suiteName: appGroupId)?
            .stringArray(forKey: loginNotifiedFilenamesKey) ?? []
        return notified.contains(filename)
    }

    @MainActor
    private static func markNotifiedForFilename(_ filename: String) {
        var notified = UserDefaults(suiteName: appGroupId)?
            .stringArray(forKey: loginNotifiedFilenamesKey) ?? []
        if !notified.contains(filename) {
            notified.append(filename)
            UserDefaults(suiteName: appGroupId)?.set(notified, forKey: loginNotifiedFilenamesKey)
        }
    }

    @MainActor
    private static func notifyLoginRequired(filename: String) async {
        if hasNotifiedForFilename(filename) {
            uploadLogger.info(
                "Login notification suppressed for \(filename, privacy: .public) (already shown)"
            )
            return
        }
        if loginNotificationInFlightFilenames.contains(filename) {
            uploadLogger.info(
                "Login notification suppressed for \(filename, privacy: .public) (in-flight)"
            )
            return
        }
        loginNotificationInFlightFilenames.insert(filename)
        defer { loginNotificationInFlightFilenames.remove(filename) }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else {
                uploadLogger.error("Login notification skipped: permission not granted")
                return
            }
        case .authorized, .provisional:
            break
        default:
            uploadLogger.error(
                "Login notification skipped: enable notifications for Stolity in System Settings"
            )
            return
        }

        // Same identifier coalesces pending requests; do not remove delivered ones — that
        // forces macOS to show the banner again on every fileproviderd retry.
        let content = UNMutableNotificationContent()
        content.title = "Stolity"
        content.body = "Please log in to the Stolity app to upload \"\(filename)\"."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(loginNotificationIdentifierPrefix).\(filename)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            markNotifiedForFilename(filename)
        } catch {
            uploadLogger.error(
                "Login notification failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
