#!/usr/bin/env python3
"""Talks to a VIA keyboard (NuPhy Air96 V2) over its raw HID interface, for the KEYBOARD tab.
  nuphy-via.py get                       -> one line of JSON with the backlight values
  nuphy-via.py set CHANNEL VALUE [B...]  -> sets one value (numbers, decimal)
  nuphy-via.py save CHANNEL              -> stores the channel's values on the keyboard
Works on the cable only. The packets are the standard VIA ones: get = 0x08, set = 0x07, save = 0x09,
channel 3 = the RGB matrix (backlight): value 1 brightness, 2 effect, 3 speed, 4 hue and saturation."""
import glob, json, os, select, sys

VID, PID = "000019F5", "00003265"      # lsusb: 19f5:3265
RGB = 3                                # VIA channel of the RGB matrix


def find_raw_hid():
    for node in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        dev = os.path.join(node, "device")
        try:
            uevent = open(os.path.join(dev, "uevent")).read().upper()
            desc = open(os.path.join(dev, "report_descriptor"), "rb").read()
        except OSError:
            continue
        if VID in uevent and PID in uevent and b"\x06\x60\xff" in desc:     # usage page 0xFF60 = VIA raw HID
            return "/dev/" + os.path.basename(node)
    return None


def ask(fd, *payload):
    os.write(fd, bytes([0x00]) + bytes(payload) + bytes(32 - len(payload)))
    ready, _, _ = select.select([fd], [], [], 1.0)
    if not ready:
        raise TimeoutError("NO ANSWER FROM THE KEYBOARD")
    return os.read(fd, 64)[:32]


def say(**kw):
    print(json.dumps(kw))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    path = find_raw_hid()
    if not path:
        return say(connected=False, error="KEYBOARD NOT FOUND. USE CABLE MODE.")
    try:
        fd = os.open(path, os.O_RDWR)
    except PermissionError:
        return say(connected=False, error="NO PERMISSION FOR " + path.upper() + ". REPLUG THE KEYBOARD.")
    try:
        cmd = sys.argv[1]
        if cmd == "get":
            got = {}
            for name, value in (("brightness", 1), ("effect", 2), ("speed", 3), ("color", 4)):
                reply = ask(fd, 0x08, RGB, value)
                if reply[0] != 0x08:
                    return say(connected=True, error="BACKLIGHT NOT ANSWERED")
                got[name] = (reply[3], reply[4]) if name == "color" else reply[3]
            say(connected=True, rgb=dict(brightness=got["brightness"], effect=got["effect"], speed=got["speed"],
                                         hue=got["color"][0], sat=got["color"][1]))
        elif cmd == "set":
            channel, value, *data = [int(a) for a in sys.argv[2:]]
            ask(fd, 0x07, channel, value, *data)
            say(connected=True)
        elif cmd == "save":
            ask(fd, 0x09, int(sys.argv[2]))
            say(connected=True)
        else:
            sys.exit(__doc__)
    except (TimeoutError, OSError) as e:
        say(connected=False, error=str(e).upper())
    finally:
        os.close(fd)


main()
