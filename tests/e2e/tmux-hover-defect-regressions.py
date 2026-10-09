#!/usr/bin/env python3
"""Strict private-tmux hover regression tests. Failures block release.

No fake terminal, no mocks, no alternate screen, no expected failures.
Run: python3 tests/e2e/tmux-hover-defect-regressions.py
"""
import importlib.util
from pathlib import Path
import re
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "hover_defect_harness", ROOT / "scripts/test-terminal-apps.py")
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)
MARKER = re.compile(r"HISTORY-MARKER-(\d{2})")
FORBIDDEN = (b"\x1b[?1049h", b"\x1b[?1049l",
             b"\x1b[?1047h", b"\x1b[?1047l",
             b"\x1b[?47h", b"\x1b[?47l")

class Options:
    terminal = "tmux"
    timeout = 18
    output = None

def styled_marker_oracle(snapshot):
    """Map each unique history marker to its exact SGR-decorated row, in order."""
    records, ordered = {}, []
    for row in snapshot.splitlines():
        for match in MARKER.finditer(row):
            ident = int(match.group(1))
            if ident in records:
                raise AssertionError(f"Duplicate historical marker {ident:02d}")
            records[ident] = row
            ordered.append(ident)
    return records, ordered

def styled_fixture(gate):
    return (
        'for n in $(seq 1 70); do\n'
        'case $((n % 3)) in\n'
        '0) printf "\\033[1;31;44mHISTORY-MARKER-%02d BOLD\\033[0m\\n" "$n" ;;\n'
        '1) printf "\\033[4;38;5;214;48;5;20mHISTORY-MARKER-%02d PALETTE\\033[0m\\n" "$n" ;;\n'
        '2) printf "\\033[38;2;12;34;56;48;2;77;88;99mHISTORY-MARKER-%02d RGB\\033[0m\\n" "$n" ;;\n'
        'esac\ndone\n'
        'printf "\\033[1;31;44mUNDERLAY-ALPHA\\033[0m\\n"\n'
        'printf "\\033[4;38;5;214mUNDERLAY-BETA\\033[0m\\n"\n'
        f'until test -e "{gate}"; do sleep .05; done')

def visible_fixture(gate):
    return (
        'for n in $(seq 1 70); do printf "HISTORY-MARKER-%02d\\n" "$n"; done\n'
        'for n in $(seq 1 24); do '
        'printf "\\033[1;31;44mCELL-ROW-%02d-ABCDEFGHIJKLMNOPQRST\\033[0m\\n" "$n"; '
        'done\n'
        f'until test -e "{gate}"; do sleep .05; done')

class HoverDefectsPTY(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="elmtui-hover-strict-")
        Options.output = Path(cls.tmp.name)
        harness.OPTIONS = Options()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def start_gated(self, name, gate, fixture, size=(120,40)):
        app = harness.TerminalApp(name,
            "(elmtui-examples.tmux-hover-demo:run-tmux-hover-demo)",
            prelude=fixture(gate), use_launcher=False)
        self.addCleanup(app.close)
        app.start()
        self.resize(app,size)
        return app

    def resize(self,app,size):
        app.tmux("resize-window","-t","app:0","-x",str(size[0]),"-y",str(size[1]))
        got=app.tmux("display-message","-p","-t","app:0.0",
                     "#{pane_width} #{pane_height}").stdout.strip()
        self.assertEqual(got,f"{size[0]} {size[1]}")

    @staticmethod
    def capture(app,styled=True,history=True):
        args=["capture-pane","-p"]
        if styled: args.append("-e")
        if history: args.extend(["-S","-"])
        args.extend(["-t","app:0.0"])
        return app.tmux(*args).stdout

    def exact_history(self,original,restored):
        before,order1=styled_marker_oracle(original)
        after,order2=styled_marker_oracle(restored)
        self.assertEqual(order1,list(range(1,71)),"Broken baseline oracle")
        missing=sorted(set(order1)-set(order2))
        unexpected=sorted(set(order2)-set(order1))
        self.assertFalse(missing or unexpected,
            f"Lost markers {missing}; unexpected markers {unexpected}")
        self.assertEqual(order2,order1,"Historical row ordering changed")
        mismatched=[n for n in order1 if after[n]!=before[n]]
        self.assertFalse(mismatched,
            f"ANSI SGR or historical row text altered for markers {mismatched}")
        self.assertNotIn("B1 / GLYPH",restored,"Tooltip leaked into history")
        self.assertNotIn("B2 focus",restored,"Focus UI leaked into history")
        for label in ("UNDERLAY-ALPHA","UNDERLAY-BETA"):
            original_rows=[row for row in original.splitlines() if label in row]
            restored_rows=[row for row in restored.splitlines() if label in row]
            self.assertLessEqual(len(original_rows),1,
                                 f"Fixture has duplicated {label} before launch")
            self.assertEqual(restored_rows,original_rows,
                             f"Underlying physical row or its SGR style changed: {label}")

    def clean_exit(self,app):
        app.wait(lambda screen:"ELMTUI_E2E_SHELL_RESTORED" in screen,
                 "terminal restored after exit")
        self.assertEqual((app.directory/"exit-code").read_text().strip(),"0")
        self.assertEqual((app.directory/"before.stty").read_text(),
                         (app.directory/"after.stty").read_text())
        self.assertEqual(app.tmux("display-message","-p","-t","app:0.0",
                                   "#{cursor_flag}").stdout.strip(),"1")
        raw=(app.directory/"terminal.raw").read_bytes()
        for seq in FORBIDDEN:
            self.assertNotIn(seq,raw,"Alternate screen is categorically banned")
        for seq in (b"\x1b[2J", b"\x1b[3J"):
            self.assertNotIn(seq,raw,"Full-screen/scrollback erase is forbidden")

    def test_oracle_detects_styled_mutation_missing_and_duplicates(self):
        original="".join(f"\x1b[31mHISTORY-MARKER-{n:02d}\x1b[0m\n"
                         for n in range(1,71))
        before,order=styled_marker_oracle(original)
        self.assertEqual(order,list(range(1,71)))
        recolored=original.replace("\x1b[31mHISTORY-MARKER-35",
                                   "\x1b[34mHISTORY-MARKER-35")
        self.assertNotEqual(styled_marker_oracle(recolored)[0],before)
        removed=original.replace("\x1b[31mHISTORY-MARKER-35\x1b[0m\n","")
        self.assertNotEqual(styled_marker_oracle(removed)[1],order)
        with self.assertRaisesRegex(AssertionError,"Duplicate"):
            styled_marker_oracle(original+"\x1b[31mHISTORY-MARKER-35\x1b[0m\n")

    def test_control_no_app_resizing_preserves_all_styled_history(self):
        """Prove the same private tmux retains history before ElmTUI starts."""
        gate=Options.output/"control.start"
        app=self.start_gated("control",gate,styled_fixture)
        app.expect("UNDERLAY-BETA")
        original=self.capture(app)
        for size in ((80,24),(120,40),(80,24),(120,40)):
            self.resize(app,size)
            self.exact_history(original,self.capture(app))
        gate.touch()
        app.expect("tmux-hover-demo [TMUX]")
        app.key("q",literal=True)
        self.clean_exit(app)

    def test_hover_both_resize_directions_lossless_styled_history(self):
        """The full 70 exact ANSI-styled rows must survive both directions."""
        for initial,target in (((80,24),(120,40)),((120,40),(80,24))):
            with self.subTest(initial=initial,target=target):
                name=f"resize-{initial[0]}-{target[0]}"
                gate=Options.output/(name+".start")
                app=self.start_gated(name,gate,styled_fixture,initial)
                app.expect("UNDERLAY-BETA")
                baseline=self.capture(app)
                gate.touch()
                app.expect("tmux-hover-demo [TMUX]")
                app.key("Right");app.expect("Cursor: (1, 0)")
                app.key("s",literal=True);app.expect("SCROLLBACK")
                app.key("p",literal=True);app.expect("PANE")
                app.key("r",literal=True);app.expect("tmux capture refreshed")
                self.resize(app,target)
                app.key("q",literal=True)
                self.clean_exit(app)
                self.exact_history(baseline,self.capture(app))
                plain=self.capture(app,styled=False)
                self.assertEqual(plain.count("UNDERLAY-ALPHA"),1)
                self.assertEqual(plain.count("UNDERLAY-BETA"),1)

    def test_b2_framing_moves_on_actual_physical_pane(self):
        """The original captured glyph is at the center of real 3x3 border."""
        gate=Options.output/"focus.start"
        app=self.start_gated("focus",gate,visible_fixture)
        app.expect("CELL-ROW-24")
        before=self.capture(app,styled=False,history=False).splitlines()
        self.assertGreaterEqual(len(before),8)
        self.assertGreaterEqual(len(before[6]),7)
        original_glyph=before[6][5]
        gate.touch()
        app.expect("B1 / GLYPH + STYLE")
        for x in range(1,6):
            app.key("Right");app.expect(f"Cursor: ({x}, 0)")
        for y in range(1,7):
            app.key("Down");app.expect(f"Cursor: (5, {y})")
        after=self.capture(app,styled=False,history=False).splitlines()
        self.assertEqual(after[5][4:7],"┌─┐","B2 border must occupy physical y5")
        self.assertEqual(after[6][4:7],f"│{original_glyph}│",
                         "Target physical cell must stay unchanged")
        self.assertEqual(after[7][4:7],"└─┘","B2 border must occupy physical y7")
        self.assertEqual(sum("B1 / GLYPH + STYLE" in row for row in after),1)
        app.key("q",literal=True)
        self.clean_exit(app)

    def test_unicode_wide_cell_navigation_no_split_or_lost_history(self):
        """Right-arrow must skip the continuation column of a real wide glyph."""
        gate=Options.output/"unicode.start"
        prelude=(
            'for n in $(seq 1 70); do printf "HISTORY-MARKER-%02d\n" "$n"; done\n'
            'for n in $(seq 1 24); do '
            'printf "\033[1;34mA界B é ROW-%02d\033[0m\n" "$n"; done\n'
            f'until test -e "{gate}"; do sleep .05; done')
        app=self.start_gated("unicode",gate,lambda _:prelude,(80,24))
        app.expect("A界B")
        baseline=self.capture(app)
        self.assertEqual(styled_marker_oracle(baseline)[1],list(range(1,71)))
        gate.touch()
        app.expect("B1 / GLYPH + STYLE")
        app.key("Right");app.expect("Cursor: (1, 0)")
        app.key("Right");app.expect("Cursor: (3, 0)")
        app.key("q",literal=True)
        self.clean_exit(app)
        self.exact_history(baseline,self.capture(app))

    def test_b1_specimen_retains_real_rgb_and_palette_colors(self):
        """B1 specimen must use captured true-color FG and 256 palette BG."""
        gate=Options.output/"rgb-specimen.start"
        prelude=(
            'for n in $(seq 1 70); do printf "HISTORY-MARKER-%02d\n" "$n"; done\n'
            'for n in $(seq 1 24); do '
            'printf "\033[38;2;12;34;56;48;5;77mABC-COLOR-%02d\033[0m\n" "$n"; done\n'
            f'until test -e "{gate}"; do sleep .05; done')
        app=self.start_gated("rgb-specimen",gate,lambda _:prelude,(80,24))
        app.expect("ABC-COLOR")
        baseline=self.capture(app)
        gate.touch()
        app.expect("B1 / GLYPH + STYLE")
        app.expect("FG: (:RGB 12 34 56)")
        app.expect("BG: (:|256| 77)")
        styled=self.capture(app,styled=True,history=False)
        specimen=next((line for line in styled.splitlines()
                       if "Specimen: Aa Bb" in line),None)
        self.assertIsNotNone(specimen,"B1 must paint a styled example")
        # tmux may combine multiple color changes into one SGR sequence.
        prefix=specimen.split("Specimen:",1)[0]
        params=";".join(re.findall(r"\x1b\[([0-9;:]*)m",prefix)).replace(":", ";")
        self.assertIn("38;2;12;34;56",params,
                      "Specimen must reproduce captured RGB FG rather than white")
        self.assertIn("48;5;77",params,
                      "Specimen must reproduce captured 256-color background")
        app.key("q",literal=True)
        self.clean_exit(app)
        self.exact_history(baseline,self.capture(app))

    def test_b2_bottom_edge_clips_without_scrolling_original_rows(self):
        """A focus box at last physical pane row clips rather than adding rows."""
        gate=Options.output/"bottom-edge.start"
        prelude=(
            'for n in $(seq 1 70); do printf "HISTORY-MARKER-%02d\n" "$n"; done\n'
            'for n in $(seq 1 23); do printf "EDGE-ROW-%02d\n" "$n"; done\n'
            'printf "EDGE-CELL-ABCDEFGHIJKLMNOPQRSTUV"\n'
            f'until test -e "{gate}"; do sleep .05; done')
        app=self.start_gated("bottom-edge",gate,lambda _:prelude,(80,24))
        app.expect("EDGE-CELL")
        before=self.capture(app,styled=False,history=False).splitlines()
        self.assertEqual(len(before),24)
        self.assertGreater(len(before[23]),5)
        original_glyph=before[23][3]
        baseline=self.capture(app)
        gate.touch()
        app.expect("B1 / GLYPH + STYLE")
        app.key("End")
        app.expect("Cursor: (0, 23)")
        for x in range(1,4):
            app.key("Right")
            app.expect(f"Cursor: ({x}, 23)")
        screen=self.capture(app,styled=False,history=False).splitlines()
        self.assertEqual(screen[22][2:5],"┌─┐",
                         "Border must be at physical penultimate row")
        self.assertEqual(screen[23][2:5],f"│{original_glyph}│",
                         "Bottom clipping must not move or erase selected glyph")
        app.key("q",literal=True)
        self.clean_exit(app)
        self.exact_history(baseline,self.capture(app))

    def test_idle_ctrl_c_and_repeat_launches_do_not_touch_history(self):
        for index,ending in enumerate(("C-c","Escape")):
            with self.subTest(ending=ending):
                gate=Options.output/f"idle-{index}.start"
                app=self.start_gated(f"idle-{index}",gate,styled_fixture,(80,24))
                app.expect("UNDERLAY-BETA")
                baseline=self.capture(app)
                gate.touch()
                app.expect("tmux-hover-demo [TMUX]")
                time.sleep(.4)
                old=(app.directory/"terminal.raw").read_bytes()
                time.sleep(.6)
                self.assertEqual((app.directory/"terminal.raw").read_bytes(),
                                 old,"Idle frame emitted unexpected bytes")
                app.key(ending)
                self.clean_exit(app)
                self.exact_history(baseline,self.capture(app))

if __name__=="__main__":
    unittest.main(verbosity=2)
