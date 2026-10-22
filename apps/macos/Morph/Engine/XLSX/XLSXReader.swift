import Foundation

/// Reads the first worksheet of an .xlsx into a table, using Foundation's XMLParser.
/// Handles shared strings, inline strings, booleans, and numbers. Dates are returned
/// as their raw serial numbers (date formatting is a later refinement).
enum XLSXReader {

    static func read(_ data: Data) throws -> DataConverter.Table {
        let entries = MiniZip.read(data)
        guard !entries.isEmpty else {
            throw ConversionError.dataParse("not a valid .xlsx archive")
        }

        let shared: [String]
        if let ss = entries["xl/sharedStrings.xml"] {
            shared = SharedStringsParser().parse(ss)
        } else {
            shared = []
        }

        guard let sheetData = firstSheet(entries) else {
            throw ConversionError.dataParse("no worksheet found in .xlsx")
        }

        let grid = SheetParser(shared: shared).parse(sheetData)
        guard let headers = grid.first else {
            throw ConversionError.dataParse("the sheet is empty")
        }
        return DataConverter.Table(headers: headers, rows: Array(grid.dropFirst()))
    }

    private static func firstSheet(_ entries: [String: Data]) -> Data? {
        let keys = entries.keys.filter { $0.hasPrefix("xl/worksheets/sheet") && $0.hasSuffix(".xml") }
        let sorted = keys.sorted { (sheetNumber($0) ?? .max, $0) < (sheetNumber($1) ?? .max, $1) }
        return sorted.first.flatMap { entries[$0] }
    }

    private static func sheetNumber(_ path: String) -> Int? {
        let name = (path as NSString).lastPathComponent
        let digits = name.drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })
        return Int(digits)
    }
}

// MARK: - Shared strings

private final class SharedStringsParser: NSObject, XMLParserDelegate {
    private var strings: [String] = []
    private var current = ""
    private var inT = false

    func parse(_ data: Data) -> [String] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return strings
    }

    func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        if el == "si" { current = "" }
        else if el == "t" { inT = true }
    }

    func parser(_ parser: XMLParser, foundCharacters s: String) {
        if inT { current += s }
    }

    func parser(_ parser: XMLParser, didEndElement el: String, namespaceURI: String?,
                qualifiedName: String?) {
        if el == "t" { inT = false }
        else if el == "si" { strings.append(current) }
    }
}

// MARK: - Worksheet

private final class SheetParser: NSObject, XMLParserDelegate {
    private let shared: [String]
    init(shared: [String]) { self.shared = shared }

    private var rows: [[String]] = []
    private var maxCols = 0

    private var currentRow: [Int: String] = [:]
    private var cellType = ""
    private var cellCol = 0
    private var fallbackCol = 0
    private var inV = false
    private var inT = false
    private var valueBuf = ""
    private var inlineBuf = ""

    func parse(_ data: Data) -> [[String]] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        // Pad every row to the widest one so columns line up.
        return rows.map { row in
            row.count < maxCols ? row + Array(repeating: "", count: maxCols - row.count) : row
        }
    }

    func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?,
                qualifiedName: String?, attributes a: [String: String]) {
        switch el {
        case "row":
            currentRow = [:]
            fallbackCol = 0
        case "c":
            cellType = a["t"] ?? ""
            cellCol = a["r"].map(Self.columnIndex(fromRef:)) ?? fallbackCol
            valueBuf = ""
            inlineBuf = ""
        case "v":
            inV = true; valueBuf = ""
        case "t":
            inT = true; inlineBuf = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters s: String) {
        if inV { valueBuf += s }
        else if inT { inlineBuf += s }
    }

    func parser(_ parser: XMLParser, didEndElement el: String, namespaceURI: String?,
                qualifiedName: String?) {
        switch el {
        case "v":
            inV = false
        case "t":
            inT = false
        case "c":
            currentRow[cellCol] = resolveCell()
            fallbackCol = cellCol + 1
            maxCols = max(maxCols, cellCol + 1)
        case "row":
            let width = (currentRow.keys.max() ?? -1) + 1
            var arr = [String](repeating: "", count: width)
            for (col, value) in currentRow where col < width { arr[col] = value }
            rows.append(arr)
        default:
            break
        }
    }

    private func resolveCell() -> String {
        let v = valueBuf.trimmingCharacters(in: .whitespacesAndNewlines)
        switch cellType {
        case "s":
            if let idx = Int(v), idx >= 0, idx < shared.count { return shared[idx] }
            return ""
        case "inlineStr":
            return inlineBuf
        case "b":
            return v == "1" ? "true" : "false"
        case "str":
            return valueBuf
        default:
            return v
        }
    }

    /// "C12" / "AB3" -> 0-based column index.
    static func columnIndex(fromRef ref: String) -> Int {
        var col = 0
        for ch in ref.uppercased() {
            guard ch.isLetter, let a = ch.asciiValue else { break }
            col = col * 26 + (Int(a) - 64)
        }
        return max(0, col - 1)
    }
}
