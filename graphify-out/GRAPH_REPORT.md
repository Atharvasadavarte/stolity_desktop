# Graph Report - .  (2026-05-07)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 156 nodes · 161 edges · 29 communities (18 shown, 11 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 8 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `45c315cd`
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
- [[_COMMUNITY_Community 26|Community 26]]

## God Nodes (most connected - your core abstractions)
1. `webview_screen.dart` - 42 edges
2. `Create()` - 6 edges
3. `MessageHandler()` - 6 edges
4. `Destroy()` - 6 edges
5. `OnCreate()` - 6 edges
6. `package:flutter/material.dart` - 5 edges
7. `main()` - 4 edges
8. `WndProc()` - 4 edges
9. `GetClientArea()` - 4 edges
10. `RunnerTests` - 3 edges

## Surprising Connections (you probably didn't know these)
- `OnCreate()` --calls--> `RegisterPlugins()`  [INFERRED]
  windows/runner/win32_window.cpp → windows/flutter/generated_plugin_registrant.cc
- `my_application_activate()` --calls--> `fl_register_plugins()`  [INFERRED]
  linux/runner/my_application.cc → linux/flutter/generated_plugin_registrant.cc
- `webview_screen.dart` --defines--> `StolityWebView`  [EXTRACTED]
  lib/main.dart → lib/webview_screen.dart
- `webview_screen.dart` --defines--> `_NavPillIconButton`  [EXTRACTED]
  lib/main.dart → lib/webview_screen.dart
- `webview_screen.dart` --defines--> `_NavPillIconButtonState`  [EXTRACTED]
  lib/main.dart → lib/webview_screen.dart

## Communities (29 total, 11 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (35): dart:async, dart:ui, services/download_service.dart, services/file_picker_service.dart, services/snackbar_service.dart, services/window_service.dart, _buildNavigationPill, ColoredBox (+27 more)

### Community 1 - "Community 1"
Cohesion: 0.18
Nodes (14): Create(), Destroy(), EnableFullDpiSupportIfAvailable(), GetClientArea(), GetThisFromHandle(), GetWindowClass(), MessageHandler(), OnCreate() (+6 more)

### Community 2 - "Community 2"
Cohesion: 0.12
Nodes (16): dart:convert, dart:io, dart:typed_data, package:file_picker/file_picker.dart, package:webview_flutter/webview_flutter.dart, package:webview_windows/webview_windows.dart, Directory, _downloadsDirectory (+8 more)

### Community 3 - "Community 3"
Cohesion: 0.14
Nodes (4): package:flutter_test/flutter_test.dart, package:stolity_desktop/main.dart, package:stolity_desktop/webview_screen.dart, main()

### Community 4 - "Community 4"
Cohesion: 0.2
Nodes (6): fl_register_plugins(), RegisterPlugins(), RegisterGeneratedPlugins(), NSWindow, -registerWithRegistry, my_application_activate()

### Community 5 - "Community 5"
Cohesion: 0.24
Nodes (7): constants.dart, package:flutter/material.dart, package:window_manager/window_manager.dart, build, MaterialApp, StolityApp, showReusableSnackbar

### Community 7 - "Community 7"
Cohesion: 0.47
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

## Knowledge Gaps
- **62 isolated node(s):** `PodsDummy_window_manager`, `PodsDummy_screen_retriever`, `PodsDummy_webview_flutter_wkwebview`, `PodsDummy_Pods_Runner`, `PodsDummy_file_picker` (+57 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `webview_screen.dart` connect `Community 0` to `Community 2`, `Community 5`?**
  _High betweenness centrality (0.341) - this node is a cross-community bridge._
- **Why does `main()` connect `Community 3` to `Community 5`?**
  _High betweenness centrality (0.249) - this node is a cross-community bridge._
- **Why does `my_application_activate()` connect `Community 4` to `Community 3`?**
  _High betweenness centrality (0.194) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `OnCreate()` (e.g. with `SetChildContent()` and `GetClientArea()`) actually correct?**
  _`OnCreate()` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PodsDummy_window_manager`, `PodsDummy_screen_retriever`, `PodsDummy_webview_flutter_wkwebview` to the rest of the system?**
  _62 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.12 - nodes in this community are weakly interconnected._