#!/usr/bin/env node
// Run with: node tests/test_model.js
// Model.js starts with the QML-only `.pragma library` line, so strip it before evaluating.
const fs = require("fs"), path = require("path"), assert = require("assert");
let src = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(/^\.pragma.*$/m, "");
const M = new Function(src + "; return {normalizeCatalog, normalizeStats, applyStats, normalizeInstalled, query, findUpdates, compareVersions, safeRepoUrl, safeImageUrl, safeCatalogUrl, actionArgs, relTime, fmtCount, validHex};")();

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

(function commands() {
  const a = M.actionArgs("install", "x", "https://github.com/o/r", { enableAfterInstall: true });
  assert.deepStrictEqual(a.argv, ["omarchy", "plugin", "add", "https://github.com/o/r.git", "--enable", "--yes"]);
  assert.ok(!M.actionArgs("install", "x", "https://github.com/o/r", { enableAfterInstall: false }).argv.includes("--enable"));
  assert.strictEqual(M.actionArgs("install", "x", "ssh://evil", {}), null);
  assert.strictEqual(M.actionArgs("remove", "--all", "", {}), null, "flag-like id refused");
  assert.deepStrictEqual(M.actionArgs("remove", "a.b", "", {}).fallback, ["omarchy", "plugin", "remove", "a.b"]);
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
console.log("model tests: ok");
