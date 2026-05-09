import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../utils/mime_types.dart';

String _escapeJsString(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll(r"'", r"\'")
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
}

Future<void> handleFilePick(
  String message,
  InAppWebViewController? controller,
) async {
  try {
    final Map<String, dynamic> data = jsonDecode(message) as Map<String, dynamic>;
    final bool isFolder = data['isFolder'] == true;
    final bool multiple = data['multiple'] == true;

    if (isFolder) {
      await handleFolderPick(controller);
      return;
    }

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: multiple,
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final filesJs = result.files.map((f) {
      final bytes = f.bytes;
      if (bytes == null) return null;
      final b64 = base64Encode(bytes);
      final mime = getMimeType(f.name);
      return '{"name":"${_escapeJsString(f.name)}","b64":"$b64","mime":"$mime"}';
    }).whereType<String>().join(',');

    const String inputSelector =
        'document.querySelector(\'input[type="file"]\')';

    if (controller == null) return;
    await controller.evaluateJavascript(source: '''
      (function() {
        var filesData = [$filesJs];
        var dt = new DataTransfer();
        filesData.forEach(function(fd) {
          var bytes = Uint8Array.from(atob(fd.b64), function(c) { return c.charCodeAt(0); });
          var blob = new Blob([bytes], {type: fd.mime});
          var file = new File([blob], fd.name, {type: fd.mime});
          dt.items.add(file);
        });
        var input = $inputSelector;
        if (input) {
          Object.defineProperty(input, 'files', { value: dt.files, configurable: true });
          input.dispatchEvent(new Event('change', {bubbles:true}));
          input.dispatchEvent(new Event('input', {bubbles:true}));
        }
      })();
    ''');
  } catch (_) {
  }
}

Future<void> handleFolderPick(InAppWebViewController? controller) async {
  try {
    final String? folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null) return;

    final directory = Directory(folderPath);
    final List<FileSystemEntity> entities =
        await directory.list(recursive: true).toList();

    final List<Map<String, dynamic>> filesData = [];
    for (final entity in entities) {
      if (entity is File) {
        try {
          final bytes = await entity.readAsBytes();
          final name = entity.path.split('/').last;
          final relativePath =
              entity.path.replaceFirst('$folderPath/', '');
          filesData.add({
            'name': name,
            'relativePath': relativePath,
            'b64': base64Encode(bytes),
            'mime': getMimeType(name),
          });
        } catch (_) {
        }
      }
    }

    if (controller == null || filesData.isEmpty) return;

    final filesJs = filesData.map((f) {
      final nameEscaped = _escapeJsString(f['name'] as String);
      final pathEscaped = _escapeJsString(f['relativePath'] as String);
      final b64 = f['b64'] as String;
      final mime = f['mime'] as String;
      return '{"name":"$nameEscaped","relativePath":"$pathEscaped","b64":"$b64","mime":"$mime"}';
    }).join(',');

    await controller.evaluateJavascript(source: '''
      (function() {
        var filesData = [$filesJs];
        var dt = new DataTransfer();
        filesData.forEach(function(fd) {
          var bytes = Uint8Array.from(atob(fd.b64), function(c) { return c.charCodeAt(0); });
          var blob = new Blob([bytes], {type: fd.mime});
          var file = new File([blob], fd.name, {type: fd.mime});
          Object.defineProperty(file, 'webkitRelativePath', {
            value: fd.relativePath,
            writable: false,
            enumerable: true
          });
          dt.items.add(file);
        });
        var input = document.querySelector('input[type="file"][webkitdirectory]');
        if (!input) input = document.querySelector('input[type="file"]');
        if (input) {
          Object.defineProperty(input, 'files', { value: dt.files, configurable: true });
          input.dispatchEvent(new Event('change', {bubbles:true}));
          input.dispatchEvent(new Event('input', {bubbles:true}));
        }
      })();
    ''');
  } catch (_) {
  }
}
