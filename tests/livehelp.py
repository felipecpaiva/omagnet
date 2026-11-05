"""Shared by the live tests: start from a known monitor, whichever one you happen to be using."""
import json, subprocess, time


def go_home():
    """Move the pointer to the middle of the first monitor (the laptop panel, id 0) so it is the focused one: the tests spawn their
    window on the focused monitor and compute areas from it. The tests put the pointer back where it was when they finish."""
    mons = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True).stdout or "[]")
    if not mons:
        return None
    m = min(mons, key=lambda x: x["id"])
    w, h = (m["height"], m["width"]) if m["transform"] % 2 else (m["width"], m["height"])
    x, y = m["x"] + int(w / m["scale"]) // 2, m["y"] + int(h / m["scale"]) // 2
    subprocess.run(["hyprctl", "eval", f"hl.dispatch(hl.dsp.cursor.move({{ x = {x}, y = {y} }}))"], capture_output=True)
    time.sleep(0.6)
    return m["name"]


def forget_headless_blocks():
    """Omarchy gives every monitor it sees, by make, model and serial, a block of ten workspaces and remembers it for good in
    ~/.local/state/omarchy/monitor-workspaces. A virtual (headless) monitor made for a test is one more monitor: each one used up a
    block, and real monitors plugged in afterwards got workspaces 261 and 271 instead of 11 and 21. This takes the HEADLESS-n lines
    out of that file (a copy is kept next to it) and reloads Hyprland so Omarchy reads the file again; the freed blocks are used by
    the next monitor that appears. It does not renumber the monitors that stay. Returns how many entries it removed. Run it after
    any test that created a virtual monitor."""
    import os
    path = os.path.expanduser("~/.local/state/omarchy/monitor-workspaces")
    if not os.path.exists(path):
        return 0
    lines = [l for l in open(path).read().splitlines() if l.strip()]
    keep = [l for l in lines if not l.split("\t")[-1].startswith("HEADLESS-")]
    removed = len(lines) - len(keep)
    if removed:
        with open(path + ".omagnet-backup", "w") as f:
            f.write("\n".join(lines) + "\n")
        with open(path, "w") as f:
            f.write("\n".join(keep) + "\n")
        subprocess.run(["hyprctl", "reload"], capture_output=True)
        time.sleep(2.5)
    return removed
