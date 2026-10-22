.pragma library

// Pure logic for Omanager: no QML types in here, so it is unit-tested with node
// (tests/test_model.js). Everything coming from the catalog or from
// `omarchy plugin list` is untrusted input: it is normalised, type-checked and
// never passed to a shell. Commands are built as argument arrays.

var DAY = 86400000
var STATS_URL = "https://api.omarchyplugins.com/v1/stats"
var SAFE_ID = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/
var REPO_HOSTS = ["github.com", "gitlab.com", "codeberg.org"]
var IMAGE_HOSTS = ["plugins.omarchy.org", "omarchyplugins.com", "raw.githubusercontent.com",
                   "github.com", "user-images.githubusercontent.com", "private-user-images.githubusercontent.com"]
var CATALOG_ORIGIN = "https://plugins.omarchy.org/"

// Size limits for what the helpers may print. The catalog is around 15 MB today.
var CATALOG_MAX = 48 * 1048576
var STATS_MAX = 8 * 1048576
var CATALOG_ITEMS_MAX = 20000

// curl for one https download: no ~/.curlrc, https only (redirects too), a time
// limit and a size limit. The caller adds `--` and the address.
function curlArgs(maxBytes, seconds) {
    return ["curl", "-q", "--fail", "--silent", "--show-error", "--location", "--max-redirs", "5",
            "--proto", "=https", "--proto-redir", "=https", "--compressed",
            "--max-time", String(seconds), "--max-filesize", String(maxBytes), "-A", "omarchy-omanager"]
}

// ---- scans of the plugins folder ---------------------------------------------
// Third-party plugins live in ~/.config/omarchy/plugins/<dir>/manifest.json. The
// directory name is not always the plugin id, so the id is read from the manifest
// itself: one `[id, version, path, clonedFrom]` JSON array per plugin. Hidden
// directories are clone staging areas and backups, never plugins, and only plain
// files are read. One jq per manifest, so a broken file only costs its own line.
function scanVersionsArgs(dir) {
    return ["find", dir, "-mindepth", "2", "-maxdepth", "2", "-type", "f",
            "-name", "manifest.json", "-not", "-path", dir + "/.*", "-size", "-256k",
            "-exec", "jq", "--compact-output",
            '[(.id // "" | tostring | .[0:128]), (.version // "" | tostring | .[0:32]), (input_filename), (.omarchy.clonedFrom // "" | tostring | .[0:256])]',
            "{}", ";"]
}

// The install time is not in the manifest, so it comes from the directory itself:
// `stat` prints birth time (0 when the filesystem does not record one), then mtime.
function scanBirthsArgs(dir) {
    return ["find", dir, "-mindepth", "1", "-maxdepth", "1", "-type", "d", "-not", "-name", ".*",
            "-exec", "stat", "--format=%W %Y %n", "{}", ";"]
}

// Which plugin directories are git checkouts (`%h` prints the folder holding .git).
function scanGitArgs(dir) {
    return ["find", dir, "-mindepth", "2", "-maxdepth", "2", "-name", ".git", "-type", "d", "-printf", "%h\n"]
}

function str(v) { return (v === null || v === undefined) ? "" : String(v) }
function num(v) { var n = Number(v); return isFinite(n) ? n : 0 }

function get(o, path) {
    var parts = path.split(".")
    var cur = o
    for (var i = 0; i < parts.length; i++) {
        if (cur === null || cur === undefined || typeof cur !== "object") return undefined
        cur = cur[parts[i]]
    }
    return cur
}

function pick(o, paths) {
    for (var i = 0; i < paths.length; i++) {
        var v = get(o, paths[i])
        if (v !== undefined && v !== null && v !== "") return v
    }
    return undefined
}

function ts(v) {
    if (v === undefined || v === null || v === "") return 0
    if (typeof v === "number") return v < 1e12 ? v * 1000 : v
    var t = Date.parse(String(v))
    return isFinite(t) ? t : 0
}

function words(v) {
    if (Array.isArray(v)) return v.map(str).map(function(s) { return s.trim() }).filter(Boolean)
    if (typeof v === "string") return v.split(/[,;]/).map(function(s) { return s.trim() }).filter(Boolean)
    return []
}

// ---- URLs -----------------------------------------------------------------
function parseUrl(u) {
    var m = /^https:\/\/([A-Za-z0-9.-]+)(?::\d+)?(\/[^\s?#]*)?(?:[?#].*)?$/.exec(str(u).trim())
    return m ? { host: m[1].toLowerCase(), path: m[2] || "/" } : null
}

// Returns a clean https clone URL, or "" when it is not a plain repo address.
function safeRepoUrl(u) {
    var s = str(u).trim()
    if (s.indexOf("git+") === 0) s = s.slice(4)
    if (/^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+$/.test(s)) s = "https://github.com/" + s
    var p = parseUrl(s)
    if (!p || REPO_HOSTS.indexOf(p.host) < 0) return ""
    var m = /^\/([A-Za-z0-9._-]+)\/([A-Za-z0-9._-]+?)(?:\.git)?\/?$/.exec(p.path)
    if (!m) return ""
    return "https://" + p.host + "/" + m[1] + "/" + m[2] + ".git"
}

function webUrl(u) {
    var s = safeRepoUrl(u)
    return s ? s.replace(/\.git$/, "") : ""
}

// Links the window opens in the browser: https on a known site only (the code
// hosts plugins live on, and the plugin website), with no user part and nothing
// unusual in them. The About page link is one of these too.
var LINK_HOSTS = REPO_HOSTS.concat(["plugins.omarchy.org", "omarchy.org"])

function safeWebUrl(u) {
    var s = str(u).trim()
    if (s.length > 2048 || /[\s\\<>"'`]/.test(s) || /[\x00-\x1f\x7f]/.test(s)) return ""
    var p = parseUrl(s)
    return p && LINK_HOSTS.indexOf(p.host) >= 0 ? s : ""
}

function safeImageUrl(u) {
    var s = str(u).trim()
    if (s === "") return ""
    if (s.indexOf("//") !== 0 && !/^[a-z]+:/i.test(s)) s = CATALOG_ORIGIN + s.replace(/^\/+/, "")
    var p = parseUrl(s)
    if (!p || IMAGE_HOSTS.indexOf(p.host) < 0 || s.length > 2048) return ""
    return s
}

function safeCatalogUrl(u) {
    var s = str(u).trim()
    return parseUrl(s) && s.length <= 2048 && !/\s/.test(s) ? s : ""
}

// ---- preview images -------------------------------------------------------
// Previews are downloaded into a local cache folder and shown from there, so an
// image is fetched once (https, size and time limits) and never streamed straight
// from the network into the window. A download is never shown as it is: it is first
// made into a small thumbnail by vipsthumbnail, in its own process with a memory and
// time cap, and only that clean PNG (no metadata) is ever decoded by the shell. An
// image built to blow up while it is decoded can then only stop its own thumbnail.
var IMAGE_MAX = 4 * 1048576
var IMAGE_BATCH = 12
var IMAGE_KEEP = 1200

// A stable file name for an image address: two 32-bit hashes and the extension.
function imageName(url) {
    var s = str(url)
    var a = 0x811c9dc5, b = 5381
    for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i)
        a = Math.imul(a ^ c, 16777619) >>> 0
        b = (Math.imul(b, 33) + c) >>> 0
    }
    var m = /\.(webp|png|jpe?g|avif|gif)(?:$|[?#])/i.exec(s)
    var hex = function(n) { return ("00000000" + n.toString(16)).slice(-8) }
    return hex(a) + hex(b) + "." + (m ? m[1].toLowerCase().replace("jpeg", "jpg") : "img")
}

function isImageName(name) {
    return /^[0-9a-f]{16}\.(webp|png|jpg|avif|gif|img)$/.test(str(name))
}

// The thumbnail made from a download: the same hash, always a PNG.
function thumbName(name) {
    return isImageName(name) ? str(name).slice(0, 16) + ".png" : ""
}
function isThumbName(name) {
    return /^[0-9a-f]{16}\.png$/.test(str(name))
}

// Makes a download into a thumbnail at most 960 by 540, all metadata left behind.
// Run with VIPS_BLOCK_UNTRUSTED=1, so only plain image loaders are used, with one
// worker thread (VIPS_CONCURRENCY=1), and under prlimit: 512 MiB of memory and
// 20 seconds of processor at most. One worker keeps it inside that memory however
// many cores the machine has.
var THUMB_MEMORY = 536870912
function thumbArgs(raw, out) {
    if (!/^\/[^\0\[\]]*\/[0-9a-f]{16}\.(webp|png|jpg|avif|gif|img)$/.test(str(raw))) return null
    if (!/^\/[^\0\[\]]*\/[0-9a-f]{16}\.png$/.test(str(out))) return null
    return ["prlimit", "--as=" + THUMB_MEMORY, "--cpu=20", "--",
            "vipsthumbnail", raw, "--size", "960x540", "-o", out + "[keep=none]"]
}

// One curl for a batch of images. Each line it prints is "<exit code> <file>", so
// the files that arrived whole are known; the rest are deleted afterwards.
function imageBatchArgs(items, dir) {
    var argv = curlArgs(IMAGE_MAX, 60).concat(["--parallel", "--parallel-max", "4",
                "--write-out", "%{exitcode} %{filename_effective}\\n"])
    for (var i = 0; i < items.length; i++) {
        var url = safeImageUrl(items[i].url)
        if (!url || !isImageName(items[i].name)) continue
        argv.push("-o", dir + "/" + items[i].name, "--url", url)
    }
    return argv
}

// The names curl reported as complete (exit code 0).
function imageReport(text, dir) {
    var ok = {}
    var lines = str(text).split("\n")
    for (var i = 0; i < lines.length; i++) {
        var m = /^0 (.+)$/.exec(lines[i].trim())
        if (!m || m[1].indexOf(dir + "/") !== 0) continue
        var name = m[1].slice(dir.length + 1)
        if (isImageName(name)) ok[name] = true
    }
    return ok
}

// `find -printf '%T@ %f\n'` of the thumbnail folder -> { keep: {name: true}, drop: [names] },
// the newest IMAGE_KEEP kept.
function imageInventory(text) {
    var rows = []
    var lines = str(text).split("\n")
    for (var i = 0; i < lines.length; i++) {
        var m = /^([0-9.]+) (\S+)$/.exec(lines[i].trim())
        if (m && isThumbName(m[2])) rows.push({ t: Number(m[1]), name: m[2] })
    }
    rows.sort(function(x, y) { return y.t - x.t })
    var keep = {}, drop = []
    for (var j = 0; j < rows.length; j++) {
        if (j < IMAGE_KEEP) keep[rows[j].name] = true
        else drop.push(rows[j].name)
    }
    return { keep: keep, drop: drop }
}

// ---- catalog --------------------------------------------------------------
function isVerified(raw) {
    var flag = pick(raw, ["verified", "isVerified"])
    if (flag === true || flag === "true") return true
    if (flag === false || flag === "false") return false
    var st = str(pick(raw, ["verification.status", "verification.state", "verificationStatus",
                            "verification", "trust.status"])).toLowerCase()
    return st.indexOf("verified") >= 0 && st.indexOf("unverified") < 0 && st.indexOf("update") < 0
}

// Install rate, as the website ranks it: install-command copies per detail view,
// by the lower bound of the 95% Wilson interval, so a few lucky copies cannot beat
// a well-measured plugin. Fewer than 20 views, or nothing to install: not rated (-1).
var RATE_MIN_VIEWS = 20
function installRate(p, copies, views) {
    if (!p.installable || !p.repo || views < RATE_MIN_VIEWS) return -1
    return wilson(Math.min(copies, views), views)
}

// "Bar widget" -> "bar-widget": how the website writes a plugin type in kind:...
function kindKey(kind) {
    return str(kind).toLowerCase().split(/[^a-z0-9]+/).filter(Boolean).join("-")
}

function wilson(pos, n) {
    if (n <= 0) return 0
    var z = 1.96, p = Math.min(1, pos / n)
    return (p + z * z / (2 * n) - z * Math.sqrt((p * (1 - p) + z * z / (4 * n)) / n)) / (1 + z * z / n)
}

function normalizePlugin(raw, fallbackId) {
    if (!raw || typeof raw !== "object") return null
    var id = str(pick(raw, ["id", "pluginId", "plugin_id", "manifest.id", "slug"]) || fallbackId).trim()
    if (!SAFE_ID.test(id)) return null
    var authorRaw = pick(raw, ["author", "owner", "manifest.author", "authors"])
    if (Array.isArray(authorRaw)) authorRaw = authorRaw[0]
    if (authorRaw && typeof authorRaw === "object") authorRaw = pick(authorRaw, ["name", "login", "username"])
    var repoRaw = pick(raw, ["repository.url", "repository", "repo", "repoUrl", "repo_url", "source.url",
                             "source.repository", "source.repo", "github", "url", "homepage"])
    if (repoRaw && typeof repoRaw === "object") repoRaw = pick(repoRaw, ["url", "href"])
    // listedAt is the public listing date the website shows in "RECENTLY ADDED".
    // It must win over addedAt, which is an internal timestamp that is often
    // populated for every plugin and would otherwise shadow it.
    var added = ts(pick(raw, ["listedAt", "listed_at", "listDate", "list_date", "listingDate",
                              "addedAt", "added", "createdAt", "created", "firstSeen",
                              "publishedAt", "published_at", "dateAdded", "date_added",
                              "added_at", "created_at", "submittedAt", "submitted_at",
                              "listing.createdAt", "listing.addedAt", "listing.date",
                              "listing.listedAt", "listing.listed_at"]))
    var updated = ts(pick(raw, ["repositoryUpdatedAt", "updatedAt", "updated", "lastUpdated", "modifiedAt", "pushedAt",
                                "lastCommitAt", "lastCommit.date", "commitDate", "upstream.updatedAt",
                                "upstream.pushedAt", "updated_at", "pushed_at", "upstreamUpdatedAt",
                                "lastPush", "commitAt", "listingValidatedAt", "validatedAt"]))
    var thumb = pick(raw, ["previewThumbnail", "previewThumb", "thumbnail", "preview", "previewUrl",
                           "cardImage", "images.card", "assets.card", "previews.card"])
    var full = pick(raw, ["previewImage", "previewFull", "image", "screenshot", "images.detail"])
    // the website's "Recent activity": a new version or a push, whichever is later
    updated = Math.max(updated, ts(pick(raw, ["versionUpdatedAt"])))
    var views = num(pick(raw, ["views", "metrics.views", "engagement.views", "detailViews"]))
    var copies = num(pick(raw, ["copies", "metrics.copies", "engagement.copies", "commandCopies", "installs"]))
    var p = {
        id: id,
        name: str(pick(raw, ["name", "displayName", "title", "manifest.name"]) || id).slice(0, 80),
        description: str(pick(raw, ["description", "summary", "manifest.description"])).slice(0, 600),
        author: str(authorRaw).slice(0, 60),
        version: str(pick(raw, ["version", "manifest.version"])).slice(0, 32),
        category: str(pick(raw, ["category", "barWidget.category"]) || "Other").slice(0, 40),
        tags: words(pick(raw, ["tags", "topics", "keywords"])).slice(0, 8).map(function(t) { return t.slice(0, 30) }),
        kinds: words(pick(raw, ["kinds", "manifest.kinds", "kind"])).slice(0, 6),
        kind: str(pick(raw, ["kind"])).slice(0, 40),
        stars: num(pick(raw, ["stars", "stargazers", "stargazersCount", "metrics.stars", "github.stars"])),
        hearts: num(pick(raw, ["hearts", "metrics.hearts", "engagement.hearts", "likes"])),
        views: views,
        copies: copies,
        verified: isVerified(raw),
        // shell suites are listed but are not single plugins: neither verified nor unverified
        suite: str(pick(raw, ["repositoryLayout"])) === "suite",
        repo: safeRepoUrl(repoRaw),
        preview: safeImageUrl(thumb || full),
        previewFull: safeImageUrl(full || thumb),
        icon: safeImageUrl(pick(raw, ["iconImage", "icon"])),
        installable: pick(raw, ["installAvailable"]) !== false,
        accent: validHex(pick(raw, ["accent"]), ""),
        addedAt: added,
        updatedAt: updated,
        // the catalog lists Omarchy's own plugins too; they ship with Omarchy
        builtin: pick(raw, ["builtIn"]) === true || str(pick(raw, ["sourceType"])) === "builtin",
        local: false
    }
    if (p.builtin) { p.author = p.author || "Omarchy"; p.installable = false; p.verified = true }
    p.fresh = Math.max(added, updated)
    p.kindKey = kindKey(p.kind)
    p.rate = installRate(p, copies, views)
    p.lname = p.name.toLowerCase()
    p.hay = (p.name + " " + p.id + " " + p.description + " " + p.author + " " + p.category + " " +
             p.tags.join(" ")).toLowerCase()
    return p
}

function normalizeCatalog(raw) {
    var list = []
    var arr = null
    if (Array.isArray(raw)) arr = raw
    else if (raw && typeof raw === "object") {
        var keys = ["plugins", "items", "entries", "catalog", "data", "results", "registry"]
        for (var k = 0; k < keys.length && !arr; k++) {
            var v = raw[keys[k]]
            if (Array.isArray(v)) arr = v
            else if (v && typeof v === "object") raw = v      // plugins keyed by id
        }
    }
    var seen = {}
    function add(entry, fallbackId) {
        var p = normalizePlugin(entry, fallbackId)
        if (p && !seen[p.id]) { seen[p.id] = true; list.push(p) }
    }
    if (arr) {
        for (var i = 0; i < arr.length && list.length < CATALOG_ITEMS_MAX; i++) add(arr[i], "")
    } else if (raw && typeof raw === "object") {
        for (var key in raw) {
            if (list.length >= CATALOG_ITEMS_MAX) break
            add(raw[key], key)
        }
    }
    return list
}

// ---- engagement stats (separate API: hearts / views / copies) ------------------
// The shape is not documented, so accept the plausible ones: a map or array,
// optionally wrapped in plugins / stats / data / items.
function normalizeStats(raw) {
    var out = {}
    var n = 0
    function take(id, v) {
        if (n >= CATALOG_ITEMS_MAX || !SAFE_ID.test(str(id)) || !v || typeof v !== "object") return
        n++
        out[id] = {
            views: num(pick(v, ["views", "detailViews", "detail_views", "view"])),
            hearts: num(pick(v, ["hearts", "likes", "heart"])),
            copies: num(pick(v, ["copies", "commandCopies", "copy", "installs"]))
        }
    }
    var src = raw
    var wrap = ["plugins", "stats", "data", "items", "entries"]
    for (var w = 0; w < wrap.length && src && !Array.isArray(src); w++)
        if (src[wrap[w]] && typeof src[wrap[w]] === "object") { src = src[wrap[w]]; break }
    if (Array.isArray(src)) {
        for (var i = 0; i < src.length; i++)
            if (src[i]) take(str(pick(src[i], ["id", "pluginId", "plugin_id", "plugin"])), src[i])
    } else if (src && typeof src === "object") {
        for (var k in src) take(k, src[k])
    }
    return out
}

// Writes the stats onto catalog entries in place. Returns how many matched.
function applyStats(catalog, stats) {
    var n = 0
    for (var i = 0; i < catalog.length; i++) {
        var st = stats[catalog[i].id]
        if (!st) continue
        var p = catalog[i]
        p.views = st.views; p.hearts = st.hearts; p.copies = st.copies
        p.rate = installRate(p, st.copies, st.views)
        n++
    }
    return n
}

// ---- installed ------------------------------------------------------------
function normalizeInstalled(raw) {
    var arr = Array.isArray(raw) ? raw : (raw && Array.isArray(raw.plugins) ? raw.plugins : [])
    var list = []
    var map = {}
    for (var i = 0; i < arr.length; i++) {
        var r = arr[i]
        if (!r || typeof r !== "object") continue
        var id = str(pick(r, ["id", "pluginId"])).trim()
        if (!SAFE_ID.test(id) || map[id]) continue
        var en = pick(r, ["enabled", "isEnabled", "active"])
        var rec = {
            id: id,
            name: str(pick(r, ["name", "displayName", "manifest.name"]) || id).slice(0, 80),
            description: str(pick(r, ["description", "manifest.description"])).slice(0, 600),
            version: str(pick(r, ["version", "manifest.version"])).slice(0, 32),
            kinds: words(pick(r, ["kinds", "manifest.kinds"])).slice(0, 6),
            enabled: en === true || en === "true",
            builtin: id.indexOf("omarchy.") === 0
        }
        list.push(rec)
        map[id] = rec
    }
    return { list: list, map: map }
}

// The directory a manifest lives in, taken from its path. It is not always the
// plugin id - a manually cloned plugin keeps the clone's folder name - and it is
// what `omarchy plugin update` resolves on disk, so it is kept alongside the id.
function dirNameOf(path) {
    var m = /^(.*)\/manifest\.json$/.exec(str(path))
    if (!m) return ""
    var dir = m[1].split("/").pop()
    return /^[A-Za-z0-9._-]{1,128}$/.test(dir) ? dir : ""
}

// `omarchy plugin list` reports no version, so each installed plugin is read
// from its own manifest.json: the scanner prints one `[id, version, path]` JSON
// array per plugin. That output is untrusted too - the id is checked, the
// version trimmed and capped, the directory taken from the path and checked as a
// plain name.
function normalizeScan(text) {
    var out = {}
    var lines = str(text).split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line === "") continue
        var row = null
        try { row = JSON.parse(line) } catch (e) { continue }
        if (!Array.isArray(row) || row.length < 2) continue
        var id = str(row[0]).trim()
        if (!SAFE_ID.test(id)) continue
        out[id] = { version: str(row[1]).trim().slice(0, 32), dir: dirNameOf(row[2]),
                    from: str(row[3]).trim().slice(0, 256) }
    }
    return out
}

// `stat -c '%W %Y %n'` over the plugin directories: birth time (0 on filesystems
// that do not record one), mtime, then the path. "Newly installed" uses birth
// and falls back to mtime, so a plugin installed on an older filesystem still
// sorts sensibly.
function normalizeBirths(text) {
    var out = {}
    var lines = str(text).split("\n")
    for (var i = 0; i < lines.length; i++) {
        var m = /^(\d+)\s+(\d+)\s+(.+)$/.exec(lines[i])
        if (!m) continue
        var dir = m[3].replace(/\/+$/, "").split("/").pop()
        if (!/^[A-Za-z0-9._-]{1,128}$/.test(dir)) continue
        var w = Number(m[1]), y = Number(m[2])
        out[dir] = w > 0 ? w * 1000 : (y > 0 ? y * 1000 : 0)
    }
    return out
}

// A set of directory names, one path per line (from `find ... -printf '%h\n'`).
// Used for the list of directories that hold a .git. Plain names only.
function normalizeDirSet(text) {
    var out = {}
    var lines = str(text).split("\n")
    for (var i = 0; i < lines.length; i++) {
        var dir = lines[i].trim().replace(/\/+$/, "").split("/").pop()
        if (/^[A-Za-z0-9._-]{1,128}$/.test(dir)) out[dir] = true
    }
    return out
}

// Folds the on-disk scan into the installed records and rebuilds the id map:
// `version` feeds findUpdates, `dir` is what an update runs against, and
// `installedAt` (from the birth scan) feeds the "Newly installed" sort. Returns
// a new { list, map } pair: the records handed in are never mutated.
function applyScan(inst, scan, births) {
    var list = []
    var map = {}
    if (!inst || !Array.isArray(inst.list)) return { list: list, map: map }
    for (var i = 0; i < inst.list.length; i++) {
        var src = inst.list[i]
        var rec = {}
        for (var k in src) rec[k] = src[k]
        var s = scan ? scan[rec.id] : null
        if (s && s.version) rec.version = s.version
        rec.dir = s ? s.dir : ""
        rec.clonedFrom = s ? s.from : ""
        rec.installedAt = (s && s.dir && births && births[s.dir] !== undefined) ? births[s.dir] : 0
        list.push(rec)
        map[rec.id] = rec
    }
    return { list: list, map: map }
}

function pseudoRecord(rec, category, author) {
    var p = {
        id: rec.id, name: rec.name, description: rec.description, author: author,
        version: rec.version, category: category, tags: rec.kinds.slice(0, 4), kinds: rec.kinds,
        stars: 0, hearts: 0, views: 0, copies: 0, verified: rec.builtin,
        repo: "", preview: "", previewFull: "", icon: "", installable: false, accent: "", addedAt: 0, updatedAt: 0, fresh: 0, rate: -1,
        builtin: rec.builtin, local: !rec.builtin, suite: false,
        kind: str(rec.kinds[0] || "").replace(/-/g, " ")
    }
    p.kind = p.kind.charAt(0).toUpperCase() + p.kind.slice(1)
    p.kindKey = kindKey(p.kind)
    p.lname = p.name.toLowerCase()
    p.hay = (p.name + " " + p.id + " " + p.description + " " + author + " " + category).toLowerCase()
    return p
}

// ---- versions -------------------------------------------------------------
function compareVersions(a, b) {
    var pa = str(a).replace(/^v/i, "").split(/[^0-9]+/).filter(Boolean).map(Number)
    var pb = str(b).replace(/^v/i, "").split(/[^0-9]+/).filter(Boolean).map(Number)
    if (!pa.length || !pb.length) return 0
    var n = Math.max(pa.length, pb.length)
    for (var i = 0; i < n; i++) {
        var x = pa[i] || 0, y = pb[i] || 0
        if (x !== y) return x < y ? -1 : 1
    }
    return 0
}

function findUpdates(catalog, installedMap) {
    var out = []
    for (var i = 0; i < catalog.length; i++) {
        var p = catalog[i]
        var inst = installedMap[p.id]
        if (inst && !inst.builtin && p.version && inst.version && compareVersions(inst.version, p.version) < 0)
            out.push(p.id)
    }
    return out
}

// ---- search / filter / sort ----------------------------------------------
function tokens(q) {
    return str(q).toLowerCase().split(/\s+/).filter(Boolean)
}

function dateOf(p, scope) {
    return scope === "added" ? p.addedAt : (scope === "updated" ? p.updatedAt : p.fresh)
}

// The pool (and the id set built alongside it) is rebuilt only when the
// catalog, the installed list or the source changes. query() runs on every
// keystroke and filter change; rebuilding a 5,000-odd-entry concatenation each
// time was the one cost that grew with the catalog.
var _poolCache = { catalog: null, installed: null, source: null, out: null }

function pool(catalog, installedList, installedMap, source) {
    if (_poolCache.catalog === catalog && _poolCache.installed === installedList && _poolCache.source === source)
        return _poolCache.out
    var out = []
    var inCatalog = {}
    for (var i = 0; i < catalog.length; i++) inCatalog[catalog[i].id] = true
    if (source === "community" || source === "all") {
        for (var c = 0; c < catalog.length; c++) if (!catalog[c].builtin) out.push(catalog[c])
        for (var j = 0; j < installedList.length; j++) {
            var r = installedList[j]
            if (!r.builtin && !inCatalog[r.id]) out.push(pseudoRecord(r, "Local", "You"))
        }
    }
    if (source === "builtin" || source === "all") {
        // the catalog's own entries (description, type, category), then any the catalog lacks
        for (var b = 0; b < catalog.length; b++) if (catalog[b].builtin) out.push(catalog[b])
        for (var k = 0; k < installedList.length; k++)
            if (installedList[k].builtin && !inCatalog[installedList[k].id])
                out.push(pseudoRecord(installedList[k], "Built-in", "Omarchy"))
    }
    _poolCache = { catalog: catalog, installed: installedList, source: source, out: out }
    return out
}

// ---- collections (the website's quick filters) ----------------------------------
// Kids, VPN and Bar are worked out from the category, tags, id, name and description
// the way the website does it; AI, Games and Security are plain tags.
var COLLECTIONS = [
    { key: "kids", label: "Kids" }, { key: "vpn", label: "VPN" }, { key: "bar", label: "Bar" },
    { key: "ai", label: "AI" }, { key: "games", label: "Games" }, { key: "security", label: "Security" }
]
var VPN_IDS = ["antesmd.amneziawg", "io.github.feilian", "jwhall.omanodes"]
var VPN_NAMES = ["airvpn", "eduvpn", "expressvpn", "fortivpn", "ivpn", "mullvad", "multivpn", "netbird", "nordvpn",
                 "nymvpn", "openvpn", "protonvpn", "surfshark", "tailscale", "twingate", "vpn", "windscribe",
                 "wireguard", "zerotier"]
var VPN_ACTIONS = ["connect", "connection", "connections", "control", "controls", "disconnect", "launcher", "manager",
                   "status", "switch", "switching", "toggle", "toggles", "tunnel", "tunnels"]
var BAR_NAMES = ["bar", "menubar", "statusbar", "topbar", "waybar"]

function terms(v) { return str(v).toLowerCase().split(/[^a-z0-9]+/).filter(Boolean) }
function identityTerms(p) { return terms(p.id.split(".").pop()).concat(terms(p.name)) }

function isKids(p) {
    return p.category === "Kids" || p.tags.indexOf("kids") >= 0 || p.tags.indexOf("education") >= 0
}

function isVpn(p) {
    if (p.category === "VPN" || VPN_IDS.indexOf(p.id.toLowerCase()) >= 0) return true
    const names = identityTerms(p)
    if (names.some(t => VPN_NAMES.indexOf(t) >= 0) || p.tags.indexOf("vpn") >= 0) return true
    if (p.tags.indexOf("security") < 0) return false
    if (names.indexOf("warp") >= 0) return true
    const desc = terms(p.description)
    return desc.some(t => t === "vpn" || t === "wireguard") && desc.some(t => VPN_ACTIONS.indexOf(t) >= 0)
}

function isBar(p) {
    if (p.category === "Bar" || p.category === "Bars" || p.kindKey === "bar") return true
    if (p.category === "Hardware") return false
    if (!identityTerms(p).some(t => BAR_NAMES.indexOf(t) >= 0)) return false
    return p.kindKey === "service" || p.category === "Appearance"
}

function inCollection(p, key) {
    switch (key) {
    case "kids": return isKids(p)
    case "vpn": return isVpn(p)
    case "bar": return isBar(p)
    case "ai": case "games": case "security": return p.tags.indexOf(key) >= 0
    default: return true
    }
}

// ---- search ---------------------------------------------------------------------
// Plain words match names, ids, descriptions, authors, categories and tags. Like on
// the website, `tag:media`, `kind:panel` and `@author` narrow it down exactly.
function parseQuery(q) {
    const out = { words: [], tags: [], kinds: [], authors: [] }
    for (const t of tokens(q)) {
        if (t.indexOf("tag:") === 0 && t.length > 4) out.tags.push(t.slice(4))
        else if (t.indexOf("kind:") === 0 && t.length > 5) out.kinds.push(kindKey(t.slice(5)))
        else if (t.charAt(0) === "@" && t.length > 1) out.authors.push(t.slice(1))
        else out.words.push(t)
    }
    return out
}

function searchOk(p, q) {
    for (const w of q.words) if (p.hay.indexOf(w) < 0) return false
    for (const t of q.tags) if (p.tags.indexOf(t) < 0) return false
    for (const k of q.kinds) if (p.kindKey.indexOf(k) !== 0) return false
    const author = p.author.toLowerCase()
    for (const a of q.authors) if (author.indexOf(a) < 0) return false
    return true
}

// ---- verification ---------------------------------------------------------------
// "any", "verified" or "unverified". Built-ins, local plugins and shell suites carry
// no verification, so they only show under "any".
function verificationOk(p, want) {
    if (want !== "verified" && want !== "unverified") return true
    if (p.builtin || p.local || p.suite) return false
    return want === "verified" ? p.verified : !p.verified
}

// ---- Top ranked -----------------------------------------------------------------
// The website's overall rank: each plugin's places by hearts, copies, views and
// stars, added up; the smallest sum ranks first. Plugins with none of them aren't
// ranked. Worked out once per catalog (and again when the stats arrive).
var RANK_METRICS = ["hearts", "copies", "views", "stars"]
var _rankCache = { catalog: null, stamp: "", ranks: {} }

function ranksOf(catalog) {
    let stamp = catalog.length + ":"
    for (let i = 0; i < catalog.length; i += 97) stamp += catalog[i].views + "," + catalog[i].hearts + ";"
    if (_rankCache.catalog === catalog && _rankCache.stamp === stamp) return _rankCache.ranks
    const ranked = catalog.filter(p => !p.builtin && RANK_METRICS.some(m => p[m] > 0))
    const sum = {}
    for (const p of ranked) sum[p.id] = 0
    for (const m of RANK_METRICS) {
        const ordered = ranked.slice().sort((a, b) => (b[m] - a[m]) || (a.id < b.id ? -1 : 1))
        let place = 0, prev = null
        ordered.forEach((p, i) => {
            if (p[m] !== prev) place = i + 1
            prev = p[m]
            sum[p.id] += place
        })
    }
    const overall = ranked.slice().sort((a, b) => (sum[a.id] - sum[b.id]) || (a.id < b.id ? -1 : 1))
    const ranks = {}
    let place = 0, prev = null
    overall.forEach((p, i) => {
        if (sum[p.id] !== prev) place = i + 1
        prev = sum[p.id]
        ranks[p.id] = place
    })
    _rankCache = { catalog: catalog, stamp: stamp, ranks: ranks }
    return ranks
}

function statusOk(p, status, ctx) {
    var inst = ctx.installedMap[p.id]
    switch (status) {
    case "installed": return !!inst
    case "notinstalled": return !inst
    case "enabled": return !!inst && inst.enabled
    case "disabled": return !!inst && !inst.enabled
    case "updates": return !!ctx.updateSet[p.id]
    case "saved": return !!ctx.bookmarks[p.id]
    case "issues": return !!ctx.healthSet[p.id]
    case "new": return p.addedAt > ctx.since
    default: return true
    }
}

function sorter(key, ctx) {
    var by = function(f, dir) { return function(a, b) { return (f(b) - f(a)) * dir } }
    var installedAt = function(p) {
        var inst = ctx && ctx.installedMap ? ctx.installedMap[p.id] : null
        return inst ? (inst.installedAt || 0) : 0
    }
    switch (key) {
    case "installed": return by(installedAt, 1)
    case "listed": return function(a, b) { return (a._i || 0) - (b._i || 0) }
    case "updated": return by(function(p) { return p.updatedAt }, 1)
    case "fresh": return by(function(p) { return p.fresh }, 1)
    case "hearts": return by(function(p) { return p.hearts }, 1)
    case "stars": return by(function(p) { return p.stars }, 1)
    case "views": return by(function(p) { return p.views }, 1)
    case "rated": return function(a, b) { return (b.rate - a.rate) || (b.views - a.views) }
    case "copies": return by(function(p) { return p.copies }, 1)
    case "rank": return function(a, b) {
        var ra = ctx && ctx.ranks ? (ctx.ranks[a.id] || Infinity) : Infinity
        var rb = ctx && ctx.ranks ? (ctx.ranks[b.id] || Infinity) : Infinity
        return ra === rb ? 0 : (ra < rb ? -1 : 1)
    }
    case "kind": return function(a, b) {
        return a.kindKey < b.kindKey ? -1 : (a.kindKey > b.kindKey ? 1 : (a.lname < b.lname ? -1 : (a.lname > b.lname ? 1 : 0)))
    }
    case "az": return function(a, b) { return a.lname < b.lname ? -1 : (a.lname > b.lname ? 1 : 0) }
    default: return by(function(p) { return p.addedAt }, 1)
    }
}

function countMap(list, field) {
    var counts = {}
    for (var i = 0; i < list.length; i++) {
        var v = field === "category" ? [list[i].category] : list[i].tags
        for (var j = 0; j < v.length; j++) counts[v[j]] = (counts[v[j]] || 0) + 1
    }
    var out = []
    for (var k in counts) out.push({ name: k, count: counts[k] })
    out.sort(function(a, b) { return (b.count - a.count) || (a.name < b.name ? -1 : 1) })
    return out
}

// The sidebar shows only the busiest categories and tags, plus whatever is picked
// now, so a catalog with thousands of different ones still makes a short list.
var MAX_CATEGORIES = 24
var MAX_TAGS = 24
function topFacets(list, max, keep) {
    var out = list.slice(0, max)
    var want = (keep || []).filter(function(k) { return k !== "" })
    for (var i = 0; i < want.length; i++) {
        var have = false
        for (var j = 0; j < out.length; j++) if (out[j].name === want[i]) { have = true; break }
        if (have) continue
        for (var k = max; k < list.length; k++) if (list[k].name === want[i]) { out.push(list[k]); break }
    }
    return out
}

// st: { query, source, category, tags[], collection, verification ("any" |
//       "verified" | "unverified"; verifiedOnly is the older way to ask for
//       "verified"), hideInstalled, status, scope, days, sort, now, since,
//       bookmarks, updateSet }
function query(catalog, installedList, installedMap, st) {
    var ctx = { installedMap: installedMap, updateSet: st.updateSet || {}, bookmarks: st.bookmarks || {},
                healthSet: st.healthSet || {}, since: st.since || 0,
                ranks: st.sort === "rank" ? ranksOf(catalog) : null }
    var all = pool(catalog, installedList, installedMap, st.source)
    var q = parseQuery(st.query)
    var verification = st.verification || (st.verifiedOnly ? "verified" : "any")
    var cutoff = st.days > 0 ? (st.now || Date.now()) - st.days * DAY : 0
    var base = []
    for (var i = 0; i < all.length; i++) {
        var p = all[i]
        if (!verificationOk(p, verification)) continue
        if (st.hideInstalled && installedMap[p.id]) continue
        if (!statusOk(p, st.status, ctx)) continue
        if (cutoff > 0 && !(dateOf(p, st.scope) >= cutoff)) continue
        if (searchOk(p, q)) { p._i = i; base.push(p) }
    }
    var collections = []
    for (var c = 0; c < COLLECTIONS.length; c++) {
        var n = 0
        for (var b = 0; b < base.length; b++) if (inCollection(base[b], COLLECTIONS[c].key)) n++
        if (n > 0) collections.push({ key: COLLECTIONS[c].key, name: COLLECTIONS[c].label, count: n })
    }
    var facets = { categories: topFacets(countMap(base, "category"), MAX_CATEGORIES, [st.category || ""]),
                   tags: topFacets(countMap(base, "tag"), MAX_TAGS, (st.tags || []).slice(0, 8)),
                   collections: collections }
    var wantTags = st.tags || []
    var items = base.filter(function(p) {
        if (st.collection && !inCollection(p, st.collection)) return false
        if (st.category && p.category !== st.category) return false
        for (var i = 0; i < wantTags.length; i++) if (p.tags.indexOf(wantTags[i]) < 0) return false
        return true
    })
    var cmp = sorter(st.sort, ctx)
    items.sort(function(a, b) { return cmp(a, b) || (a._i - b._i) })
    return { items: items, facets: facets, poolSize: all.length }
}

// ---- commands (argument arrays only, never a shell string) --------------------
function actionArgs(kind, id, repo, cfg) {
    var base = ["omarchy", "plugin"]
    if (kind === "install") {
        var url = safeRepoUrl(repo)
        if (!url) return null
        var argv = base.concat(["add", url])
        if (!cfg || cfg.enableAfterInstall !== false) argv.push("--enable")
        argv.push("--yes")
        return { argv: argv, fallback: null }
    }
    if (!SAFE_ID.test(str(id))) return null
    if (kind === "update")
        return { argv: base.concat(["update", id, "--yes"]), fallback: null }
    if (kind === "enable" || kind === "disable") return { argv: base.concat([kind, id]), fallback: null }
    if (kind === "remove")
        return { argv: base.concat(["remove", id, "--yes"]), fallback: base.concat(["remove", id]) }
    return null
}

function installCommand(p) {
    return p.repo && !p.builtin ? "omarchy plugin add " + p.repo + " --enable" : ""
}

// `omarchy plugin update` and `remove` resolve "$PLUGINS_DIR/<name>", so the name
// they need is the on-disk directory, which is not always the manifest id (a
// manually cloned plugin keeps the clone's folder name). When the directory is
// known it is preferred; otherwise the id is passed as before.
function pluginTarget(kind, id, installedMap) {
    if ((kind === "update" || kind === "remove") && installedMap) {
        var inst = installedMap[id]
        if (inst && SAFE_ID.test(str(inst.dir))) return inst.dir
    }
    return id
}

// ---- plugin sets (profiles) ----------------------------------------------------
// A set is a list of the installed third-party plugins, each with the repo that
// would reinstall it: the catalog's address when known, otherwise the manifest's
// own clonedFrom. Built-in plugins are left out (they ship with Omarchy).
function buildSet(installedList, catalog) {
    var repoById = {}
    for (var i = 0; i < catalog.length; i++) repoById[catalog[i].id] = catalog[i].repo
    var out = []
    for (var j = 0; j < installedList.length; j++) {
        var rec = installedList[j]
        if (rec.builtin) continue
        var repo = safeRepoUrl(repoById[rec.id] || rec.clonedFrom || "")
        out.push({ id: rec.id, name: rec.name, repo: repo || "" })
    }
    return out
}

// What restoring a set would do, as actions ready for Service.perform. Additive:
// installed-but-off plugins are enabled, missing ones with a known repo are
// installed, and nothing already present is touched.
function planRestore(set, installedMap) {
    var out = []
    if (!set || !set.plugins) return out
    for (var i = 0; i < set.plugins.length; i++) {
        var pl = set.plugins[i]
        var inst = installedMap ? installedMap[pl.id] : null
        if (inst) {
            if (!inst.enabled) out.push({ kind: "enable", id: pl.id, name: pl.name, repo: "" })
        } else {
            var repo = safeRepoUrl(pl.repo)
            if (repo) out.push({ kind: "install", id: pl.id, name: pl.name, repo: repo })
        }
    }
    return out
}

// What is wrong with the installed set, one finding per problem, for the
// Installed tab's Health view. Read-only: records come from applyScan (so they
// carry `dir`), the directory list from the birth scan, and the set of git
// checkouts from the .git scan.
function healthOf(installedList, births, gitDirs, catalogMap) {
    var out = []
    var known = {}
    function push(id, dir, name, kind, text) {
        out.push({ id: id, dir: dir || "", name: name || id, kind: kind, text: text })
    }
    for (var i = 0; i < installedList.length; i++) {
        var rec = installedList[i]
        var dir = rec.dir || ""
        if (dir) known[dir] = true
        if (rec.builtin) continue
        if (dir && dir !== rec.id)
            push(rec.id, dir, rec.name, "renamed", "Installed in '" + dir + "', not '" + rec.id + "'")
        if (dir && gitDirs && !gitDirs[dir])
            push(rec.id, dir, rec.name, "nogit", "Not a git checkout: omarchy cannot update it")
        if (!catalogMap || !catalogMap[rec.id])
            push(rec.id, dir, rec.name, "orphan", "Not in the catalog (local or unpublished)")
    }
    if (births) {
        for (var d in births) {
            if (known[d]) continue
            push(d, d, d, "nomanifest", "No readable manifest.json")
        }
    }
    return out
}

// ---- git history (changelog in the detail pane) --------------------------------
// The plugin folders hold other people's repositories, so git runs with the bits
// that could start a program turned off: no hooks, no fsmonitor, no signature
// checks, no saved credentials, and https as the only way out.
function gitBase(dirPath) {
    return ["git", "-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=",
            "-c", "log.showSignature=false", "-c", "credential.helper=",
            "-c", "protocol.allow=never", "-c", "protocol.https.allow=always",
            "-C", str(dirPath)]
}

// One line per commit: abbreviated hash, author date, subject, tab-separated.
function gitLogArgs(dirPath, incoming) {
    var argv = gitBase(dirPath).concat(["log", "-n", "20", "--no-color",
                "--pretty=format:%h\t%ad\t%s", "--date=short"])
    if (incoming) argv.push("HEAD..FETCH_HEAD")
    return argv
}

// What an update would bring in is fetched from the catalog's address for the
// plugin, not from whatever remote the folder has configured. null without one.
function gitFetchArgs(dirPath, repo) {
    var url = safeRepoUrl(repo)
    if (!url) return null
    return gitBase(dirPath).concat(["fetch", "--quiet", "--no-tags", "--", url, "HEAD"])
}

function parseGitLog(text) {
    var out = []
    var lines = str(text).split("\n")
    for (var i = 0; i < lines.length && out.length < 20; i++) {
        if (lines[i].trim() === "") continue
        var parts = lines[i].split("\t")
        if (parts.length < 3) continue
        out.push({ hash: str(parts[0]).slice(0, 40), date: str(parts[1]).slice(0, 10),
                   subject: str(parts.slice(2).join("\t")).slice(0, 200) })
    }
    return out
}

// ---- display helpers -----------------------------------------------------------
function relTime(t, now) {
    if (!t) return "unknown"
    var d = Math.max(0, (now || Date.now()) - t)
    if (d < DAY) return "today"
    var days = Math.floor(d / DAY)
    if (days < 14) return days + "d ago"
    if (days < 60) return Math.floor(days / 7) + "w ago"
    if (days < 365) return Math.floor(days / 30) + "mo ago"
    return Math.floor(days / 365) + "y ago"
}

function fmtCount(n) {
    n = num(n)
    if (n >= 10000) return Math.round(n / 1000) + "k"
    if (n >= 1000) return (Math.round(n / 100) / 10) + "k"
    return String(Math.round(n))
}

function hueOf(name) {
    var h = 7
    var s = str(name)
    for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 360
    return h / 360
}

function validHex(v, fallback) {
    var s = str(v).trim()
    if (/^#[0-9a-fA-F]{6}$/.test(s)) return s
    if (/^#[0-9a-fA-F]{3}$/.test(s)) return "#" + s[1] + s[1] + s[2] + s[2] + s[3] + s[3]
    return fallback
}
