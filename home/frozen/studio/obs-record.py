#!/usr/bin/env python3
# Talks to OBS Studio's built-in WebSocket server (Tools > WebSocket Server Settings in OBS).
#   studio-obs watch    prints "recording", "idle" or "off" (OBS not reachable) whenever that changes
#   studio-obs stop     stops OBS's recording
# Only the local machine, no password: untick "Enable Authentication" in OBS. Port is set below.
import base64, json, os, socket, struct, sys, time

HOST, PORT = "127.0.0.1", 4455      # edit here: must match OBS's WebSocket Server Settings
RETRY = 5                           # seconds between tries while OBS is closed
OUTPUT_EVENTS = 1 << 6              # the "Outputs" event group, where RecordStateChanged lives


def read_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("closed")
        buf += chunk
    return buf


def send_frame(sock, opcode, data):
    n = len(data)
    head = bytes([0x80 | opcode])
    if n < 126:
        head += bytes([0x80 | n])
    elif n < 65536:
        head += bytes([0x80 | 126]) + struct.pack(">H", n)
    else:
        head += bytes([0x80 | 127]) + struct.pack(">Q", n)
    mask = os.urandom(4)
    sock.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))


def recv_message(sock):
    # one text message; answers pings, raises when the server closes
    while True:
        b1, b2 = read_exact(sock, 2)
        opcode, n = b1 & 0x0F, b2 & 0x7F
        if n == 126:
            n = struct.unpack(">H", read_exact(sock, 2))[0]
        elif n == 127:
            n = struct.unpack(">Q", read_exact(sock, 8))[0]
        data = read_exact(sock, n)
        if opcode == 0x8:
            raise ConnectionError("closed")
        if opcode == 0x9:
            send_frame(sock, 0xA, data)
            continue
        if opcode in (0x1, 0x0):
            return json.loads(data.decode())


def send_json(sock, obj):
    send_frame(sock, 0x1, json.dumps(obj).encode())


def connect():
    sock = socket.create_connection((HOST, PORT), timeout=3)
    key = base64.b64encode(os.urandom(16)).decode()
    sock.sendall((
        "GET / HTTP/1.1\r\nHost: %s:%d\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
        "Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n"
        "Sec-WebSocket-Protocol: obswebsocket.json\r\n\r\n" % (HOST, PORT, key)).encode())
    head = b""
    while b"\r\n\r\n" not in head:
        head += read_exact(sock, 1)
    if b" 101 " not in head.split(b"\r\n")[0]:
        raise ConnectionError("no websocket")
    hello = recv_message(sock)
    if hello["d"].get("authentication"):
        raise PermissionError("OBS asks for a password: untick Enable Authentication in its WebSocket settings")
    send_json(sock, {"op": 1, "d": {"rpcVersion": 1, "eventSubscriptions": OUTPUT_EVENTS}})
    recv_message(sock)                      # Identified
    sock.settimeout(None)
    return sock


def request(sock, kind):
    send_json(sock, {"op": 6, "d": {"requestType": kind, "requestId": kind}})
    while True:
        msg = recv_message(sock)
        if msg["op"] == 7 and msg["d"]["requestId"] == kind:
            return msg["d"]


def say(state):
    print(state, flush=True)


def watch():
    last = None
    while True:
        try:
            sock = connect()
            status = request(sock, "GetRecordStatus")["responseData"]["outputActive"]
            last = "recording" if status else "idle"
            say(last)
            while True:
                msg = recv_message(sock)
                if msg["op"] == 5 and msg["d"]["eventType"] == "RecordStateChanged":
                    last = "recording" if msg["d"]["eventData"]["outputActive"] else "idle"
                    say(last)
        except PermissionError as e:
            print(e, file=sys.stderr, flush=True)
        except (OSError, ConnectionError, ValueError, KeyError):
            pass
        if last != "off":
            last = "off"
            say("off")
        time.sleep(RETRY)


def stop():
    try:
        res = request(connect(), "StopRecord")
    except (OSError, ConnectionError, ValueError, PermissionError) as e:
        sys.exit("cannot reach OBS: %s" % e)
    if not res["requestStatus"]["result"]:
        sys.exit(res["requestStatus"].get("comment", "OBS refused"))


if __name__ == "__main__":
    {"watch": watch, "stop": stop}.get(sys.argv[1] if len(sys.argv) > 1 else "", lambda: sys.exit(__doc__))()
