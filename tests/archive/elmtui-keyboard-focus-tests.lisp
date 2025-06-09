;; ;;; Tests for the integrated keyboard and focus management system
;; ;;;===============================================================
;; (uiop:define-package :elmtui.tests.keyboard-focus
;;   (:use :cl :fiveam :alexandria)
;;   (:import-from :elmtui.core.keymap
;;    :normalized-key
;;                 :make-normalized-key
;;    :key-event->normalized-key
;;                 :parse-key-string)
;;   (:import-from :elmtui.core.keymap.registry
;;    :register-keymap
;;                 :find-keymap
;;    :lookup-key-binding)
;;   (:import-from :elmtui.core.keymap-system
;;    :initialize-keymap-system
;;                 :create-focus-manager
;;    :focus-element
;;                 :focus-next
;;    :focus-previous)
;;   (:import-from :elmtui.core.focus
;;    :make-focus-manager
;;                 :focus-manager-current-focus)
;;   (:import-from :elmtui.core.focus.directional
;;    :register-element-position
;;                 :navigate-direction))

;; (in-package :elmtui.tests.keyboard-focus)

;; ;; Define test suite
;; (def-suite elmtui-keyboard-focus-tests
;;   :description "Tests for the keyboard event system and focus management.")

;; (in-suite elmtui-keyboard-focus-tests)

;; ;;;-----------------------------------------------------------------------------
;; ;;; Keymap System Tests
;; ;;;-----------------------------------------------------------------------------

;; (test keymap-basics
;;   "Test basic keymap functionality"
;;   (let ((km (elmtui.core.keymap:make-keymap)))
;;     ;; Add a binding
;;     (setf (gethash (make-normalized-key :key #\x :modifiers '(:ctrl))
;;                    (elmtui.core.keymap:keymap-bindings km))
;;           '(:type :action :target my-action :description "Test"))

;;     ;; Look it up
;;     (let ((binding (elmtui.core.keymap:lookup-keymap
;;                     km
;;                     (make-normalized-key :key #\x :modifiers '(:ctrl)))))
;;       (is (equal (getf binding :type) :action))
;;       (is (equal (getf binding :target) 'my-action)))))

;; (test key-string-parsing
;;   "Test parsing key strings"
;;   (let ((key1 (parse-key-string "C-x"))
;;         (key2 (parse-key-string "S-F1"))
;;         (key3 (parse-key-string "Alt-Space")))

;;     (is (eq (elmtui.core.keymap::normalized-key-key key1) #\x))
;;     (is (equal (elmtui.core.keymap::normalized-key-modifiers key1) '(:ctrl)))

;;     (is (eq (elmtui.core.keymap::normalized-key-key key2) :f1))
;;     (is (equal (elmtui.core.keymap::normalized-key-modifiers key2) '(:shift)))

;;     (is (eq (elmtui.core.keymap::normalized-key-key key3) :space))
;;     (is (equal (elmtui.core.keymap::normalized-key-modifiers key3) '(:alt)))))

;; (test registry-functionality
;;   "Test keymap registry"
;;   (initialize-keymap-system)
;;   (let ((test-km (elmtui.core.keymap:make-keymap)))
;;     ;; Register a test keymap
;;     (register-keymap :test-map test-km)

;;     ;; Check if it can be found
;;     (is (eq (find-keymap :test-map) test-km))))

;; ;;;-----------------------------------------------------------------------------
;; ;;; Focus Management Tests
;; ;;;-----------------------------------------------------------------------------

;; (test basic-focus
;;   "Test basic focus management"
;;   (let ((fm (make-focus-manager)))
;;     ;; Register some focusable elements
;;     ;; (register-focusable fm :button1)
;;     ;; (register-focusable fm :button2)
;;     ;; (register-focusable fm :button3)

;;     ;; Test focus setting
;;     (focus-element fm :button1)
;;     (is (eq (focus-manager-current-focus fm) :button1))

;;     ;; Test focus navigation
;;     (focus-next fm)
;;     (is (eq (focus-manager-current-focus fm) :button2))

;;     (focus-previous fm)
;;     (is (eq (focus-manager-current-focus fm) :button1))))

;; (test directional-navigation
;;   "Test directional (arrow key) navigation"
;;   (let ((fm (make-focus-manager)))
;;     ;; Set focusable elements directly
;;     (setf (elmtui.core.focus:focus-manager-focusable-elements fm)
;;           (list :btn-top :btn-left :btn-center :btn-right :btn-bottom))

;;     ;; Set positions
;;     (register-element-position :btn-top :x 50 :y 10 :width 80 :height 20)
;;     (register-element-position :btn-left :x 10 :y 50 :width 80 :height 20)
;;     (register-element-position :btn-center :x 50 :y 50 :width 80 :height 20)
;;     (register-element-position :btn-right :x 90 :y 50 :width 80 :height 20)
;;     (register-element-position :btn-bottom :x 50 :y 90 :width 80 :height 20)

;;     ;; Start with center button
;;     (focus-element fm :btn-center)

;;     ;; Test navigation in each direction
;;     (navigate-direction fm :up)
;;     (is (eq (focus-manager-current-focus fm) :btn-top))

;;     (focus-element fm :btn-center)
;;     (navigate-direction fm :down)
;;     (is (eq (focus-manager-current-focus fm) :btn-bottom))

;;     (focus-element fm :btn-center)
;;     (navigate-direction fm :left)
;;     (is (eq (focus-manager-current-focus fm) :btn-left))

;;     (focus-element fm :btn-center)
;;     (navigate-direction fm :right)
;;     (is (eq (focus-manager-current-focus fm) :btn-right))))

;; ;;;-----------------------------------------------------------------------------
;; ;;; Run Tests
;; ;;;-----------------------------------------------------------------------------

;; ;; ;;;===============================================================
;; ;; ;;; File: tests/e(test basic-focus-management
;; ;;   "Test basic focus management"
;; ;;   (let ((fm (make-focus-manager)))
;; ;;     ;; Set focusable elements directly
;; ;;     ;; (In the new system, these would typically be populated by
;; ;;     ;; recalculate-focusable-elements from the UI tree)
;; ;;     (setf (elmtui.core.focus:focus-manager-focusable-elements fm)
;; ;;           (list :button1 :button2 :button3))

;; ;;     ;; Test focus setting
;; ;;     (focus-element fm :button1)
;; ;;     (is (eq (focus-manager-current-focus fm) :button1))

;; ;;     ;; Test focus navigation
;; ;;     (focus-next fm)
;; ;;     (is (eq (focus-manager-current-focus fm) :button2))

;; ;;     (focus-previous fm)
;; ;;     (is (eq (focus-manager-current-focus fm) :button1))))us-tests.lisp
;; (defun run-elmtui-keyboard-focus-tests ()
;;   (run! 'elmtui-keyboard-focus-tests))
