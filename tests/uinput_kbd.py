"""A virtual keyboard made through /dev/uinput, so Hyprland sees real key events (wtype's modifiers
do not trigger binds). Needs write access to /dev/uinput. Standard library only.
Usage as a module:  with Keyboard() as kb: kb.tap("ctrl+alt+left")
"""
import fcntl, os, struct, time

EV_SYN, EV_KEY = 0, 1
UI_SET_EVBIT, UI_SET_KEYBIT, UI_DEV_SETUP = 0x40045564, 0x40045565, 0x405C5503
UI_DEV_CREATE, UI_DEV_DESTROY = 0x5501, 0x5502

KEYS = {
    "ctrl": 29, "alt": 56, "shift": 42, "super": 125,
    "left": 105, "right": 106, "up": 103, "down": 108, "return": 28, "backspace": 14, "tab": 15,
    "a": 30, "c": 46, "d": 32, "e": 18, "f": 33, "g": 34, "i": 23, "j": 36, "k": 37, "t": 20, "u": 22,
    "f9": 67,
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
