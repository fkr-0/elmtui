;;;===============================================================
;;; File: tests/elmtui-core-keymap-tests.lisp
;;; Tests for src/core/keymap.lisp
;;;===============================================================
(uiop:define-package :elmtui-tests.elmtui-core-keymap-tests
  (:use :cl :fiveam :alexandria)
  (:import-from :elmtui.core.keymap
                #:parse-key-string
                #:key-event->normalized-key
                #:normalized-key->string
                #:make-normalized-key
                #:normalized-key-key
                #:normalized-key-modifiers
                #:normalized-key=)
  (:import-from :elmtui.core.event-types
                #:make-key-event)
  (:export #:core-keymap-suite))

(in-package :elmtui-tests.elmtui-core-keymap-tests)

(def-suite core-keymap-suite
  :description "Tests for elmtui.core.keymap functions.")

(in-suite core-keymap-suite)

(test parse-key-string-simple-chars
  (is (normalized-key= (parse-key-string "a") (make-normalized-key :key #\a :modifiers nil)))
  (is (normalized-key= (parse-key-string "A") (make-normalized-key :key #\A :modifiers nil)))
  (is (normalized-key= (parse-key-string "7") (make-normalized-key :key #\7 :modifiers nil))))

(test parse-key-string-special-keys
  (is (normalized-key= (parse-key-string "Enter") (make-normalized-key :key :enter :modifiers nil)))
  (is (normalized-key= (parse-key-string "Esc") (make-normalized-key :key :escape :modifiers nil)))
  (is (normalized-key= (parse-key-string "Escape") (make-normalized-key :key :escape :modifiers nil)))
  (is (normalized-key= (parse-key-string "Space") (make-normalized-key :key :space :modifiers nil)))
  (is (normalized-key= (parse-key-string "Tab") (make-normalized-key :key :tab :modifiers nil)))
  (is (normalized-key= (parse-key-string "Backspace") (make-normalized-key :key :backspace :modifiers nil)))
  (is (normalized-key= (parse-key-string "Delete") (make-normalized-key :key :delete :modifiers nil)))
  (is (normalized-key= (parse-key-string "Up") (make-normalized-key :key :up :modifiers nil)))
  (is (normalized-key= (parse-key-string "F1") (make-normalized-key :key :f1 :modifiers nil)))
  (is (normalized-key= (parse-key-string "f12") (make-normalized-key :key :f12 :modifiers nil))))

(test parse-key-string-with-modifiers
  (is (normalized-key= (parse-key-string "C-a")
                       (make-normalized-key :key #\a :modifiers '(:ctrl))))
  (is (normalized-key= (parse-key-string "Ctrl-A")
                       (make-normalized-key :key #\A :modifiers '(:ctrl))))
  (is (normalized-key= (parse-key-string "S-Tab")
                       (make-normalized-key :key :tab :modifiers '(:shift))))
  (is (normalized-key= (parse-key-string "Alt-Enter")
                       (make-normalized-key :key :enter :modifiers '(:alt))))
  (is (normalized-key= (parse-key-string "M-x")
                       (make-normalized-key :key #\x :modifiers '(:alt))))
  (is (normalized-key= (parse-key-string "C-S-F1")
                       (make-normalized-key :key :f1 :modifiers '(:ctrl :shift))))
  (is (normalized-key= (parse-key-string "Ctrl+Shift+delete")
                       (make-normalized-key :key :delete :modifiers '(:ctrl :shift)))))

(test parse-key-string-modifier-order-and-case
  (is (normalized-key= (parse-key-string "S-C-b")
                       (make-normalized-key :key #\b :modifiers '(:ctrl :shift))))
  (is (normalized-key= (parse-key-string "shift-ctrl-B")
                       (make-normalized-key :key #\B :modifiers '(:ctrl :shift)))))

(test key-event-to-normalized-key-conversion
  (is (normalized-key= (key-event->normalized-key (make-key-event :key :enter :modifiers nil))
                       (make-normalized-key :key :enter :modifiers nil)))
  (is (normalized-key= (key-event->normalized-key (make-key-event :key :a :char #\a :modifiers '(:control)))
                       (make-normalized-key :key #\a :modifiers '(:ctrl))))
  (is (normalized-key= (key-event->normalized-key (make-key-event :key :A :char #\A :modifiers '(:shift :alt)))
                       (make-normalized-key :key #\A :modifiers '(:alt :shift))))
  (is (normalized-key= (key-event->normalized-key (make-key-event :key :f5 :modifiers '(:shift :control)))
                       (make-normalized-key :key :f5 :modifiers '(:ctrl :shift)))))

(test normalized-key-to-string-conversion
  (is (string= (normalized-key->string (make-normalized-key :key #\a :modifiers nil)) "a"))
  (is (string= (normalized-key->string (make-normalized-key :key :enter :modifiers nil)) "Enter"))
  (is (string= (normalized-key->string (make-normalized-key :key #\x :modifiers '(:ctrl))) "Ctrl-x"))
  (is (string= (normalized-key->string (make-normalized-key :key :f1 :modifiers '(:alt :shift))) "Alt-Shift-F1"))
  (is (string= (normalized-key->string (make-normalized-key :key #\Z :modifiers '(:shift :ctrl :alt))) "Alt-Ctrl-Shift-Z")))

(test parse-key-string-errors
  (signals error (parse-key-string "C--a")) ; Multiple separators
  (signals error (parse-key-string "Ctrl-Alt")) ; No key part
  (signals error (parse-key-string "C-x-y")) ; Multiple key parts
  (finishes (warn "Unrecognized special key name: ~S in ~S. Treating as keyword." "UnknownKey" "UnknownKey")))
