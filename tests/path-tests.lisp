(uiop:define-package :elmtui.tests.path
  (:use :cl :fiveam :elmtui.contracts :elmtui.pipeline :elmtui.tea-state.state
   :elmtui.utils)
  (:import-from :elmtui.view.core #:ui-node-p)
  (:import-from :elmtui.view.styled #:styled-ui-node-p)
  (:import-from :elmtui.pipeline
                #:generate-dsl)

  (:import-from :elmtui.view.geo #:make-rectangle #:w #:h #:rectangle #:make-size
                #:make-pos)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-terminal-buffer-p
                #:make-virtual-buffer)
  (:import-from :elmtui.examples.rainbow-app
                #:rainbow-content-view
                #:rainbow-stylesheet))
(in-package :elmtui.tests.path)

(def-suite path-suite
  :in elmtui.tests:elmtui-test
  :description "Tests for the rendering pipeline contracts.")
(in-suite path-suite)
;;; helpers ---------------------------------------------------------------

(defun make-mixed-container ()
  "Return a three‑level structure mixing hash‑table + plist."
  (let* ((level3 (list :value '(1 2 3)))
         (level2 (make-hash-table :test 'equal)))
    (setf (gethash :c level2) level3)
    (list :a level2)))                             ; plist at top → {:a level2}

(test pathtests-get-path-basic
  (let* ((ht (make-hash-table :test 'equal)))
    (set-path ht '(:x :y :z) 42)                 ; create intermediate nodes
    ;; ht)
    (is (= 42 (get-path '(:x :y :z) ht)))
    (is (= 42 (get-path '(:y :z) (gethash :x ht))))
    ;; symbol == single‑elem list
    (is (eq (get-path :x ht) (get-path '(:x) ht)))
    ;; default when missing
    (is (eql :dflt (get-path '(:missing :path) ht :dflt)))))

(test pathtests-set-path-createp-nil
  (let ((ht (make-hash-table)))
    (signals error (set-path ht '(:k :missing) :val :createp nil))))

(test pathtests-mixed-container-roundtrip
  (let* ((root (make-mixed-container)))
    (is (equal '(1 2 3) (get-path '(:a :c :value) root)))
    ;; update
    (set-path root '(:a :c :value) '(:new 99))
    (is (equal '(:new 99) (get-path '(:a :c :value) root)))))

;;; ───────────────────────── remove-path ─────────────────────────────────

(test pathtests-remove-path-leaf
  (let* ((root (make-mixed-container)))
    (multiple-value-bind (new removedp)
        (remove-path root '(:a :c :value))
      (is-true removedp)
      ;; value gone
      (is-true (null (get-path '(:a :c :value) new nil))))))

(test pathtests-remove-path-prune-empty-flag
  (let* ((root (make-mixed-container)))
    ;; remove with prune‑empty NIL  → keeps empty hash‑table
    (multiple-value-bind (new removedp)
        (remove-path root '(:a :c :value) :prune-empty nil)
      (is-true removedp)
      (is (typep (get-path '(:a) new) 'hash-table)))
    ;; prune‑empty T  → branch disappears
    (multiple-value-bind (new removedp)
        (remove-path root '(:a :c) :prune-empty t)
      (is-true removedp)
      (is (null (get-path '(:a :c) new nil))))))

;;; ───────────────────── state-ref / logging ─────────────────────────────

(test pathtests-state-ref-basic
  (let ((state (make-application-state)))
    (setf (state-ref state '(:lvl1 :lvl2)) 99)
    ;; (is (= 99 (state-ref state '(:lvl1 :lvl2))))
    ;; symbol vs list
    (setf (state-ref state :flag) t)

    (is (eq t (state-ref state '(:flag))))))

(test pathtests-logging-and-version
  (let ((state (make-application-state)))
    ;; empty log
    (is (null (application-state-log state)))
    (is (= 0 (state-ref state '(:version) 0)))          ; no :version yet
    ;; mutation through (setf state-ref)
    (setf (state-ref state '(:foo)) 1)
    (is (= 1 (length (application-state-log state))))
    (destructuring-bind (key old new) (first (application-state-log state))
      (is (equal '(:foo) key))
      (is (eql :not-present old))
      (is (= 1 new)))
    ;; wrapper behaves identically
    (elmtui.tea-state.state::state-set state '(:foo) 2)
    (is (= 2 (state-ref state '(:foo))))
    (is (= 2 (length (application-state-log state))))))
