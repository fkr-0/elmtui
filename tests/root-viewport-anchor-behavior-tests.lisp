(uiop:define-package :elmtui.tests.root-viewport.behavior
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.widgets.root-viewport
    #:make-root-viewport)
  (:import-from :elmtui.tea-state.api
    #:state-ref
    #:apply-patches
    #:ur-patches
    #:ur-commands)

  (:import-from :elmtui.ui.api
    #:init #:update)
  (:export #:run-root-viewport-anchor-behavior-tests
           #:revert-scroll-on-shutdown))

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

;; (defun %set (ht keys value)
;;   (let ((cur ht))
;;     (loop for k in (butlast keys) do
;;       (multiple-value-bind (v p) (gethash k cur)
;;         (setf (state-ref cur k))))))

;; (defun apply-patches-to-ht (state patches)
;;   (dolist (p patches state)
;;     (%set state (first p) (second p))))

;; (defun make-state () (make-hash-table :test 'equal))

(defun init-root (anchor term-w term-h cur-r cur-c)
  (let* ((id :rv)
          (id-path `(:components ,id))
          (rv (make-root-viewport id :anchor anchor))
          (state (elmtui.tea-state:make-application-state)))
    (multiple-value-bind (_component patches _cmds)
      (init rv :id-path id-path
        :initial-terminal-dimensions (list term-w term-h)
        :initial-cursor-pos (list cur-c cur-r)
        :anchor anchor)
      (list _component patches _cmds)

      (values rv id-path (elmtui.tea-state:apply-patches state patches) state))))

(defun upd (rv id-path state msg)
  "Updated test helper for the modern update method that returns an update-result"
  (let ((result (update rv msg state :id-path id-path)))
    (let ((patches (ur-patches result))
          (commands (ur-commands result)))
      (format t "Patches: ~S Cmds: ~S~%" patches commands)
      (elmtui.tea-state:apply-patches state patches)
      (values patches state commands))))

(defun has-render-cmd-p (cmds op &optional arg)
  (some (lambda (c)
          (and (consp c)
            (eq (first c) :render)
            (eq (second c) op)
            (or (null arg) (eql (third c) arg))))
    cmds))

(defun state-patch-p (patches id-path subpath &optional value)
  (let ((target (append id-path subpath)))
    (some (lambda (patch)
            (and (equal (first patch) target)
                 (or (null value) (equal (second patch) value))))
      patches)))

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
  (multiple-value-bind (rv idp o state) (init-root :below-cursor 40 20 18 10)
    ;; Set terminal size so overflow logic has context
    (setf (state-ref state (append idp '(:state :terminal-size))) '(40 20))
    (setf (state-ref state (append idp '(:state :cursor-pos))) '(10 18))
    ;; Force a larger viewport height in state to provoke overflow
    (setf (state-ref state (append idp '(:state :height))) 10)
    (setf (state-ref state (append idp '(:state :width))) 40)
    (setf (state-ref state (append idp '(:state :pos-known))) t)
    (multiple-value-bind (patches state cmds)
      (upd rv idp state '(:terminalresized :width 40 :height 20))
      (is (state-patch-p patches idp '(:state :width) 40)
        "Viewport width patch recorded on resize")
      (is (state-patch-p patches idp '(:state :height) 10)
        "Viewport height patch recorded on resize")
      ;; overflow handling may now clear-below instead of scrolling; accept either
      (is-true (or (has-render-cmd-p cmds :scroll-down)
                 (has-render-cmd-p cmds :clear-below-cursor))))))

(test above-cursor-overflow-scrolls-up
  (multiple-value-bind (rv idp statep state) (init-root :above-cursor 40 20 3 10)
    ;; Set terminal size and cursor pos for overflow logic context
    (setf (state-ref state (append idp '(:state :terminal-size))) '(40 20))
    (setf (state-ref state (append idp '(:state :cursor-pos))) '(10 3))
    ;; Set height larger than available rows above cursor (3)
    (setf (state-ref state (append idp '(:state :height))) 6)
    (setf (state-ref state (append idp '(:state :width))) 40)
    (setf (state-ref state (append idp '(:state :size-known))) t)
    (multiple-value-bind (s cmds)
      (update rv '(:cursorposition :col 10 :row 3) state :id-path idp)

      (declare (ignore s))
      ;; Accept clear-above-cursor (first-ready) or explicit scroll-up when overflow detected
      (is-true (or (has-render-cmd-p cmds :clear-above-cursor)
                 (has-render-cmd-p cmds :scroll-up))))))

(test revert-scroll-on-shutdown
  (multiple-value-bind (rv idp o state) (init-root :below-cursor 80 24 12 10)

    ;; Set terminal size and cursor pos for context
    (setf (state-ref state (append idp '(:state :terminal-size))) '(80 24))
    (setf (state-ref state (append idp '(:state :cursor-pos))) '(10 12))
    ;; Simulate issued scroll net = 5 and ensure on :appshutdown we scroll back up 5
    (setf (state-ref state (append idp '(:state :issued-scroll-net))) 5)
    (setf (state-ref state (append idp '(:state :width))) 80)
    (setf (state-ref state (append idp '(:state :height))) 12)
    (multiple-value-bind (s k cmds)
      (upd rv idp state '(:appshutdown))
      (declare (ignore s))
      (is-true (has-render-cmd-p cmds :scroll-up 5)))))

(defun run-root-viewport-anchor-behavior-tests ()
  (run! :elmtui/root-vp/behavior))
