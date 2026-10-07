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

function safeWebUrl(u) {
    var p = parseUrl(u)
    return p ? str(u).trim() : ""
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

// ---- catalog --------------------------------------------------------------
function isVerified(raw) {
    var flag = pick(raw, ["verified", "isVerified"])
    if (flag === true || flag === "true") return true
    if (flag === false || flag === "false") return false
    var st = str(pick(raw, ["verification.status", "verification.state", "verificationStatus",
                            "verification", "trust.status"])).toLowerCase()
    return st.indexOf("verified") >= 0 && st.indexOf("unverified") < 0 && st.indexOf("update") < 0
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
        stars: num(pick(raw, ["stars", "stargazers", "stargazersCount", "metrics.stars", "github.stars"])),
        hearts: num(pick(raw, ["hearts", "metrics.hearts", "engagement.hearts", "likes"])),
        views: views,
        copies: copies,
        verified: isVerified(raw),
        repo: safeRepoUrl(repoRaw),
        preview: safeImageUrl(thumb || full),
        previewFull: safeImageUrl(full || thumb),
        icon: safeImageUrl(pick(raw, ["iconImage", "icon"])),
        installable: pick(raw, ["installAvailable"]) !== false,
        accent: validHex(pick(raw, ["accent"]), ""),
        addedAt: added,
        updatedAt: updated,
        builtin: false,
        local: false
    }
    p.fresh = Math.max(added, updated)
    p.rate = wilson(copies, views)
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
        for (var i = 0; i < arr.length; i++) add(arr[i], "")
    } else if (raw && typeof raw === "object") {
        for (var key in raw) add(raw[key], key)
    }
    return list
}

// ---- engagement stats (separate API: hearts / views / copies) ------------------
// The shape is not documented, so accept the plausible ones: a map or array,
// optionally wrapped in plugins / stats / data / items.
function normalizeStats(raw) {
    var out = {}
    function take(id, v) {
        if (!SAFE_ID.test(str(id)) || !v || typeof v !== "object") return
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
        p.rate = wilson(st.copies, st.views)
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

function pseudoRecord(rec, category, author) {
    var p = {
        id: rec.id, name: rec.name, description: rec.description, author: author,
        version: rec.version, category: category, tags: rec.kinds.slice(0, 4), kinds: rec.kinds,
        stars: 0, hearts: 0, views: 0, copies: 0, verified: rec.builtin,
        repo: "", preview: "", previewFull: "", icon: "", installable: false, accent: "", addedAt: 0, updatedAt: 0, fresh: 0, rate: 0,
        builtin: rec.builtin, local: !rec.builtin
    }
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

function pool(catalog, installedList, installedMap, source) {
    var out = []
    if (source === "community" || source === "all") {
        out = out.concat(catalog)
        var inCatalog = {}
        for (var i = 0; i < catalog.length; i++) inCatalog[catalog[i].id] = true
        for (var j = 0; j < installedList.length; j++) {
            var r = installedList[j]
            if (!r.builtin && !inCatalog[r.id]) out.push(pseudoRecord(r, "Local", "You"))
        }
    }
    if (source === "builtin" || source === "all") {
        for (var k = 0; k < installedList.length; k++)
            if (installedList[k].builtin) out.push(pseudoRecord(installedList[k], "Built-in", "Omarchy"))
    }
    return out
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
    case "new": return p.addedAt > ctx.since
    default: return true
    }
}

function sorter(key) {
    var by = function(f, dir) { return function(a, b) { return (f(b) - f(a)) * dir } }
    switch (key) {
    case "listed": return function(a, b) { return (a._i || 0) - (b._i || 0) }
    case "updated": return by(function(p) { return p.updatedAt }, 1)
    case "fresh": return by(function(p) { return p.fresh }, 1)
    case "hearts": return by(function(p) { return p.hearts }, 1)
    case "stars": return by(function(p) { return p.stars }, 1)
    case "views": return by(function(p) { return p.views }, 1)
    case "rated": return function(a, b) { return (b.rate - a.rate) || (b.views - a.views) }
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

// st: { query, source, category, tags[], verifiedOnly, hideInstalled, status,
//       scope, days, sort, now, since, bookmarks, updateSet }
function query(catalog, installedList, installedMap, st) {
    var ctx = { installedMap: installedMap, updateSet: st.updateSet || {}, bookmarks: st.bookmarks || {},
                since: st.since || 0 }
    var all = pool(catalog, installedList, installedMap, st.source)
    var toks = tokens(st.query)
    var cutoff = st.days > 0 ? (st.now || Date.now()) - st.days * DAY : 0
    var base = []
    for (var i = 0; i < all.length; i++) {
        var p = all[i]
        if (st.verifiedOnly && !p.verified) continue
        if (st.hideInstalled && installedMap[p.id]) continue
        if (!statusOk(p, st.status, ctx)) continue
        if (cutoff > 0 && !(dateOf(p, st.scope) >= cutoff)) continue
        var ok = true
        for (var t = 0; t < toks.length; t++) if (p.hay.indexOf(toks[t]) < 0) { ok = false; break }
        if (ok) { p._i = i; base.push(p) }
    }
    var facets = { categories: countMap(base, "category"), tags: countMap(base, "tag").slice(0, 40) }
    var wantTags = st.tags || []
    var items = base.filter(function(p) {
        if (st.category && p.category !== st.category) return false
        for (var i = 0; i < wantTags.length; i++) if (p.tags.indexOf(wantTags[i]) < 0) return false
        return true
    })
    var cmp = sorter(st.sort)
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
    if (kind === "update") return { argv: base.concat(["update", id]), fallback: null }
    if (kind === "enable" || kind === "disable") return { argv: base.concat([kind, id]), fallback: null }
    if (kind === "remove")
        return { argv: base.concat(["remove", id, "--yes"]), fallback: base.concat(["remove", id]) }
    return null
}

function installCommand(p) {
    return p.repo ? "omarchy plugin add " + p.repo + " --enable" : ""
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
