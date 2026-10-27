// Build with SearchEntry.swift and FilenameIndex.swift using swiftc -O.
// Measures actual SQLite reads/ranking over one million synthetic filename rows;
// it does not claim filesystem crawling or Spotlight latency.
import Foundation

@main
struct SearchBenchmark {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("frog-search-bench-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let index = try FilenameIndex(url: root.appendingPathComponent("index.sqlite"))
        let count = 1_000_000
        let start = ContinuousClock.now
        for offset in stride(from: 0, to: count, by: 1000) {
            let entries = (offset..<offset + 1000).map { rowIndex in
                SearchEntry(url: URL(fileURLWithPath: "/fixture/group-\(rowIndex / 1000)/document-\(rowIndex).swift"), isDirectory: rowIndex % 10 == 0)
            }
            try await index.upsert(entries, generation: "fixture")
        }
        try await index.upsert([SearchEntry(url: URL(fileURLWithPath: "/fixture/.aurora"), isDirectory: true)], generation: "fixture")
        print("rows=\(count + 1) build=\(start.duration(to: .now))")
        let reader = try FilenameIndex(url: root.appendingPathComponent("index.sqlite"))
        var milliseconds: [Double] = []
        for _ in 0..<20 {
            for query in ["do", "doc", "document-99999", "99999", "aurora", "missing-name"] {
                let before = ContinuousClock.now
                let results = try await reader.search(query)
                let duration = before.duration(to: .now).components
                milliseconds.append(Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15)
                if query == "aurora" && results.first?.name != ".aurora" { fatalError("Hidden result missing") }
                if results.count > 40 { fatalError("Unbounded results") }
            }
        }
        milliseconds.sort()
        print(String(
            format: "queries=%d p50=%.2fms p95=%.2fms max=%.2fms",
            milliseconds.count,
            milliseconds[milliseconds.count / 2],
            milliseconds[Int(Double(milliseconds.count) * 0.95)],
            milliseconds.last ?? 0
        ))
    }
}
