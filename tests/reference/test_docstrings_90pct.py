"""Live Common Lisp acceptance checks for 82 documentation contracts.

The explicit symbol/kind snapshot is fixed at authoring time, and will detect
later removal of documentation or changes to the exported API.
"""
from __future__ import annotations

from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
DOCUMENTED_EXPORTS = """(CL-INPUTS.TERMINAL.ANSII:+ANSI-ESCAPE-SEQUENCES+ variable)
(CL-INPUTS.TERMINAL.ANSII:+ANSI-ESCAPE-SEQUENCES-LOOKUP+ variable)
(CL-INPUTS.TERMINAL.ANSII:+ANSI-ESCAPE-SEQUENCES-RESET-LOOKUP+ variable)
(CL-INPUTS.TERMINAL.ANSII:ANSI-ATTR-SEQ function)
(CL-INPUTS.TERMINAL.ANSII:ANSI-BG-COLOR-SEQ function)
(CL-INPUTS.TERMINAL.ANSII:ANSI-FG-COLOR-SEQ function)
(CL-INPUTS.TERMINAL.ANSII:DEFAULT-ARGS function)
(CL-INPUTS.TERMINAL.ANSII:DESCRIPTION function)
(CL-INPUTS.TERMINAL.ANSII:IDENTIFIER function)
(CL-INPUTS.TERMINAL.ANSII:INTRODUCER type)
(CL-INPUTS.TERMINAL.ANSII:INTRODUCER-CODE function)
(CL-INPUTS.TERMINAL.ANSII:INTRODUCER-DESC function)
(CL-INPUTS.TERMINAL.ANSII:INTRODUCER-ESC function)
(CL-INPUTS.TERMINAL.ANSII:INTRODUCER-ESC-CHAR function)
(CL-INPUTS.TERMINAL.ANSII:INTRODUCER-ESC-DEC function)
(CL-INPUTS.TERMINAL.ANSII:INTRODUCER-ESC-HEX function)
(CL-INPUTS.TERMINAL.ANSII:INTRODUCER-ESC-OCT function)
(CL-INPUTS.TERMINAL.ANSII:INTRODUCER-ESC-STR function)
(CL-INPUTS.TERMINAL.ANSII:INTRODUCER-NAME function)
(CL-INPUTS.TERMINAL.ANSII:MAKE-ANSI-SEQUENCE function)
(CL-INPUTS.TERMINAL.ANSII:MAKE-INTRODUCER function)
(CL-INPUTS.TERMINAL.ANSII:NUMBER-OF-ARGUMENTS function)
(CL-INPUTS.TERMINAL.ANSII:PRERENDER function)
(CL-INPUTS.TERMINAL.ANSII:RENDER-SEQ function)
(CL-INPUTS.TERMINAL.ANSII:RESET-SEQUENCE function)
(CL-INPUTS.TERMINAL.ANSII:RESPONSE-TYPE function)
(CL-INPUTS.TERMINAL.ANSII:SEQ function)
(CL-EVENTS.CHANNEL:-> function)
(CL-EVENTS.CHANNEL:<- function)
(CL-EVENTS.CHANNEL:CHAN-CLOSE function)
(CL-EVENTS.CHANNEL:CHAN-PUT function)
(CL-EVENTS.CHANNEL:CHAN-TAKE function)
(CL-EVENTS.CHANNEL:CHANNEL type)
(CL-EVENTS.CHANNEL:CHANNEL-PUT! function)
(CL-EVENTS.CHANNEL:CHANNEL-REMOVE-FILTER function)
(CL-EVENTS.CHANNEL:CHANNEL-STATE function)
(CL-EVENTS.CHANNEL:CHANNEL-TAKE! function)
(CL-EVENTS.CHANNEL:FILTERED-CHANNEL type)
(CL-EVENTS.CHANNEL:MAILBOX type)
(CL-EVENTS.CHANNEL:MAILBOX-STATE function)
(CL-EVENTS.CHANNEL:MAKE-CHANNEL function)
(CL-EVENTS.CHANNEL:MAKE-FILTERED-CHANNEL function)
(CL-EVENTS.CHANNEL:MAKE-MAILBOX function)
(CL-EVENTS.CHANNEL:MB-CLOSE function)
(CL-EVENTS.CHANNEL:MB-EMPTY-P function)
(CL-EVENTS.CHANNEL:MB-PUT function)
(CL-EVENTS.CHANNEL:MB-TAKE function)
(CL-EVENTS.CHANNEL:NO-WAIT function)
(CL-STYLES.PROPERTIES:DEFINE-GROUP function)
(CL-STYLES.PROPERTIES:ENSURE-DECLARATIONS function)
(CL-STYLES.PROPERTIES:EXPECTED function)
(CL-STYLES.PROPERTIES:GOT function)
(CL-STYLES.PROPERTIES:GROUPS-FOR-LAYOUT function)
(CL-STYLES.PROPERTIES:PROPERTIES-FOR-GROUP function)
(CL-STYLES.PROPERTIES:PROPERTIES-FOR-LAYOUT function)
(CL-STYLES.PROPERTIES:PROPERTY-DEFINITION function)
(CL-STYLES.PROPERTIES:REGISTER-PROPERTY function)
(CL-STYLES.PROPERTIES:STYLE-CONTRACT-VIOLATION type)
(CL-STYLES.PROPERTIES:WHERE function)
(CL-STYLES.PROPERTIES:DEFPROPERTY function)
(CL-EVENTS.MESSAGING:ENVELOPE->MESSAGES function)
(CL-EVENTS.MESSAGING:EXPAND-MESSAGE function)
(CL-EVENTS.MESSAGING:MAKE-MESSAGE-ENVELOPE function)
(CL-EVENTS.MESSAGING:MESSAGE->ENVELOPE function)
(CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE type)
(CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE-BROADCAST-P function)
(CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE-BUBBLE-P function)
(CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE-CAPTURE-P function)
(CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE-MESSAGE function)
(CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE-PHASE function)
(CL-EVENTS.MESSAGING:MESSAGE-ENVELOPE-STOP-P function)
(CL-EVENTS.MESSAGING:MESSAGE-PHASES function)
(CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-CLOSE-COUNT function)
(CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-CLOSED-P function)
(CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-HEIGHT function)
(CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-NONBLOCKING-P function)
(CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-OPEN-P function)
(CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-RAW-DEPTH function)
(CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-READ-COUNT function)
(CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-WAIT-COUNT function)
(CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-WIDTH function)
(CL-INPUTS.DEVICE.FAKETERM:FAKETERM-DEVICE-P function)"""


def evaluate(form: str, system: str = "elmtui") -> str:
    result = subprocess.run(
        ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
         "--noinform", "--non-interactive", "--eval", "(require :asdf)",
         "--eval", f"(asdf:load-system :{system})", "--eval", form],
        cwd=ROOT, text=True, capture_output=True, timeout=45,
    )
    if result.returncode:
        raise AssertionError(
            f"SBCL returned {result.returncode}\n"
            + (result.stdout + "\n" + result.stderr)[-7000:]
        )
    return result.stdout


class NinetyPercentDocstrings(unittest.TestCase):
    def test_all_82_live_exports_have_substantive_docstrings(self):
        self.assertEqual(82, len(DOCUMENTED_EXPORTS.splitlines()))
        form = (
            "(progn (dolist (entry '("
            + DOCUMENTED_EXPORTS
            + ")) (destructuring-bind (symbol kind) entry "
            + "(unless (and (eq :external "
            + "(nth-value 1 (find-symbol (symbol-name symbol) "
            + "(symbol-package symbol)))) "
            + "(stringp (documentation symbol kind)) "
            + "(>= (length (documentation symbol kind)) 50)) "
            + "(error \"Missing public docstring: ~S ~S\" symbol kind)))) "
            + '(format t "DOCS-82-EXPORTED-PASS~%"))'
        )
        self.assertIn("DOCS-82-EXPORTED-PASS", evaluate(form))

    def test_ansi_sequence_interpolation_and_configuration(self):
        form = r"""(progn
          (let* ((seq (cl-inputs.terminal.ansii:make-ansi-sequence
                        :seq (list "[" nil "m")
                        :description "Test attribute"
                        :identifier :test-attr))
                 (rendered (cl-inputs.terminal.ansii:render-seq seq 31)))
            (assert (= 27 (char-code (char rendered 0))))
            (assert (string= (subseq rendered 1) "[31m"))
            (assert (= 1 (cl-inputs.terminal.ansii:number-of-arguments seq)))
            (assert (eq :test-attr (cl-inputs.terminal.ansii:identifier seq))))
          (assert (stringp (cl-inputs.terminal.ansii:ansi-fg-color-seq nil)))
          (assert (hash-table-p
                    cl-inputs.terminal.ansii:+ansi-escape-sequences+))
          (format t "ANSI-INTERPOLATION-PASS~%"))"""
        self.assertIn("ANSI-INTERPOLATION-PASS", evaluate(form))

    def test_channels_mailboxes_and_close_status(self):
        form = r"""(progn
          (let ((channel (cl-events.channel:make-channel :capacity 1)))
            (assert (eq :open (cl-events.channel:channel-state channel)))
            (multiple-value-bind (ok status) (cl-events.channel:chan-put channel :sentinel)
              (assert ok) (assert (eq :ok status)))
            (multiple-value-bind (v status) (cl-events.channel:chan-take channel)
              (assert (eq :sentinel v)) (assert (eq :ok status)))
            (cl-events.channel:chan-close channel)
            (assert (eq :closed (cl-events.channel:channel-state channel))))
          (let ((mb (cl-events.channel:make-mailbox)))
            (multiple-value-bind (ok status) (cl-events.channel:mb-put mb :old)
              (assert ok) (assert (eq :ok status)))
            (cl-events.channel:mb-put mb :new)
            (multiple-value-bind (value status) (cl-events.channel:mb-take mb)
              (assert (eq :new value)) (assert (eq :ok status)))
            (cl-events.channel:mb-close mb)
            (assert (eq :closed (cl-events.channel:mailbox-state mb))))
          (format t "CHANNEL-MAILBOX-PASS~%"))"""
        self.assertIn("CHANNEL-MAILBOX-PASS", evaluate(form))

    def test_style_property_validation_and_message_envelope(self):
        form = r"""(progn
          (assert (equal '(:type :button) (cl-styles.selector:type> :button)))
          (assert (equal '(:padding-left 3)
                         (cl-styles.properties:ensure-declarations '(:padding-left 3))))
          (let* ((env (cl-events.messaging:make-message-envelope
                        :message :payload :phase :target :stop-p t))
                 (msgs (cl-events.messaging:envelope->messages (list env))))
            (assert (equal '(:payload) msgs))
            (assert (eq :target (cl-events.messaging:message-envelope-phase env)))
            (assert (cl-events.messaging:message-envelope-stop-p env)))
          (format t "STYLES-ENVELOPE-PASS~%"))"""
        self.assertIn("STYLES-ENVELOPE-PASS", evaluate(form))

    def test_fake_terminal_open_close_and_lifecycle_metrics(self):
        form = r"""(progn
          (let ((dev (cl-inputs.device.api:make-device :faketerm
                       :width 12 :height 4)))
            (assert (cl-inputs.device.faketerm:faketerm-device-p dev))
            (assert (= 12 (cl-inputs.device.faketerm:faketerm-device-width dev)))
            (cl-inputs.device.api:open-device dev)
            (assert (cl-inputs.device.faketerm:faketerm-device-open-p dev))
            (cl-inputs.device.api:close-device dev)
            (cl-inputs.device.api:close-device dev)
            (assert (= 1 (cl-inputs.device.faketerm:faketerm-device-close-count dev)))
            (assert (cl-inputs.device.faketerm:faketerm-device-closed-p dev)))
          (format t "FAKETERM-LIFECYCLE-PASS~%"))"""
        self.assertIn("FAKETERM-LIFECYCLE-PASS", evaluate(form))

    def test_standalone_subsystem_scope_not_misrepresented(self):
        # Compatibility documentation from the ElmTUI root cannot qualify an
        # independently loaded CL-STATE release.
        form = r"""(progn
          (assert (null (find-package :elmtui.app.api)))
          (assert (null (documentation 'cl-state.patch:patch-op 'function)))
          (format t "STANDALONE-SCOPE-PASS~%"))"""
        self.assertIn("STANDALONE-SCOPE-PASS", evaluate(form, "cl-state"))


if __name__ == "__main__":
    unittest.main()
