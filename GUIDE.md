# 📖 Aura User Guide: Master the Staircase

Welcome to the definitive guide to **Frog Native**. This document covers every interaction, shortcut, and design philosophy needed to master the Aura experience.

---

## 🎹 1. Essential Shortcuts

### Navigation
- **`Up / Down Arrows`**: Navigate the visible staircase.
- **`Right Arrow`**: Expand folder / Descend into first child.
- **`Left Arrow`**: Collapse folder / Ascend to parent folder.
- **`Cmd + Shift + Enter`**: **Solo Mode** (Zoom into selected folder as new root).
- **`Escape`**: Exit Solo Mode / Close Command Palette / Close Editor.

### Searching (Aura Spotlight)
- **`Cmd + K`**: Open Spotlight.
- **`Enter`**: Reveal and center file in the staircase.
- **`Cmd + Enter`**: Open file directly in the Portal.
- **`Arrows / Mouse Hover`**: Preview file (600ms debounce).

### Actions
- **`Cmd + N`**: Create a new "Untitled Folder".
- **`Cmd + Backspace`**: Move selected item(s) to system Trash.
- **`Cmd + C`**: **Aura Hook** (Captures URL + rich image data).
- **`Cmd + ,`**: Open Aura Preferences.

---

## 🌈 2. Reading the Aura

### Color & Light
- **Pulsating Green:** A new file has just landed (lasts 5s).
- **Orange Glow:** Recent modification ("Hot" file).
- **Blue Tint:** Long-term storage ("Cold" file).
- **Yellow Guide Lines:** Modified Git state.
- **Green Guide Lines:** New/Added Git state.

### Indentation Guides
The vertical lines are the "spine" of the Aura. They connect parents to their children. If a line is glowing yellow, every file in that branch has uncommitted changes.

---

## 🚪 3. The Aura Portal
The Portal is for "one-off" work. When you don't want to open a heavy editor, just double-click:
- **Markdown:** Renders with native headers and lists.
- **JSON/Code:** Monospaced frosted editor with direct save support.
- **Binaries:** Automatically hands off to your default native app.

---

## ⚙️ 4. Personalization
Use **Cmd + ,** to tune your experience:
- **Aura Intensity:** Adjust the strength of the depth-based shading.
- **Sound Settings:** Toggle tactile sound effects or adjust volume.
- **Glow Duration:** Customize how long new files pulsate green.

---

## 🦉 Design Philosophy: The Staircase
Frog Native is built on the idea that **Indentation is Physical.** By treating the filesystem as a vertical staircase, we reduce the cognitive load of "jumping" between windows and keep your focus on the relative depth of your project.

*Happy Climbing.*
