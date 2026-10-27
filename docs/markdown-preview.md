# Markdown preview and window header

The preview renders a Markdown document rather than treating each source line as a row.
Use a CommonMark/GFM parser, then an escaped HTML renderer in a local WebKit view with
Solarized colors, a readable measure, semantic headings, tables, lists, quotes, and code.
Keep editing as plain text. Do not execute source HTML/scripts or fetch remote images.

The rendered preview HTML is a product verification seam. Assert semantic elements,
literal code, repeated paragraphs, and inert untrusted markup at that output boundary;
verify typography and header alignment in the native app with a public fixture.

The header's title and search control belong on the same horizontal row as the native
window controls. Remove the extra safe-area offset rather than drawing replacement
traffic lights. Preserve the system controls and window behavior.
The Search/Action control is 24 points high inside the 28-point header, with
11-point text and compact padding. Verify its bounds and alignment in the native
window and confirm both clicking it and Command-K still open the palette.

## Hidden files

Each pane owns its layout and hidden-file visibility; theme is app-wide. Each pane's
toolbar controls only that pane. Command-Shift-Period and palette layout commands
target the active pane. Preferences exposes separate left/right settings.
Migrate the former shared settings once into pane-specific persisted keys.
The preferences persist across launches and visibility defaults to visible. Filter loaded rows
without rescanning directories; preserve expanded branches so showing hidden items
restores the tree. Clear hidden selections, and skip hidden children during keyboard
navigation. Explicitly revealing a hidden file from search turns visibility on only in the target pane.

The native row data (`PaneState.visibleItems` for trees and `displayedItems` for flat
lists/tables) is the product verification seam for visibility and keyboard selection.
Use a real filesystem fixture containing dotfiles, filesystem-hidden flags, and nested
hidden folders; assert rendered row names, selection, and preserved expansion. Native
QA verifies independent toolbar/shortcut behavior and persisted restoration.
Persisted pane settings are an additional product seam: instantiate panes against an
isolated preferences domain, change them independently, then reopen and assert the
restored layouts and visible rows. Theme continues using its existing app-wide key.

Pane activation is verified at the native input seam: click a row in the inactive pane,
check that the blue border follows, then use Command-Shift-Period and verify only that
pane changes. Repeat in both directions and across tree/list/table layouts. Activation
observes native mouse-down events without consuming them; editor clicks retain text
focus. Disable this observation while the search modal is open so it cannot activate
the obscured pane beneath it.

## Multiple selection

Verify selection at the native input seam in Vertical Tree: click a file, then
Shift-Down twice. Three adjacent rows and the status-bar count must agree;
Shift-Up contracts the range. Command-click adds/removes a separate row,
Shift-click selects a range, and an unmodified click returns to one row.
Repeat across expanded folder children and in the other pane; selection in one
pane must not change the other. Double-click activation and disclosure expansion
must still work. This catches a row gesture replacing the selection with one URL
or a missing list selection binding; do not substitute a test of SwiftUI itself.

## Column visibility

Right-click a column header to toggle metadata columns or restore the defaults.
Keep Name visible. Store explicit column choices per pane and share them between that
pane's tree and table layouts. Until customized, preserve existing context/layout defaults.
Both header cells and row cells consume `PaneState.displayedColumns`, an ordered product
rendering seam. Verify column names before/after toggles, pane isolation, and reopening
from an isolated preferences domain. Native QA checks header menu precedence, cell/header
alignment, restored columns, and normal file context menus on rows.

Created and Modified use localized relative calendar dates (Today, Yesterday,
Tomorrow) and medium calendar dates otherwise. Hover reveals the full date and
time. Verify both columns in the native tree/table using files with recent and
older timestamps; the relative label must not change sorting by actual dates.
