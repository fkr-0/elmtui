(uiop:define-package :elmtui.tests.packager
  (:use :cl :fiveam)
  (:import-from :elmtui.packager
                #:main)
  (:import-from :elmtui.examples.runner
                #:normalize-example-name
                #:%resolve-example-file
                #:%default-output-path)
  (:export #:packager-tests))

(in-package :elmtui.tests.packager)

(def-suite packager-tests
  :in elmtui.tests:elmtui-test
  :description "Tests for elmtui packager argument parsing and entry resolution")

(in-suite packager-tests)

(test parse-args-supports-entry-short-E
  (let* ((cfg (elmtui.packager::%parse-args
               '("-s" "elmtui" "-f" "examples/minimal-app.lisp" "-e" "(print :ok)"
                 "-E" "cl:identity" "-o" "./out-bin"))))
    (is (equal (getf cfg :systems) '("elmtui")))
    (is (= (length (getf cfg :files)) 1))
    (is (equal (getf cfg :evals) '("(print :ok)")))
    (is (string= (getf cfg :entry) "cl:identity"))
    (is (pathnamep (getf cfg :output)))))

(test parse-args-help
  (let ((cfg (elmtui.packager::%parse-args '("--help"))))
    (is (getf cfg :help))))

(test parse-args-rejects-unknown-option
  (signals error
    (elmtui.packager::%parse-args '("--bogus" "x"))))

(test resolve-entry-function-works
  (let ((fn (elmtui.packager::%resolve-entry-function "cl:identity")))
    (is (functionp fn))
    (is (eq (funcall fn :x) :x))))

(test validate-required-options
  (signals error
    (elmtui.packager::%validate-required-options '(:entry nil :output #P"./x")))
  (signals error
    (elmtui.packager::%validate-required-options '(:entry "cl:identity" :output nil))))

(test normalize-example-name-strips-lisp-suffix
  (is (string= (normalize-example-name "fzy-picker.lisp") "fzy-picker"))
  (is (string= (normalize-example-name "fzy-picker") "fzy-picker")))

(test resolve-example-file-accepts-name-with-or-without-suffix
  (let ((plain (%resolve-example-file "fzy-picker"))
        (with-suffix (%resolve-example-file "fzy-picker.lisp")))
    (is (equal plain with-suffix))
    (is (pathnamep plain))))

(test default-output-path-uses-normalized-example-name
  (let ((p (%default-output-path "fzy-picker.lisp")))
    (is (pathnamep p))
    (is (string= (file-namestring p) "fzy-picker"))))

(test resolve-entry-symbol-supports-descriptive-example-filename
  (asdf:load-system "elmtui-examples")
  (let* ((pkg (find-package :elmtui.examples.tmux-idle))
         (resolved (elmtui.examples.runner::%resolve-entry-symbol pkg "tmux-idle-screensaver"))
         (expected (find-symbol "RUN-TMUX-IDLE" pkg)))
    (is (not (null resolved)))
    (is (eq resolved expected))))

(test parse-command-options-supports-output-and-backend
  (let ((opts (elmtui.examples.runner::%parse-command-options
               '("/tmp/example-bin" "--backend" "urxvt")
               :allow-output t)))
    (is (string= (getf opts :output-path) "/tmp/example-bin"))
    (is (eq (getf opts :backend-type) :URXVT))))

(test resolve-entry-symbol-prefers-run-over-main
  (asdf:load-system "elmtui-examples")
  (let* ((pkg (find-package :elmtui.examples.scroll-panel-demo))
         (resolved (elmtui.examples.runner::%resolve-entry-symbol pkg "scroll-panel-demo"))
         (expected (find-symbol "RUN-SCROLL-PANEL-DEMO" pkg)))
    (is (not (null resolved)))
    (is (eq resolved expected))))
