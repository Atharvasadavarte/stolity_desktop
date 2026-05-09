# Graph Report - macos  (2026-05-08)

## Corpus Check
- 22 files · ~8,749 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 77 nodes · 83 edges · 22 communities (11 shown, 11 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 1 edges (avg confidence: 0.8)
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

## God Nodes (most connected - your core abstractions)
1. `OrderedSet` - 17 edges
2. `SequencedContents` - 13 edges
3. `Installation` - 5 edges
4. `AppDelegate` - 4 edges
5. `RunnerTests` - 3 edges
6. `MainFlutterWindow` - 3 edges
7. `+()` - 3 edges
8. `RegisterGeneratedPlugins()` - 2 edges
9. `Usage` - 2 edges
10. `PodsDummy_window_manager` - 1 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (22 total, 11 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.16
Nodes (6): CustomStringConvertible, Equatable, ExpressibleByArrayLiteral, RandomAccessCollection, +(), OrderedSet

### Community 2 - "Community 2"
Cohesion: 0.18
Nodes (10): code:swift (var set = OrderedSet<Int>()), code:ruby (pod 'OrderedSet', '5.0'), code:block3 (github "Weebly/OrderedSet"), code:swift (import OrderedSet), code:swift (package.append(.package(url: "https://github.com/Weebly/Orde), CONTRIBUTING, Installation, Introduction (+2 more)

### Community 3 - "Community 3"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), NSWindow, MainFlutterWindow

## Knowledge Gaps
- **16 isolated node(s):** `PodsDummy_window_manager`, `PodsDummy_flutter_secure_storage_darwin`, `PodsDummy_screen_retriever`, `PodsDummy_OrderedSet`, `PodsDummy_flutter_inappwebview_macos` (+11 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `OrderedSet` connect `Community 0` to `Community 1`?**
  _High betweenness centrality (0.063) - this node is a cross-community bridge._
- **Why does `SequencedContents` connect `Community 1` to `Community 0`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **What connects `PodsDummy_window_manager`, `PodsDummy_flutter_secure_storage_darwin`, `PodsDummy_screen_retriever` to the rest of the system?**
  _16 weakly-connected nodes found - possible documentation gaps or missing edges._