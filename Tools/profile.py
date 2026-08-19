"""Measure what the addon costs, rather than guessing at it.

Runs the same stubbed client as Tools/loadcheck.py and reports three
things that actually decide whether an addon feels bad in game:

  LOAD       -- how long the files take to parse and run, and how much
                memory they leave behind. Paid once, at login, on top of
                every other addon the player has.

  GARBAGE    -- bytes allocated per frame by anything with an OnUpdate.
                This is the number that matters. Lua's collector runs
                when allocation crosses a threshold, so a handler that
                allocates every frame does not cost you a little all the
                time -- it costs you a collection pause, periodically,
                forever. A frame that allocates nothing never triggers
                one.

  WORK       -- how long a frame takes here. Wall-clock under lupa is
                NOT the client's frame time and must not be read as ms
                in game; it is only useful as a before-and-after ratio
                against itself.

Nothing here asserts. It prints numbers so a change can be shown to have
helped -- see the perf budget in loadcheck.py for the part that fails.
"""

import gc
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lupa import LuaRuntime                       # noqa: E402
import loadcheck as LC                            # noqa: E402


def build(stub_anchors=True):
    """A loaded addon, in a fresh Lua state.

    `stub_anchors` silences the anchor recorder, which is right for
    measuring garbage and wrong for anything that wants to know where
    things ended up.
    """
    L = LuaRuntime(unpack_returned_tuples=False)
    L.execute("_G = _G or _ENV")
    L.execute(LC.PRELUDE)
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
    started = time.perf_counter()
    for rel in LC.toc_files():
        path = os.path.join(LC.ROOT, rel)
        if not os.path.exists(path):
            continue
        src = open(path, encoding="utf-8-sig").read()
        err = run_lua(src, "@" + rel, ns)
        if err and not LC.is_version_divergence(str(err)):
            print("  load error in %s: %s" % (rel, err))
    load_secs = time.perf_counter() - started

    # Silence the stub's own bookkeeping before measuring anything.
    #
    # THIS IS THE WHOLE VALIDITY OF THE NUMBER BELOW. The harness records
    # every anchor so layout can be inspected after a draw: SetPoint
    # allocates a list and a point table on each call, and put() clears
    # and re-anchors on every sprite on every frame. Left in, the report
    # was 8-23 KB per frame and almost all of it was the test rig --
    # which is a great way to spend a day optimising nothing.
    #
    # In the client these are C functions and allocate no Lua garbage at
    # all, so a no-op is much closer to the truth than the recorder is.
    if stub_anchors:
        L.execute("""
            local mt = getmetatable(UIParent)
            rawset(mt, "SetPoint", function(self) return self end)
            rawset(mt, "ClearAllPoints", function(self) return self end)
            rawset(mt, "SetAllPoints", function(self) return self end)
        """)
    return L, ns, load_secs


def kb(L):
    """Live Lua heap in KB, after a full collection."""
    return L.eval("function() collectgarbage('collect') return collectgarbage('count') end")()


def measure_frames(L, ns, boss, frames=600):
    """Bytes allocated per frame, and seconds per frame, for one fight."""
    probe = L.eval("""
        function(ns, bossId, frames)
            local T, S = ns.RaidTrainer, ns.RaidTrainer.state
            local f = ns.RaidTrainerFrame
            local update = f._scripts.OnUpdate
            T:Start(bossId, false)
            S.countdown = 0
            -- Warm up first: the first frames build sprite pools and
            -- font strings that a steady-state frame reuses, and
            -- counting those as per-frame cost would blame the loop for
            -- one-off setup.
            for _ = 1, 120 do
                S.hp, S.firing = 100, true
                update(f, 0.016)
            end
            collectgarbage('collect')
            local before = collectgarbage('count')
            for _ = 1, frames do
                S.hp, S.firing = 100, true
                update(f, 0.016)
            end
            local after = collectgarbage('count')
            T:Stop()
            return (after - before) * 1024 / frames
        end
    """)
    gc.disable()
    started = time.perf_counter()
    per_frame_bytes = probe(ns, boss, frames)
    elapsed = time.perf_counter() - started
    gc.enable()
    return per_frame_bytes, elapsed / frames


def main():
    L, ns, load_secs = build()

    print("LOAD")
    print("  %d files parsed and run in %.0f ms" % (len(LC.toc_files()), load_secs * 1000))
    print("  %.0f KB of Lua heap left resident" % kb(L))

    print()
    print("GARBAGE AND WORK, per trainer frame")
    print("  %-14s %14s %12s" % ("boss", "bytes/frame", "rel. time"))
    bosses = L.eval("""
        function(ns)
            local out = {}
            for _, b in ipairs(ns.RaidGuide:Ordered()) do
                if ns.RaidTrainerScenarios[b.id] then out[#out + 1] = b.id end
            end
            return table.concat(out, ",")
        end
    """)(ns)
    baseline = None
    for boss in str(bosses).split(","):
        per_frame, secs = measure_frames(L, ns, boss)
        if baseline is None:
            baseline = secs
        print("  %-14s %14.0f %11.2fx" % (boss, per_frame, secs / baseline))


if __name__ == "__main__":
    main()
