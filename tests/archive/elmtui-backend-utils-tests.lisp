;;;===============================================================
;;; File: tests/elmtui-backend-utils-tests.lisp
;;; FiveAM Unit Tests for Backend Common Utils (ANSI parsing, utils, etc.)
;;;===============================================================

(uiop:define-package :elmtui-backend-utils-tests
  (:use :cl :fiveam
        :elmtui.backend.common.utils)
  (:export :run-elmtui-backend-utils-tests))

(in-package :elmtui-backend-utils-tests)

(def-suite elmtui-backend-utils-suite
  :description "Unit tests for elmtui.backend.common.utils (ANSI, parsing, helpers)")
(in-suite elmtui-backend-utils-suite)

;;; Introducer tests
(test introducer-key-basic
  (is (eq (introducer-key 91) :CSI)) ; 91 = #x5B = '[', should map to :CSI
  (is (eq (introducer-key 80) :DCS)) ; 80 = #x50 = 'P', should map to :DCS
  (is (null (introducer-key 255))))

;;; CSI final byte check
(test csi-final-byte
  (is (is-csi-final-byte? 64))
  (is (is-csi-final-byte? 126))
  (is (not (is-csi-final-byte? 32))))

;;; Split sequence utility
(test split-seq-if
  (is (equal (split-seq-if #'digit-char-p "a1b2c3") '("a" "1" "b" "2" "c" "3"))))

;;; Parameter parsing
(test parse-parameters
  (is (equal (parse-parameters '(#\1 #\2 #\; #\3 #\4)) '(12 34)))
  (is (equal (parse-parameters '(#\;)) '())))

;;; Clamp utility (from ui.widgets.utils)
(test clamp-util
  (is (= (elmtui.view.layout.flex:clamp 5 1 10) 5))
  (is (= (elmtui.view.layout.flex:clamp -1 0 3) 0))
  (is (= (elmtui.view.layout.flex:clamp 99 0 10) 10)))

;;; Focusable ID collection utility
(test collect-focusable-ids
  (let* ((node (make-instance 'elmtui.view.core:ui-node
                              :props '(:widget-id :foo :focusable t)
                              :children (list (make-instance 'elmtui.view.core:ui-node
                                                             :props '(:widget-id :bar :focusable t)
                                                             :children nil)))))
    (is (equal (elmtui.core.focus::collect-focusable-ids node) '(:foo :bar)))))

;;; ANSI sequence lookup (basic)
(test ansi-sequence-lookup
  (is (null (get-sequence :NONEXISTENT)))
  (is (functionp #'get-sequence)))

;;; SGR parameter parsing (basic)
(test parse-sgr-parameters
  (is (listp (parse-sgr-parameters '(1 31 44))))
  (is (listp (parse-sgr-parameters '()))))

;;; Run all tests
(defun run-elmtui-backend-utils-tests ()
  (fiveam:run! 'elmtui-backend-utils-suite))
