(uiop:define-package :elmtui.tests.tmux-capture
  (:use :cl :fiveam)
  (:import-from :elmtui.platform.tmux
                #:split-by-ansi-sequences
                #:parse-ansi-sgr
                #:parse-ansi-string)
  (:export #:tmux-capture-tests))

(in-package :elmtui.tests.tmux-capture)

(def-suite tmux-capture-tests
  :in elmtui.tests:elmtui-test
  :description "Tests for tmux screen capture module")

(in-suite tmux-capture-tests)

(test split-by-ansi-simple
  "Splitting a string with ANSI escape sequences works correctly"
  (let* ((input "Hello\e[31mWorld\e[0m!")
         (result (split-by-ansi-sequences input)))
    (is (= (length result) 3))
    (is (string= (first result) "Hello"))
    (is (string= (second result) "\e[31m"))
    (is (string= (third result) "World\e[0m!"))))
