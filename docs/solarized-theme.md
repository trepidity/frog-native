# Solarized themes

The Solarized file-manager handoff (2026-10-27), sections 4–7, supplies the palette and semantic roles. Solarized Dark is the default; Preferences → Appearance stores an explicit Dark or Light choice under `appearance.theme`. Unknown saved values fall back to Dark. There is no system-following mode.

All app-owned browsing layouts, search, editor, help, and preferences share one palette environment. The two window roots observe the same persisted choice. Native flat List/Table selection, menus, pickers, dialogs and Quick Look use the corresponding macOS appearance; their system-owned rendering is not an exact-token guarantee. The app icon is unchanged.

Tree and search rows use an opaque base surface with no zebra stripes, heatmap, birth glow, or Git background tint. Selection uses `sel` and a 2-point leading bar. Inactive panes retain readable text. Hidden names use muted ink; file kinds use one accent on the icon. Git state is separately written as a label. Hover uses `panel2` with the adjusted foregrounds below.

Light uses the handoff's stronger primary/secondary/muted alternatives (`#51666c`, `#4f6168`, `#54686f`). The handoff's normal inks do not all clear 4.5:1 on `panel2`; hover-specific inks are minimally mixed toward white (Dark) or black (Light). This preserves the ratified default Dark values on ordinary rows. No alpha dimming is applied to readable text.

## Measured ink contrast

WCAG sRGB relative luminance, `(lighter + 0.05) / (darker + 0.05)`. Normal minimum covers `bg`, `bg2`, `panel`, and `sel`. Raised minimum covers `panel2`. Values are calculated from the actual source constants; ratios below are rounded for display, while tests use unrounded ratios.

| Theme | Role | Normal hex | Minimum | Raised hex | On panel2 |
|---|---|---|---:|---|---:|
| Dark | primary | `#eee8d5` | 10.610:1 | `#eee8d5` | 9.440:1 |
| Dark | secondary | `#93a1a1` | 4.862:1 | `#97a5a5` | 4.539:1 |
| Dark | muted | `#8c9b9b` | 4.505:1 | `#97a5a5` | 4.539:1 |
| Dark | blue | `#51a0d5` | 4.543:1 | `#61a9d9` | 4.508:1 |
| Dark | good | `#90a114` | 4.515:1 | `#9baa2b` | 4.505:1 |
| Dark | bad | `#e8776e` | 4.516:1 | `#eb867e` | 4.540:1 |
| Dark | warn | `#bb9314` | 4.517:1 | `#c29e2b` | 4.527:1 |
| Dark | cyan | `#3ba89e` | 4.507:1 | `#4eb1a8` | 4.504:1 |
| Dark | violet | `#9294cc` | 4.538:1 | `#9c9ed1` | 4.530:1 |
| Light | primary | `#51666c` | 4.943:1 | `#50656b` | 4.508:1 |
| Light | secondary | `#4f6168` | 5.286:1 | `#4f6168` | 4.748:1 |
| Light | muted | `#54686f` | 4.779:1 | `#51646b` | 4.548:1 |
| Light | blue | `#1e6ca4` | 4.587:1 | `#1c669a` | 4.506:1 |
| Light | good | `#606e00` | 4.598:1 | `#5a6800` | 4.508:1 |
| Light | bad | `#c42c2a` | 4.582:1 | `#b82928` | 4.546:1 |
| Light | warn | `#846400` | 4.506:1 | `#7b5d00` | 4.517:1 |
| Light | cyan | `#1e746d` | 4.541:1 | `#1c6c66` | 4.546:1 |
| Light | violet | `#5d61a9` | 4.573:1 | `#585b9f` | 4.512:1 |

## Verification

`swift test` includes a contrast floor check for both palettes (90 foreground/surface combinations). Replacing the lifted Dark blue with canonical `#268bd2` was checked as a negative control: it fails three normal-surface assertions. This numeric test checks palette values, not pixels or OS-controlled widgets. Native UI checks cover theme selection, live propagation, relaunch persistence, readable file metadata, selection bars, tree expansion, and search reveal.
