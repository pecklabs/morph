# Morph (macOS)

Native SwiftUI file converter. Pure Apple frameworks — no third-party dependencies.

## Build & run

```bash
xcodegen generate                       # project.yml -> Morph.xcodeproj
xcodebuild -scheme Morph -configuration Debug build
# or open Morph.xcodeproj and hit Run
```

Requires Xcode 15+ and macOS 14+.

## Architecture

```
Morph/
├── MorphApp.swift          # @main App + window + menu commands
├── Models/
│   ├── Catalog.swift       # FileKind, Operation, Target + the conversion matrix
│   └── ConversionJob.swift # ConversionJob (@Observable) + ConvertOptions
├── Engine/                 # pure, UI-free converters (safe to run off-main)
│   ├── Support.swift       # ConversionError + OutputPath (collision-free naming)
│   ├── ImageConverter.swift# Image I/O; writable formats queried at runtime
│   ├── PDFConverter.swift  # PDFKit + Core Graphics
│   ├── DataConverter.swift # CSV/TSV/JSON, quote-aware, type-inferring
│   └── ConversionEngine.swift # routes a Target to its converter
├── Store/
│   └── AppModel.swift      # @MainActor state: jobs, options, run loop, Finder reveal
└── Views/                  # ContentView, DropZoneView, JobRowView, OptionsBarView, Theme
```

The UI never calls Image I/O / PDFKit directly — it goes through `ConversionEngine`,
which runs inside a detached task so the window stays responsive during a batch.

## Notes / roadmap

- **Sandbox is off** for the MVP so output can be written next to the input file.
  App Store distribution will need App Sandbox + security-scoped bookmarks.
- **WebP output** appears only when the host's Image I/O can encode it
  (`CGImageDestinationCopyTypeIdentifiers()`); it is absent on current macOS.
- **XLSX** (Excel) read/write is implemented with no external dependencies
  (`Engine/XLSX/`: a minimal ZIP via the Compression framework + a hand-rolled
  stored-ZIP writer with CRC32, `XMLParser` for reading, inline-string XML for
  writing). First worksheet only; dates currently read as raw serial numbers.
- The conversion matrix mirrors `../../packages/conversion-spec/conversions.json`.
