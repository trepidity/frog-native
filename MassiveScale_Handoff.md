# Technical Handoff: Mastering Massive Filesystem Scale

## Objective
Enable the "Aura" to handle directories with 100,000+ files and folders without UI stutters or application hangs.

## Current High-Performance Architecture

### 1. Asynchronous Enumeration (`PaneState.swift`)
We have moved away from synchronous `FileManager` calls on the Main Actor.
- **Implementation:** `loadContents()` and `loadChildrenAsync()` now use `Task(priority: .userInitiated)` and `Task.detached`.
- **Benefit:** The actual scanning of the disk happens on a background thread. The user can still scroll, switch panes, or use the Command Palette while a 100k-file directory is being indexed.

### 2. Off-Thread Sorting & Processing
Sorting a massive array of `FileItem` objects is CPU-heavy.
- **Strategy:** The sorting logic is performed inside a `Task.detached` block. This ensures that even if sorting takes several hundred milliseconds, the UI main loop is never blocked.
- **Handoff Task:** Ensure that any future sorting criteria (size, kind) also happen within this detached context.

### 3. State-Driven Loading Indicators
- **Property:** `isPathLoading: Bool` in `PaneState`.
- **Function:** This is set to `true` immediately before the background task starts and `false` once the data is delivered to the `items` array.
- **Next Step:** The UI (`FileBrowserPane`) should be updated to show a subtle "Aura Loading" state (perhaps a pulsating glow on the staircase) when this is true.

## Performance Roadmap for the Coder

### Phase A: Chunked Updates (Pagination)
Currently, we deliver all 100,000 items at once when the scan completes.
- **Optimization:** For extremely large folders, modify the detached task to send results back in chunks (e.g., the first 500 items immediately, then the rest in batches of 5,000).
- **Tool:** Use `AsyncStream` to yield items from the background thread to the UI in real-time.

### Phase B: Virtualized "Staircase"
While the data is now fetched efficiently, rendering 100,000 SwiftUI views is still expensive.
- **Optimization:** Ensure the `VerticalTreePane` uses native virtualization. SwiftUI's `List` does some of this, but for the recursive tree, we should ensure we aren't pre-calculating the height of every unexpanded "ghost" or child.

### Phase C: Directory Observability
- **Improvement:** Implement `DispatchSourceFileSystemObject` or `FSEvents` to monitor massive directories for changes without re-scanning the entire tree.

## Relevant Files
- `Sources/frog-native/State/PaneState.swift`: The engine room for async loading.
- `Sources/frog-native/Models/FileItem.swift`: Lightweight metadata structure.

## Goal
The Aura should feel "instant" regardless of project size. The "Staircase" should be a lightweight window into a massive data ocean.
