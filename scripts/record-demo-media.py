#!/usr/bin/env python3
"""Record the website/release demo media from real ElmTUI example sessions.

Each scenario starts a private Xvfb display, opens urxvt attached to a private
tmux server, runs a maintained example through scripts/examples.sh, drives it
with scripted keys and captures the terminal window with ffmpeg.

    scripts/record-demo-media.py                # all scenarios -> website/assets/
    scripts/record-demo-media.py tetris glider  # selected scenarios
    scripts/record-demo-media.py --out DIR hero

Scenarios and outputs:
    workbench  workbench.gif           Workbench REPL, completion, inspector
    hero       workbench-hero.webp     Workbench still (completion + inspector)
    tetris     neon-tetris.gif         neon-tetris clearing lines
    glider     tmux-glider.gif         Conway glider over live tmux pane text
    slider     terminal-slider.gif     tmux slider: reverse, speed, pause

Requires: Xvfb, urxvt (rxvt-unicode), xdotool, tmux, ffmpeg (x11grab, libwebp)
and the DejaVu Sans Mono font. Nothing outside the private display, tmux
server and a temporary work directory is touched.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DISPLAY = ':77'
WORK = Path()  # per-run temporary directory, set by main()


def sh(*args, **kw):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kw)


class Session:
    """A private tmux server whose single pane runs an interactive bash."""

    def __init__(self, name, cols, rows):
        self.dir = WORK / name
        self.dir.mkdir(parents=True, exist_ok=True)
        # Unix socket paths are limited to ~108 bytes; keep this one short.
        self.sock = f'/tmp/elmtui-demo-{os.getpid()}-{name}.sock'
        self.cols, self.rows = cols, rows
        launch = self.dir / 'launch.sh'
        launch.write_text(
            '#!/bin/bash\ntrap : INT\ncd ' + shlex.quote(str(ROOT)) + '\n'
            'export PS1="\\[\\e[1;35m\\]elmtui\\[\\e[0m\\] \\[\\e[36m\\]~/code\\[\\e[0m\\] $ "\n'
            'clear\nexec bash --norc -i\n')
        self.tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'rec', '-x', str(cols),
                  '-y', str(rows), 'bash ' + shlex.quote(str(launch)))
        self.tmux('set-option', '-g', 'status', 'off')
        self.tmux('set-option', '-g', 'default-terminal', 'tmux-256color')
        self.tmux('set-option', '-ga', 'terminal-overrides', ',rxvt-unicode*:Tc')
        self.tmux('set-option', '-g', 'history-limit', '5000')

    def tmux(self, *args):
        return subprocess.run(['tmux', '-S', self.sock, *args], capture_output=True, text=True)

    def screen(self):
        return self.tmux('capture-pane', '-p', '-t', 'rec:0.0').stdout

    def wait(self, text, timeout=120):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if text in self.screen():
                return
            time.sleep(.1)
        raise SystemExit(f'timeout waiting for {text!r}:\n{self.screen()}')

    def keys(self, *keys, literal=False):
        self.tmux('send-keys', '-t', 'rec:0.0', *(['-l'] if literal else []), *keys)

    def type(self, text, delay=.06):
        for ch in text:
            self.keys(ch, literal=True)
            time.sleep(delay)

    def close(self):
        self.tmux('kill-server')
        Path(self.sock).unlink(missing_ok=True)


def start_x():
    xvfb = subprocess.Popen(['Xvfb', DISPLAY, '-screen', '0', '1920x1200x24', '-nolisten', 'tcp'],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1)
    if xvfb.poll() is not None:
        raise SystemExit(f'Xvfb could not start on {DISPLAY}')
    return xvfb


def open_terminal(session, font_size):
    """Open urxvt attached to SESSION; return it and its window geometry."""
    env = dict(os.environ, DISPLAY=DISPLAY)
    env.pop('TMUX', None)
    title = 'elmtui-demo-' + session.dir.name
    errors = session.dir / 'urxvt.err'
    term = subprocess.Popen(
        ['urxvt', '-title', title, '-geometry', f'{session.cols}x{session.rows}+0+0',
         '-fn', f'xft:DejaVu Sans Mono:size={font_size}', '-bg', '#0b0d1a', '-fg', '#d8dcf0',
         '+sb', '-b', '0', '-bl', '-cr', '#ff6ec7',
         '-e', 'tmux', '-S', session.sock, 'attach', '-t', 'rec'],
        env=env, stdout=subprocess.DEVNULL, stderr=errors.open('w'))
    for _ in range(100):
        found = subprocess.run(['xdotool', 'search', '--name', '^' + title + '$'],
                               env=env, capture_output=True, text=True)
        if found.returncode == 0:
            window = found.stdout.split()[0]
            break
        time.sleep(.1)
    else:
        raise SystemExit('terminal window did not appear: ' + errors.read_text())
    time.sleep(.8)
    geometry = sh('xdotool', 'getwindowgeometry', '--shell', window, env=env).stdout
    g = dict(line.split('=') for line in geometry.split())
    # Even dimensions keep the video encoders happy.
    return term, int(g['X']), int(g['Y']), int(g['WIDTH']) // 2 * 2, int(g['HEIGHT']) // 2 * 2


def grab_args(x, y, w, h, framerate=None):
    rate = ['-framerate', str(framerate)] if framerate else []
    return ['-f', 'x11grab', '-draw_mouse', '0', *rate, '-video_size', f'{w}x{h}',
            '-i', f'{DISPLAY}+{x},{y}']


def to_gif(raw, out, width=None, fps=12):
    scale = f',scale={width}:-1:flags=lanczos' if width else ''
    sh('ffmpeg', '-y', '-loglevel', 'error', '-i', str(raw), '-vf',
       f'fps={fps}{scale},split[a][b];[a]palettegen=max_colors=192:stats_mode=diff[p];'
       '[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle',
       '-loop', '0', str(out))


# --- neon-tetris placement planner -------------------------------------------
# neon-tetris spawns a fixed O, I, T, L cycle at x=4 in a 10x16 well, so a
# placement sequence that clears lines can be computed ahead of time.

WELL_W, WELL_H = 10, 16
PIECES = {
    (0, 0): [(0, 0), (1, 0), (0, 1), (1, 1)],
    (1, 0): [(1, 0), (1, 1), (1, 2), (1, 3)], (1, 1): [(0, 1), (1, 1), (2, 1), (3, 1)],
    (2, 0): [(1, 0), (0, 1), (1, 1), (2, 1)], (2, 1): [(1, 0), (0, 1), (1, 1), (1, 2)],
    (3, 0): [(0, 0), (0, 1), (1, 1), (2, 1)], (3, 1): [(0, 0), (0, 1), (0, 2), (1, 2)],
}


def _collides(well, shape, rot, x, y):
    for dx, dy in PIECES[shape, rot]:
        cx, cy = x + dx, y + dy
        if cx < 0 or cx >= WELL_W or cy >= WELL_H or (cy >= 0 and well[cy][cx]):
            return True
    return False


def _drop(well, shape, rot, x):
    if _collides(well, shape, rot, x, 0):
        return None
    y = 0
    while not _collides(well, shape, rot, x, y + 1):
        y += 1
    placed = [row[:] for row in well]
    for dx, dy in PIECES[shape, rot]:
        placed[y + dy][x + dx] = 1
    kept = [row for row in placed if not all(row)]
    cleared = WELL_H - len(kept)
    return [[0] * WELL_W for _ in range(cleared)] + kept, cleared


def _score(well, lines):
    heights = [next((WELL_H - r for r in range(WELL_H) if well[r][c]), 0) for c in range(WELL_W)]
    holes = sum(1 for c in range(WELL_W) for r in range(WELL_H)
                if not well[r][c] and any(well[k][c] for k in range(r)))
    bumps = sum(abs(heights[i] - heights[i + 1]) for i in range(WELL_W - 1))
    return lines * 100 - holes * 40 - max(heights) * 3 - bumps * 2


def plan_tetris(pieces=20, beam_width=400):
    """Return [(rotation, x), ...] for the first PIECES pieces."""
    beam = [([[0] * WELL_W for _ in range(WELL_H)], 0, [])]
    for i in range(pieces):
        shape = i % 4
        candidates = []
        for well, lines, moves in beam:
            for rot in ((0, 1) if shape else (0,)):
                if _collides(well, shape, rot, 4, 0):
                    continue
                for x in range(-1, WELL_W):
                    result = _drop(well, shape, rot, x)
                    if result:
                        candidates.append((result[0], lines + result[1], moves + [(rot, x)]))
        candidates.sort(key=lambda c: _score(c[0], c[1]), reverse=True)
        beam = candidates[:beam_width]
    return beam[0][2]


# --- scenarios ----------------------------------------------------------------
# Each scenario is a generator: setup before the first yield is not recorded.
# A scenario that yields 'still' produces a single frame at that point.

BACKDROP = ('clear; git log --oneline --graph --decorate --color=always -{n} | cut -c1-{c}; '
            'echo; ls --color=always -C -w {w} --hide=\\*.fasl examples | head -{h}')


def tetris(s):
    plan = plan_tetris()
    s.keys('scripts/examples.sh run neon-tetris', 'Enter')
    s.wait('QUIT')
    time.sleep(.8)
    yield
    shape_shown = lambda: (re.search(r'SHAPE (\d)', s.screen()) or [None, None])[1]
    for i, (rot, x) in enumerate(plan):
        deadline = time.monotonic() + 10
        while shape_shown() != str(i % 4) and time.monotonic() < deadline:
            time.sleep(.02)
        time.sleep(.12)
        if rot:
            s.keys('w', literal=True)
            time.sleep(.12)
        for _ in range(abs(x - 4)):
            s.keys('d' if x > 4 else 'a', literal=True)
            time.sleep(.1)
        time.sleep(.15)
        while shape_shown() == str(i % 4) and time.monotonic() < deadline:
            s.keys('s', literal=True)
            time.sleep(.07)
    time.sleep(2.5)
    s.keys('q', literal=True)
    time.sleep(1.2)


def glider(s):
    s.keys(BACKDROP.format(n=14, c=110, w=118, h=12), 'Enter')
    time.sleep(1.5)
    s.keys('scripts/examples.sh run tmux-glider', 'Enter')
    time.sleep(.3)
    typed = s.screen()
    deadline = time.monotonic() + 60
    while s.screen() == typed and time.monotonic() < deadline:
        time.sleep(.05)
    yield
    time.sleep(18)
    s.keys('q', literal=True)
    time.sleep(1.5)


def slider(s):
    s.keys(BACKDROP.format(n=9, c=100, w=108, h=6), 'Enter')
    time.sleep(1.5)
    s.keys('scripts/examples.sh run tmux-slider', 'Enter')
    s.wait('CYAN SHIFT')
    yield
    time.sleep(3)
    s.keys('Left'); time.sleep(2.2)
    s.keys('Up'); s.keys('Up'); time.sleep(2)
    s.keys('Space'); time.sleep(1.2)
    s.keys('Space'); s.keys('Right'); time.sleep(2)
    s.keys('q', literal=True); time.sleep(1)


def workbench(s):
    s.keys('scripts/examples.sh run repl', 'Enter')
    s.wait('Lisp Workbench')
    time.sleep(1)
    yield

    def submit(form, pause=1.4):
        s.type(form); time.sleep(.4); s.keys('Enter'); time.sleep(pause)
    submit('(defun square (x) (* x x))')
    submit("(mapcar #'square '(1 2 3 4 5))")
    s.type('(string-up'); time.sleep(.3)
    s.keys('C-Space'); time.sleep(2.2)
    s.keys('Tab'); time.sleep(.7)
    submit(' "hello, elmtui")')
    s.keys('F2'); time.sleep(1)
    for _ in range(3):
        s.keys('Down'); time.sleep(.45)
    s.keys('Enter'); time.sleep(1.2)
    for _ in range(4):
        s.keys('Down'); time.sleep(.35)
    time.sleep(1)
    s.keys('Escape'); time.sleep(.8)
    submit('(loop for i below 8 collect (expt 2 i))', 2.2)
    s.keys('C-d'); time.sleep(1.5)


def hero(s):
    s.keys('scripts/examples.sh run repl', 'Enter')
    s.wait('Lisp Workbench')
    time.sleep(1)

    def submit(form):
        s.type(form, .01); s.keys('Enter'); time.sleep(.8)
    submit('(defun square (x) (* x x))')
    submit("(mapcar #'square '(1 2 3 4 5))")
    submit('(string-upcase "hello, elmtui")')
    submit('(loop for i below 8 collect (expt 2 i))')
    s.keys('F2'); time.sleep(.6)
    for _ in range(3):
        s.keys('Down'); time.sleep(.2)
    s.keys('Enter'); time.sleep(.8)
    s.keys('Escape'); time.sleep(.5)
    s.type('(string-', .01); s.keys('C-Space'); time.sleep(1.5)
    yield 'still'
    s.keys('Escape'); s.keys('C-d'); time.sleep(1)


# name: (scenario, output file, columns, rows, font size, GIF width or None)
SCENARIOS = {
    'workbench': (workbench, 'workbench.gif', 120, 30, 11, 960),
    'hero': (hero, 'workbench-hero.webp', 120, 36, 15, None),
    'tetris': (tetris, 'neon-tetris.gif', 84, 26, 12, None),
    'glider': (glider, 'tmux-glider.gif', 120, 32, 11, 960),
    'slider': (slider, 'terminal-slider.gif', 112, 18, 11, 896),
}


def record(name, out_dir):
    scenario, filename, cols, rows, font, width = SCENARIOS[name]
    out = out_dir / filename
    xvfb = start_x()
    session = Session(name, cols, rows)
    term = None
    try:
        term, x, y, w, h = open_terminal(session, font)
        steps = scenario(session)
        mode = next(steps)
        if mode == 'still':
            sh('ffmpeg', '-y', '-loglevel', 'error', *grab_args(x, y, w, h), '-frames:v', '1',
               *(['-c:v', 'libwebp', '-lossless', '1'] if out.suffix == '.webp' else []), str(out))
            for _ in steps:
                pass
        else:
            raw = session.dir / 'raw.mkv'
            ffmpeg = subprocess.Popen(
                ['ffmpeg', '-y', '-loglevel', 'error', *grab_args(x, y, w, h, 20),
                 '-c:v', 'libx264rgb', '-crf', '0',
                 '-preset', 'ultrafast', str(raw)], stdin=subprocess.PIPE)
            time.sleep(.5)
            for _ in steps:
                pass
            ffmpeg.communicate(b'q', timeout=30)
            to_gif(raw, out, width=width)
        print(f'{out.relative_to(ROOT) if out.is_relative_to(ROOT) else out}: '
              f'{out.stat().st_size // 1024} KiB from a {w}x{h} terminal')
    finally:
        session.close()
        if term:
            term.terminate()
        xvfb.terminate()
        xvfb.wait(timeout=10)  # release the display before the next scenario


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('scenarios', nargs='*', metavar='SCENARIO',
                        help='one of ' + ', '.join(SCENARIOS) + ' (default: all)')
    parser.add_argument('--out', type=Path, default=ROOT / 'website/assets',
                        help='output directory (default: website/assets)')
    parser.add_argument('--plan-tetris', action='store_true',
                        help='print the planned neon-tetris placements and exit')
    args = parser.parse_args()
    unknown = [name for name in args.scenarios if name not in SCENARIOS]
    if unknown:
        parser.error('unknown scenario: ' + ', '.join(unknown))
    if args.plan_tetris:
        print(json.dumps(plan_tetris()))
        return
    args.out.mkdir(parents=True, exist_ok=True)
    global WORK
    with tempfile.TemporaryDirectory(prefix='elmtui-demo-media-') as work:
        WORK = Path(work)
        for name in args.scenarios or SCENARIOS:
            record(name, args.out.resolve())


if __name__ == '__main__':
    sys.exit(main())
