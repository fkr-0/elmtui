"""Runtime qualification for public topic, registry, pipeline and channel docstrings.

The 100 symbols below are owned by ElmTUI and intentionally tested through
CLPM/SBCL rather than checking strings in a generated documentation file.
These tests are discovered by the existing reference CI job.
"""
from __future__ import annotations

from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SYMBOLS = """(ELMTUI.CORE.TOPICS:FIND-TOPIC function)
(ELMTUI.CORE.TOPICS:FIND-TOPICS-BY-PATTERN function)
(ELMTUI.CORE.TOPICS:LIST-TOPICS function)
(ELMTUI.CORE.TOPICS:MAKE-TOPIC function)
(ELMTUI.CORE.TOPICS:MAKE-TOPIC-SUBSCRIPTION function)
(ELMTUI.CORE.TOPICS:REGISTER-TOPIC function)
(ELMTUI.CORE.TOPICS:TOPIC-ANCESTORS function)
(ELMTUI.CORE.TOPICS:TOPIC-CHILDREN function)
(ELMTUI.CORE.TOPICS:TOPIC-DESCENDANTS function)
(ELMTUI.CORE.TOPICS:TOPIC-DESCRIPTION function)
(ELMTUI.CORE.TOPICS:TOPIC-MATCH-P function)
(ELMTUI.CORE.TOPICS:TOPIC-NAME function)
(ELMTUI.CORE.TOPICS:TOPIC-PARENT function)
(ELMTUI.CORE.TOPICS:TOPIC-PATH function)
(ELMTUI.CORE.TOPICS:TOPIC-PATTERN-MATCH-P function)
(ELMTUI.CORE.TOPICS:TOPIC-SUBSCRIPTION-HANDLER function)
(ELMTUI.CORE.TOPICS:TOPIC-SUBSCRIPTION-PATTERN function)
(ELMTUI.CORE.TOPICS:TOPIC-SUBSCRIPTION-PRIORITY function)
(ELMTUI.CORE.TOPICS:TOPIC type)
(ELMTUI.CORE.TOPICS:TOPIC-SUBSCRIPTION type)
(ELMTUI.CORE.TOPIC-REGISTRY:CLEAR-REGISTRY function)
(ELMTUI.CORE.TOPIC-REGISTRY:DISPATCH-TOPIC function)
(ELMTUI.CORE.TOPIC-REGISTRY:FIND-HANDLERS-FOR-TOPIC function)
(ELMTUI.CORE.TOPIC-REGISTRY:FIND-SUBSCRIPTIONS-FOR-TOPIC function)
(ELMTUI.CORE.TOPIC-REGISTRY:GET-ALL-SUBSCRIPTIONS function)
(ELMTUI.CORE.TOPIC-REGISTRY:GET-CHANNEL-SUBSCRIPTIONS function)
(ELMTUI.CORE.TOPIC-REGISTRY:GET-TOPICS-WITH-SUBSCRIBERS function)
(ELMTUI.CORE.TOPIC-REGISTRY:LIST-SUBSCRIPTIONS function)
(ELMTUI.CORE.TOPIC-REGISTRY:PUBLISH function)
(ELMTUI.CORE.TOPIC-REGISTRY:PUBLISH-TO-CHANNEL function)
(ELMTUI.CORE.TOPIC-REGISTRY:PUBLISH-TO-TOPIC function)
(ELMTUI.CORE.TOPIC-REGISTRY:SUBSCRIBE-TO-TOPIC-ON-CHANNEL function)
(ELMTUI.CORE.TOPIC-REGISTRY:SUBSCRIPTION-COUNT function)
(ELMTUI.CORE.TOPIC-REGISTRY:SUBSCRIPTION-INFO function)
(ELMTUI.CORE.TOPIC-REGISTRY:UNSUBSCRIBE function)
(ELMTUI.CORE.TOPIC-REGISTRY:UNSUBSCRIBE-FROM-CHANNEL function)
(ELMTUI.CORE.EVENT-PIPELINE:MAKE-PIPELINE function)
(ELMTUI.CORE.EVENT-PIPELINE:PIPELINE-FALLTHROUGH function)
(ELMTUI.CORE.EVENT-PIPELINE:PIPELINE-PIPES function)
(ELMTUI.CORE.EVENT-PIPELINE:PROCESS-EVENT function)
(ELMTUI.CORE.EVENT-PIPELINE:CONDITIONAL-PIPE type)
(ELMTUI.CORE.EVENT-PIPELINE:FILTER-PIPE type)
(ELMTUI.CORE.EVENT-PIPELINE:PIPE type)
(ELMTUI.CORE.EVENT-PIPELINE:PIPELINE type)
(ELMTUI.CORE.EVENT-PIPELINE:TRANSFORM-PIPE type)
(ELMTUI.CORE.EVENT-CHANNELS:ADD-EVENT-FILTER function)
(ELMTUI.CORE.EVENT-CHANNELS:CHANNEL-OF function)
(ELMTUI.CORE.EVENT-CHANNELS:CHANNEL-PRIORITY function)
(ELMTUI.CORE.EVENT-CHANNELS:FILTERS function)
(ELMTUI.CORE.EVENT-CHANNELS:HANDLERS function)
(ELMTUI.CORE.EVENT-CHANNELS:MAKE-COMMAND-CHANNEL function)
(ELMTUI.CORE.EVENT-CHANNELS:MAKE-FOCUS-CHANNEL function)
(ELMTUI.CORE.EVENT-CHANNELS:MAKE-KEYBOARD-CHANNEL function)
(ELMTUI.CORE.EVENT-CHANNELS:MAKE-MESSAGE-CHANNEL function)
(ELMTUI.CORE.EVENT-CHANNELS:MAKE-MOUSE-CHANNEL function)
(ELMTUI.CORE.EVENT-CHANNELS:MAKE-SYSTEM-CHANNEL function)
(ELMTUI.CORE.EVENT-CHANNELS:MAKE-UI-CHANNEL function)
(ELMTUI.CORE.EVENT-CHANNELS:NAME function)
(ELMTUI.CORE.EVENT-CHANNELS:PRIORITY function)
(ELMTUI.CORE.EVENT-CHANNELS:RECEIVE-EVENT function)
(ELMTUI.CORE.EVENT-CHANNELS:REGISTER-EVENT-HANDLER function)
(ELMTUI.CORE.EVENT-CHANNELS:REMOVE-EVENT-FILTER function)
(ELMTUI.CORE.EVENT-CHANNELS:SEND-EVENT function)
(ELMTUI.CORE.EVENT-CHANNELS:SET-CHANNEL-PRIORITY function)
(ELMTUI.CORE.EVENT-CHANNELS:UNREGISTER-EVENT-HANDLER function)"""

ADDITIONAL_SYMBOLS = """(ELMTUI.UI.WIDGETS.LISTBOX:LISTBOX-MODEL-HEIGHT function)
(ELMTUI.UI.WIDGETS.LISTBOX:LISTBOX-MODEL-ID function)
(ELMTUI.UI.WIDGETS.LISTBOX:LISTBOX-MODEL-ITEMS function)
(ELMTUI.UI.WIDGETS.LISTBOX:LISTBOX-MODEL-ON-SELECT function)
(ELMTUI.UI.WIDGETS.LISTBOX:LISTBOX-MODEL-SCROLL-OFFSET function)
(ELMTUI.UI.WIDGETS.LISTBOX:LISTBOX-MODEL-SELECTED-INDEX function)
(ELMTUI.UI.WIDGETS.LISTBOX:MSG-LISTBOX-KEY-PRESS variable)
(ELMTUI.UI.WIDGETS.LISTBOX:MSG-LISTBOX-SCROLL-DOWN variable)
(ELMTUI.UI.WIDGETS.LISTBOX:MSG-LISTBOX-SCROLL-UP variable)
(ELMTUI.UI.WIDGETS.LISTBOX:MSG-LISTBOX-SELECT-INDEX variable)
(ELMTUI.UI.WIDGETS.LISTBOX:MSG-LISTBOX-SET-ITEMS variable)
(ELMTUI.CORE.FOCUS:FOCUS-MANAGER-ACTIVE-FOCUS-CONTEXT function)
(ELMTUI.CORE.FOCUS:FOCUS-MANAGER-CONTEXT-DATA function)
(ELMTUI.CORE.FOCUS:FOCUS-MANAGER-CURRENT-FOCUS function)
(ELMTUI.CORE.FOCUS:FOCUS-MANAGER-FOCUS-HISTORY function)
(ELMTUI.CORE.FOCUS:FOCUS-MANAGER-FOCUS-RING-DIRTY-P function)
(ELMTUI.CORE.FOCUS:FOCUS-MANAGER-FOCUSABLE-ELEMENTS function)
(ELMTUI.STATE.MSG:ARG-DEF-KEYWORD function)
(ELMTUI.STATE.MSG:ARG-DEF-TYPE function)
(ELMTUI.STATE.MSG:MESSAGE-SCHEMA-DOCSTRING function)
(ELMTUI.STATE.MSG:MESSAGE-SCHEMA-NAME function)
(ELMTUI.STATE.MSG:MESSAGE-SCHEMA-VARIANTS function)
(ELMTUI.STATE.MSG:VARIANT-DEFINITION-ARG-SPEC function)
(ELMTUI.STATE.MSG:VARIANT-DEFINITION-ARGS function)
(ELMTUI.STATE.MSG:VARIANT-DEFINITION-CONSTRUCTOR-NAME function)
(ELMTUI.STATE.MSG:VARIANT-DEFINITION-NAME function)
(ELMTUI.RENDER.DIFF:BUFFERS-NOT-COMPATIBLE-ERROR type)
(ELMTUI.RENDER.DIFF:DIFF-METRICS type)
(ELMTUI.RENDER.DIFF:BUFFERS-NOT-COMPATIBLE-ERROR-BACK function)
(ELMTUI.RENDER.DIFF:BUFFERS-NOT-COMPATIBLE-ERROR-FRONT function)
(ELMTUI.RENDER.DIFF:BUFFERS-NOT-COMPATIBLE-ERROR-REASON function)
(ELMTUI.RENDER.DIFF:DIFF-METRICS-BATCHES function)
(ELMTUI.RENDER.DIFF:DIFF-METRICS-CELLS-CHANGED function)
(ELMTUI.RENDER.DIFF:DIFF-METRICS-CELLS-COMPARED function)
(ELMTUI.RENDER.DIFF:DIFF-METRICS-FULL-REDRAWS function)"""


def evaluate(form: str) -> str:
    command = [
        "clpm", "bundle", "exec", "--with-client", "sbcl", "--",
        "--noinform", "--non-interactive",
        "--eval", "(require :asdf)",
        "--eval", "(asdf:load-system :elmtui)",
        "--eval", form,
    ]
    result = subprocess.run(
        command, cwd=ROOT, text=True, capture_output=True, timeout=45
    )
    if result.returncode != 0:
        raise AssertionError(
            f"CLPM/SBCL failed with code {result.returncode}:\n"
            + (result.stdout + "\n" + result.stderr)[-6000:]
        )
    return result.stdout


class PublicCoreDocstrings(unittest.TestCase):
    def test_all_100_exported_contracts_are_documented(self):
        self.assertEqual(100, len(SYMBOLS.splitlines()) + len(ADDITIONAL_SYMBOLS.splitlines()))
        form = (
            "(progn (dolist (spec '("
            + SYMBOLS + "\n" + ADDITIONAL_SYMBOLS
            + ")) (destructuring-bind (symbol kind) spec "
            + "(unless (and (eq (nth-value 1 (find-symbol (symbol-name symbol) "
            + "(symbol-package symbol))) :external) "
            + "(let ((doc (documentation symbol kind))) "
            + "(and (stringp doc) (>= (length doc) 45)))) "
            + "(error \"Undocumented or non-public core symbol ~S / ~S\" symbol kind)))) "
            + '(format t "CORE-DOCSTRINGS-100-PASS~%"))'
        )
        self.assertIn("CORE-DOCSTRINGS-100-PASS", evaluate(form))

    def test_key_behavioral_contracts_not_generic_placeholders(self):
        form = r'''(progn
          (flet ((contains (symbol needle)
                   (unless (search needle (documentation symbol 'function))
                     (error "Missing meaningful docstring for ~S" symbol))))
            (contains 'elmtui.core.topics:make-topic "does not register")
            (contains 'elmtui.core.topics:topic-pattern-match-p "empty suffix")
            (contains 'elmtui.core.topic-registry:find-subscriptions-for-topic "stably ordered")
            (contains 'elmtui.core.event-pipeline:process-event "FALLTHROUGH")
            (contains 'elmtui.core.event-channels:register-event-handler "not automatically")
            (contains 'elmtui.ui.widgets.listbox:listbox-model-scroll-offset "first visible")
            (contains 'elmtui.render.diff:diff-metrics-cells-changed "requiring output"))
          (format t "CORE-DOCSTRINGS-CONTRACTS-PASS~%"))'''
        self.assertIn("CORE-DOCSTRINGS-CONTRACTS-PASS", evaluate(form))

    def test_described_topic_and_pipeline_paths_are_operational(self):
        form = r'''(progn
          (let* ((root (elmtui.core.topics:make-topic "root"))
                 (child (elmtui.core.topics:make-topic "leaf" :parent root))
                 (pipeline (elmtui.core.event-pipeline:make-pipeline
                            :pipes (list (make-instance
                                           'elmtui.core.event-pipeline:transform-pipe
                                           :transform #'1+)))))
            (assert (equal (elmtui.core.topics:topic-path child)
                           '("root" "leaf")))
            (assert (elmtui.core.topics:topic-pattern-match-p "root/*" child))
            (assert (elmtui.core.topics:topic-match-p child root))
            (assert (not (elmtui.core.topics:topic-match-p root child)))
            (assert (= 42 (elmtui.core.event-pipeline:process-event pipeline 41)))
            (let ((channel (elmtui.core.event-channels:make-keyboard-channel)))
              (assert (typep channel
                             'elmtui.core.event-channels:keyboard-channel))))
          (format t "CORE-DOCSTRINGS-BEHAVIOR-PASS~%"))'''
        self.assertIn("CORE-DOCSTRINGS-BEHAVIOR-PASS", evaluate(form))


if __name__ == "__main__":
    unittest.main()
