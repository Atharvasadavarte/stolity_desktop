# Graph Report - stolity_desktop  (2026-05-09)

## Corpus Check
- 62 files · ~21,134 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 274 nodes · 355 edges · 43 communities (27 shown, 16 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 12 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `da6a03bf`
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

## God Nodes (most connected - your core abstractions)
1. `webview_screen.dart` - 42 edges
2. `OrderedSet` - 17 edges
3. `SequencedContents` - 13 edges
4. `AppDelegate` - 8 edges
5. `Destroy()` - 8 edges
6. `package:flutter/material.dart` - 7 edges
7. `Create()` - 6 edges
8. `MessageHandler()` - 6 edges
9. `OnCreate()` - 6 edges
10. `main()` - 5 edges

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

## Communities (43 total, 16 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.05
Nodes (65): auth_token_service.dart, dart:async, dart:collection, dart:developer, dart:ui, package:flutter/foundation.dart, services/download_service.dart, services/file_picker_service.dart (+57 more)

### Community 1 - "Community 1"
Cohesion: 0.12
Nodes (19): RegisterPlugins(), FlutterWindow(), OnCreate(), Create(), Destroy(), EnableFullDpiSupportIfAvailable(), GetClientArea(), GetThisFromHandle() (+11 more)

### Community 2 - "Community 2"
Cohesion: 0.15
Nodes (7): CustomStringConvertible, Equatable, ExpressibleByArrayLiteral, RandomAccessCollection, +(), OrderedSet, SequencedContents

### Community 3 - "Community 3"
Cohesion: 0.09
Nodes (21): dart:convert, dart:io, dart:typed_data, package:file_picker/file_picker.dart, package:flutter_inappwebview/flutter_inappwebview.dart, package:flutter_secure_storage/flutter_secure_storage.dart, package:webview_flutter/webview_flutter.dart, package:webview_windows/webview_windows.dart (+13 more)

### Community 4 - "Community 4"
Cohesion: 0.16
Nodes (14): package:flutter_test/flutter_test.dart, package:stolity_desktop/main.dart, package:stolity_desktop/webview_screen.dart, main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose() (+6 more)

### Community 5 - "Community 5"
Cohesion: 0.15
Nodes (7): fl_register_plugins(), RegisterGeneratedPlugins(), NSWindow, GeneratedPluginRegistrant, GeneratedPluginRegistrant, -registerWithRegistry, MainFlutterWindow

### Community 6 - "Community 6"
Cohesion: 0.2
Nodes (8): ../constants.dart, package:flutter/material.dart, package:window_manager/window_manager.dart, build, main, MaterialApp, StolityApp, showReusableSnackbar

### Community 7 - "Community 7"
Cohesion: 0.18
Nodes (10): code:swift (var set = OrderedSet<Int>()), code:ruby (pod 'OrderedSet', '5.0'), code:block3 (github "Weebly/OrderedSet"), code:swift (import OrderedSet), code:swift (package.append(.package(url: "https://github.com/Weebly/Orde), CONTRIBUTING, Installation, Introduction (+2 more)

### Community 8 - "Community 8"
Cohesion: 0.39
Nodes (3): FlutterAppDelegate, FlutterImplicitEngineDelegate, AppDelegate

### Community 9 - "Community 9"
Cohesion: 0.47
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

## Knowledge Gaps
- **76 isolated node(s):** `PodsDummy_window_manager`, `PodsDummy_flutter_secure_storage_darwin`, `PodsDummy_screen_retriever`, `PodsDummy_OrderedSet`, `PodsDummy_flutter_inappwebview_macos` (+71 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `main()` connect `Community 4` to `Community 6`?**
  _High betweenness centrality (0.180) - this node is a cross-community bridge._
- **Why does `my_application_activate()` connect `Community 4` to `Community 5`?**
  _High betweenness centrality (0.144) - this node is a cross-community bridge._
- **Why does `fl_register_plugins()` connect `Community 5` to `Community 4`?**
  _High betweenness centrality (0.143) - this node is a cross-community bridge._
- **What connects `PodsDummy_window_manager`, `PodsDummy_flutter_secure_storage_darwin`, `PodsDummy_screen_retriever` to the rest of the system?**
  _76 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.12 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._