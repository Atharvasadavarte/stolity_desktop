import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class DownloadService {
  static Directory _downloadsDirectory() {
    final env = Platform.environment;
    if (Platform.isMacOS || Platform.isLinux) {
      final home = env['HOME'] ?? '';
      return Directory('$home/Downloads');
    }
    if (Platform.isWindows) {
      final profile = env['USERPROFILE'] ?? '';
      return Directory('$profile\\Downloads');
    }
    // Fallback to current directory
    return Directory.current;
  }

  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  static Future<String> _uniquePathFor(String baseName) async {
    final dir = _downloadsDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    var path = '${dir.path}${Platform.pathSeparator}$baseName';
    var file = File(path);
    if (!await file.exists()) return path;
    final dot = baseName.lastIndexOf('.');
    final name = dot > 0 ? baseName.substring(0, dot) : baseName;
    final ext = dot > 0 ? baseName.substring(dot) : '';
    var i = 1;
    while (await file.exists()) {
      path = '${dir.path}${Platform.pathSeparator}${name} ($i)$ext';
      file = File(path);
      i += 1;
    }
    return path;
  }

  static String _filenameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (last.isNotEmpty) return _sanitizeFileName(last);
    } catch (_) {}
    return 'downloaded_file';
  }

  static String? _filenameFromContentDisposition(String? header) {
    if (header == null) return null;
    try {
      // filename*=UTF-8''name.ext or filename="name.ext"
      final fnStar = RegExp(r"filename\*=(?:UTF-8'')?([^;]+)", caseSensitive: false).firstMatch(header);
      if (fnStar != null) return Uri.decodeFull(fnStar.group(1)!.trim().replaceAll('"', ''));
      final fn = RegExp(r'filename="?([^\";]+)"?', caseSensitive: false).firstMatch(header);
      if (fn != null) return fn.group(1)!.trim();
    } catch (_) {}
    return null;
  }

  static Future<File> saveBytes(Uint8List bytes, String filename) async {
    final safe = _sanitizeFileName(filename.isNotEmpty ? filename : 'downloaded_file');
    final target = await _uniquePathFor(safe);
    final file = File(target);
    try {
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      rethrow;
    }
  }

  static Future<File> downloadUrl(String url, {String? suggestedFilename}) async {
    final client = HttpClient();
    final uri = Uri.parse(url);
    final request = await client.getUrl(uri);
    request.followRedirects = true;
    final response = await request.close();

    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw HttpException('HTTP ${response.statusCode} when downloading $url');
    }

    String filename = suggestedFilename ?? '';
    if (filename.isEmpty) {
      filename = _filenameFromContentDisposition(response.headers.value('content-disposition')) ?? _filenameFromUrl(url);
    }
    filename = _sanitizeFileName(filename);

    final targetPath = await _uniquePathFor(filename);
    final outFile = File(targetPath);
    IOSink? sink;
    try {
      sink = outFile.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      return outFile;
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}
      rethrow;
    }
  }

  static Future<File> downloadBase64(String base64data, String filename) async {
    final bytes = base64Decode(base64data);
    return await saveBytes(bytes, filename);
  }
}
