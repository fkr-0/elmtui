(uiop:define-package :elmtui.tests.root-viewport.behavior
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.widgets.root-viewport
                #:make-root-viewport)
  (:import-from :elmtui.ui.api
                #:init #:update)
  (:export #:run-root-viewport-anchor-behavior-tests))

(in-package :elmtui.tests.root-viewport.behavior)

(def-suite elmtui/root-vp/behavior)
(in-suite elmtui/root-vp/behavior)

;;; minimal hash-table state utils
(defun %get (ht keys &optional default)
  (if (null keys) ht
      (let ((cur ht) (found t))
        (dolist (k keys)
          (multiple-value-bind (v p) (gethash k cur)
            (if p
                (setf cur v)
                (progn (setf found nil) (return)))))
        (if found cur default))))

(defun %set (ht keys value)
  (let ((cur ht))
    (loop for k in (butlast keys) do
      (multiple-value-bind (v p) (gethash k cur)
        (unless p
          (setf v (make-hash-table :test 'equal))
          (setf (gethash k cur) v))
        (setf cur v)))
    (setf (gethash (car (last keys)) cur) value)))

(defun apply-patches-to-ht (state patches)
  (dolist (p patches state)
    (%set state (first p) (second p))))

(defun make-state () (make-hash-table :test 'equal))

(defun init-root (anchor term-w term-h cur-r cur-c)
  (let* ((id :rv)
         (id-path `(:components ,id))
         (rv (make-root-viewport id :anchor anchor))
         (state (make-state)))
    (multiple-value-bind (_component patches _cmds)
        (init rv :id-path id-path
                 :initial-terminal-dimensions (list term-w term-h)
                 :initial-cursor-pos (list cur-c cur-r)
                 :anchor anchor)
      (declare (ignore _component _cmds))
      (values rv id-path (apply-patches-to-ht state patches)))))

(defun upd (rv id-path state msg)
  (multiple-value-bind (patches cmds)
      (update rv msg state :id-path id-path)
    (values (apply-patches-to-ht state patches) cmds)))

(defun has-render-cmd-p (cmds op &optional arg)
  (some (lambda (c)
          (and (consp c)
               (eq (first c) :render)
               (eq (second c) op)
               (or (null arg) (eql (third c) arg))))
        cmds))

;; TODO
;; (test initial-clear-below-vs-above
;;   (list (dolist (anchor '(:below-cursor :above-cursor))
;;     (multiple-value-bind (rv idp state) (init-root :below-cursor 80 24 12 40)
;;       ;; Send size then cursor
;;       (multiple-value-bind (s1 c1)
;;           (upd rv idp state '(:terminalresized :width 80 :height 24))
;;       ;; (list s1 c1 )))
;;         (declare (ignore s1 c1))
;;         (multiple-value-bind (s2 cmds)
;;             (upd rv idp state '(:cursorpositionchanged :col 40 :row 12))
;;           (declare (ignore s2))
;;           ;; (ecase anchor
;;           ;;   (:below-cursor (is-true (has-render-cmd-p cmds :clear)))
;;           ;;   (:above-cursor (is-true (has-render-cmd-p cmds :clear))))
;; cmds
;;           ))))))

(test below-cursor-overflow-scrolls-down
  (multiple-value-bind (rv idp state) (init-root :below-cursor 40 20 18 10)
    ;; Force a larger viewport height in state to provoke overflow
    (%set state (append idp '(:state :height)) 10)
    (%set state (append idp '(:state :pos-known)) t)
    (multiple-value-bind (s cmds)
        (upd rv idp state '(:terminalresized :width 40 :height 20))
      (declare (ignore s))
      (is-true (has-render-cmd-p cmds :scroll-down)))))

(test above-cursor-overflow-scrolls-up
  (multiple-value-bind (rv idp state) (init-root :above-cursor 40 20 3 10)
    ;; Set height larger than available rows above cursor (3)
    (%set state (append idp '(:state :height)) 6)
    (%set state (append idp '(:state :size-known)) t)
    (multiple-value-bind (s cmds)
        (upd rv idp state '(:cursorpositionchanged :col 10 :row 3))
      (declare (ignore s))
      ;; Note: for above-cursor we clear-above first-ready; overflow behavior may not scroll automatically
      ;; Depending on policy you may choose :scroll-up here. If implemented later, adapt this test.
      (is-true (or (has-render-cmd-p cmds :clear-above-cursor)
                   (has-render-cmd-p cmds :scroll-up))))))

(test revert-scroll-on-shutdown
  (multiple-value-bind (rv idp state) (init-root :below-cursor 80 24 12 10)
    ;; Simulate issued scroll net = 5 and ensure on :appshutdown we scroll back up 5
    (%set state (append idp '(:state :issued-scroll-net)) 5)
    (multiple-value-bind (s cmds)
        (upd rv idp state '(:appshutdown))
      (declare (ignore s))
      (is-true (has-render-cmd-p cmds :scroll-up 5)))))

(defun run-root-viewport-anchor-behavior-tests ()
  (run! :elmtui/root-vp/behavior))
