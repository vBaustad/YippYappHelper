// Capture healer trinket rankings from questionablyepic.com/live/trinkets.
//
// QE Live has no data endpoint. The page computes every number in the
// browser from the player it holds in React state, so there is nothing
// to fetch -- the only way to read it is to drive the page and read the
// chart component's props back out. That is what this file does.
//
// Usage:
//   1. open https://questionablyepic.com/live/trinkets
//   2. paste this whole file into the console
//   3. await QECapture.run()            -- about 90 seconds, 14 charts
//   4. copy(QECapture.payload())        -- lands on the clipboard
//   5. save it as Tools/qe_capture.json
//   6. python Tools/scrape_healer_trinkets.py
//
// The one thing that is not obvious: changing the spec dropdown does NOT
// reliably recompute the chart. Read it straight after and you get the
// PREVIOUS spec's numbers, which look plausible and are wrong -- the
// first version of this capture produced a whole file of them, with
// Mistweaver's list sitting under Holy Paladin's name. What does force a
// recompute is a fresh mount, so every reading here navigates to the
// home page and back before it reads anything. Two passes in opposite
// spec order then returned byte-identical numbers, which is the check
// worth repeating if this ever needs changing.

window.QECapture = (function () {
  const SPECS = ["Restoration Druid", "Holy Priest", "Discipline Priest",
                 "Restoration Shaman", "Holy Paladin", "Mistweaver Monk",
                 "Preservation Evoker"];
  const CONTENTS = ["Raid", "Dungeon"];
  const MAX_ROWS = 25;    // matches Tools/scrape_trinkets.py
  const CURVE_ROWS = 15;  // ditto -- the tail is not what anyone compares

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  function fiber(el) {
    const k = Object.keys(el).find((x) => x.startsWith("__reactFiber$"));
    return el[k];
  }

  // Walk up from a DOM node until a fiber's props satisfy `test`. The
  // page is minified, so props are the only stable handle: class names
  // and component names change with every deploy, but "the ancestor
  // holding `data` and `itemLevels`" is the chart by definition.
  function climb(el, test, max) {
    let f = fiber(el);
    for (let d = 0; f && d < (max || 16); d++, f = f.return) {
      const p = f.memoizedProps;
      if (p && typeof p === "object" && test(p)) return p;
    }
    return null;
  }

  function chart() {
    const c = [...document.querySelectorAll("div")]
      .filter((d) => /recharts-responsive/i.test(d.className.toString()))[0];
    if (!c) return null;
    return climb(c, (p) => Array.isArray(p.data) && Array.isArray(p.itemLevels), 8);
  }

  const specSelect = () => document.querySelector('[aria-labelledby="class-select-label"]');
  const contentSelect = () =>
    [...document.querySelectorAll('[role="button"][aria-haspopup="listbox"]')]
      .find((e) => CONTENTS.includes(e.textContent.trim()));

  // A real click, not the React onChange handler. Calling onChange
  // directly moves the select's own label and nothing else -- the page
  // keeps the old player and the chart never notices.
  async function pick(find, value) {
    const el = find();
    if (!el) return "select not found";
    el.dispatchEvent(new MouseEvent("mousedown", { bubbles: true, button: 0 }));
    await sleep(400);
    const li = [...document.querySelectorAll('li[role="option"], .MuiMenu-list li')]
      .find((i) => i.getAttribute("data-value") === value || i.textContent.trim() === value);
    if (!li) {
      document.body.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
      return "option not found: " + value;
    }
    li.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    li.click();
    await sleep(300);
    return "ok";
  }

  async function remount() {
    const logo = [...document.querySelectorAll("a")]
      .find((a) => a.getAttribute("href") === "/live/");
    logo.click();
    await sleep(1500);
    history.back();
    await sleep(3000);
  }

  function playstyle() {
    const e = [...document.querySelectorAll("*")]
      .find((x) => x.children.length === 0 && /Current Playstyle/.test(x.textContent));
    if (!e) return null;
    return e.textContent.replace(/^[-\s]*/, "").replace("Current Playstyle: ", "")
            .replace(/ - (Raid|Dungeon)$/, "").trim();
  }

  const state = { status: "idle", log: [], results: [] };

  async function run(specs, contents) {
    state.status = "running";
    state.log = [];
    state.results = [];
    for (const spec of specs || SPECS) {
      for (const content of contents || CONTENTS) {
        await pick(specSelect, spec);
        await sleep(600);
        await pick(contentSelect, content);
        await sleep(600);
        await remount();
        const c = chart();
        const showing = (contentSelect() || {}).textContent;
        if (!c) { state.log.push("NO CHART " + spec + "/" + content); continue; }
        // Recorded, not assumed: if the selects do not read back what we
        // picked, the block is mislabelled and the whole file is junk.
        state.results.push({
          spec, content, playstyle: playstyle(),
          specNow: (specSelect() || {}).textContent.trim(),
          contentNow: showing && showing.trim(),
          itemLevels: c.itemLevels, rows: c.data,
        });
        state.log.push(spec + "/" + content + " shows=" + (showing && showing.trim()) +
                       " rows=" + c.data.length);
      }
    }
    state.status = "done";
    return state.log;
  }

  // Condensed the same way the bloodmallet scrape condenses its payload:
  // top 25 by value, item-level curves for the top 15, and one shared
  // pool of curves because specs agree about a trinket far more often
  // than they disagree.
  function payload() {
    const items = {}, pool = [], poolIdx = {};
    const blocks = state.results.map((r) => {
      const rows = r.rows.map((x) => {
        const v = {};
        for (const k of Object.keys(x)) if (/^i\d+$/.test(k)) v[+k.slice(1)] = Math.round(x[k]);
        const tip = x.tooltip || [];
        if (!items[x.id]) {
          items[x.id] = [x.name, x.highestLevel,
            (tip.find((t) => /^Drops from:/.test(t)) || "").replace("Drops from: ", "").trim()];
        }
        const levels = r.itemLevels.filter((l) => v[l] != null);
        const at = Math.max(...levels.filter((l) => l <= x.highestLevel));
        return { id: x.id, at, val: v[at], lo: Math.min(...levels),
                 arr: r.itemLevels.map((l) => (v[l] == null ? -1 : v[l])) };
      }).sort((a, b) => b.val - a.val).slice(0, MAX_ROWS);
      return {
        s: r.spec, c: r.content, p: r.playstyle, L: r.itemLevels,
        r: rows.map((row, i) => {
          let ci = -1;
          if (i < CURVE_ROWS) {
            const key = row.arr.join(",");
            if (poolIdx[key] == null) { poolIdx[key] = pool.length; pool.push(row.arr); }
            ci = poolIdx[key];
          }
          return [row.id, row.at, row.val, row.lo, ci];
        }),
      };
    });
    return JSON.stringify({
      captured: new Date().toISOString().slice(0, 10),
      source: "questionablyepic.com/live/trinkets",
      items, pool, blocks,
    });
  }

  return { run, payload, state, chart, pick, specSelect, contentSelect };
})();
