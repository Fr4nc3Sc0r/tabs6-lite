import socket, os, sys, re
p = sys.argv[1]
os.makedirs(os.path.dirname(p), exist_ok=True)
try: os.unlink(p)
except FileNotFoundError: pass
s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM); s.bind(p); os.chmod(p, 0o666); s.settimeout(float(sys.argv[2]))
out = open(sys.argv[3], "wb")
try:
    while True:
        d = s.recv(65536)
        # android_log_header_t (11 bytes) + prio + tag\0 + msg\0
        body = d[11:]
        prio = body[0] if body else 0
        parts = body[1:].split(b"\0")
        out.write(b"%s %s: %s\n" % (b"?VDIWEF"[prio:prio+1] if prio < 8 else b"?", parts[0], b" ".join(parts[1:])[:2000])); out.flush()
except socket.timeout:
    pass
