#!/usr/bin/env node
// Run with: node tests/test_model.js
// Model.js starts with the QML-only `.pragma library` line, so strip it before evaluating.
const fs = require("fs"), path = require("path"), assert = require("assert");
let src = fs.readFileSync(path.join(__dirname, "..", "qml", "js", "Model.js"), "utf8").replace(/^\.pragma.*$/m, "");
const M = new Function(src + "; return {normalizeCatalog, normalizeStats, applyStats, normalizeInstalled, normalizeScan, normalizeBirths, normalizeDirSet, applyScan, healthOf, pluginTarget, buildSet, planRestore, gitLogArgs, gitFetchArgs, parseGitLog, imageName, thumbName, thumbArgs, imageBatchArgs, imageReport, imageInventory, query, MAX_CATEGORIES, MAX_TAGS, findUpdates, compareVersions, safeRepoUrl, safeImageUrl, safeWebUrl, parseQuery, inCollection, ranksOf, kindKey, safeCatalogUrl, actionArgs, relTime, fmtCount, validHex};")();

const DAY = 864e5, now = Date.parse("2026-10-07T12:00:00Z");
const iso = d => new Date(now - d * DAY).toISOString();
const raw = { plugins: [
  { id: "a.old-popular", name: "Old Popular", description: "Big", category: "Media", tags: ["media"], stars: 50, hearts: 9, views: 100, copies: 40, verified: true,
    repository: "https://github.com/a/old-popular", addedAt: iso(300), updatedAt: iso(2), version: "1.2.0" },
  { id: "b.brand-new", name: "Brand New", category: "Widgets", tags: ["clock"], createdAt: iso(1), pushedAt: iso(1), version: "0.1.0", repo: "b/brand-new" },
  { id: "c.upgraded", name: "Upgraded", category: "Widgets", added: iso(100), lastUpdated: iso(0.5), verification: { status: "verified" }, repository: { url: "git+https://github.com/c/upgraded.git" } },
  { id: "d.stale", name: "Stale", category: "Other", addedAt: iso(200), updatedAt: iso(150) },
  { id: "--evil", name: "bad id" },
  { id: "e.badrepo", name: "Bad Repo", repository: "https://evil.example/x/y --upload-pack=sh" },
]};

(function normalization() {
  const l = M.normalizeCatalog(raw);
  assert.strictEqual(l.length, 5, "unsafe id dropped");
  const by = Object.fromEntries(l.map(p => [p.id, p]));
  assert.strictEqual(by["b.brand-new"].repo, "https://github.com/b/brand-new.git");
  assert.strictEqual(by["c.upgraded"].repo, "https://github.com/c/upgraded.git");
  assert.strictEqual(by["c.upgraded"].verified, true);
  assert.strictEqual(by["e.badrepo"].repo, "");
  assert.strictEqual(M.normalizeCatalog([raw.plugins[0]]).length, 1, "bare array ok");
  const keyed = M.normalizeCatalog({ plugins: { "x.one": { name: "One" } } });
  assert.strictEqual(keyed[0].id, "x.one", "map keyed by id ok");
})();

(function urls() {
  assert.strictEqual(M.safeRepoUrl("https://github.com/o/r"), "https://github.com/o/r.git");
  for (const bad of ["--upload-pack=x", "http://github.com/o/r", "https://github.com/o/r/tree/main", "https://github.com.evil.com/o/r", "https://github.com/o/r; rm -rf ~", "file:///etc/passwd", ""])
    assert.strictEqual(M.safeRepoUrl(bad), "", bad);
  assert.strictEqual(M.safeImageUrl("assets/img/plugins/x.webp"), "https://plugins.omarchy.org/assets/img/plugins/x.webp");
  assert.strictEqual(M.safeImageUrl("https://tracker.example/p.png"), "");
  assert.strictEqual(M.safeCatalogUrl("javascript:alert(1)"), "");
  assert.strictEqual(M.safeCatalogUrl("https://plugins.omarchy.org/catalog.json"), "https://plugins.omarchy.org/catalog.json");
})();

const cat = M.normalizeCatalog(raw);
const inst = M.normalizeInstalled([
  { id: "a.old-popular", enabled: true, version: "1.0.0" },
  { id: "omarchy.clock", enabled: true, version: "1" },
  { id: "me.local-dev", enabled: false },
]);
const base = { query: "", source: "community", category: "", tags: [], verifiedOnly: false, hideInstalled: false,
  status: "any", scope: "either", days: 0, sort: "newest", now, since: 0, bookmarks: {}, updateSet: {} };
const ids = r => r.items.map(p => p.id);

(function sorting() {
  assert.strictEqual(ids(M.query(cat, inst.list, inst.map, { ...base, sort: "newest" }))[0], "b.brand-new", "newest = most recently uploaded");
  assert.strictEqual(ids(M.query(cat, inst.list, inst.map, { ...base, sort: "updated" }))[0], "c.upgraded", "updated = most recently upgraded");
  // old-popular was uploaded long ago but upgraded 2d ago: 'fresh' (both) ranks it above brand-new? no: brand-new is 1d old
  const fresh = ids(M.query(cat, inst.list, inst.map, { ...base, sort: "fresh" }));
  assert.strictEqual(fresh[0], "c.upgraded");
  assert.strictEqual(fresh[1], "b.brand-new");
  assert.strictEqual(fresh[2], "a.old-popular", "upgraded plugin surfaces in the combined sort");
  assert.strictEqual(ids(M.query(cat, inst.list, inst.map, { ...base, sort: "hearts" }))[0], "a.old-popular");
  assert.deepStrictEqual(ids(M.query(cat, inst.list, inst.map, { ...base, sort: "az" })).slice(0, 2), ["e.badrepo", "b.brand-new"], "A to Z sorts by display name");
})();

(function recency() {
  const q = (scope, days) => ids(M.query(cat, inst.list, inst.map, { ...base, scope, days, sort: "fresh" }));
  assert.deepStrictEqual(q("added", 7), ["b.brand-new"]);
  assert.deepStrictEqual(q("updated", 7).sort(), ["a.old-popular", "b.brand-new", "c.upgraded"]);
  assert.deepStrictEqual(q("either", 7).sort(), ["a.old-popular", "b.brand-new", "c.upgraded"]);
  assert.ok(!q("either", 30).includes("d.stale"));
})();

(function filters() {
  const run = o => M.query(cat, inst.list, inst.map, { ...base, ...o });
  assert.deepStrictEqual(ids(run({ query: "brand new" })), ["b.brand-new"]);
  assert.deepStrictEqual(ids(run({ category: "Widgets", sort: "az" })), ["b.brand-new", "c.upgraded"]);
  assert.deepStrictEqual(ids(run({ tags: ["clock"] })), ["b.brand-new"]);
  assert.ok(run({ verifiedOnly: true }).items.every(p => p.verified));
  assert.ok(!ids(run({ hideInstalled: true })).includes("a.old-popular"));
  assert.ok(ids(run({ status: "installed", source: "all" })).includes("me.local-dev"), "local plugin not in catalog is listed");
  assert.deepStrictEqual(ids(run({ source: "builtin" })), ["omarchy.clock"]);
  assert.deepStrictEqual(ids(run({ status: "new", since: now - 3 * DAY })), ["b.brand-new"]);
  assert.deepStrictEqual(ids(run({ status: "saved", bookmarks: { "d.stale": true } })), ["d.stale"]);
  const f = run({}).facets;
  assert.strictEqual(f.categories.find(c => c.name === "Widgets").count, 2);
  // facets ignore the category choice so the sidebar keeps showing siblings
  assert.strictEqual(run({ category: "Media" }).facets.categories.length, f.categories.length);
})();

(function updates() {
  assert.strictEqual(M.compareVersions("1.0.0", "1.2.0"), -1);
  assert.strictEqual(M.compareVersions("v2.0", "1.9.9"), 1);
  assert.strictEqual(M.compareVersions("1.0", "1.0.0"), 0);
  assert.strictEqual(M.compareVersions("", "1.0"), 0);
  assert.deepStrictEqual(M.findUpdates(cat, inst.map), ["a.old-popular"]);
})();

(function installedScan() {
  // `plugin list --json` carries no version at all, so the installed version is
  // read from manifest.json and merged in. Without that merge the Updates tab
  // can never find anything to update. The same scan also recovers the plugin's
  // directory (which is what an update runs against) and its install time.
  const text = [
    '["a.old-popular","1.1.0","/p/a.old-popular/manifest.json"]',
    '["omarchy.clock","1","/p/omarchy.clock/manifest.json"]',
    '["bad --id","9.9.9","/p/bad/manifest.json"]',
    '["no.version","","/p/no.version/manifest.json"]',
    'not json at all',
    '["also.trailing","2.0.0","/p/also.trailing/manifest.json","extra"]',
  ].join("\n");
  const s = M.normalizeScan(text);
  assert.deepStrictEqual(s, {
    "a.old-popular": { version: "1.1.0", dir: "a.old-popular", from: "" },
    "omarchy.clock": { version: "1", dir: "omarchy.clock", from: "" },
    "no.version": { version: "", dir: "no.version", from: "" },
    "also.trailing": { version: "2.0.0", dir: "also.trailing", from: "extra" },
  });
  assert.deepStrictEqual(M.normalizeScan(""), {}, "an empty scan is not an error");
  assert.deepStrictEqual(M.normalizeScan('["x.y","v\n1.0"]'), {}, "a stray newline cannot forge an id");
  assert.strictEqual(M.normalizeScan('["x.y","1","/p/weird name/manifest.json"]')["x.y"].dir, "", "a dir with spaces is not a plain name");
  assert.strictEqual(M.normalizeScan('["x.y","1","/p/x"]')["x.y"].dir, "", "a path without manifest.json has no dir");

  const births = M.normalizeBirths([
    "1791724859 1792217628 /p/a.old-popular",
    "0 1792217628 /p/omarchy.clock",
    "oops",
  ].join("\n"));
  assert.strictEqual(births["a.old-popular"], 1791724859 * 1000, "birth wins when present");
  assert.strictEqual(births["omarchy.clock"], 1792217628 * 1000, "mtime is the fallback");

  const merged = M.applyScan(inst, s, births);
  assert.strictEqual(merged.map["a.old-popular"].version, "1.1.0", "the version on disk wins");
  assert.strictEqual(merged.map["a.old-popular"].dir, "a.old-popular");
  assert.strictEqual(merged.map["a.old-popular"].installedAt, births["a.old-popular"]);
  assert.strictEqual(merged.map["omarchy.clock"].version, "1");
  assert.strictEqual(merged.map["a.old-popular"].clonedFrom, "", "clonedFrom comes from the scan");
  assert.strictEqual(merged.map["me.local-dev"].version, "", "no manifest, no version");
  assert.strictEqual(merged.map["me.local-dev"].installedAt, 0, "no manifest, no install time");
  assert.strictEqual(inst.map["a.old-popular"].version, "1.0.0", "the installed base is not mutated");
  assert.strictEqual(inst.list[0], inst.map["a.old-popular"], "the input pair still shares records");
  assert.strictEqual(merged.list[0], merged.map["a.old-popular"], "the rebuilt pair shares them too");
  assert.deepStrictEqual(M.findUpdates(cat, merged.map), ["a.old-popular"], "updates now come from both sides");
  assert.deepStrictEqual(M.applyScan(null, s, births), { list: [], map: {} });
})();

(function newlyInstalledSort() {
  // The Installed tab can order by the moment each plugin landed on disk, newest
  // first. Where there is no install time (local plugins, above) it sorts last.
  const s = M.normalizeScan([
    '["a.old-popular","1.0.0","/p/a.old-popular/manifest.json"]',
    '["omarchy.clock","1","/p/omarchy.clock/manifest.json"]',
  ].join("\n"));
  const births = { "a.old-popular": 1000, "omarchy.clock": 9000 };
  const merged = M.applyScan(inst, s, births);
  const run = o => ids(M.query(cat, merged.list, merged.map, { ...base, source: "all", status: "installed", ...o }));
  assert.deepStrictEqual(run({ sort: "installed" }), ["omarchy.clock", "a.old-popular", "me.local-dev"], "newest install first, unknown last");
})();

(function health() {
  // Health reads the on-disk picture and reports what an update would trip on.
  const inst2 = M.normalizeInstalled([
    { id: "a.old-popular", enabled: true },
    { id: "omarchy.clock", enabled: true },
    { id: "renamed.one", enabled: true },
  ]);
  const s = M.normalizeScan([
    '["a.old-popular","1.0.0","/p/a.old-popular/manifest.json"]',
    '["omarchy.clock","1","/p/omarchy.clock/manifest.json"]',
    '["renamed.one","2.0.0","/p/folder-name/manifest.json"]',
  ].join("\n"));
  const births = { "a.old-popular": 1, "omarchy.clock": 2, "folder-name": 3, "junk-dir": 4 };
  const merged = M.applyScan(inst2, s, births);
  const catMap = { "a.old-popular": true, "omarchy.clock": true };
  const git = M.normalizeDirSet("/p/folder-name\n");           // only renamed.one is a checkout
  const h = M.healthOf(merged.list, births, git, catMap);
  const kinds = h.map(x => x.id + ":" + x.kind).sort();
  assert.ok(kinds.includes("a.old-popular:nogit"), "a plugin without .git is flagged");
  assert.ok(kinds.includes("renamed.one:renamed"), "a dir != id is flagged");
  assert.ok(kinds.includes("renamed.one:orphan"), "renamed.one is not in the catalog");
  assert.ok(kinds.includes("junk-dir:nomanifest"), "a dir with no readable manifest is flagged");
  assert.ok(!kinds.some(k => k.startsWith("omarchy.clock")), "a healthy builtin is not flagged");
  assert.ok(!kinds.some(k => k.startsWith("a.old-popular:orphan")), "a cataloged plugin is not an orphan");

  assert.deepStrictEqual(M.normalizeDirSet("/p/one\nnope name\n"), { one: true });
})();

(function targetDirectory() {
  // omarchy plugin update/remove resolve $PLUGINS_DIR/<name>, and the name is the
  // directory, not the manifest id. A renamed plugin must be updated by its dir.
  const merged = M.applyScan(inst, M.normalizeScan('["a.old-popular","1","/p/folder-name/manifest.json"]'), {});
  assert.strictEqual(M.pluginTarget("update", "a.old-popular", merged.map), "folder-name");
  assert.strictEqual(M.pluginTarget("remove", "a.old-popular", merged.map), "folder-name");
  assert.strictEqual(M.pluginTarget("enable", "a.old-popular", merged.map), "a.old-popular", "enable uses the id");
  assert.strictEqual(M.pluginTarget("update", "x", {}), "x", "no dir known, id stands");
  assert.deepStrictEqual(M.actionArgs("update", M.pluginTarget("update", "a.old-popular", merged.map), "", {}).argv,
    ["omarchy", "plugin", "update", "folder-name", "--yes"]);
})();

(function issuesStatus() {
  // me.local-dev is installed but not in the catalog, so it is the one finding
  // here; the "Needs attention" status filters the list to exactly those.
  const s = M.normalizeScan('["a.old-popular","1.0.0","/p/a.old-popular/manifest.json"]');
  const merged = M.applyScan(inst, s, { "a.old-popular": 1 });
  const h = M.healthOf(merged.list, {}, { "a.old-popular": true }, { "a.old-popular": true });
  assert.deepStrictEqual(h.map(f => f.id), ["me.local-dev"]);
  const set = {};
  for (const f of h) set[f.id] = true;
  const got = ids(M.query(cat, merged.list, merged.map, { ...base, source: "all", status: "issues", healthSet: set }));
  assert.deepStrictEqual(got, ["me.local-dev"]);
})();

(function gitHistory() {
  // The changelog is git's own output, parsed defensively: hash, date, subject.
  const log = M.parseGitLog([
    "a1b2c3d\t2026-10-01\tFix the thing",
    "9f8e7d6\t2026-09-20\tAdd a\tfeature with a tab",
    "garbage line without tabs",
    "",
    "deadbee\t2026-09-01\tInitial commit",
  ].join("\n"));
  assert.deepStrictEqual(log[0], { hash: "a1b2c3d", date: "2026-10-01", subject: "Fix the thing" });
  assert.strictEqual(log[1].subject, "Add a\tfeature with a tab", "tabs inside a subject survive");
  assert.strictEqual(log.length, 3, "a line with no tabs is skipped");
  assert.deepStrictEqual(M.parseGitLog(""), []);

  const recent = M.gitLogArgs("/home/me/plugins/x.y", false);
  const at = recent.indexOf("-C");
  assert.deepStrictEqual(recent.slice(at, at + 3), ["-C", "/home/me/plugins/x.y", "log"]);
  for (const c of ["core.hooksPath=/dev/null", "core.fsmonitor=", "protocol.allow=never"])
    assert.ok(recent.includes(c), "git runs with " + c);
  assert.ok(!recent.includes("HEAD..FETCH_HEAD"), "recent history is not ranged");
  assert.ok(M.gitLogArgs("/p/x", true).includes("HEAD..FETCH_HEAD"), "incoming history is ranged");
  const f = M.gitFetchArgs("/p/x", "https://github.com/o/r");
  assert.deepStrictEqual(f.slice(f.indexOf("fetch")), ["fetch", "--quiet", "--no-tags", "--", "https://github.com/o/r.git", "HEAD"]);
  assert.ok(f.includes("core.hooksPath=/dev/null"));
  assert.strictEqual(M.gitFetchArgs("/p/x", "ext::sh -c id"), null, "only a plain repository address is fetched");
  assert.strictEqual(M.gitFetchArgs("/p/x", ""), null, "no address, no fetch");
})();

(function images() {
  const n = M.imageName("https://plugins.omarchy.org/assets/img/plugins/a-card.webp");
  assert.ok(/^[0-9a-f]{16}\.webp$/.test(n), "a plain hashed name: " + n);
  assert.strictEqual(M.imageName("https://plugins.omarchy.org/x"), M.imageName("https://plugins.omarchy.org/x"), "stable");
  const argv = M.imageBatchArgs([
    { url: "https://plugins.omarchy.org/a.webp", name: n },
    { url: "https://evil.example/a.png", name: "0000000000000000.png" },
    { url: "https://plugins.omarchy.org/b.webp", name: "../../etc/passwd" }
  ], "/c");
  assert.strictEqual(argv.filter(a => a === "--url").length, 1, "only allowed hosts and plain names are fetched");
  assert.ok(argv.includes("--max-filesize") && argv.includes("=https"));
  const ok = M.imageReport("0 /c/" + n + "\n22 /c/0000000000000000.png\n0 /etc/" + n + "\n", "/c");
  assert.deepStrictEqual(Object.keys(ok), [n], "only complete files in the cache folder count");
  const thumb = M.thumbName(n);
  assert.strictEqual(thumb, n.slice(0, 16) + ".png", "a thumbnail is always a png");
  assert.strictEqual(M.thumbName("../x.png"), "");
  const inv = M.imageInventory("5 " + thumb + "\n9 1111111111111111.png\n1 notes.txt\n3 " + n + "\n");
  assert.deepStrictEqual(Object.keys(inv.keep).sort(), ["1111111111111111.png", thumb].sort(), "only thumbnails are ever shown");
  const targs = M.thumbArgs("/c/incoming/" + n, "/c/thumbs/" + thumb);
  assert.strictEqual(targs[0], "prlimit", "made in a capped process");
  assert.ok(targs.some(a => /^--as=\d+$/.test(a)) && targs.includes("vipsthumbnail"));
  assert.strictEqual(targs[targs.length - 1], "/c/thumbs/" + thumb + "[keep=none]", "no metadata is kept");
  assert.strictEqual(M.thumbArgs("/c/incoming/" + n, "/c/thumbs/x.png"), null);
  assert.strictEqual(M.thumbArgs("/c/[x]/" + n, "/c/thumbs/" + thumb), null, "no vips options sneak in through a path");
})();

(function links() {
  assert.strictEqual(M.safeWebUrl("https://github.com/o/r"), "https://github.com/o/r");
  assert.strictEqual(M.safeWebUrl("https://github.com/qempexe?tab=repositories&q=omarchy"), "https://github.com/qempexe?tab=repositories&q=omarchy");
  assert.strictEqual(M.safeWebUrl("https://plugins.omarchy.org/#author=qempexe"), "https://plugins.omarchy.org/#author=qempexe");
  assert.strictEqual(M.safeWebUrl("https://evil.example/"), "", "unknown site");
  assert.strictEqual(M.safeWebUrl("https://evil.example\\@github.com/"), "", "backslash trick");
  assert.strictEqual(M.safeWebUrl("https://user@github.com/"), "", "user part");
  assert.strictEqual(M.safeWebUrl("http://github.com/"), "", "https only");
  assert.strictEqual(M.safeWebUrl("file:///etc/passwd"), "");
})();

(function websiteFilters() {
  const cat = M.normalizeCatalog({ plugins: [
    { id: "a.kids", name: "Letters", author: "Ana", category: "Productivity", tags: ["education"], kind: "Bar widget",
      verificationStatus: "verified", repo: "https://github.com/a/kids", installAvailable: true },
    { id: "b.vpn", name: "Mullvad Toggle", author: "Bo", category: "System", tags: ["security"], kind: "Panel",
      verificationStatus: "unverified", repo: "https://github.com/b/vpn" },
    { id: "c.bar", name: "Top Bar", author: "qempexe", category: "Appearance", tags: ["media"], kind: "Service",
      verificationStatus: "verified", repo: "https://github.com/c/bar" },
    { id: "d.suite", name: "Shell", author: "Cy", category: "Desktop", tags: ["ai"], kind: "Suite",
      repositoryLayout: "suite", verificationStatus: "unverified", repo: "https://github.com/d/suite" }
  ] });
  const ids = (l) => l.map(p => p.id).sort();
  assert.deepStrictEqual(ids(cat.filter(p => M.inCollection(p, "kids"))), ["a.kids"], "Kids from the education tag");
  assert.deepStrictEqual(ids(cat.filter(p => M.inCollection(p, "vpn"))), ["b.vpn"], "VPN from the name");
  assert.deepStrictEqual(ids(cat.filter(p => M.inCollection(p, "bar"))), ["c.bar"], "Bar: a bar-named service");
  assert.deepStrictEqual(ids(cat.filter(p => M.inCollection(p, "ai"))), ["d.suite"]);

  const q = M.parseQuery("Tag:Media kind:bar-widget @Qemp hello");
  assert.deepStrictEqual(q, { words: ["hello"], tags: ["media"], kinds: ["bar-widget"], authors: ["qemp"] });
  assert.strictEqual(M.kindKey("Bar widget"), "bar-widget");

  const run = (o) => ids(M.query(cat, [], {}, Object.assign({ query: "", source: "community", sort: "az", days: 0, status: "any" }, o)).items);
  assert.deepStrictEqual(run({ query: "tag:media @qempexe" }), ["c.bar"]);
  assert.deepStrictEqual(run({ query: "kind:panel" }), ["b.vpn"]);
  assert.deepStrictEqual(run({ verification: "verified" }), ["a.kids", "c.bar"]);
  assert.deepStrictEqual(run({ verification: "unverified" }), ["b.vpn"], "a suite is neither verified nor unverified");
  assert.deepStrictEqual(run({ verifiedOnly: true }), ["a.kids", "c.bar"], "the older verifiedOnly still works");
  assert.deepStrictEqual(run({ collection: "vpn" }), ["b.vpn"]);
  const facets = M.query(cat, [], {}, { query: "", source: "community", sort: "az", days: 0, status: "any" }).facets;
  assert.deepStrictEqual(facets.collections.map(c => c.key), ["kids", "vpn", "bar", "ai", "security"]);

  cat[0].hearts = 5; cat[0].views = 50; cat[1].stars = 9; cat[2].hearts = 5; cat[2].stars = 9; cat[2].views = 60;
  const ranks = M.ranksOf(cat.slice());
  assert.strictEqual(ranks["c.bar"], 1, "best places add up to the top rank");
  assert.strictEqual(ranks["d.suite"], undefined, "no hearts, copies, views or stars: not ranked");
  assert.deepStrictEqual(M.query(cat, [], {}, { query: "", source: "community", sort: "rank", days: 0, status: "any" }).items.map(p => p.id)[0], "c.bar");
  assert.strictEqual(cat[0].rate, -1, "under 20 views at load: not rated");
})();

(function builtins() {
  const cat = M.normalizeCatalog({ plugins: [
    { id: "omarchy.clock", name: "Clock", sourceType: "builtin", builtIn: true, kind: "Bar widget", category: "Bar widgets" },
    { id: "a.b", name: "Thing", author: "x", repo: "https://github.com/a/b", verificationStatus: "verified" }
  ] });
  assert.ok(cat[0].builtin && !cat[0].installable, "the catalog's built-ins are built-in, never installed");
  const inst = M.normalizeInstalled([{ id: "omarchy.clock", enabled: true }, { id: "omarchy.extra", enabled: true }]);
  const ids = (src) => M.query(cat, inst.list, inst.map, { query: "", source: src, sort: "az", days: 0, status: "any" }).items.map(p => p.id);
  assert.deepStrictEqual(ids("community"), ["a.b"], "built-ins stay out of Community");
  assert.deepStrictEqual(ids("builtin").sort(), ["omarchy.clock", "omarchy.extra"], "catalog built-ins, then installed ones it lacks");
})();

(function commands() {
  const a = M.actionArgs("install", "x", "https://github.com/o/r", { enableAfterInstall: true });
  assert.deepStrictEqual(a.argv, ["omarchy", "plugin", "add", "https://github.com/o/r.git", "--enable", "--yes"]);
  assert.ok(!M.actionArgs("install", "x", "https://github.com/o/r", { enableAfterInstall: false }).argv.includes("--enable"));
  assert.strictEqual(M.actionArgs("install", "x", "ssh://evil", {}), null);
  assert.strictEqual(M.actionArgs("remove", "--all", "", {}), null, "flag-like id refused");
  assert.deepStrictEqual(M.actionArgs("remove", "a.b", "", {}).fallback, ["omarchy", "plugin", "remove", "a.b"]);
  const u = M.actionArgs("update", "a.b", "", {});
  assert.deepStrictEqual(u.argv, ["omarchy", "plugin", "update", "a.b", "--yes"], "update is non-interactive: it needs --yes");
  assert.strictEqual(u.fallback, null, "a fallback without --yes could only fail with the same refusal");
  assert.strictEqual(M.actionArgs("explode", "a.b", "", {}), null);
})();

(function display() {
  assert.strictEqual(M.relTime(now - 0.2 * DAY, now), "today");
  assert.strictEqual(M.relTime(now - 3 * DAY, now), "3d ago");
  assert.strictEqual(M.relTime(0, now), "unknown");
  assert.strictEqual(M.fmtCount(1234), "1.2k");
  assert.strictEqual(M.validHex("#abc", "#000"), "#aabbcc");
  assert.strictEqual(M.validHex("red; drop", "#000"), "#000");
})();
(function realShape() {
  // field names as the live catalog uses them
  const l = M.normalizeCatalog([{ id: "crmne.hyprmoncfg", name: "Hyprmoncfg", repo: "https://github.com/crmne/omarchy-hyprmoncfg",
    listedAt: iso(3), previewImage: "assets/img/plugins/5-crmne-omarchy-hyprmoncfg-detail.webp",
    previewThumbnail: "assets/img/plugins/5-crmne-omarchy-hyprmoncfg-card.webp", iconImage: "assets/img/plugins/5-icon.webp",
    verificationStatus: "verified", installAvailable: true, stars: 12, accent: "#ff6a1f" },
    { id: "x.unver", name: "U", verificationStatus: "update-unverified", installAvailable: false }]);
  assert.strictEqual(l[0].preview, "https://plugins.omarchy.org/assets/img/plugins/5-crmne-omarchy-hyprmoncfg-card.webp");
  assert.strictEqual(l[0].previewFull, "https://plugins.omarchy.org/assets/img/plugins/5-crmne-omarchy-hyprmoncfg-detail.webp");
  assert.ok(l[0].icon.endsWith("5-icon.webp"));
  assert.strictEqual(l[0].verified, true);
  assert.strictEqual(l[1].verified, false);
  assert.strictEqual(l[1].installable, false);
  assert.ok(l[0].addedAt > 0);
  assert.strictEqual(l[0].accent, "#ff6a1f");
  for (const shape of [{ "crmne.hyprmoncfg": { views: 10, hearts: 2, copies: 4 } },
                       { plugins: [{ id: "crmne.hyprmoncfg", views: 10, hearts: 2, copies: 4 }] },
                       { stats: { "crmne.hyprmoncfg": { views: 10, hearts: 2, copies: 4 } } }]) {
    const c = M.normalizeCatalog([{ id: "crmne.hyprmoncfg", name: "H" }]);
    assert.strictEqual(M.applyStats(c, M.normalizeStats(shape)), 1);
    assert.deepStrictEqual([c[0].views, c[0].hearts, c[0].copies], [10, 2, 4]);
  }
})();
(function upgradedField() {
  const l = M.normalizeCatalog([
    { id: "r.upd", name: "R", addedAt: "2026-07-28", listingValidatedAt: "2026-07-28T12:24:24.000Z", repositoryUpdatedAt: "2026-10-01T08:00:00.000Z" },
    { id: "r.none", name: "N", addedAt: "2026-07-28", listingValidatedAt: "2026-07-28T12:24:24.000Z", repositoryUpdatedAt: null }]);
  assert.strictEqual(l[0].updatedAt, Date.parse("2026-10-01T08:00:00.000Z"), "repositoryUpdatedAt is the upgrade date");
  assert.strictEqual(l[1].updatedAt, Date.parse("2026-07-28T12:24:24.000Z"), "falls back when it is empty");
})();
(function sets() {
  const catalog = M.normalizeCatalog([
    { id: "cat.one", name: "One", repo: "https://github.com/o/one" },
    { id: "cat.two", name: "Two", repo: "https://evil.example/x --upload-pack=sh" },
  ]);
  const inst = M.normalizeInstalled({ plugins: [
    { id: "omarchy.builtin", name: "B", enabled: true },
    { id: "cat.one", name: "One", enabled: true },
    { id: "local.thing", name: "Thing", enabled: false },
  ] });
  const merged = M.applyScan(inst, M.normalizeScan([
    '["omarchy.builtin","1","/p/omarchy.builtin/manifest.json"]',
    '["cat.one","1","/p/cat.one/manifest.json"]',
    '["local.thing","1","/p/local.thing/manifest.json","https://github.com/l/thing"]',
  ].join("\n")), {});
  const set = M.buildSet(merged.list, catalog);
  assert.deepStrictEqual(set.map(p => p.id), ["cat.one", "local.thing"], "built-ins are left out");
  assert.strictEqual(set[0].repo, "https://github.com/o/one.git", "repo comes from the catalog");
  assert.strictEqual(set[1].repo, "https://github.com/l/thing.git", "otherwise from the manifest's clonedFrom");

  const map = merged.map;
  // nothing here is installed, so each is planned by its repo: a bad repo and no
  // repo are both skipped, only the good one is installed.
  const plan = M.planRestore({ plugins: [
    { id: "cat.two", name: "Two", repo: "https://evil.example/x --upload-pack=sh" },
    { id: "new.plugin", name: "New", repo: "https://github.com/n/new" },
    { id: "missing.off", name: "Off", repo: "" },
  ] }, map);
  assert.strictEqual(plan.length, 1, "only the missing plugin with a good repo is planned");
  assert.deepStrictEqual(plan[0], { kind: "install", id: "new.plugin", name: "New", repo: "https://github.com/n/new.git" });

  // an installed-but-disabled plugin is enabled, not reinstalled
  const off = Object.fromEntries(M.normalizeInstalled({ plugins: [
    { id: "local.thing", name: "Thing", enabled: false }] }).list.map(r => [r.id, r]));
  const plan2 = M.planRestore({ plugins: [{ id: "local.thing", name: "Thing", repo: "https://github.com/l/thing" }] }, off);
  assert.deepStrictEqual(plan2, [{ kind: "enable", id: "local.thing", name: "Thing", repo: "" }]);

  assert.deepStrictEqual(M.planRestore(null, map), [], "no set plans nothing");
})();

(function manyCategories() {
  // a catalog with thousands of different categories and tags still gives a short sidebar
  const many = { plugins: [] };
  for (let i = 0; i < 5000; i++)
    many.plugins.push({ id: "x.p" + i, name: "P" + i, category: "C" + i, tags: ["t" + i], repo: "https://github.com/x/p" + i });
  many.plugins.push({ id: "x.big1", name: "Big", category: "Common", tags: ["shared"], repo: "https://github.com/x/b1" });
  many.plugins.push({ id: "x.big2", name: "Big2", category: "Common", tags: ["shared"], repo: "https://github.com/x/b2" });
  const c = M.normalizeCatalog(many);
  const q = (st) => M.query(c, [], {}, Object.assign({}, base, { now }, st)).facets;
  const f = q({});
  assert.strictEqual(f.categories.length, M.MAX_CATEGORIES);
  assert.strictEqual(f.tags.length, M.MAX_TAGS);
  assert.strictEqual(f.categories[0].name, "Common", "the busiest come first");
  // the one picked stays in the list even when it would not make the cut
  const g = q({ category: "C4999", tags: ["t4998"] });
  assert.strictEqual(g.categories.length, M.MAX_CATEGORIES + 1);
  assert.ok(g.categories.some(x => x.name === "C4999"));
  assert.ok(q({ tags: ["t4998"] }).tags.some(x => x.name === "t4998"));
  assert.strictEqual(q({ category: "Common" }).categories.length, M.MAX_CATEGORIES, "already listed: not added twice");
})();
console.log("model tests: ok");
