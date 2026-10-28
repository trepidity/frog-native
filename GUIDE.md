# 📖 Aura User Guide: Master the Staircase

Welcome to the definitive guide to **Frog**. This document covers every interaction, shortcut, and design philosophy needed to master the Aura experience.

---

## 🎹 1. Essential Shortcuts

### Navigation
- **`Up / Down Arrows`**: Navigate the visible staircase.
- **`Right Arrow`**: Expand folder / Descend into first child.
- **`Left Arrow`**: Collapse folder / Ascend to parent folder.
- **`Cmd + Shift + Enter`**: **Solo Mode** (Zoom into selected folder as new root).
- **`Escape`**: Exit Solo Mode / Close Command Palette / Close Editor.

### Searching (Aura Spotlight)
- **`Cmd + K`**: Search this Mac for files, folders, or commands.
- **`Enter`**: Browse the selected folder, or load a file’s parent and select the file.
- **`Cmd + Enter`**: Open the selected file with the editor or its default application.
- **`Arrows / Mouse Hover`**: Preview file (600ms debounce).

Type an absolute path or `~/` path for direct navigation and path completion. Hidden names and package contents are included in the filename index. Search remains usable while initial indexing runs; protected folders require macOS access.

Double-click a directory breadcrumb above the tree to browse that directory.

### Selecting files

- **`Cmd + Click`**: Add or remove individual files from the selection.
- **`Shift + Click`** or **`Shift + Up / Down`**: Select a contiguous range.
- **`Cmd + A`**: Select all rows in the focused file list.
- **Click** without modifiers to return to a single selection.

### Actions
- **`Cmd + N`**: Create a new "Untitled Folder".
- **`Cmd + Backspace`**: Move selected item(s) to system Trash.
- **Right-click → Rename…**: Rename a single file or folder in any browser layout. The dialog selects the current name for editing. Press **Return** to rename or **Escape** to cancel. Invalid names and filesystem errors appear in the dialog; an existing item is never replaced.
- **Window placement**: The app remembers its monitor, position, and window size between launches. If the monitor is disconnected or its usable resolution changes, the window is fitted onto an available display.
- **`Cmd + C`**: **Aura Hook** (Captures URL + rich image data).
- **`Cmd + ,`**: Open Aura Preferences.

---

## 🌈 2. Reading the Aura

### Solarized Themes
Solarized Dark is the default. **Cmd+, → Appearance → Colors** switches between Dark and Light immediately and remembers the choice.

- **Selection:** A subtle fill and leading bar; the blue bar identifies the focused pane.
- **Folders:** Blue icons; links and aliases use a cyan link glyph.
- **Git:** Added, Modified, Deleted, and Untracked labels carry the status in words as well as color.
- **Hidden items:** Readable, muted names; file sizes remain visible.

### Indentation Guides
Neutral vertical guides connect parents and children. Toggle the guides or Git labels in Appearance preferences.

---

## 🚪 3. The Aura Portal
The Portal is for "one-off" work. When you don't want to open a heavy editor, just double-click:
- **Markdown:** Renders with native headers and lists.
- **JSON/Code:** Monospaced themed editor with direct save support.
- **Binaries:** Automatically hands off to your default native app.

---

## ⚙️ 4. Personalization
Use **Cmd + ,** to tune your experience:
- **Colors:** Choose Solarized Dark or Solarized Light.
- **Sound Settings:** Toggle tactile sound effects or adjust volume.
- **File List:** Toggle hierarchy guides and Git status labels.

---

## 🦉 Design Philosophy: The Staircase
Frog is built on the idea that **Indentation is Physical.** By treating the filesystem as a vertical staircase, we reduce the cognitive load of "jumping" between windows and keep your focus on the relative depth of your project.

*Happy Climbing.*
