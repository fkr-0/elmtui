"""Regression qualification of the 102 public API docstrings added at 85%.

The export symbol/kind snapshot is fixed here; unlike a dynamic audit, removing
documentation entries does not change the expected symbols in these tests.
"""
from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCUMENTED_EXPORTS = """(CL-STYLES.SELECTOR:ATTR> function)
(CL-STYLES.SELECTOR:CHILD> function)
(CL-STYLES.SELECTOR:CLS> function)
(CL-STYLES.SELECTOR:DESCENDANT> function)
(CL-STYLES.SELECTOR:FIRST-CHILD function)
(CL-STYLES.SELECTOR:HAS function)
(CL-STYLES.SELECTOR:ID> function)
(CL-STYLES.SELECTOR:INVALID-SELECTOR type)
(CL-STYLES.SELECTOR:INVALID-SELECTOR-PATH function)
(CL-STYLES.SELECTOR:INVALID-SELECTOR-REASON function)
(CL-STYLES.SELECTOR:INVALID-SELECTOR-SELECTOR function)
(CL-STYLES.SELECTOR:LAST-CHILD function)
(CL-STYLES.SELECTOR:MATCH-SELECTOR-P function)
(CL-STYLES.SELECTOR:NTH-CHILD function)
(CL-STYLES.SELECTOR:SEL-AND function)
(CL-STYLES.SELECTOR:SEL-NOT function)
(CL-STYLES.SELECTOR:SEL-OR function)
(CL-STYLES.SELECTOR:STATE> function)
(CL-STYLES.SELECTOR:TYPE> function)
(CL-STATE.PATCH:INVALID-PATCH-FORMAT type)
(CL-STATE.PATCH:INVALID-PATCH-OPERATION type)
(CL-STATE.PATCH:INVALID-PATCH-OPERATION-OPERATION function)
(CL-STATE.PATCH:INVALID-PATCH-PATH type)
(CL-STATE.PATCH:INVALID-PATCH-PATH-PATH function)
(CL-STATE.PATCH:INVALID-PATCH-VALUE type)
(CL-STATE.PATCH:INVALID-PATCH-VALUE-OPERATION function)
(CL-STATE.PATCH:INVALID-PATCH-VALUE-VALUE function)
(CL-STATE.PATCH:MAKE-PATCH function)
(CL-STATE.PATCH:NORMALIZE-PATCHES function)
(CL-STATE.PATCH:PATCH type)
(CL-STATE.PATCH:PATCH-OP function)
(CL-STATE.PATCH:PATCH-P function)
(CL-STATE.PATCH:PATCH-PATH function)
(CL-STATE.PATCH:PATCH-VALIDATION-ERROR type)
(CL-STATE.PATCH:PATCH-VALIDATION-ERROR-INPUT function)
(CL-STATE.PATCH:PATCH-VALIDATION-ERROR-REASON function)
(CL-STATE.PATCH:PATCH-VALUE function)
(CL-STATE.CORE:APPLICATION-STATE type)
(CL-STATE.CORE:APPLICATION-STATE-BACKEND function)
(CL-STATE.CORE:APPLICATION-STATE-HISTORY function)
(CL-STATE.CORE:APPLICATION-STATE-LOCK function)
(CL-STATE.CORE:APPLICATION-STATE-LOG function)
(CL-STATE.CORE:APPLICATION-STATE-OBSERVERS function)
(CL-STATE.CORE:APPLICATION-STATE-P function)
(CL-STATE.CORE:APPLICATION-STATE-REVISION function)
(CL-STATE.CORE:APPLICATION-STATE-UNDONE function)
(CL-STATE.CORE:APPLICATION-STATE-VERSION function)
(CL-STATE.CORE:INVALID-STATE-PATH-PATH function)
(CL-STATE.CORE:MAKE-APPLICATION-STATE function)
(CL-STATE.CORE:STATE-CONFLICT-OPERATION function)
(CL-STATE.CORE:STATE-CONFLICT-STATE function)
(CL-STATE.CORE:STATE-REVISION-CONFLICT-ACTUAL-REVISION function)
(CL-STATE.CORE:STATE-REVISION-CONFLICT-EXPECTED-REVISION function)
(CL-STYLES.ENGINE:*CASCADE-SEMANTICS-REVISION* variable)
(CL-STYLES.ENGINE:COMPUTED-STYLE-RESULT type)
(CL-STYLES.ENGINE:COMPUTED-STYLE-RESULT-DIAGNOSTICS function)
(CL-STYLES.ENGINE:COMPUTED-STYLE-RESULT-REVISION function)
(CL-STYLES.ENGINE:COMPUTED-STYLE-RESULT-STYLE function)
(CL-STYLES.ENGINE:COMPUTED-STYLE-RESULT-TRACE function)
(CL-STYLES.ENGINE:DECLARATION-TRACE type)
(CL-STYLES.ENGINE:DECLARATION-TRACE-ORIGIN function)
(CL-STYLES.ENGINE:DECLARATION-TRACE-PROPERTY function)
(CL-STYLES.ENGINE:DECLARATION-TRACE-SELECTOR function)
(CL-STYLES.ENGINE:DECLARATION-TRACE-SOURCE-DECLARATIONS function)
(CL-STYLES.ENGINE:DECLARATION-TRACE-SOURCE-ORDER function)
(CL-STYLES.ENGINE:DECLARATION-TRACE-SPECIFICITY function)
(CL-STYLES.ENGINE:DECLARATION-TRACE-STATUS function)
(CL-STYLES.ENGINE:DECLARATION-TRACE-VALUE function)
(CL-STYLES.ENGINE:DECLARATION-TRACE-VARIABLE-EXPANSIONS function)
(CL-STYLES.ENGINE:INHERIT-PROPERTIES function)
(CL-STYLES.ENGINE:MATCH-RULES function)
(CL-STYLES.ENGINE:STYLE-PATCH type)
(CL-STYLES.ENGINE:STYLE-PATCH-COMPUTED function)
(CL-STYLES.ENGINE:STYLE-PATCH-PATH function)
(CL-STYLES.ENGINE:STYLE-REVISION type)
(CL-STYLES.ENGINE:STYLE-REVISION-CASCADE function)
(CL-STYLES.ENGINE:STYLE-REVISION-STYLESHEET function)
(CL-INPUTS.PROTOCOL:+DEFAULT-ESCAPE-TIMEOUT+ variable)
(CL-INPUTS.PROTOCOL:+DEFAULT-MAX-BUFFER-BYTES+ variable)
(CL-INPUTS.PROTOCOL:+DEFAULT-MAX-PASTE-BYTES+ variable)
(CL-INPUTS.PROTOCOL:+DEFAULT-MAX-SEQUENCE-BYTES+ variable)
(CL-INPUTS.PROTOCOL:PROTOCOL-BUFFERED-BYTE-COUNT function)
(CL-INPUTS.PROTOCOL:PROTOCOL-EVENT type)
(CL-INPUTS.PROTOCOL:PROTOCOL-EVENT-CATEGORY function)
(CL-INPUTS.PROTOCOL:PROTOCOL-EVENT-METADATA function)
(CL-INPUTS.PROTOCOL:PROTOCOL-EVENT-PAYLOAD function)
(CL-INPUTS.PROTOCOL:PROTOCOL-EVENT-RAW function)
(CL-INPUTS.PROTOCOL:PROTOCOL-EVENT-REASON function)
(CL-INPUTS.PROTOCOL:PROTOCOL-NEXT-DEADLINE function)
(ELMTUI.APP.API:APP-CONFIG type)
(ELMTUI.APP.API:APP-CONFIG-BINARY-OPTIONS function)
(ELMTUI.APP.API:APP-CONFIG-CLI-OPTIONS function)
(ELMTUI.APP.API:APP-CONFIG-COMMAND-PROCESSOR-FN function)
(ELMTUI.APP.API:APP-CONFIG-CONFIGURE-FN function)
(ELMTUI.APP.API:APP-CONFIG-INITIAL-STATE-PLIST function)
(ELMTUI.APP.API:APP-CONFIG-MESSAGE-QUEUE function)
(ELMTUI.APP.API:APP-CONFIG-NAME function)
(ELMTUI.APP.API:APP-CONFIG-RENDERER-FN function)
(ELMTUI.APP.API:APP-CONFIG-ROOT-COMPONENT-DSL function)
(ELMTUI.APP.API:APP-CONFIG-SUBSCRIPTIONS-FN-FORM function)
(ELMTUI.APP.API:APP-CONFIG-UPDATE-FN-SYM function)
(ELMTUI.APP.API:APP-CONFIG-VIEW-FN-SYM function)"""


def sbcl(form: str) -> str:
    result = subprocess.run(
        ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
         "--noinform", "--non-interactive", "--eval", "(require :asdf)",
         "--eval", "(asdf:load-system :elmtui)", "--eval", form],
        cwd=ROOT, capture_output=True, text=True, timeout=50,
    )
    if result.returncode:
        raise AssertionError(
            f"SBCL failed rc={result.returncode}\n"
            + (result.stdout + "\n" + result.stderr)[-6500:]
        )
    return result.stdout


class EightyFivePercentDocumentation(unittest.TestCase):
    def test_all_102_exports_exist_and_have_substantive_docs(self):
        self.assertEqual(102, len(DOCUMENTED_EXPORTS.splitlines()))
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
            + '(format t "API-102-DOCSTRINGS-PASS~%"))'
        )
        self.assertIn("API-102-DOCSTRINGS-PASS", sbcl(form))

    def test_selector_dsl_forms_and_unimplemented_inheritance_are_accurate(self):
        form = r"""(progn
          (assert (equal (cl-styles.selector:sel-and
                           (cl-styles.selector:id> :root)
                           (cl-styles.selector:cls> :active))
                         '(:and (:id :root) (:class :active))))
          (assert (equal (cl-styles.selector:nth-child 2) '(:nth-child 2)))
          (assert (null (cl-styles.engine:inherit-properties nil nil)))
          (assert (search "Compatibility stub"
                          (documentation 'cl-styles.engine:inherit-properties 'function)))
          (format t "SELECTOR-ENGINE-CONTRACTS-PASS~%"))"""
        self.assertIn("SELECTOR-ENGINE-CONTRACTS-PASS", sbcl(form))

    def test_patch_validation_and_protocol_limits(self):
        form = r"""(progn
          (let ((patch (cl-state.patch:make-patch
                         :path :count :op :set :value 7)))
            (assert (cl-state.patch:patch-p patch))
            (assert (eq :set (cl-state.patch:patch-op patch)))
            (assert (eql 7 (cl-state.patch:patch-value patch))))
          (assert (= 2 (length
                         (cl-state.patch:normalize-patches
                           '((:count 8) (:obsolete :removed))))))
          (assert (handler-case
                    (progn (cl-state.patch:make-patch
                             :path :count :op :invalid :value 2)
                           nil)
                    (cl-state.patch:invalid-patch-operation () t)))
          (assert (handler-case
                    (progn (cl-inputs.protocol:make-protocol-parser
                             :max-sequence-bytes 2)
                           nil)
                    (error () t)))
          (assert (plusp cl-inputs.protocol:+default-max-paste-bytes+))
          (format t "PATCH-PROTOCOL-CONTRACTS-PASS~%"))"""
        self.assertIn("PATCH-PROTOCOL-CONTRACTS-PASS", sbcl(form))

    def test_application_configuration_readers(self):
        form = r"""(progn
          (let* ((channel (elmtui.core.event-channels:make-keyboard-channel))
                 (config (elmtui.app.api::make-app-config
                           :name 'sample-app
                           :message-queue channel
                           :initial-state-plist '(:count 0)
                           :state-semantics :strict-elm)))
            (assert (typep config 'elmtui.app.api:app-config))
            (assert (eq 'sample-app (elmtui.app.api:app-config-name config)))
            (assert (eq channel (elmtui.app.api:app-config-message-queue config)))
            (assert (equal '(:count 0)
                           (elmtui.app.api:app-config-initial-state-plist config))))
          (format t "APP-CONFIG-CONTRACTS-PASS~%"))"""
        self.assertIn("APP-CONFIG-CONTRACTS-PASS", sbcl(form))


if __name__ == "__main__":
    unittest.main()
