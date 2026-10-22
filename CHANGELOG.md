# Changelog

## 2.0.2

- Previews are now shown as small thumbnails, made once from each download by `vipsthumbnail` in its own process with a memory and time limit. The window only ever opens those, never the downloaded file, so a broken or oversized image can't weigh down the shell. Previews cached by earlier versions are cleared once and fetched again.

## 2.0.1

- The right-click menu now works: Enable, Disable, Save, Open folder, Open repository, Show details and Remove now act on the plugin you opened it on.

## 2.0.0

### From the community

Thanks to [@TowhidMolla-Dev](https://github.com/TowhidMolla-Dev) for the first contribution to Omanager ([#1](https://github.com/qempexe/omarchy-omanager/pull/1)), which brought:

- **Plugin sets**: save what you have installed under a name, and restore it later or on another machine. Restoring only enables and installs, it never removes.
- **Batch select**: pick several plugins and update, enable, disable, save or remove them in one go.
- **Right-click menu** on every plugin, with only what applies to it.
- **Changelog in the details**: an installed plugin's recent commits, and the commits an update would bring in.
- **Health** in the Installed tab: plugins in a differently named folder, not git checkouts, missing from the catalog, or without a manifest. Updates and removals now use the plugin's real folder name.
- **Newly installed** sort, and a faster search that no longer rebuilds the whole list on every key.
- Updates run without stopping at a prompt (`--yes`), and installed versions are read from each plugin's `manifest.json`, so updates are found again.
- A bigger default window: 560 x 680.

### New

- **Colors tab**, with five schemes: Follow theme, Theme palette (every category gets a color from your theme), Window borders (your active window border's colors), Custom (your own background, text and accent) and Monochrome. A Text setting keeps text always readable, follows the theme, or uses your own color. My color and By category from 1.x carry over as Custom and Theme palette.
- **Window outline** in your window border's gradient, at the border's own angle, or in one of its colors; and **Window opacity**.
- **Every filter from the website**: Verified and Unverified, the Kids, VPN, Bar, AI, Games and Security collections, the Most copied, Top ranked and Plugin type sorts, and `tag:`, `kind:` and `@author` in the search box. Recently upgraded now also counts a new version, like the website's Recent activity, and Best install rate rates plugins the way the website does.
- **A logo**, light and dark, in the header, and an **About** tab in Settings.
- **Previews are cached**: each image is downloaded once into `~/.cache/omarchy-omanager/previews`, and shown from there. The newest 1200 are kept.
- Settings have headings within each tab, and the Window tab has its own Look section.

### Changed

- The files are sorted into folders by role (`qml/browse`, `qml/panel`, `qml/core`, `qml/controls`, `qml/js`), and the changelog moved here from the README.
- Every helper command runs with a time limit and a limit on what it may print, and the catalog download keeps to https all the way, redirects included.
- Incoming changes are fetched from the plugin's address in the catalog.
- Links open only on the sites plugins live on and on the plugin website.

### Fixed

- The changelog in the details loads again.
- The window opens at the new default size everywhere, not only in the settings.
- Omarchy's own plugins listed in the catalog show under Built-in only, and never offer an install command.

## 1.5.0

- **New look for the whole panel**, docked and popped out: one rounded panel with a plain neutral edge, a header card (title, status, Refresh, Pop out / Dock, close), underlined tabs, one content card of rows, and the `Esc` footer. The search box now sits at the top of the content card.
- **The docked manager is a popup** placed flush against the bar, instead of the shell's own panel frame. `Panel.qml` keeps the contract `BarWidget.qml` uses (`opened`, `open()`, `close()`).
- **Compact by default.** New defaults: 460 x 620, *List* layout, window tint 0. Narrow windows get a *Filters* drawer; from about 720 px wide the filter sidebar and *List + stage* return. If you changed these before, your saved values still win; use *Reset all* to take the new defaults.
- **Switches.** Installed plugins and on/off settings use switch. An installed plugin's switch enables or disables it, and enabled plugins get the accent-tinted row.

## 1.4.1

- **Settings now survive a shell restart, logout or reboot.** Changes were always written to `settings.json`, but the file was never read back correctly: `FileView.text` is a method in Quickshell, and `SettingsStore.qml` passed the method itself instead of calling it. The saved JSON failed to parse, every start looked like "no saved settings", and the first change you made overwrote the file with defaults. The store now reads the file with `text()` (through a small `readText()` helper, the same pattern `Service.qml` uses), merges it under anything changed in memory, and notifies listeners once it has loaded.
- If you lost settings to the old overwrite, set them once more; they persist from here on.

## 1.4.0

- **New look for the whole panel**:
  - a header card with the title, plugin counts, one search box, and the actions (layout, Refresh, Pop out / Dock, close);
  - equal-width underlined tabs: Browse, Installed, Updates, Saved, Settings;
  - the filters, results and stage sit in one rounded content card;
  - a footer with the `Esc` hint, the catalog status and the Log button.
- **Plain edges.** The window edge is a neutral line; the header logo and the search box no longer have accent borders. *Window outline* (now off by default) switches the edge to the accent color.
- **Follows the shell's accent.** With *Follow theme* or *By category*, selected tiles, tabs, chips and sliders use the shell theme's accent color (the bar's foreground when the shell exposes none). *My color* and *Monochrome* behave as before.
- **Roundness reaches everything.** Buttons, chips, cards, the content card and the window all scale with the Roundness setting (0 stays square).
- **New Settings tab.** One underlined tab per group; the header's search box searches the settings, *Reset all* sits in the header. The footer says how many settings differ from the defaults.
- **Tiles, segmented bars, chips and sliders.** Colors, Card style, Spacing, Open as and Layout are tiles with a little picture of each choice. Short choices (Card columns, Filters sidebar, Start on, the recency filter, Bar button shows, Middle click) are one segmented bar. Sort by stays chips because it has nine. Sliders have `− value +` on the right, a reset arrow, and the range under the track.
- **`control` in `tools/gen.py`.** `E()` takes an optional `control="tiles" | "seg" | "chips"`; without it a choice is a segmented bar up to 5 options and chips beyond that. `Schema.js` carries it.

## 1.3.1

- The search boxes and setting fields no longer use Qt's built-in text input, so nothing reads the clipboard on its own. Middle-click paste, selecting text with the mouse, cut and copy, and input-method composition are not available in them.
- **No native text input, guarded by a test.** No file in the plugin creates a `TextInput`, `TextField`, `TextArea` or `TextEdit`. Those watch the clipboard on their own and read foreign text through Qt's Wayland receiver, which has no total byte limit or deadline, so a clipboard provider that streams forever could stall the shared shell without any paste. Fields are drawn by `PasteInput.qml` from a plain `Text`; the only clipboard read is Ctrl+V / Shift+Insert through `wl-paste`, capped at 1 KB and 2 seconds. `tests/test_no_native_text.py` fails if a native text element, a `QtQuick.Controls` import, a direct clipboard hook, or a loss of that cap ever appears.

## 1.3.0

- Changes apply on the spot and are saved to `settings.json`. Omanager no longer calls `omarchy bar set`, so Omarchy's own settings screen does not show Omanager's values.
- A chosen value is shown on its control straight away, and the file is only written by Omanager (read once at startup, never watched), so a value should not snap back to an old one.
- **Open as** is read on every bar-button click until you use Pop out or Dock in the session. Before, it was read once per session, so the bar button kept opening the panel until a restart.
- **Start on, Sort by, the recency filter, Verified only and Hide installed** update the Browse filters as soon as you change them. A filter you have set yourself is left alone.
- **Window width and height** are dimmed and locked while the manager is popped out, with a note explaining why.
- The main search box is limited to 50 characters, and text that doesn't fit is cut at the box edge.
- Bar button text is limited to 10 characters, same fitting fix.
- Catalog address is limited to 100 characters, same fitting fix.
- My accent color is limited to 7 characters, same fitting fix.
- Ctrl+V and Shift+Insert in the search boxes and setting fields read at most 1 KB of the clipboard, with a 2-second limit, and run no shell. Without this, a very large clipboard could be read in full before the length limit applied.
- Settings edits are meant to run without freezing the shell. The likely cause of the earlier freeze (a process started for every edit) has been removed.

## 1.2.0

- **Pop-out matches the bar.** The pop-out window and the bar panel now paint the same opaque surface, taken from the bar's own background colour. Before, the pop-out used a neutral grey derived from the foreground, so the two looked different.
- **Colors that read on any bar.** Text falls back to black or white when the bar's foreground is too close to its background.
- **Status colours on light themes.** Verified, update, and warning colours use darker variants on light surfaces. Before, the pastel versions were hard to read.
- **Selected chips and tabs.** Labels pick black or white against the fill, so they stay readable with any accent colour, including light custom colours.
- **By category** picks tone lightness from the actual surface, so the hues stay legible on light and dark bars.
- **Monochrome** is truly grey. Surfaces and text use only black, white and greys, with no tint from the bar's colours.

## 1.1.0

- Fixed **"Newly uploaded"**: the listing date (`listedAt`) is now preferred over the internal `addedAt` timestamp, so the ordering matches the website's **RECENTLY ADDED** view.
- Added a new **As listed** sort option that preserves the raw catalog order as a guaranteed fallback.
- Added a **Compact** layout: a dense, table-like view of the whole catalog with one plugin per row:
  - category dot
  - name
  - category
  - author
  - stats
  - status badges
  - upload age
  - saved star
  - install button
- Compact can be selected from the header's layout button or **Settings > Window > Layout**.
- The filter and sort pipeline is unchanged, so the Compact view shows exactly the same set of plugins as the other layouts.

## 1.0.0

- First release.
