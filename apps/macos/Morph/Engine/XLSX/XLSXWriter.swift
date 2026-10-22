import Foundation

/// Builds a minimal, valid .xlsx from a table using inline strings (no shared-string
/// table needed). Numeric-looking cells are written as numbers; everything else as text.
enum XLSXWriter {

    static func data(from table: DataConverter.Table) -> Data {
        let sheet = sheetXML(table)

        let files: [(name: String, data: Data)] = [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rootRels.utf8)),
            ("xl/workbook.xml", Data(workbook.utf8)),
            ("xl/_rels/workbook.xml.rels", Data(workbookRels.utf8)),
            ("xl/worksheets/sheet1.xml", Data(sheet.utf8)),
        ]
        return MiniZip.write(files)
    }

    // MARK: - Sheet

    private static func sheetXML(_ table: DataConverter.Table) -> String {
        var rows = ""
        var rowIndex = 1

        rows += rowXML(table.headers, rowIndex: rowIndex, allText: true)
        rowIndex += 1

        for row in table.rows {
            rows += rowXML(row, rowIndex: rowIndex, allText: false)
            rowIndex += 1
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>\(rows)</sheetData></worksheet>
        """
    }

    private static func rowXML(_ cells: [String], rowIndex: Int, allText: Bool) -> String {
        var out = "<row r=\"\(rowIndex)\">"
        for (col, value) in cells.enumerated() {
            let ref = columnLetter(col) + String(rowIndex)
            out += cellXML(value, ref: ref, allText: allText)
        }
        out += "</row>"
        return out
    }

    private static func cellXML(_ value: String, ref: String, allText: Bool) -> String {
        if !allText, isNumeric(value) {
            return "<c r=\"\(ref)\"><v>\(value)</v></c>"
        }
        return "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(value))</t></is></c>"
    }

    private static func isNumeric(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        // Reject things like "007" or "+1" that are better kept as text; accept plain ints/decimals.
        if let _ = Int(s) { return s == "0" || !(s.hasPrefix("0") && s.count > 1) }
        if let _ = Double(s) {
            return s.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789")) != nil
                && !s.lowercased().contains("x")
        }
        return false
    }

    /// 0-based column index -> A, B, …, Z, AA, …
    static func columnLetter(_ index: Int) -> String {
        var n = index + 1
        var s = ""
        while n > 0 {
            let r = (n - 1) % 26
            s = String(UnicodeScalar(65 + r)!) + s
            n = (n - 1) / 26
        }
        return s
    }

    private static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s.unicodeScalars {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "\t", "\n", "\r": out.unicodeScalars.append(ch)
            default:
                // Strip XML-illegal control characters.
                if ch.value < 0x20 { continue }
                out.unicodeScalars.append(ch)
            }
        }
        return out
    }

    // MARK: - Fixed package parts

    private static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>
    """

    private static let rootRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
    """

    private static let workbook = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
    """

    private static let workbookRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>
    """
}
