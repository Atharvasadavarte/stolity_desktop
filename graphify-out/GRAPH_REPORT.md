# Graph Report - stolity_desktop  (2026-05-15)

## Corpus Check
- 68 files · ~25,970 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 419 nodes · 598 edges · 49 communities (35 shown, 14 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 23 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `309feea1`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]

## God Nodes (most connected - your core abstractions)
1. `webview_screen.dart` - 42 edges
2. `OrderedSet` - 17 edges
3. `AppDelegate` - 16 edges
4. `SequencedContents` - 13 edges
5. `FileProviderExtension` - 11 edges
6. `uploadFilesMultipart()` - 11 edges
7. `StolityFileProviderExtension` - 11 edges
8. `BuddyFileProviderExtension` - 11 edges
9. `StolityWorkingSetEnumerator` - 10 edges
10. `StolityUploadService` - 9 edges

## Surprising Connections (you probably didn't know these)
- `main()` --calls--> `my_application_new()`  [INFERRED]
  linux/runner/main.cc → linux/runner/my_application.cc
- `my_application_activate()` --calls--> `fl_register_plugins()`  [INFERRED]
  linux/runner/my_application.cc → linux/flutter/generated_plugin_registrant.cc
- `webview_screen.dart` --defines--> `StolityWebView`  [EXTRACTED]
  lib/main.dart → lib/webview_screen.dart
- `webview_screen.dart` --defines--> `_NavPillIconButton`  [EXTRACTED]
  lib/main.dart → lib/webview_screen.dart
- `webview_screen.dart` --defines--> `_NavPillIconButtonState`  [EXTRACTED]
  lib/main.dart → lib/webview_screen.dart

## Communities (49 total, 14 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (32): auth_token_service.dart, dart:collection, dart:developer, package:flutter/foundation.dart, services/download_service.dart, _armPopupFallback, _attemptAutoLogin, _authLog (+24 more)

### Community 1 - "Community 1"
Cohesion: 0.06
Nodes (33): dart:async, dart:ui, services/file_picker_service.dart, services/window_service.dart, _buildNavigationPill, ColoredBox, Dialog, dispose (+25 more)

### Community 2 - "Community 2"
Cohesion: 0.12
Nodes (19): RegisterPlugins(), FlutterWindow(), OnCreate(), Create(), Destroy(), EnableFullDpiSupportIfAvailable(), GetClientArea(), GetThisFromHandle() (+11 more)

### Community 3 - "Community 3"
Cohesion: 0.15
Nodes (7): CustomStringConvertible, Equatable, ExpressibleByArrayLiteral, RandomAccessCollection, +(), OrderedSet, SequencedContents

### Community 4 - "Community 4"
Cohesion: 0.11
Nodes (6): NSFileProviderEnumerator, RootEnumerator, StolityRootEnumerator, StolityWorkingSetEnumerator, TrashEnumerator, WorkingSetEnumerator

### Community 5 - "Community 5"
Cohesion: 0.17
Nodes (24): abortMultipartUpload(), abortUpload(), buildEndpoint(), cancelFileUpload(), completeMultipartUpload(), copyFileToStablePath(), createCancelError(), doHttpRequest() (+16 more)

### Community 6 - "Community 6"
Cohesion: 0.1
Nodes (3): BuddyRootEnumerator, BuddyWorkingSetEnumerator, BuddyFileProviderExtension

### Community 7 - "Community 7"
Cohesion: 0.23
Nodes (9): Error, LocalizedError, ChunkMeta, StolityUploadError, invalidStartResponse, missingETag, missingToken, uploadFailed (+1 more)

### Community 8 - "Community 8"
Cohesion: 0.16
Nodes (14): package:flutter_test/flutter_test.dart, package:stolity_desktop/main.dart, package:stolity_desktop/webview_screen.dart, main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose() (+6 more)

### Community 9 - "Community 9"
Cohesion: 0.12
Nodes (16): dart:convert, dart:io, dart:typed_data, package:flutter_secure_storage/flutter_secure_storage.dart, package:flutter/services.dart, AuthTokenService, _deleteTokenFromSharedContainer, isTokenValid (+8 more)

### Community 10 - "Community 10"
Cohesion: 0.24
Nodes (3): FlutterAppDelegate, FlutterImplicitEngineDelegate, AppDelegate

### Community 11 - "Community 11"
Cohesion: 0.12
Nodes (9): PodsDummy_file_picker, PodsDummy_flutter_inappwebview_macos, PodsDummy_flutter_secure_storage_darwin, NSObject, PodsDummy_OrderedSet, PodsDummy_Pods_Runner, PodsDummy_Pods_RunnerTests, PodsDummy_screen_retriever (+1 more)

### Community 12 - "Community 12"
Cohesion: 0.15
Nodes (7): fl_register_plugins(), RegisterGeneratedPlugins(), NSWindow, GeneratedPluginRegistrant, GeneratedPluginRegistrant, -registerWithRegistry, MainFlutterWindow

### Community 13 - "Community 13"
Cohesion: 0.2
Nodes (8): ../constants.dart, package:flutter/material.dart, package:window_manager/window_manager.dart, build, main, MaterialApp, StolityApp, showReusableSnackbar

### Community 14 - "Community 14"
Cohesion: 0.24
Nodes (6): NSFileProviderItem, DummyItem, FileProviderWellKnownItems, RootItem, StolityFileItem, StolityFileProviderDomainSupport

### Community 15 - "Community 15"
Cohesion: 0.18
Nodes (10): code:swift (var set = OrderedSet<Int>()), code:ruby (pod 'OrderedSet', '5.0'), code:block3 (github "Weebly/OrderedSet"), code:swift (import OrderedSet), code:swift (package.append(.package(url: "https://github.com/Weebly/Orde), CONTRIBUTING, Installation, Introduction (+2 more)

### Community 17 - "Community 17"
Cohesion: 0.22
Nodes (8): package:file_picker/file_picker.dart, package:flutter_inappwebview/flutter_inappwebview.dart, package:webview_flutter/webview_flutter.dart, package:webview_windows/webview_windows.dart, services/snackbar_service.dart, _escapeJsString, handleFolderPick, ../utils/mime_types.dart

### Community 19 - "Community 19"
Cohesion: 0.47
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

## Knowledge Gaps
- **76 isolated node(s):** `FileProviderWellKnownItems`, `missingToken`, `invalidStartResponse`, `main`, `package:flutter_test/flutter_test.dart` (+71 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `main()` connect `Community 8` to `Community 13`?**
  _High betweenness centrality (0.080) - this node is a cross-community bridge._
- **Why does `my_application_activate()` connect `Community 8` to `Community 12`?**
  _High betweenness centrality (0.064) - this node is a cross-community bridge._
- **Why does `fl_register_plugins()` connect `Community 12` to `Community 8`?**
  _High betweenness centrality (0.064) - this node is a cross-community bridge._
- **What connects `FileProviderWellKnownItems`, `missingToken`, `invalidStartResponse` to the rest of the system?**
  _76 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.12 - nodes in this community are weakly interconnected._