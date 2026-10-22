# Morph (Windows) — planned

Tauri 2 scaffold (React + TypeScript frontend, Rust backend). **Conversions are not
implemented yet** — this directory holds the starting point for the Windows build,
which comes after the macOS app.

When picked up, implement the conversion engine in Rust to match
`../../packages/conversion-spec/conversions.json`:

- **Images** — `image` crate (PNG/JPEG/GIF/BMP/TIFF; HEIC/WebP may need system libs)
- **Data** — `csv`, `serde_json`, `calamine` (read xlsx), `rust_xlsxwriter` (write xlsx)
- **Documents** — `printpdf` (images → PDF), `pdfium-render` (PDF → images)

Keep the Rust command surface close to the macOS `ConversionEngine` so both apps
behave the same.

## Dev

```bash
pnpm install
pnpm tauri dev
```
