import Foundation
import Compression

/// Minimal ZIP reader/writer for the XLSX (OOXML) container — no external deps.
/// Reads stored and DEFLATE entries; writes stored (uncompressed) entries, which
/// every spreadsheet app accepts.
enum MiniZip {

    // MARK: - Read

    /// Returns every entry's decompressed bytes, keyed by path.
    static func read(_ data: Data) -> [String: Data] {
        let bytes = [UInt8](data)
        let n = bytes.count
        guard n >= 22 else { return [:] }

        func u16(_ o: Int) -> Int { Int(bytes[o]) | Int(bytes[o + 1]) << 8 }
        func u32(_ o: Int) -> Int {
            Int(bytes[o]) | Int(bytes[o + 1]) << 8 | Int(bytes[o + 2]) << 16 | Int(bytes[o + 3]) << 24
        }

        // Locate End Of Central Directory (scan backwards; comment is usually empty).
        var eocd = -1
        var i = n - 22
        let minStart = max(0, n - 22 - 65_536)
        while i >= minStart {
            if bytes[i] == 0x50, bytes[i + 1] == 0x4b, bytes[i + 2] == 0x05, bytes[i + 3] == 0x06 {
                eocd = i; break
            }
            i -= 1
        }
        guard eocd >= 0 else { return [:] }

        let count = u16(eocd + 10)
        var cd = u32(eocd + 16)
        var result: [String: Data] = [:]

        for _ in 0..<count {
            guard cd + 46 <= n,
                  bytes[cd] == 0x50, bytes[cd + 1] == 0x4b, bytes[cd + 2] == 0x01, bytes[cd + 3] == 0x02
            else { break }

            let method = u16(cd + 10)
            let compSize = u32(cd + 20)
            let uncompSize = u32(cd + 24)
            let fnLen = u16(cd + 28)
            let extraLen = u16(cd + 30)
            let commentLen = u16(cd + 32)
            let localOffset = u32(cd + 42)

            let name = String(decoding: bytes[(cd + 46)..<(cd + 46 + fnLen)], as: UTF8.self)

            if localOffset + 30 <= n {
                let lfn = u16(localOffset + 26)
                let lex = u16(localOffset + 28)
                let dataStart = localOffset + 30 + lfn + lex
                if dataStart + compSize <= n {
                    let comp = Array(bytes[dataStart..<dataStart + compSize])
                    if method == 0 {
                        result[name] = Data(comp)
                    } else if method == 8 {
                        result[name] = inflate(comp, expected: uncompSize)
                    }
                }
            }
            cd += 46 + fnLen + extraLen + commentLen
        }
        return result
    }

    /// Raw DEFLATE (RFC 1951) decode — ZIP method 8 matches Apple's COMPRESSION_ZLIB.
    private static func inflate(_ comp: [UInt8], expected: Int) -> Data {
        guard expected > 0 else { return Data() }
        var dst = [UInt8](repeating: 0, count: expected)
        let written = comp.withUnsafeBufferPointer { src in
            dst.withUnsafeMutableBufferPointer { d in
                compression_decode_buffer(d.baseAddress!, expected,
                                          src.baseAddress!, comp.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        return Data(dst.prefix(written))
    }

    // MARK: - Write (stored / no compression)

    static func write(_ entries: [(name: String, data: Data)]) -> Data {
        var out = [UInt8]()
        out.reserveCapacity(entries.reduce(0) { $0 + $1.data.count + 128 })

        func put16(_ v: Int) { out.append(UInt8(v & 0xff)); out.append(UInt8((v >> 8) & 0xff)) }
        func put32(_ v: Int) {
            out.append(UInt8(v & 0xff)); out.append(UInt8((v >> 8) & 0xff))
            out.append(UInt8((v >> 16) & 0xff)); out.append(UInt8((v >> 24) & 0xff))
        }

        struct Central { let name: [UInt8]; let crc: UInt32; let size: Int; let offset: Int }
        var centrals: [Central] = []

        for entry in entries {
            let name = Array(entry.name.utf8)
            let payload = [UInt8](entry.data)
            let crc = crc32(payload)
            let offset = out.count

            put32(0x04034b50)           // local file header signature
            put16(20); put16(0); put16(0) // version needed, flags, method (0 = stored)
            put16(0); put16(0)            // mod time, mod date
            put32(Int(crc)); put32(payload.count); put32(payload.count)
            put16(name.count); put16(0)   // name length, extra length
            out.append(contentsOf: name)
            out.append(contentsOf: payload)

            centrals.append(Central(name: name, crc: crc, size: payload.count, offset: offset))
        }

        let cdStart = out.count
        for c in centrals {
            put32(0x02014b50)                       // central dir header signature
            put16(20); put16(20); put16(0); put16(0) // version made/needed, flags, method
            put16(0); put16(0)                       // time, date
            put32(Int(c.crc)); put32(c.size); put32(c.size)
            put16(c.name.count); put16(0); put16(0)  // name, extra, comment lengths
            put16(0); put16(0); put32(0)             // disk start, internal/external attrs
            put32(c.offset)
            out.append(contentsOf: c.name)
        }
        let cdSize = out.count - cdStart

        put32(0x06054b50)                 // EOCD signature
        put16(0); put16(0)                // disk numbers
        put16(centrals.count); put16(centrals.count)
        put32(cdSize); put32(cdStart); put16(0)

        return Data(out)
    }

    // MARK: - CRC32

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
            return c
        }
    }()

    static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for b in bytes {
            crc = (crc >> 8) ^ crcTable[Int((crc ^ UInt32(b)) & 0xff)]
        }
        return crc ^ 0xffffffff
    }
}
