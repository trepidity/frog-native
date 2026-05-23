import Foundation

extension PaneState {
    var visibleItems: [VisibleTreeItem] {
        let key = "\(expandedItems.count)-\(items.count)-\(itemChildren.count)-\(sortField)-\(sortOrder)"
        if let cached = cachedVisibleItems, key == lastVisibleItemsKey {
            return cached
        }

        var result: [VisibleTreeItem] = []

        func addVisible(_ items: [FileItem], level: Int, parentLineStates: [Bool]) {
            for (index, item) in items.enumerated() {
                let isLast = index == items.count - 1
                result.append(
                    VisibleTreeItem(
                        item: item,
                        level: level,
                        parentLineStates: parentLineStates,
                        isLast: isLast
                    )
                )
                if expandedItems.contains(item.url), let children = itemChildren[item.url] {
                    let nextParentLineStates = parentLineStates + [!isLast]
                    addVisible(children, level: level + 1, parentLineStates: nextParentLineStates)
                }
            }
        }

        addVisible(items, level: 0, parentLineStates: [])
        cachedVisibleItems = result
        lastVisibleItemsKey = key
        return result
    }

    func toggleExpansion(for item: FileItem) {
        if expandedItems.contains(item.url) {
            expandedItems.remove(item.url)
        } else {
            expandedItems.insert(item.url)
            if itemChildren[item.url] == nil {
                Task {
                    let children = await loadChildrenAsync(for: item)
                    self.itemChildren[item.url] = children
                }
            }
        }
    }

    func revealAndSelect(item: FileItem) {
        var current = item.url.deletingLastPathComponent()
        var parentsToExpand: [URL] = []
        while current.path.hasPrefix(currentDirectory.path) && current.path != currentDirectory.path {
            parentsToExpand.append(current)
            current = current.deletingLastPathComponent()
        }
        for parentURL in parentsToExpand.reversed() where !expandedItems.contains(parentURL) {
            expandedItems.insert(parentURL)
            self.itemChildren[parentURL] = loadChildrenSync(for: FileItem(url: parentURL))
        }
        selection = [item.url]
    }
}
