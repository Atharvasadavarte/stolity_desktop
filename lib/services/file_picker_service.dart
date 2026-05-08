import 'dart:convert';
import 'dart:io';
import '../services/snackbar_service.dart';

import 'package:file_picker/file_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

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
  WebViewController? macController,
  WebviewController? windowsController,
) async {
  try {
    print('[DEBUG] handleFilePick called with message: $message');
    final Map<String, dynamic> data = jsonDecode(message) as Map<String, dynamic>;
    final bool isFolder = data['isFolder'] == true;
    final bool multiple = data['multiple'] == true;

    print('[DEBUG] isFolder=$isFolder, multiple=$multiple');

    if (isFolder) {
      print('[DEBUG] Folder upload detected, calling handleFolderPick');
      await handleFolderPick(macController, windowsController);
      return;
    }

    print('[DEBUG] File upload detected, showing file picker');

    // File picker logic - using FilePicker directly for file selection
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: multiple,
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      print('[DEBUG] File picker cancelled or no files selected');
      return;
    }

    print('[DEBUG] Selected ${result.files.length} files');

    final filesJs = result.files.map((f) {
      final bytes = f.bytes;
      if (bytes == null) return null;
      final b64 = base64Encode(bytes);
      final mime = getMimeType(f.name);
      return '{"name":"${_escapeJsString(f.name)}","b64":"$b64","mime":"$mime"}';
    }).whereType<String>().join(',');

    final String inputSelector = 'document.querySelector(\'input[type="file"]\')';

    if (macController != null) {
      print('[DEBUG] Injecting files into webpage');
      // ignore: avoid-dynamic, invalid function
      await macController.runJavaScript('''
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
            console.log('[JS] Injected ' + dt.files.length + ' files into input');
          } else {
            console.error('[JS] Could not find file input element');
          }
        })();
      ''');
      print('[DEBUG] File injection complete');
    }
  } catch (e) {
    print('[ERROR] File picker error: $e');
    // ignore file picker bridge errors
  }
}

Future<void> handleFolderPick(
  WebViewController? macController,
  WebviewController? windowsController,
) async {
  try {
    print('[DEBUG] handleFolderPick called');
    final String? folderPath = await FilePicker.platform.getDirectoryPath();
    print('[DEBUG] Folder selected: $folderPath');
    
    if (folderPath == null) {
      print('[DEBUG] Folder path is null, returning');
      return;
    }

    final directory = Directory(folderPath);
    final List<FileSystemEntity> entities = await directory.list(recursive: true).toList();
    
    print('[DEBUG] Found ${entities.length} entities in folder');

    final List<Map<String, dynamic>> filesData = [];
    for (final entity in entities) {
      print('[DEBUG] Entity: ${entity.path}, isFile: ${entity is File}, isDir: ${entity is Directory}');
      if (entity is File) {
        try {
          final bytes = await entity.readAsBytes();
          final name = entity.path.split('/').last;
          final relativePath = entity.path.replaceFirst('$folderPath/', '');
          filesData.add({
            'name': name,
            'relativePath': relativePath,
            'b64': base64Encode(bytes),
            'mime': getMimeType(name),
          });
          print('[DEBUG] Added file: $relativePath (${bytes.length} bytes)');
        } catch (e) {
          print('[DEBUG] Failed to read file ${entity.path}: $e');
        }
      }
    }

    print('[DEBUG] Total files to upload: ${filesData.length}');

    final filesJs = filesData.map((f) {
      final nameEscaped = _escapeJsString(f['name'] as String);
      final pathEscaped = _escapeJsString(f['relativePath'] as String);
      final b64 = f['b64'] as String;
      final mime = f['mime'] as String;
      return '{"name":"$nameEscaped","relativePath":"$pathEscaped","b64":"$b64","mime":"$mime"}';
    }).join(',');

    if (macController != null && filesData.isNotEmpty) {
      print('[DEBUG] Injecting ${filesData.length} files into webpage');
      await macController.runJavaScript("""
        (function() {
          console.log('[JS] Starting folder injection with ' + $filesJs.length + ' files');
          var filesData = [$filesJs];
          console.log('[JS] filesData length:', filesData.length);
          var dt = new DataTransfer();
          filesData.forEach(function(fd, idx) {
            console.log('[JS] Processing file', idx, ':', fd.name || fd.relativePath);
            var bytes = Uint8Array.from(atob(fd.b64), function(c) { return c.charCodeAt(0); });
            var blob = new Blob([bytes], {type: fd.mime});
            // Use the original file name and set webkitRelativePath to preserve directory structure
            var file = new File([blob], fd.name, {type: fd.mime});
            Object.defineProperty(file, 'webkitRelativePath', {
              value: fd.relativePath,
              writable: false,
              enumerable: true
            });
            dt.items.add(file);
            console.log('[JS] File added to DataTransfer with webkitRelativePath:', fd.relativePath);
          });
          console.log('[JS] DataTransfer has', dt.items.length, 'files');
          var input = document.querySelector('input[type="file"][webkitdirectory]');
          console.log('[JS] Found input with webkitdirectory:', !!input);
          if (!input) input = document.querySelector('input[type="file"]');
          console.log('[JS] Found any file input:', !!input);
          if (input) {
            Object.defineProperty(input, 'files', { value: dt.files, configurable: true });
            console.log('[JS] Set files on input, count:', input.files.length);
            input.dispatchEvent(new Event('change', {bubbles:true}));
            input.dispatchEvent(new Event('input', {bubbles:true}));
            console.log('[JS] Dispatched change and input events');
          } else {
            console.error('[JS] No file input found!');
          }
        })();
      """);
      print('[DEBUG] JavaScript injection complete');
    } else if (filesData.isEmpty) {
      print('[ERROR] No files to inject, skipping JavaScript injection');
    }
  } catch (e, stackTrace) {
    print('[ERROR] Folder picker error: $e');
    print('[ERROR] Stack trace: $stackTrace');
    // ignore folder picker errors
  }
}
