# Universal filename search

The palette searches independently of either pane. Enter browses a directory or loads
a file's parent and selects the file after loading. Breadcrumbs carry directory URLs;
double-clicking one navigates with normal back/forward history and exits Solo mode.

## Hot path

1. A persistent SQLite filename index supplies a bounded candidate set. B-tree lookups
   serve exact/prefix matches; [FTS5 trigrams](https://sqlite.org/fts5.html#the_trigram_tokenizer) serve literal substrings of three or more
   characters. One- and two-character queries use prefixes, avoiding a full-table scan.
2. A native asynchronous Spotlight query runs across indexed local volumes in parallel,
   providing coverage before Frog's first crawl completes. Each provider publishes
   progressively; results are merged by path and ranked exact, prefix, then substring.
3. Rows carry URL and directory type only. No image decoding, file content reads, Git
   processes, or recursive filesystem traversal occur for filename queries. Explicit
   path completion enumerates only the immediate parent, checks cancellation between
   entries, and stops after 100 candidates. The palette displays at most 40 results.
4. Each edit stops its old Spotlight query and invalidates outstanding results. SQLite
   checks cancellation before/among rows and via its VM progress handler. Activations
   also capture a pane and generation; dismissing or replacing a query invalidates them.

No typo-tolerant fuzzy matching or file-content search is claimed. The query path has
no arbitrary 150 ms debounce. Exact and prefix matches win over incidental substrings.

## Coverage and maintenance

The first background crawl prioritizes the user's home, publishing immediate children
before descending, then scans the local filesystem. Hidden files and package descendants
are included; symlinks are indexed as names without traversing their targets. Remote
volumes, `/dev`, `/Network`, duplicate `/System/Volumes` trees, and the index's own cache
are excluded. Spotlight may contribute additional indexed locations. Direct paths remain
usable independently of indexing, subject to filesystem availability and permissions.

The index stores names, paths, directory flags, and crawl generations under the app's
Application Support directory. It stores no file contents. SQLite WAL and 256-entry
batches keep maintenance separate from small query operations. The directory is private
to the user; the database has mode 0600.

[FSEvents](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html) delivers file-level name changes. Content-only writes are ignored; changed
files are reconciled individually, and changed directories recursively. Access changes
can revisit a denied subtree. Dropped events or invalidated roots request a full scan.
The queue coalesces paths and falls back to a full scan above 512 pending paths.

A durable dirty marker is set before reconciliation. Scope, event watermark, access
status, and clearing that marker commit together only after pending work drains. Failed
work leaves the marker set and requires a full scan on the next change or restart.
Only confirmed absence deletes indexed rows; denied access preserves prior records.
Results are checked again on activation because files can move after a query.

Initial crawling is necessary before complete coverage of accessible local names.
Spotlight exclusions, offline volumes, and macOS permissions limit what either index
can return. The UI reports indexing, access limitations, and provider errors separately
from a completed empty query. It does not claim access to every protected system file.

## Verification (2026-10-27)

The production SQLite implementation was compiled with optimization and queried through
a newly opened database connection containing **1,000,001 synthetic filename records**.
Across 120 exact/prefix/substring/missing queries: **1.62 ms median, 18.43 ms p95,
18.74 ms maximum**. Fixture construction took 29.68 seconds; peak process footprint was
39.4 MB. These are local lookup/ranking measurements, not cold filesystem discovery,
Spotlight response time, UI render time, or an end-to-end navigation guarantee.

Reproduce:

```sh
swiftc -O -parse-as-library Sources/frog-native/Search/SearchEntry.swift \
  Sources/frog-native/Search/FilenameIndex.swift scripts/benchmark-search.swift \
  -o /tmp/frog-search-benchmark
/usr/bin/time -l /tmp/frog-search-benchmark
swift test
```

Regression seams are the durable filename database, actual fixture filesystem crawls,
search-session generation transitions, and pane navigation state. Cases cover hidden
and package names, literal query characters, accent folding, rename/deletion, permission
denial, symlink events, interrupted scope resets, cancellation, and cross-root jumps.
The symlink and interrupted-reset cases were observed failing before their fixes.

Native QA uses a separate app bundle and preferences. It verifies keyboard focus,
Spotlight results outside the fixture scope, hidden-name search, folder and file jumps,
breadcrumb double-clicks, FSEvents create/rename updates, and create/delete recovery
after restarting the app. The `FROG_SEARCH_ROOT`
environment override confines this QA index to disposable fixture files.
