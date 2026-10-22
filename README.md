# Morph — File Converter

On-device file converter. Drop files in, pick a target format, convert. Nothing is
uploaded — every conversion runs locally.

This is a **monorepo**: the macOS app is built first as a native SwiftUI app; the
Windows app will follow as a Tauri app that reuses the shared conversion spec.

```
file-converter/
├── apps/
│   ├── macos/              # SwiftUI native app (built first) — see apps/macos/README.md
│   └── windows/            # Tauri app (planned) — scaffold in place
├── packages/
│   └── conversion-spec/    # conversions.json — shared source of truth for the
│                           # conversion matrix, consumed by both apps
├── samples/                # sample files to try (image / csv / json)
└── docs/
```

## Status

| Platform | Stack              | State                                            |
|----------|--------------------|--------------------------------------------------|
| macOS    | SwiftUI + Apple SDKs | **MVP working** — image / document / data        |
| Windows  | Tauri (Rust + web) | Scaffold only; conversions not yet implemented   |

## What it converts (macOS MVP)

- **Images** — PNG · JPEG · HEIC · TIFF · GIF · BMP (+ WebP where the OS supports it),
  with optional resize and quality control. Backed by Image I/O.
- **Documents** — images → PDF, and PDF pages → PNG/JPEG at a chosen DPI. Backed by PDFKit.
- **Data** — CSV ↔ TSV ↔ JSON ↔ Excel (XLSX), with quote-aware parsing and type
  inference. XLSX read/write is implemented with no external dependencies.

## Developing the macOS app

```bash
cd apps/macos
xcodegen generate          # regenerate Morph.xcodeproj from project.yml
open Morph.xcodeproj        # or: xcodebuild -scheme Morph build
```

The Xcode project is generated from `project.yml` and is **not** committed — run
`xcodegen generate` after cloning.
