#!/usr/bin/env python3
"""Tiny input bridge: the app connects to 127.0.0.1:7788 and sends one command per line.
  m X Y        absolute pointer move
  r DX DY      relative pointer move
  b N 1|0      mouse button N down/up (1 left, 2 middle, 3 right, 4/5 wheel)
  k NAME 1|0   key down/up by X keysym name (e.g. a, Return, Escape, Shift_L, F5)
  t TEXT       type text
"""
import socket, threading, time
from Xlib import X, XK, display
from Xlib.ext import xtest

d = None
for _ in range(50):
    try:
        d = display.Display(':1'); break
    except Exception:
        time.sleep(0.2)
if d is None:
    raise SystemExit('no X display')
lock = threading.Lock()
root = d.screen().root
SHIFTED = {'~':'`','!':'1','@':'2','#':'3','$':'4','%':'5','^':'6','&':'7','*':'8','(':'9',')':'0','_':'-','+':'=',
           '{':'[','}':']','|':'\\',':':';','"':"'",'<':',','>':'.','?':'/'}

def keycode(name):
    ks = XK.string_to_keysym(name)
    if ks == 0 and len(name) == 1:
        ks = ord(name)
    return d.keysym_to_keycode(ks) if ks else 0

def key(name, down):
    kc = keycode(name)
    if kc:
        xtest.fake_input(d, X.KeyPress if down else X.KeyRelease, kc)

def type_char(ch):
    names = {' ':'space','\n':'Return','\t':'Tab','\b':'BackSpace'}
    if ch in names:
        key(names[ch], 1); key(names[ch], 0); return
    shift = ch.isupper() or ch in SHIFTED
    base = SHIFTED.get(ch, ch.lower())
    if shift: key('Shift_L', 1)
    key(base, 1); key(base, 0)
    if shift: key('Shift_L', 0)

def handle(line):
    p = line.split(' ', 2)
    c = p[0]
    if c == 'm':
        xtest.fake_input(d, X.MotionNotify, x=int(float(p[1])), y=int(float(p[2])))
    elif c == 'r':
        xtest.fake_input(d, X.MotionNotify, detail=1, x=int(float(p[1])), y=int(float(p[2])))
    elif c == 'b':
        xtest.fake_input(d, X.ButtonPress if p[2] == '1' else X.ButtonRelease, int(p[1]))
    elif c == 'k':
        key(p[1], p[2] == '1')
    elif c == 't':
        for ch in (p[1] if len(p) == 2 else p[1] + ' ' + p[2]):
            type_char(ch)
    d.sync()

def client(conn):
    buf = b''
    with conn:
        while True:
            data = conn.recv(4096)
            if not data: return
            buf += data
            while b'\n' in buf:
                line, buf = buf.split(b'\n', 1)
                line = line.decode('utf-8', 'ignore').strip('\r')
                if not line: continue
                try:
                    with lock: handle(line)
                except Exception as e:
                    print('input error:', line, e, flush=True)

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('127.0.0.1', 7788)); srv.listen(4)
print('input daemon ready', flush=True)
while True:
    c, _ = srv.accept()
    c.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    threading.Thread(target=client, args=(c,), daemon=True).start()
