;;;===============================================================
;;; File: tests/v2/test-events.lisp
;;; FiveAM Unit Tests for elmtui.core.event-types, event-propagation, event-async
;;;===============================================================

(uiop:define-package :elmtui-test-events
  (:use :cl :fiveam)
  (:import-from :elmtui.core.event-types
                #:make-ui-event #:ui-event-p #:ui-event-type #:ui-event-target
                #:ui-event-consumed-p #:stop-propagation #:prevent-default
                #:make-key-event #:key-event-p #:key-event-type #:key-event-key
                #:key-event-modifiers #:valid-key-event-p #:normalize-key-event
                #:make-mouse-event #:mouse-event-p #:mouse-event-type #:mouse-event-x
                #:mouse-event-y #:mouse-event-button #:valid-mouse-event-p #:normalize-mouse-event)
  (:import-from :elmtui.core.event-propagation
                #:find-ui-node-by-id #:get-ui-tree-path #:dispatch-event)
  (:import-from :elmtui.core.event-async
                #:initialize-event-channels #:dispatch-event-async #:schedule-event)
  (:export :run-elmtui-test-events))

(in-package :elmtui-test-events)

(def-suite elmtui-test-events-suite
  :description "Unit tests for elmtui.core event system")
(in-suite elmtui-test-events-suite)

;;; --- Event Types ---

(test ui-event-struct
  (let ((evt (make-ui-event :type :foo :target :bar)))
    (is (ui-event-p evt))
    (is (eq (ui-event-type evt) :foo))
    (is (eq (ui-event-target evt) :bar))
    (is (not (ui-event-consumed-p evt)))
    (stop-propagation evt)
    (is (ui-event-consumed-p evt))))

(test key-event-struct
  (let ((evt (make-key-event :type :key-down :key #\a :modifiers '(:ctrl))))
    (is (key-event-p evt))
    (is (eq (key-event-type evt) :key-down))
    (is (eq (key-event-key evt) #\a))
    (is (equal (key-event-modifiers evt) '(:ctrl)))
    (is (valid-key-event-p evt)))
  ;; Normalization
  (let ((norm (normalize-key-event '(:type :key-up :key :enter :modifiers ("ctrl" :alt)))))
    (is (key-event-p norm))
    (is (eq (key-event-type norm) :key-up))
    (is (eq (key-event-key norm) :enter))
    (is (member :ctrl (key-event-modifiers norm)))
    (is (member :alt (key-event-modifiers norm)))))

(test mouse-event-struct
  (let ((evt (make-mouse-event :type :mouse-down :x 10 :y 20 :button :left)))
    (is (mouse-event-p evt))
    (is (eq (mouse-event-type evt) :mouse-down))
    (is (= (mouse-event-x evt) 10))
    (is (= (mouse-event-y evt) 20))
    (is (eq (mouse-event-button evt) :left))
    (is (valid-mouse-event-p evt)))
  ;; Normalization
  (let ((norm (normalize-mouse-event '(:type :mouse-up :x 5 :y 6 :button 2 :modifiers ("shift")))))
    (is (mouse-event-p norm))
    (is (eq (mouse-event-type norm) :mouse-up))
    (is (= (mouse-event-x norm) 5))
    (is (= (mouse-event-y norm) 6))
    (is (eq (mouse-event-button norm) :right))
    (is (member :shift (slot-value norm 'elmtui.core.event-types::modifiers)))))

;;; --- Event Propagation ---

(defstruct dummy-node
  id
  children)

(defun make-dummy-ui-tree ()
  ;; root -> a -> b
  (let* ((b (make-dummy-node :id :b :children nil))
         (a (make-dummy-node :id :a :children (list b)))
         (root (make-dummy-node :id :root :children (list a))))
    root))

(test find-ui-node-by-id-and-path
  (let ((tree (make-dummy-ui-tree)))
    (is (eq (elmtui.core.event-propagation::find-ui-node-by-id tree :root) tree))
    (is (eq (elmtui.core.event-propagation::find-ui-node-by-id tree :a) (second (dummy-node-children tree))))
    (is (eq (elmtui.core.event-propagation::find-ui-node-by-id tree :b)
            (first (dummy-node-children (second (dummy-node-children tree))))))
    ;; Path
    (let ((path (elmtui.core.event-propagation::get-ui-tree-path tree :b)))
      (is (= (length path) 3))
      (is (eq (first path) tree))
      (is (eq (second path) (second (dummy-node-children tree))))
      (is (eq (third path) (first (dummy-node-children (second (dummy-node-children tree)))))))))

;;; --- Event Async (smoke test) ---

;; (test event-async-channels
;;   (initialize-event-channels)
;;   (is (boundp 'elmtui.core.event-async::*main-event-channel*))
;;   (is (boundp 'elmtui.core.event-async::*key-event-channel*))
;;   (is (boundp 'elmtui.core.event-async::*mouse-event-channel*))
;;   (is (boundp 'elmtui.core.event-async::*ui-event-channel*)))

;; (test event-async-dispatch
;;   (initialize-event-channels)
;;   (let ((evt (make-ui-event :type :foo)))
;;     (dispatch-event-async evt :normal)
;;     ;; Can't easily test async delivery without a running event loop,
;;     ;; but at least ensure no error is signaled.
;;     (is t)))

(defun run-elmtui-test-events ()
  (fiveam:run! 'elmtui-test-events-suite))
