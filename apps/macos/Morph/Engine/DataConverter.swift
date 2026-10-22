import Foundation

/// CSV / TSV / JSON interconversion using only Foundation. On-device, no deps.
enum DataConverter {

    /// A simple tabular representation: header row + string rows.
    struct Table {
        var headers: [String]
        var rows: [[String]]
    }

    static func convert(input: URL, toExt ext: String, destination: URL? = nil, outputURL: URL? = nil) throws -> URL {
        let inExt = input.pathExtension.lowercased()
        let raw = try Data(contentsOf: input)
        guard !raw.isEmpty else { throw ConversionError.emptyInput }

        let table: Table
        switch inExt {
        case "csv": table = try parseDelimited(raw, delimiter: ",")
        case "tsv": table = try parseDelimited(raw, delimiter: "\t")
        case "json": table = try parseJSON(raw)
        case "xlsx": table = try XLSXReader.read(raw)
        default: throw ConversionError.dataParse("unsupported input .\(inExt)")
        }

        let outURL = outputURL ?? OutputPath.make(for: input, ext: ext, in: destination)
        OutputPath.ensureParent(of: outURL)
        let data: Data
        switch ext.lowercased() {
        case "csv": data = serializeDelimited(table, delimiter: ",")
        case "tsv": data = serializeDelimited(table, delimiter: "\t")
        case "json": data = try serializeJSON(table)
        case "xlsx": data = XLSXWriter.data(from: table)
        default: throw ConversionError.dataParse("unsupported output .\(ext)")
        }

        try data.write(to: outURL)
        return outURL
    }

    // MARK: - Delimited parsing (RFC 4180-ish: handles quotes, escaped quotes, newlines in quotes)

    static func parseDelimited(_ data: Data, delimiter: Character) throws -> Table {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ConversionError.dataParse("not valid text")
        }

        var records: [[String]] = []
        var field = ""
        var record: [String] = []
        var inQuotes = false
        var iterator = text.makeIterator()
        var pending: Character? = nil

        func nextChar() -> Character? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }

        while let ch = nextChar() {
            if inQuotes {
                if ch == "\"" {
                    if let peek = nextChar() {
                        if peek == "\"" {
                            field.append("\"")  // escaped quote
                        } else {
                            inQuotes = false
                            pending = peek
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else {
                switch ch {
                case "\"":
                    inQuotes = true
                case delimiter:
                    record.append(field); field = ""
                case "\r":
                    // swallow; a following \n ends the record
                    if let peek = nextChar() {
                        if peek == "\n" {
                            record.append(field); field = ""
                            records.append(record); record = []
                        } else {
                            record.append(field); field = ""
                            records.append(record); record = []
                            pending = peek
                        }
                    } else {
                        record.append(field); field = ""
                        records.append(record); record = []
                    }
                case "\n":
                    record.append(field); field = ""
                    records.append(record); record = []
                default:
                    field.append(ch)
                }
            }
        }
        // trailing field / record
        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            records.append(record)
        }

        // drop a trailing empty record (file ending in newline)
        if let last = records.last, last.count == 1, last[0].isEmpty {
            records.removeLast()
        }

        guard let headers = records.first else { throw ConversionError.dataParse("no rows") }
        let width = headers.count
        let rows = records.dropFirst().map { row -> [String] in
            var r = row
            if r.count < width { r += Array(repeating: "", count: width - r.count) }
            if r.count > width { r = Array(r.prefix(width)) }
            return r
        }
        return Table(headers: headers, rows: Array(rows))
    }

    static func serializeDelimited(_ table: Table, delimiter: Character) -> Data {
        let d = String(delimiter)
        func escape(_ value: String) -> String {
            let needsQuote = value.contains(d) || value.contains("\"") || value.contains("\n") || value.contains("\r")
            if needsQuote {
                return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return value
        }
        var lines: [String] = []
        lines.append(table.headers.map(escape).joined(separator: d))
        for row in table.rows {
            lines.append(row.map(escape).joined(separator: d))
        }
        return (lines.joined(separator: "\n") + "\n").data(using: .utf8) ?? Data()
    }

    // MARK: - JSON

    /// Parses a JSON array of flat objects (the common export shape) into a table.
    static func parseJSON(_ data: Data) throws -> Table {
        let obj = try JSONSerialization.jsonObject(with: data)

        if let array = obj as? [[String: Any]] {
            // Union of keys, ordered by first appearance.
            var headers: [String] = []
            var seen = Set<String>()
            for item in array {
                for key in item.keys where !seen.contains(key) {
                    seen.insert(key); headers.append(key)
                }
            }
            headers.sort()  // stable, predictable column order
            let rows = array.map { item in headers.map { stringify(item[$0]) } }
            return Table(headers: headers, rows: rows)
        }

        if let array = obj as? [Any] {
            // Array of scalars -> single "value" column.
            let rows = array.map { [stringify($0)] }
            return Table(headers: ["value"], rows: rows)
        }

        if let dict = obj as? [String: Any] {
            // Single object -> one row.
            let headers = dict.keys.sorted()
            return Table(headers: headers, rows: [headers.map { stringify(dict[$0]) }])
        }

        throw ConversionError.dataParse("expected a JSON array or object at the top level")
    }

    static func serializeJSON(_ table: Table) throws -> Data {
        var array: [[String: Any]] = []
        for row in table.rows {
            var dict: [String: Any] = [:]
            for (i, header) in table.headers.enumerated() where i < row.count {
                dict[header] = coerce(row[i])
            }
            array.append(dict)
        }
        return try JSONSerialization.data(withJSONObject: array, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Value helpers

    /// JSON value -> string cell.
    static func stringify(_ value: Any?) -> String {
        switch value {
        case nil, is NSNull: return ""
        case let s as String: return s
        case let n as NSNumber:
            // NSNumber bridges both numbers and booleans; separate the bool case.
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "true" : "false" }
            return n.stringValue
        default: return "\(value!)"
        }
    }

    /// String cell -> typed JSON value (Int / Double / Bool / String).
    static func coerce(_ s: String) -> Any {
        if s.isEmpty { return NSNull() }
        if s == "true" { return true }
        if s == "false" { return false }
        if let i = Int(s) { return i }
        if let d = Double(s), s.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789")) != nil {
            return d
        }
        return s
    }
}
