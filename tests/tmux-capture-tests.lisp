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
  (let* ((input (concatenate 'string "Hello" (format nil "~C[31m" #\Escape) "World" (format nil "~C[0m" #\Escape) "!"))
         (result (split-by-ansi-sequences input)))
    ;; Result: ("Hello" "^[31m" "World" "^[0m" "!")
    (is (= (length result) 5))
    (is (string= (first result) "Hello"))
    (is (string= (second result) (format nil "~C[31m" #\Escape)))
    (is (string= (third result) "World"))
    (is (string= (fourth result) (format nil "~C[0m" #\Escape)))
    (is (string= (fifth result) "!"))))
