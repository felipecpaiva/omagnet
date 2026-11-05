"""A virtual keyboard and mouse made through /dev/uinput, so Hyprland sees real input events (wtype's
modifiers do not trigger binds). Needs write access to /dev/uinput. Standard library only.
Usage as a module:  with Keyboard() as kb: kb.tap("ctrl+alt+left")
                    with Mouse() as m: m.press(); m.move(-3000, 0); m.release()
"""
import fcntl, os, struct, time

EV_SYN, EV_KEY = 0, 1
UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_RELBIT, UI_DEV_SETUP = 0x40045564, 0x40045565, 0x40045566, 0x405C5503
EV_REL, REL_X, REL_Y, BTN_LEFT = 2, 0, 1, 0x110
UI_DEV_CREATE, UI_DEV_DESTROY = 0x5501, 0x5502

KEYS = {
    "ctrl": 29, "alt": 56, "shift": 42, "super": 125,
    "left": 105, "right": 106, "up": 103, "down": 108, "return": 28, "backspace": 14, "tab": 15,
    "a": 30, "c": 46, "d": 32, "e": 18, "f": 33, "g": 34, "i": 23, "j": 36, "k": 37, "t": 20, "u": 22,
    "f9": 67, "escape": 1,
}


class Keyboard:
    def __enter__(self):
        self.fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
        fcntl.ioctl(self.fd, UI_SET_EVBIT, EV_KEY)
        for code in KEYS.values():
            fcntl.ioctl(self.fd, UI_SET_KEYBIT, code)
        name = b"omagnet-test-keyboard".ljust(80, b"\0")
        fcntl.ioctl(self.fd, UI_DEV_SETUP, struct.pack("<HHHH80sI", 0x03, 0x1234, 0x5678, 1, name, 0))
        fcntl.ioctl(self.fd, UI_DEV_CREATE)
        time.sleep(0.8)  # let the compositor pick the new device up
        return self

    def __exit__(self, *exc):
        fcntl.ioctl(self.fd, UI_DEV_DESTROY)
        os.close(self.fd)

    def _emit(self, type_, code, value):
        os.write(self.fd, struct.pack("<qqHHi", 0, 0, type_, code, value))

    def _sync(self):
        self._emit(EV_SYN, 0, 0)

    def tap(self, combo, hold=0.05):
        """Press the modifiers, tap the last key, release in reverse. combo like 'ctrl+alt+left'."""
        codes = [KEYS[p] for p in combo.lower().split("+")]
        for c in codes:
            self._emit(EV_KEY, c, 1); self._sync(); time.sleep(0.02)
        time.sleep(hold)
        for c in reversed(codes):
            self._emit(EV_KEY, c, 0); self._sync(); time.sleep(0.02)

    def down(self, key):
        self._emit(EV_KEY, KEYS[key.lower()], 1); self._sync(); time.sleep(0.05)

    def up(self, key):
        self._emit(EV_KEY, KEYS[key.lower()], 0); self._sync(); time.sleep(0.05)


class Mouse:
    """A relative mouse with one button. A huge move (for example -3000) pushes the pointer to the screen
    edge, which is how the tests reach edges and corners without depending on pointer acceleration."""

    def __enter__(self):
        self.fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
        fcntl.ioctl(self.fd, UI_SET_EVBIT, EV_KEY)
        fcntl.ioctl(self.fd, UI_SET_KEYBIT, BTN_LEFT)
        fcntl.ioctl(self.fd, UI_SET_EVBIT, EV_REL)
        fcntl.ioctl(self.fd, UI_SET_RELBIT, REL_X)
        fcntl.ioctl(self.fd, UI_SET_RELBIT, REL_Y)
        name = b"omagnet-test-mouse".ljust(80, b"\0")
        fcntl.ioctl(self.fd, UI_DEV_SETUP, struct.pack("<HHHH80sI", 0x03, 0x1234, 0x5679, 1, name, 0))
        fcntl.ioctl(self.fd, UI_DEV_CREATE)
        time.sleep(0.8)
        return self

    def __exit__(self, *exc):
        fcntl.ioctl(self.fd, UI_DEV_DESTROY)
        os.close(self.fd)

    def _emit(self, type_, code, value):
        os.write(self.fd, struct.pack("<qqHHi", 0, 0, type_, code, value))

    def _sync(self):
        self._emit(EV_SYN, 0, 0)

    def press(self):
        self._emit(EV_KEY, BTN_LEFT, 1); self._sync(); time.sleep(0.05)

    def release(self):
        self._emit(EV_KEY, BTN_LEFT, 0); self._sync(); time.sleep(0.05)

    def move(self, dx, dy, steps=20, pause=0.01):
        """Move in small steps, like a hand, so the compositor sees a drag and not a jump."""
        for i in range(1, steps + 1):
            self._emit(EV_REL, REL_X, int(dx * i / steps) - int(dx * (i - 1) / steps))
            self._emit(EV_REL, REL_Y, int(dy * i / steps) - int(dy * (i - 1) / steps))
            self._sync(); time.sleep(pause)

