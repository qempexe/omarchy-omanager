// node tests/test_theme.js: reading colors out of an Omarchy theme
const fs = require("fs"), path = require("path"), assert = require("assert");
const src = fs.readFileSync(path.join(__dirname, "..", "qml", "js", "Theme.js"), "utf8").replace(/^\.pragma.*$/m, "");
const T = new Function(src + "; return { parsePalette, parseBorder };")();

assert.deepStrictEqual(T.parsePalette('red = "#d27a52"\nyellow = "#E0B25C"\naccent = "#c8925a"\n'), ["#d27a52", "#e0b25c"],
  "named colors in order, lower case, accent left out");
assert.deepStrictEqual(T.parsePalette('color1 = "#111111"\ncolor2 = "#222222"\n'), ["#111111", "#222222"], "older themes");
assert.deepStrictEqual(T.parsePalette('red = "$(id)"\n'), [], "only hex values");
assert.deepStrictEqual(T.parseBorder('local active_border_color = { colors = { "rgba(1ee9d6ee)", "rgba(fe4fb6ee)" }, angle = 45 }'),
  { colors: ["#1ee9d6", "#fe4fb6"], angle: 45 });
assert.deepStrictEqual(T.parseBorder("col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg\ncol.inactive_border = rgba(595959aa)"),
  { colors: ["#33ccff", "#00ff99"], angle: 45 });
assert.deepStrictEqual(T.parseBorder("col.inactive_border = rgba(595959aa)"), { colors: [], angle: 0 }, "inactive border ignored");
console.log("theme tests: ok");
