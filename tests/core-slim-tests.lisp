(uiop:define-package :elmtui.tests.core-slim
  (:use :cl :fiveam)
  (:export #:run-core-slim-tests))
(in-package :elmtui.tests.core-slim)

(def-suite core-slim-tests
  :description "Optional example widgets never enter the mandatory ElmTUI system.")
(in-suite core-slim-tests)

(test example-component-boundary
  ;; ASDF ownership, not just the presence or absence of text, is the contract.
  (dolist (name '("keytester" "keytester-map" "counter"))
    (is-false (asdf:find-component
               (asdf:find-system "elmtui") (list "ui" "widgets" name)))
    (is-true (asdf:find-component
              (asdf:find-system "elmtui-example-widgets") name))))

(test examples-and-cli-declare-optional-dependency
  (dolist (system '("elmtui-examples" "elmtui-examples-cli"))
    (is (member "elmtui-example-widgets"
                (mapcar (lambda (s) (string-downcase (string s)))
                        (asdf:system-depends-on (asdf:find-system system)))
                :test #'string=))))

(test developer-tools-have-optional-asdf-owner
  (is-false (asdf:find-component (asdf:find-system "elmtui") "dev/dev"))
  (is-true (asdf:find-component (asdf:find-system "elmtui-dev") "dev")))

(test key-tester-model-remains-available
  (let ((model (example.key-tester:make-key-tester)))
    (is (string= "" (example.key-tester::key-tester-input model)))
    (is (string= "" (example.key-tester::key-tester-echo model)))
    (is (search "Input:" (with-output-to-string (out)
                              (example.key-tester:key-tester-render
                               model :stream out))))
    (is (find-package :example.key-tester.keymap))))

(test example-keymap-context-retained
  (is (boundp 'example.key-tester.keymap:*key-tester-keymap*))
  (is (boundp 'example.key-tester.keymap:*key-tester-context*))
  (is (fboundp 'example.key-tester.keymap:kt-focus-gained))
  (is (fboundp 'example.key-tester.keymap:kt-focus-lost)))

(test counter-widget-class-retained
  (is (find-class 'elmtui.ui.widgets.counter:counter nil)))

(defun run-core-slim-tests ()
  "Execute focused FiveAM regressions for optional package ownership."
  (run! 'core-slim-tests))
