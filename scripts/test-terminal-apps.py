#!/usr/bin/env python3
"""Black-box application tests through private tmux PTYs or urxvt/Xvfb.

No Lisp functions are mocked. Every scenario starts a fresh CLPM/SBCL process.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
OPTIONS = None


class TerminalApp:
    def __init__(self, name, expression, source=None, environment=None, prelude='', use_launcher=True):
        self.directory = OPTIONS.output / (name + '-' + uuid.uuid4().hex[:8])
        self.directory.mkdir(parents=True)
        self.socket = str(Path(tempfile.gettempdir()) /
                          ('elmtui-' + uuid.uuid4().hex[:16] + '.sock'))
        self.window = None
        self.emulator = None
        self.frames = []
        self.expression = expression
        self.name = name
        self.source = source
        self.environment = environment or {}
        self.prelude = prelude
        self.use_launcher = use_launcher

    def tmux(self, *args, check=True):
        return subprocess.run(['tmux', '-S', self.socket, *args], check=check,
                              text=True, capture_output=True, timeout=10)

    def start(self):
        command = ['clpm', 'bundle', 'exec', '--with-client', 'sbcl', '--',
                   '--noinform', '--non-interactive', '--no-sysinit', '--no-userinit', '--eval', '(require :asdf)',
                   '--eval', '(setf *compile-verbose* nil *load-verbose* nil)',
                   '--eval', '(asdf:load-system "elmtui")']
        if self.source:
            command.extend(['--load', str(ROOT / 'examples' / self.source)])
        else:
            command.extend(['--eval', '(asdf:load-system "elmtui-examples")'])
        command.extend(['--eval', self.expression])
        if self.source == 'wifi-menu.lisp' and self.use_launcher:
            command = [str(ROOT / 'scripts/examples.sh'), 'run', 'wifi-menu']
        elif self.use_launcher and self.name in {
                'minimal', 'focus', 'keymap', 'scroll', 'life'}:
            example = {'minimal': 'minimal-app', 'focus': 'focus-simple',
                       'keymap': 'keymap-app', 'scroll': 'scroll-panel-demo',
                       'life': 'game-of-life'}[self.name]
            command = [str(ROOT / 'scripts/examples.sh'), 'run', example]
        # Capture errors separately: log strings must never satisfy screen checks.
        script = self.directory / 'launch.sh'
        script.write_text('#!/bin/sh\ncd ' + shlex.quote(str(ROOT)) + '\n'
                          + ''.join('export ' + name + '=' + shlex.quote(value) + '\n'
                                    for name, value in self.environment.items())
                          + 'stty -g > ' + shlex.quote(str(self.directory / 'before.stty')) + '\n'
                          + self.prelude + '\n'
                          + shlex.join(command) + ' 2>' + shlex.quote(str(self.directory / 'stderr.txt')) + '\n'
                          'status=$?\nstty -g > ' + shlex.quote(str(self.directory / 'after.stty')) + '\n'
                          'printf "%s\\n" "$status" > ' + shlex.quote(str(self.directory / 'exit-code')) + '\n'
                          'printf "ELMTUI_E2E_SHELL_RESTORED"\nsleep 300\n')
        self.tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'app',
                  '-x', '100', '-y', '35', 'sh ' + shlex.quote(str(script)))
        self.tmux('set-option', '-g', 'status', 'off')
        self.tmux('set-option', '-g', 'history-limit', '10000')
        self.tmux('pipe-pane', '-t', 'app:0.0',
                  'cat > ' + shlex.quote(str(self.directory / 'terminal.raw')))
        if OPTIONS.terminal == 'urxvt':
            title = 'elmtui-e2e-' + self.directory.name
            self.emulator = subprocess.Popen(
                ['urxvt', '-name', title, '-title', title, '-geometry', '100x35',
                 '-e', 'tmux', '-S', self.socket, 'attach-session', '-t', 'app'],
                stdout=subprocess.DEVNULL,
                stderr=(self.directory / 'urxvt.stderr').open('w'))
            deadline = time.monotonic() + OPTIONS.timeout
            while time.monotonic() < deadline:
                result = subprocess.run(['xdotool', 'search', '--name', '^' + title + '$'],
                                        capture_output=True, text=True)
                if result.returncode == 0:
                    self.window = result.stdout.splitlines()[0]
                    break
                time.sleep(.1)
            if self.window is None:
                raise AssertionError('urxvt window did not appear')
            subprocess.run(['xdotool', 'windowfocus', '--sync', self.window],
                           check=True, capture_output=True, timeout=10)
        return self

    def screen(self):
        return self.tmux('capture-pane', '-p', '-t', 'app:0.0').stdout

    def wait(self, predicate, description):
        deadline = time.monotonic() + OPTIONS.timeout
        while time.monotonic() < deadline:
            screen = self.screen()
            if predicate(screen):
                self.frames.append({'assertion': description, 'screen': screen})
                return screen
            if (self.directory / 'exit-code').exists():
                raise AssertionError('App exited before ' + description + '\n' + screen)
            time.sleep(.1)
        raise AssertionError('Timed out waiting for ' + description + '\n' + self.screen())

    def expect(self, text):
        return self.wait(lambda screen: text in screen, 'visible ' + repr(text))

    def key(self, tmux_key, x_key=None, literal=False):
        if self.window:
            subprocess.run(['xdotool', 'key', '--clearmodifiers', '--window', self.window,
                            x_key or tmux_key], check=True, timeout=10)
        else:
            self.tmux('send-keys', '-t', 'app:0.0', *(['-l'] if literal else []), tmux_key)

    def finish(self, key='C-q', x_key='ctrl+q'):
        if key:
            self.key(key, x_key)
        deadline = time.monotonic() + OPTIONS.timeout
        while not (self.directory / 'exit-code').exists():
            if time.monotonic() >= deadline:
                raise AssertionError('App did not exit through its normal input path')
            time.sleep(.1)
        code = (self.directory / 'exit-code').read_text().strip()
        if code != '0':
            raise AssertionError('App exited with status ' + code)
        before = (self.directory / 'before.stty').read_text()
        after = (self.directory / 'after.stty').read_text()
        if before != after:
            raise AssertionError('Terminal termios was not restored\nbefore=' + before + '\nafter=' + after)
        if self.tmux('display-message', '-p', '-t', 'app:0.0', '#{cursor_flag}').stdout.strip() != '1':
            raise AssertionError('Cursor remains hidden after shutdown')
        if 'ELMTUI_E2E_SHELL_RESTORED' not in self.screen():
            raise AssertionError('Shell output is not visible after shutdown')
        errors = (self.directory / 'stderr.txt').read_text(errors='replace')
        if re.search(r'unhandled|fatal error|undefined function|WARNING:', errors, re.I):
            raise AssertionError('Compiler/runtime diagnostic in stderr: ' + errors[-3000:])

    def close(self):
        try:
            (self.directory / 'last-screen.txt').write_text(self.screen())
        except (subprocess.SubprocessError, OSError):
            pass
        (self.directory / 'frames.json').write_text(json.dumps(self.frames, indent=2))
        self.tmux('kill-server', check=False)
        if self.emulator:
            try:
                self.emulator.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.emulator.terminate()
                self.emulator.wait(timeout=5)


class FullTerminalApps(unittest.TestCase):
    def app(self, name, expression, **kwargs):
        app = TerminalApp(name, expression, **kwargs)
        self.addCleanup(app.close)
        return app.start()

    def wifi(self, secure=False, multiple=False):
        fixture = OPTIONS.output / 'nmcli-fixture'
        fixture.mkdir(exist_ok=True)
        stub = fixture / 'nmcli'
        stub.write_text('#!/usr/bin/env python3\nimport json, os, sys\n'
                        'with open(os.environ["ELMTUI_NMCLI_CALLS"], "a") as f: f.write(json.dumps(sys.argv[1:])+"\\n")\n'
                        'if "list" in sys.argv:\n'
                        ' name = "E2E-Secure" if os.environ.get("ELMTUI_WIFI_SECURE") == "1" else "E2E-Guest"\n'
                        ' security = "WPA2" if os.environ.get("ELMTUI_WIFI_SECURE") == "1" else "--"\n'
                        ' print(" :"+name+":11\\\\:22\\\\:33\\\\:44\\\\:55\\\\:66:90:"+security+":wlan0")\n'
                        ' if os.environ.get("ELMTUI_WIFI_MULTIPLE") == "1": print(" :E2E-Second:22\\\\:22\\\\:33\\\\:44\\\\:55\\\\:66:80:"+security+":wlan0")\n'
                        'elif "connect" in sys.argv: print("fixture connected")\n'
                        'else: sys.exit(2)\n')
        stub.chmod(0o755)
        calls = OPTIONS.output / ('nmcli-calls-' + uuid.uuid4().hex + '.jsonl')
        return self.app('wifi', '(elmtui.examples.wifi-menu:run-wifi-menu)',
                        source='wifi-menu.lisp',
                        environment={'PATH': str(fixture) + os.pathsep + os.environ['PATH'],
                                     'ELMTUI_NMCLI_CALLS': str(calls),
                                     'ELMTUI_WIFI_SECURE': '1' if secure else '0',
                                     'ELMTUI_WIFI_MULTIPLE': '1' if multiple else '0'},
                        prelude="printf '\\033[2J\\033[HKEEP-ABOVE\\033[6;9H'"), calls

    def test_wifi_abort_removes_menu_restores_cursor(self):
        app, calls = self.wifi()
        screen = app.expect('E2E-Guest')
        self.assertIn('KEEP-ABOVE', screen.splitlines()[0])
        self.assertNotIn('Wi-Fi', '\n'.join(screen.splitlines()[:6]))
        app.finish('Escape', 'Escape')
        self.assertNotIn('E2E-Guest', app.screen())
        self.assertNotIn('NetworkManager', app.screen())
        self.assertIn('KEEP-ABOVE', app.screen().splitlines()[0])
        self.assertEqual(app.screen().splitlines()[5],
                         '        ELMTUI_E2E_SHELL_RESTORED')
        invocations = [json.loads(line) for line in calls.read_text().splitlines()]
        self.assertTrue(invocations)
        self.assertTrue(all('list' in argv for argv in invocations))

    def test_wifi_confirm_removes_menu(self):
        app, calls = self.wifi()
        app.expect('E2E-Guest')
        app.finish('Enter', 'Return')
        self.assertNotIn('E2E-Guest', app.screen())
        self.assertTrue(any('connect' in json.loads(line) for line in calls.read_text().splitlines()))

    def test_wifi_password_and_selection_have_bounded_latency(self):
        app, calls = self.wifi(secure=True, multiple=True)
        app.expect('E2E-Secure')
        app.expect('E2E-Second')

        def timed_key(key, x_key, predicate, description, literal=False):
            started = time.monotonic()
            app.key(key, x_key, literal=literal)
            app.wait(predicate, description)
            elapsed = time.monotonic() - started
            app.frames[-1]['elapsed_seconds'] = elapsed
            self.assertLess(elapsed, 1.0, description + ' took ' + str(elapsed))

        timed_key('Down', 'Down',
                  lambda screen: any(line.lstrip().startswith('>') and 'E2E-Second' in line
                                     for line in screen.splitlines()), 'selection moved down')
        timed_key('Up', 'Up',
                  lambda screen: any(line.lstrip().startswith('>') and 'E2E-Secure' in line
                                     for line in screen.splitlines()), 'selection moved up')
        timed_key('Enter', 'Return', lambda screen: 'Password:' in screen,
                  'password prompt opened')
        for character, count in [('a', 1), ('b', 2), ('c', 3)]:
            timed_key(character, character,
                      lambda screen, count=count: bool(re.search(
                          r'^ *Password: \*{' + str(count) + r'} *$', screen, re.M)),
                      'password has ' + str(count) + ' masked characters', literal=True)
        timed_key('BSpace', 'BackSpace',
                  lambda screen: bool(re.search(r'^ *Password: \*{2} *$', screen, re.M)),
                  'backspace removed one masked character')
        started = time.monotonic()
        app.finish('Escape', 'Escape')
        elapsed = time.monotonic() - started
        app.frames.append({'assertion': 'password abort restores terminal',
                           'elapsed_seconds': elapsed, 'screen': app.screen()})
        self.assertLess(elapsed, 1.0)
        self.assertNotIn('Password:', app.screen())
        self.assertNotIn('E2E-Secure', app.screen())
        self.assertEqual(app.screen().splitlines()[5],
                         '        ELMTUI_E2E_SHELL_RESTORED')
        self.assertTrue(all('list' in json.loads(line) for line in calls.read_text().splitlines()))

    def test_wifi_startup_frames_do_not_interleave(self):
        # The first scan completes while startup terminal events and the main
        # thread's forced render are active. Repeated boots expose frame races.
        for iteration in range(3):
            app, _calls = self.wifi(secure=True, multiple=True)
            try:
                app.expect('E2E-Secure')
                app.expect('E2E-Second')
                app.key('Enter', 'Return')
                screen = app.expect('Password:')
                self.assertEqual(screen.count('Wi-Fi / NetworkManager'), 1)
                self.assertEqual(screen.count('E2E-Secure'), 1)
                self.assertEqual(screen.count('E2E-Second'), 1)
                self.assertIn('        Wi-Fi / NetworkManager', screen.splitlines())
                self.assertRegex(screen, r'(?m)^ *Password: *$')
                app.frames.append({'assertion': 'startup frame is intact',
                                   'iteration': iteration, 'screen': screen})
                app.finish('Escape', 'Escape')
            finally:
                app.close()

    def test_minimal_input_render_and_shutdown(self):
        app = self.app('minimal', '(elmtui.examples.minimal:run-minimal :platform :terminal)')
        app.expect('Hello slurp')
        app.key('a', 'a', literal=True)
        app.expect('Hello A')
        app.key('b', 'b', literal=True)
        app.expect('Hello B')
        app.finish()

    def test_focus_tab_button_activation(self):
        app = self.app('focus', '(elmtui.examples.focus-simple:run-focus-simple)')
        app.expect('Cancel')
        app.expect('OK')
        app.key('Tab', 'Tab')
        app.key('Enter', 'Return')
        app.finish(key=None)

    def test_counter_keymap_increment_decrement_reset(self):
        app = self.app('keymap', '(elmtui.examples.keymap-app::run-keymap-example-app :platform :terminal)')
        app.expect('Counter [COUNTER-A]: 10')
        app.key('+', 'plus', literal=True)
        app.expect('Counter [COUNTER-A]: 11')
        app.key('-', 'minus', literal=True)
        app.expect('Counter [COUNTER-A]: 10')
        app.key('Enter', 'Return')
        app.expect('Counter [COUNTER-A]: 0')
        app.finish()

    def test_scroll_navigation_and_shutdown(self):
        app = self.app('scroll', '(elmtui.examples.scroll-panel-demo:run-scroll-panel-demo)')
        app.expect('Line 01:')
        app.key('NPage', 'Next')
        app.wait(lambda screen: 'Scroll panel content' in screen and 'Line 01:' not in screen,
                 'page-down moves first line out of viewport')
        app.key('Home', 'Home')
        app.expect('Line 01:')
        app.key('End', 'End')
        app.expect('Line 80:')
        app.finish('q', 'q')

    def test_game_of_life_pause_reset_resume(self):
        app = self.app('life', '(elmtui.examples.game-of-life:run-game-of-life-app :platform :terminal)')
        app.expect('● RUNNING')
        app.key('Space', 'space')
        app.expect('Ⅱ PAUSED')
        app.key('r', 'r', literal=True)
        app.expect('GEN 000 Ⅱ PAUSED')
        app.key('Space', 'space')
        app.expect('● RUNNING')
        app.finish('q', 'q')


def main():
    global OPTIONS
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--terminal', choices=['tmux', 'urxvt'], default='tmux')
    parser.add_argument('--timeout', type=float, default=30)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--case', help='Run only tests whose name contains this string')
    OPTIONS = parser.parse_args()
    required = ['tmux', 'clpm', 'sbcl'] + (['urxvt', 'xdotool', 'xvfb-run'] if OPTIONS.terminal == 'urxvt' else [])
    missing = [name for name in required if not shutil.which(name)]
    if missing:
        parser.error('Required executables missing: ' + ', '.join(missing))
    if OPTIONS.timeout <= 0:
        parser.error('--timeout must be positive')
    if OPTIONS.terminal == 'urxvt' and not os.environ.get('ELMTUI_E2E_PRIVATE_X'):
        # Always use a fresh display, even when the user has a desktop DISPLAY.
        env = dict(os.environ, ELMTUI_E2E_PRIVATE_X='1')
        return subprocess.call(['xvfb-run', '-a', '-s', '-screen 0 1280x900x24',
                                sys.executable, str(Path(__file__).resolve()), *sys.argv[1:]], env=env)
    OPTIONS.output = (OPTIONS.output or ROOT / 'test-output' / ('terminal-e2e-' + uuid.uuid4().hex[:8])).resolve()
    OPTIONS.output.mkdir(parents=True, exist_ok=True)
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(FullTerminalApps)
    if OPTIONS.case:
        suite = unittest.TestSuite(test for test in suite if OPTIONS.case in test.id())
        if suite.countTestCases() == 0:
            parser.error('--case matched no tests')
    started = time.monotonic()
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    report = {'terminal': OPTIONS.terminal, 'tests': result.testsRun,
              'failures': len(result.failures), 'errors': len(result.errors),
              'seconds': time.monotonic() - started,
              'git_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'successful': result.wasSuccessful()}
    (OPTIONS.output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Artifacts: ' + str(OPTIONS.output))
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    sys.exit(main())
