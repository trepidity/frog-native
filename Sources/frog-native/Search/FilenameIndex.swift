import Foundation
import SQLite3

/// All access to this connection is serialized by FilenameIndex's actor.
private final class SearchDatabase {
    var handle: OpaquePointer?
    init(url: URL) throws {
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw CocoaError(.fileReadUnknown)
        }
        sqlite3_busy_timeout(handle, 1000)
    }
    deinit { sqlite3_close(handle) }
}

actor FilenameIndex {
    private let database: SearchDatabase
    private var handle: OpaquePointer? { database.handle }
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(url: URL) throws {
        database = try SearchDatabase(url: url)
        let schema = """
        PRAGMA journal_mode=WAL;
        PRAGMA synchronous=NORMAL;
        PRAGMA cache_size=-8192;
        CREATE TABLE IF NOT EXISTS files(id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL, directory INTEGER NOT NULL, generation TEXT NOT NULL);
        CREATE INDEX IF NOT EXISTS files_name ON files(name);
        CREATE VIRTUAL TABLE IF NOT EXISTS names USING fts5(name, content='files', content_rowid='id', tokenize='trigram');
        CREATE TRIGGER IF NOT EXISTS files_ai AFTER INSERT ON files BEGIN
            INSERT INTO names(rowid,name) VALUES(new.id,new.name); END;
        CREATE TRIGGER IF NOT EXISTS files_ad AFTER DELETE ON files BEGIN
            INSERT INTO names(names,rowid,name) VALUES('delete',old.id,old.name); END;
        CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);
        """
        guard sqlite3_exec(database.handle, schema, nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: "FilenameIndex", code: 1, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database.handle))])
        }
    }

    private func execute(_ sql: String, _ values: [String] = []) throws {
        let statement = try prepare(sql, values)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw error() }
    }

    private func error() -> Error {
        NSError(
            domain: "FilenameIndex",
            code: Int(sqlite3_errcode(handle)),
            userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(handle))]
        )
    }

    private func prepare(_ sql: String, _ values: [String]) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { throw error() }
        for (index, value) in values.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), value, -1, transient)
        }
        return statement
    }

    func value(for key: String) throws -> String? {
        let statement = try prepare("SELECT value FROM metadata WHERE key=?", [key])
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW ? String(cString: sqlite3_column_text(statement, 0)) : nil
    }

    func setValue(_ value: String, for key: String) throws {
        try execute("INSERT OR REPLACE INTO metadata VALUES(?,?)", [key, value])
    }

    func checkpoint(scope: String, event: UInt64, denied: Int) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try setValue(scope, for: "scope")
            try setValue(String(event), for: "event")
            try setValue(String(denied), for: "denied")
            try setValue("0", for: "dirty")
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func reset() throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try setValue("1", for: "dirty")
            try execute("DELETE FROM files")
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func upsert(_ entries: [SearchEntry], generation: String) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            // A filename belongs to its path; only type and generation can change in place.
            let statement = try prepare("""
                INSERT INTO files(path,name,directory,generation) VALUES(?,?,?,?)
                ON CONFLICT(path) DO UPDATE SET directory=excluded.directory,generation=excluded.generation
                """, [])
            defer { sqlite3_finalize(statement) }
            for entry in entries {
                sqlite3_reset(statement)
                let values = [entry.url.path, SearchEntry.normalize(entry.name), entry.isDirectory ? "1" : "0", generation]
                for (index, value) in values.enumerated() {
                    sqlite3_bind_text(statement, Int32(index + 1), value, -1, transient)
                }
                guard sqlite3_step(statement) == SQLITE_DONE else { throw error() }
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    /// Only called after a successful traversal. A denied subtree never causes mass deletion.
    func prune(root: URL, generation: String) throws {
        let prefix = root.path == "/" ? "/" : root.path + "/"
        try execute("DELETE FROM files WHERE generation<>? AND (path=? OR (path>=? AND path<?))",
                    [generation, root.path, prefix, prefix + "\u{10ffff}"])
    }

    func preserve(root: URL, generation: String) throws {
        let prefix = root.path == "/" ? "/" : root.path + "/"
        try execute("UPDATE files SET generation=? WHERE path=? OR (path>=? AND path<?)",
                    [generation, root.path, prefix, prefix + "\u{10ffff}"])
    }

    func search(_ query: String, limit: Int = 40) throws -> [SearchEntry] {
        try Task.checkCancellation()
        sqlite3_progress_handler(handle, 1000, { _ in Task<Never, Never>.isCancelled ? 1 : 0 }, nil)
        defer { sqlite3_progress_handler(handle, 0, nil, nil) }
        let needle = SearchEntry.normalize(query)
        guard !needle.isEmpty else { return [] }
        var candidates: [SearchEntry] = []
        // Each branch has an index and a bound. Short queries never fall back to a table scan.
        for prefix in [needle, "." + needle] {
            candidates += try rows("SELECT path,directory FROM files WHERE name=? LIMIT 80", [prefix])
            candidates += try rows("SELECT path,directory FROM files WHERE name>=? AND name<? ORDER BY name LIMIT 120",
                                   [prefix, prefix + "\u{10ffff}"])
        }
        if needle.count >= 3 {
            let phrase = "\"" + needle.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            candidates += try rows("""
                SELECT files.path,files.directory FROM names JOIN files ON files.id=names.rowid
                WHERE names MATCH ? LIMIT 240
                """, [phrase])
        }
        return SearchEntry.ranked(candidates, query: query, limit: limit)
    }

    private func rows(_ sql: String, _ values: [String]) throws -> [SearchEntry] {
        try Task.checkCancellation()
        let statement = try prepare(sql, values)
        defer { sqlite3_finalize(statement) }
        var results: [SearchEntry] = []
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            try Task.checkCancellation()
            let path = String(cString: sqlite3_column_text(statement, 0))
            results.append(SearchEntry(url: URL(fileURLWithPath: path), isDirectory: sqlite3_column_int(statement, 1) != 0))
            result = sqlite3_step(statement)
        }
        try Task.checkCancellation()
        guard result == SQLITE_DONE else { throw error() }
        return results
    }
}
