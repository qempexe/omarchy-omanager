# Omanager

A plugin manager for the Omarchy bar. Click the bar button and a panel opens; click it again and it closes. Browse the community catalog, filter it every way you can think of, and install, update, enable, disable, or remove plugins without touching a terminal.

![Omanager preview](preview.png)

## Features

- **Tabs**: Browse, Installed, Updates (with *Update all*), Saved, Sets, Settings.
- **Stats**: stars, hearts, views, and install-command copies show on every card, list row, and compact row, and in the detail / stage pane.
- **Sort**:
  - newly uploaded
  - **as listed** (the exact order the catalog feed returns them in — matches the website's default view)
  - recently upgraded
  - **new or upgraded** (whichever is most recent)
  - most hearts
  - stars
  - views
  - best install rate
  - A to Z
  - **newly installed** (Installed tab only: the moment each plugin landed on disk, newest first)

  The Installed tab's sort list also offers **Newly installed**, which reads each plugin directory's birth time (falling back to its modification time on filesystems that don't record one). Everything else is offered there too.
- **Health** (Installed tab): flags installed plugins that need attention and adds a **Needs attention** status to filter the list to them:
  - installed in a folder whose name differs from its id
  - not a git checkout, so `omarchy plugin update` cannot touch it
  - not in the catalog (local or unpublished)
  - a plugin directory with no readable `manifest.json`
  The detail pane shows the exact problem and an **Open folder** button. Updates and removals always run against the real folder name, so a plugin in a differently named folder still updates and removes correctly.
- **Changelog**: the detail pane lists an installed plugin's recent commits (`git log`, read-only). When an update is pending, **Incoming** fetches and shows exactly what the update would bring in, so you can see the changes before you update.
- **Right-click a plugin** for a short menu of what applies to it (update/install, enable/disable, save, open folder or repository, copy install command, details, remove).
- **Batch select**: **Select** turns cards into checkboxes and shows an action bar to **Update / Enable / Disable / Save / Remove** everything picked at once (only the applicable ones act). Removals still ask to confirm.
- **Plugin sets** (Sets tab): name a snapshot of what you have installed, then **Restore** it later to re-enable what is off and reinstall what is missing (using the plugin's repo, so it works on a fresh machine). Nothing already present is removed or downgraded, so restoring is always safe.
- **Filters**:
  - community / built-in / all
  - category
  - tags (several at once)
  - verified only
  - hide installed
  - status (installed, not installed, has update, saved, new since your last visit)
  - time window (week, month, 3 months, year) that looks at uploads, upgrades, or either

  The **Uploaded / Upgraded / Either** chips are dimmed until a time window is chosen because they only apply to it.

- **Search** across names, IDs, authors, categories, tags, and descriptions.
- **Pop out / dock**:
  - The header's *Pop out* button turns the manager into a real window you can move, resize, and tile.
  - *Dock* puts it back into the bar panel.
  - Filters, selection, and search survive the switch.
  - The dock and the pop-out are the same panel, so they look identical.
  - In a narrow window the filters open from a *Filters* button; from about 720 px wide the sidebar is shown.
  - **Settings > Window > Open as** picks which one the bar button opens first.
- **Layouts**:
  - *List* — default: compact row cards. Installed plugins have an on/off switch.
  - *List + stage* — wide windows only (about 720 px and up): the list on the left, a large preview with actions for the selected plugin on the right.
  - *Cards* — 1 to 4 columns or automatic.
  - *Compact* — a dense, table-like view with one plugin per row: name, category, author, stats, status, upload age, and install button.

  Previews come from the catalog's own thumbnails and full-size images. Compact skips them entirely, so it stays fast on large catalogs.

  Cycle with the header's layout button, or pick one in **Settings > Window > Layout**.

- **Colors**:
  - follow the bar theme
  - your own accent color
  - monochrome
  - a different tint per category

  Plus card style, spacing, roundness, text size, and window tint.

- **36 settings**, grouped into:
  - Appearance
  - Window
  - Browse
  - Catalog
  - Safety
  - Bar

  Settings are searchable, written in plain language, and have a reset arrow for anything you changed.

- **Safety**:
  - confirmation before install / update / remove
  - optional block on unverified plugins
  - commands run as argument lists (never through a shell)
  - repository addresses must be plain HTTPS GitHub / GitLab / Codeberg repositories

- **Offline support**: works offline from a cached catalog and keeps bookmarks and your last visit.
- **Fast refresh**: the catalog is requested compressed and conditionally, so an unchanged catalog is a tiny `304` instead of a multi-megabyte download. Hearts, views, and copies come from the marketplace's separate stats API.

## Install

```bash
omarchy plugin add https://github.com/qempexe/omarchy-omanager.git --enable
```

Or from a local copy:

```bash
mkdir -p ~/.config/omarchy/plugins/io.github.qempexe.omanager
cp -r ./. ~/.config/omarchy/plugins/io.github.qempexe.omanager/
omarchy plugin validate ~/.config/omarchy/plugins/io.github.qempexe.omanager
omarchy plugin enable io.github.qempexe.omanager --section right
```

Requires `curl` (catalog download). `wl-clipboard` is needed on Wayland: `wl-copy` for "Copy install command" and `wl-paste` for pasting into text fields (read at most 1 KB, for at most 2 seconds, and only when you press Ctrl+V or Shift+Insert).

### Floating the Pop-out Window (Hyprland)

Hyprland tiles new windows. To make the popped-out manager float and center, match its title (a Quickshell toplevel always has the class `org.quickshell`).

In `~/.config/hypr/hyprland.lua`, following the style Omarchy uses:

```lua
o.window({ class = "^org\\.quickshell$", title = "^Omanager$" }, { tag = "+omanager-window" })
o.window({ tag = "omanager-window" }, { float = true })
o.window({ tag = "omanager-window" }, { center = true })
o.window({ tag = "omanager-window" }, { size = { 460, 620 } })
```

Without rules it still works; it just tiles like any other window.

## Settings

Everything is in the window's **Settings** tab (or by right-clicking the bar button).

Each change is applied instantly and saved locally, in `settings.json` in your state folder (`~/.local/state/omarchy-omanager/`). Omanager does not run `omarchy bar set`, so Omarchy's own settings screen shows the defaults, not your values. Editing `settings.json` by hand takes effect after a shell restart. Settings persist across shell restarts, logouts and reboots: the file is read once at startup and merged under anything you change in the meantime.

A few settings behave differently in some situations:

- **Open as** is read each time you click the bar button, until you use Pop out or Dock in the current session.
- **Window width and height** are locked (dimmed) while the manager is popped out, because the window manager sizes that window. They apply again after you dock it.
- **Start on, Sort by, the recency filter, Verified only and Hide installed** update the Browse filters when you change them. A filter you have set yourself is left alone.

The list lives in `tools/gen.py`. Each choice can say how it is drawn with `control="tiles"`, `"seg"` or `"chips"`. Edit it, run:

```bash
python3 tools/gen.py
```

Then `manifest.json`, `Schema.js`, and the settings block of `BarWidget.qml` are regenerated together.

## Shell Commands

```bash
omarchy-shell shell summon io.github.qempexe.omanager   # open the window
omarchy-shell shell hide io.github.qempexe.omanager     # close it
omarchy-shell io.github.qempexe.omanager refresh        # re-download the catalog
omarchy-shell io.github.qempexe.omanager status         # JSON: catalog, updates, activity
```

## How It Works

```text
Service.qml    catalog download + cache, `omarchy plugin list --json`, action queue
Model.js       normalising, filtering, sorting, URL/command safety (unit-tested)
BarWidget.qml  bar button, settings, owns UiState, decides panel vs window
UiState.qml    all window state (filters, selection, theme helpers, results)
ManagerView    the whole UI; shown by Panel.qml (docked popup) or PopoutWindow.qml
ResultsView    the scrolling grid / list / compact table + empty states
PluginCard     one plugin in card, list, or compact form
Sw             the on/off switch
SettingsView   the Settings tab body: group tabs and the settings
SettingRow     one setting: tiles, segmented bar, chips, slider, switch, field
TileArt        the little pictures inside the settings tiles
PasteInput     the text field (a plain Text, never a TextInput)
```

## Tests

```bash
node tests/test_model.js        # catalog parsing, filters, sorts, command safety
python3 tests/test_manifest.py  # manifest / Schema.js / QML drift, plain-text rule
python3 tests/test_no_native_text.py  # no TextInput anywhere, paste read stays capped
```

## Changelog

### Unreleased

- **Installed-tab upgrades**: a *Newly installed* sort (by the on-disk directory's birth time), and a **Health** view that flags plugins that need attention — installed under a different folder name than their id, not a git checkout, missing a manifest, or missing from the catalog.
- **Update and remove by folder name.** `omarchy plugin update` and `remove` resolve the on-disk directory, not the manifest id; the manager now passes the directory, so a plugin cloned into a differently named folder updates and removes correctly. (Built-in and enable/disable still use the id.)
- **Changelog in the detail pane**: recent commits for an installed plugin, plus the exact commits an available update would bring in.
- **Right-click** any plugin for a short, context-aware menu.
- **Batch select**: pick several plugins and Update / Enable / Disable / Save / Remove them together.
- **Plugin sets**: save the current install as a named set and restore it on another machine.
- **Faster search**: the query pool is cached across keystrokes instead of rebuilt each time.

### 1.5.0

- **New look for the whole panel**, docked and popped out: one rounded panel with a plain neutral edge, a header card (title, status, Refresh, Pop out / Dock, close), underlined tabs, one content card of rows, and the `Esc` footer. The search box now sits at the top of the content card.
- **The docked manager is a popup** placed flush against the bar, instead of the shell's own panel frame. `Panel.qml` keeps the contract `BarWidget.qml` uses (`opened`, `open()`, `close()`).
- **Compact by default.** New defaults: 460 x 620, *List* layout, window tint 0. Narrow windows get a *Filters* drawer; from about 720 px wide the filter sidebar and *List + stage* return. If you changed these before, your saved values still win; use *Reset all* to take the new defaults.
- **Switches.** Installed plugins and on/off settings use switch. An installed plugin's switch enables or disables it, and enabled plugins get the accent-tinted row.

### 1.4.1

- **Settings now survive a shell restart, logout or reboot.** Changes were always written to `settings.json`, but the file was never read back correctly: `FileView.text` is a method in Quickshell, and `SettingsStore.qml` passed the method itself instead of calling it. The saved JSON failed to parse, every start looked like "no saved settings", and the first change you made overwrote the file with defaults. The store now reads the file with `text()` (through a small `readText()` helper, the same pattern `Service.qml` uses), merges it under anything changed in memory, and notifies listeners once it has loaded.
- If you lost settings to the old overwrite, set them once more; they persist from here on.

### 1.4.0

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

### 1.3.1

- The search boxes and setting fields no longer use Qt's built-in text input, so nothing reads the clipboard on its own. Middle-click paste, selecting text with the mouse, cut and copy, and input-method composition are not available in them.
- **No native text input, guarded by a test.** No file in the plugin creates a `TextInput`, `TextField`, `TextArea` or `TextEdit`. Those watch the clipboard on their own and read foreign text through Qt's Wayland receiver, which has no total byte limit or deadline, so a clipboard provider that streams forever could stall the shared shell without any paste. Fields are drawn by `PasteInput.qml` from a plain `Text`; the only clipboard read is Ctrl+V / Shift+Insert through `wl-paste`, capped at 1 KB and 2 seconds. `tests/test_no_native_text.py` fails if a native text element, a `QtQuick.Controls` import, a direct clipboard hook, or a loss of that cap ever appears.


### 1.3.0

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

### 1.2.0

- **Pop-out matches the bar.** The pop-out window and the bar panel now paint the same opaque surface, taken from the bar's own background colour. Before, the pop-out used a neutral grey derived from the foreground, so the two looked different.
- **Colors that read on any bar.** Text falls back to black or white when the bar's foreground is too close to its background.
- **Status colours on light themes.** Verified, update, and warning colours use darker variants on light surfaces. Before, the pastel versions were hard to read.
- **Selected chips and tabs.** Labels pick black or white against the fill, so they stay readable with any accent colour, including light custom colours.
- **By category** picks tone lightness from the actual surface, so the hues stay legible on light and dark bars.
- **Monochrome** is truly grey. Surfaces and text use only black, white and greys, with no tint from the bar's colours.

### 1.1.0

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

### 1.0.0

- First release.

## Status

The logic in `Model.js` and the manifest/QML consistency are covered by the tests.

The bar widget has been loaded in a live shell; the 1.5.0 popup (`Panel.qml`), the pop-out, and the layouts have not been run there yet.

Things that are inferred rather than confirmed:

- **Catalog fields**: previews use `previewThumbnail` / `previewImage`, and the listing date reads `listedAt` first (falling back to `addedAt`, `createdAt`, and several other spellings) so the "Newly uploaded" order matches the website.
- **Last upgraded date**: reads `repositoryUpdatedAt` first, then several other spellings. If "Upgraded" shows "unknown" or looks wrong, adjust the alias list in `normalizePlugin`.
- **Stats API response shape**: `api.omarchyplugins.com/v1/stats` accepts several shapes. If none matches, hearts / views simply stay empty.
- **Installed versions**: `omarchy plugin list --json` reports no version at all, so the Updates tab reads each plugin's `manifest.json` under `~/.config/omarchy/plugins/*/` with `jq` (an omarchy dependency, run through `find -exec`). Without `jq` the scan comes back empty, no updates are shown, and the activity log says why.
- **Install time**: not in the manifest either, so the Installed tab's **Newly installed** sort takes each plugin directory's birth time from `stat` (`%W`, falling back to mtime `%Y` on filesystems that don't record birth time). Directories with no readable time sort last.
- **Update/remove by folder**: `omarchy plugin update` and `omarchy plugin remove` resolve `~/.config/omarchy/plugins/<name>`, where `<name>` is the folder, not the manifest id. A plugin installed in a folder named differently from its id (a manual clone) is updated and removed by its folder name; enable/disable still use the id.
- **`FloatingWindow`**: the pop-out comes from Quickshell. It is used by other Omarchy plugins but has not been run here.
- **CLI flags**: the `--yes` flags on `plugin add` / `plugin remove` and the `plugin enable|disable|update` subcommands are assumed. Remove retries without `--yes` if the first attempt fails.

Run:

```bash
omarchy plugin validate .
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

first if something looks off.

### If Clicking the Bar Button Shows Nothing

The button now logs why and never silently does nothing.

If the bar panel fails to load or does not open within about half a second, the manager opens as its own window instead.

Look in `qs log` for lines starting with `Omanager:`:

```text
Omanager: Panel.qml failed to load
Omanager: the panel did not open
```

Panel sizing no longer depends on the shell's `Style.space` / `fittedContentWidth` helpers existing.

To always use the window, set **Settings > Window > Open as** to **Own window**.

## License

MIT