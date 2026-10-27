# Frog Native — Solarized Asset Kit

Default: Solarized Dark. Light is an alternate asset family. The frog eyes and stepped folder front identify the file manager; the two lower panels echo its dual-pane layout. The small icon removes fine details at 16–32 px.

- `macOS/`: Dark/Light `.icns`, complete ten-image `.iconset`, Xcode app-icon catalogs, and monochrome menu-bar masks. Set `NSImage.isTemplate = true` for template PNGs; these are masks, not UI black fills.
- `Windows/`: multi-resolution ICO (16, 20, 24, 32, 40, 48, 64, 96, 128, 256 px).
- `Linux/`: hicolor PNG hierarchy and scalable SVG. Default app identifier: `frog-native`.
- `Web/`: SVG/ICO favicons, Apple touch icon, 192/512 PNGs, safe-zone maskable icon, and relative-path web manifests. Set deployment URLs in the consuming site.
- `Brand/`: transparent frog marks, monochrome marks, SVG/PNG wordmarks. Wordmark SVGs use Helvetica Neue with Arial/sans-serif fallback; PNG lockups are fixed. These are editable text, not outlined font artwork.
- `UI/`: 30 original 24-point glyphs, Dark/Light SVG and 2x PNG, plus `currentColor` templates. These are reusable exports; the native app continues using system symbols.
- `Palette/`: semantic JSON/CSS, GIMP palettes, visual swatches, and Xcode light/dark color assets. Raised-surface inks preserve the hover contrast corrections. The Swift theme is the color authority.
- `Source/`: editable app-icon vectors, standard/small/full-square. The full-square variant and foreground mark can be imported into Icon Composer; this kit does not claim to include a compiled layered Icon Composer project.
- `Preview/`: overview board. `asset-manifest.json` inventories files and SHA-256 hashes.

From the repository, run `python3 scripts/generate-assets.py` on macOS to regenerate, then `python3 scripts/validate-assets.py` to check the kit. It uses the system Swift/AppKit SVG renderer and `iconutil`, with no third-party packages. Generated assets and brand source follow the repository license. No Apple SF Symbol artwork is redistributed.

macOS release packaging uses the Dark ICNS. The app icon does not switch when the in-app Light theme is selected. Windows/Linux/web are export assets, not new platform application builds. No custom document associations or OS file-type defaults are registered.
