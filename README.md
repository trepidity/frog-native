# 🐸 Frog Native: The Aura Experience

### *Climb the Staircase. Sense the Filesystem.*

**Frog Native** is a next-generation, spatially-aware dual-pane file manager for macOS. It moves beyond the flat, mechanical lists of traditional managers and introduces the **Aura Design System**—an immersive environment where hierarchy is felt through light, depth, and sound.

---

## 🌟 The Aura Philosophy
Designed for designers and developers who live in their files, Frog Native treats the filesystem as a physical structure. 

- **🪜 The Staircase:** A high-performance vertical tree that visualizes directory depth through recursive indentation and glowing guide lines.
- **🌈 Solarized Themes:** Solarized Dark is the default. Choose Dark or Light in **Preferences → Appearance** (Cmd+,); the choice applies immediately and persists across launches.
- **🌿 Git Status:** Added, Modified, Deleted, and Untracked labels use semantic accents while the file-list background stays quiet.
- **🎼 Auditory Aura:** Every interaction has a voice. Experience subtle, tactile sound effects for expansion, selection, and "teleporting" files.

---

## 🚀 Key Features

### 🔦 Universal Search
Press **Cmd+K** to search filenames and folders across this Mac, including hidden names and package contents.
- A persistent filename index and macOS Spotlight provide progressive results without a per-keystroke disk crawl.
- Exact names and prefixes rank first. Queries of three or more characters also match substrings; case and accents are folded.
- **Enter** browses a folder or selects a file in its parent directory, even outside the active pane. **Cmd+Enter** opens a file.
- Absolute paths and `~/` paths support direct navigation and immediate-child completion.
- Filesystem events update names after creates, renames, and deletes, including changes made while the app was closed.
- Initial indexing and access limits are visible. Network volumes and inaccessible locations are not fully indexed.

See [search architecture and measured performance](docs/universal-search.md).

### 🚪 Aura Portal (Integrated Editing)
Double-click a file to "enter the portal." 
- **Native Viewers:** High-fidelity rendering for Markdown and JSON.
- **In-App Edits:** Modify and save project files without ever leaving your Aura workspace.
- **Smart Open:** Automatically chooses between the internal Portal or your favorite native macOS tools.

### 🫳 Tactile Drag & Drop
Bridge the gap between panes with physical movement.
- **Spring-Loading:** Hover over a folder while dragging to watch it "breathe" and automatically expand.
- **Rich Copy:** Cmd+C captures both the file URL and actual image data for seamless pasting into Slack, Figma, or Photoshop.

---

## 🛠️ Requirements & Build
- **macOS 14.0+**
- **Swift 6.0**
- **Xcode 15.0+**

```bash
git clone git@github.com:trepidity/frog-native.git
cd frog-native
swift run
```

---

## Asset Kit

The Solarized frog-and-folder identity includes macOS ICNS/Xcode catalogs, Windows ICO, Linux hicolor icons, web icons, transparent logos, 30 original UI glyphs, and semantic palette files.

See [the asset guide](Assets/README.md) and [preview board](Assets/Preview/asset-board.png). Regenerate with `python3 scripts/generate-assets.py`; validate with `python3 scripts/validate-assets.py`. The generated download is `dist/FrogNative-AssetKit.zip`.

## 🦉 Design Credits
Built with **"Owl-Like" Thinking**—observing user behavior to create a tool that is as silent and powerful as a predator, yet as fluid and beautiful as a work of art.

## 📄 License
Frog Native is licensed under the **MIT License + Commons Clause**.

Anyone may use, copy, modify, publish, distribute, and sublicense the software, but the software may not be sold as a product or service whose value derives substantially from Frog Native.

See [LICENSE](LICENSE) for the full terms.
