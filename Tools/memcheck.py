#!/usr/bin/env python3
"""
Where the addon's memory goes, per file, without starting the client.

Usage:
    python Tools/memcheck.py
    python Tools/memcheck.py --top 15
    python Tools/memcheck.py --all      # every file, not just the heavy ones

Loads the addon in .toc order against the same stub Tools/loadcheck.py
uses, collecting garbage around each file and recording what it kept.
That is the number the client reports too: GetAddOnMemoryUsage counts
Lua allocations that outlive the load, which for us is almost entirely
the generated data tables.

What this does NOT measure, and what it therefore cannot exonerate:

  * frames. A CreateFrame costs C memory the client does not attribute
    to Lua at all, and the stub's frames are plain tables, so a page
    that builds two hundred rows looks cheap here and is not.
  * anything allocated after login. The second phase fires PLAYER_LOGIN
    and measures again, which catches the indexes built there, but a
    page only pays for itself when it is first opened.
  * the interpreter. lupa is not WoW's Lua 5.1: the absolute kilobytes
    will not match the client's. The ranking is the point.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lupa import LuaRuntime  # noqa: E402
from loadcheck import PRELUDE, ROOT, toc_files, is_version_divergence  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", type=int, default=20)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--min", type=float, default=8.0,
                    help="hide files under this many KB (unless --all)")
    args = ap.parse_args()

    L = LuaRuntime(unpack_returned_tuples=False)
    L.execute("_G = _G or _ENV")
    L.execute(PRELUDE)
    ns = L.eval("{}")

    run_lua = L.eval("""
        function(src, name, ns)
            local chunk = load(src, name)
            if not chunk then return "could not compile" end
            local ok, err = pcall(chunk, "YippYappHelper", ns)
            if ok then return nil end
            return tostring(err)
        end
    """)
    # Two full collections, because one leaves finalisable garbage behind
    # and the next file gets charged for it.
    settle = L.eval("""
        function()
            collectgarbage("collect")
            collectgarbage("collect")
            return collectgarbage("count")
        end
    """)

    rows, skipped = [], []
    before = settle()
    for rel in toc_files():
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            continue
        src = open(path, encoding="utf-8-sig").read()
        err = run_lua(src, "@" + rel, ns)
        after = settle()
        if err and not is_version_divergence(err):
            skipped.append(rel)
        rows.append((after - before, rel, len(src)))
        before = after

    total = sum(kb for kb, _, _ in rows)

    # Login is where the lazy work lands -- the trinket index, the loot
    # scan's caches -- and it is charged to us the same way the files
    # are.
    fire = L.eval("""
        function()
            if FireEvent then pcall(FireEvent, "PLAYER_LOGIN") end
            collectgarbage("collect")
            collectgarbage("collect")
            return collectgarbage("count")
        end
    """)
    login = fire() - before

    rows.sort(reverse=True)
    shown = rows if args.all else [r for r in rows[:args.top] if r[0] >= args.min]

    print("%-52s %9s  %9s" % ("file", "KB", "source KB"))
    print("-" * 74)
    for kb, rel, srclen in shown:
        print("%-52s %9.1f  %9.1f" % (rel, kb, srclen / 1024.0))
    hidden = len(rows) - len(shown)
    if hidden > 0:
        rest = total - sum(kb for kb, _, _ in shown)
        print("%-52s %9.1f" % ("(%d more files)" % hidden, rest))
    print("-" * 74)
    print("%-52s %9.1f" % ("loaded", total))
    print("%-52s %9.1f" % ("PLAYER_LOGIN", login))
    print("%-52s %9.1f" % ("total", total + login))
    if skipped:
        print("\nfailed to load (not counted honestly): %s" % ", ".join(skipped))
    return 0


if __name__ == "__main__":
    sys.exit(main())
