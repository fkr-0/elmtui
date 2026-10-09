(uiop:define-package :elmtui.tests.root-viewport.behavior
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.widgets.root-viewport
    #:make-root-viewport)
  (:import-from :elmtui.state.api
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

(test zero-dimension-startup-never-queues-zero-scroll
  "A cursor report before terminal dimensions must not reserve a phantom effect."
  (multiple-value-bind (rv idp ignored state)
      (init-root :below-cursor 100 35 2 1)
    (declare (ignore ignored))
    (setf (state-ref state (append idp '(:terminal-size))) '(0 0)
          (state-ref state (append idp '(:size-known))) nil
          (state-ref state (append idp '(:height))) 13)
    (upd rv idp state '(:cursorposition :col 1 :row 2))
    (is (null (state-ref state (append idp '(:pending-scroll-ops)))))
    (is (= 0 (state-ref state (append idp '(:issued-scroll-net)))))
    (upd rv idp state '(:terminalresized :width 100 :height 35))
    (is (null (state-ref state (append idp '(:pending-scroll-ops)))))
    (is (consp (elmtui.ui.api:view rv state :id-path idp)))))

(test below-cursor-bottom-row-reserves-every-viewport-row
  "For a zero-indexed last-row cursor, there are no rows below the cursor."
  (multiple-value-bind (height issued commands)
      (elmtui.ui.widgets.root-viewport::%overflow-effects
       :below-cursor 20 35 34 :scroll 0)
    (is (null height))
    (is (= 20 issued))
    (is (equal '((:render :scroll-down 20)) commands)))
  (multiple-value-bind (height issued commands)
      (elmtui.ui.widgets.root-viewport::%overflow-effects
       :below-cursor 20 35 33 :scroll 0)
    (is (null height))
    (is (= 19 issued))
    (is (equal '((:render :scroll-down 19)) commands))))

(defclass root-vp-mock-child (elmtui.ui.api:component) ())

(defmethod elmtui.ui.dsl-resolution:dsl-type ((type (eql :root-vp-mock-child)) &optional props)
  (declare (ignore props))
  (values 'root-vp-mock-child nil))

(defmethod elmtui.ui.api:update ((component root-vp-mock-child) msg app-state &key id-path)
  (declare (ignore component app-state))
  (elmtui.state.api:make-update-result
    :patches (list (list (append id-path '(:child-handled-msg)) msg))))

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
          (state (elmtui.state:make-application-state)))
    (multiple-value-bind (_component patches _cmds)
      (init rv :id-path id-path
        :initial-terminal-dimensions (list term-w term-h)
        :initial-cursor-pos (list cur-c cur-r)
        :anchor anchor)
      (list _component patches _cmds)

      (values rv id-path (elmtui.state:apply-patches state patches) state))))

(defun upd (rv id-path state msg)
  "Updated test helper for the modern update method that returns an update-result"
  (let ((result (update rv msg state :id-path id-path)))
    (let ((patches (ur-patches result))
          (commands (ur-commands result)))
      (elmtui.state:apply-patches state patches)
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
    (declare (ignore o))
    ;; Set terminal size so overflow logic has context
    (setf (state-ref state (append idp '(:terminal-size))) '(40 20))
    (setf (state-ref state (append idp '(:cursor-pos))) '(10 18))
    ;; Force a larger viewport height in state to provoke overflow
    (setf (state-ref state (append idp '(:height))) 10)
    (setf (state-ref state (append idp '(:width))) 40)
    (setf (state-ref state (append idp '(:pos-known))) t)
    (multiple-value-bind (patches state cmds)
      (upd rv idp state '(:terminalresized :width 40 :height 20))
      (declare (ignore state))
      (is (state-patch-p patches idp '(:width) 40)
        "Viewport width patch recorded on resize")
      (is (state-patch-p patches idp '(:height) 10)
        "Viewport height patch recorded on resize")
      (is-true (has-render-cmd-p cmds :scroll-down)))))

(test bottom-row-scroll-acknowledgment-reanchors-without-repeating
  "A bottom-row anchor must wait for scrolling and then use the shifted anchor."
  (multiple-value-bind (rv idp _ state) (init-root :below-cursor 20 10 10 1)
    (declare (ignore _))
    (setf (state-ref state (append idp '(:height))) 4)
    (multiple-value-bind (patches updated commands)
        (upd rv idp state '(:terminalresized :width 20 :height 10))
      (declare (ignore patches updated))
      (is-true (has-render-cmd-p commands :scroll-down 4)))
    (is (equal '(4) (state-ref state (append idp '(:pending-scroll-ops)))))
    (is (null (elmtui.ui.api:view rv state :id-path idp))
        "Do not paint into rows which are still awaiting scroll completion")
    (multiple-value-bind (patches updated commands)
        (upd rv idp state '(:terminalresized :width 20 :height 10))
      (declare (ignore patches updated))
      (is (not (has-render-cmd-p commands :scroll-down))
          "An outstanding scroll suppresses duplicate requests"))
    (upd rv idp state '(:terminal-scrolled :direction :down :amount 4))
    (is (null (state-ref state (append idp '(:pending-scroll-ops)))))
    (is (= 0 (state-ref state (append idp '(:issued-scroll-net)))))
    (is (= 4 (state-ref state (append idp '(:scrolled-net)))))
    (is (equal '(1 6) (state-ref state (append idp '(:cursor-pos)))))
    ;; An actual terminal cursor-position report is *physical*. CSI S
    ;; moves pane content but does not move that hardware cursor.
    (multiple-value-bind (patches updated commands)
        (upd rv idp state '(:cursorposition :col 1 :row 10))
      (declare (ignore patches updated))
      (is (not (has-render-cmd-p commands :scroll-down))
          "Re-probing the physical cursor must not reserve another scroll"))
    (is (equal '(1 6) (state-ref state (append idp '(:cursor-pos))))
        "Logical content anchor remains shifted after a physical cursor probe")
    (is (consp (elmtui.ui.api:view rv state :id-path idp))
        "Layout is now permitted after the anchor was shifted")
    (multiple-value-bind (patches updated commands)
        (upd rv idp state '(:terminalresized :width 20 :height 10))
      (declare (ignore patches updated))
      (is (not (has-render-cmd-p commands :scroll-down))
          "The new cursor-relative anchor already has room for all four rows"))))

(test scroll-acknowledgment-must-match-ordered-request
  "Unsolicited and failed scrolls must not corrupt anchored geometry."
  (multiple-value-bind (rv idp _ state) (init-root :below-cursor 20 10 10 1)
    (declare (ignore _))
    (setf (state-ref state (append idp '(:height))) 3)
    (upd rv idp state '(:terminalresized :width 20 :height 10))
    (is (equal '(3) (state-ref state (append idp '(:pending-scroll-ops)))))
    (upd rv idp state '(:terminal-scrolled :direction :up :amount 3))
    (is (equal '(3) (state-ref state (append idp '(:pending-scroll-ops)))))
    (is (equal '(1 10) (state-ref state (append idp '(:cursor-pos)))))
    (upd rv idp state '(:terminal-scroll-failed :direction :down :amount 3))
    (is (null (state-ref state (append idp '(:pending-scroll-ops)))))
    (is (= 0 (state-ref state (append idp '(:issued-scroll-net)))))
    (is (= 0 (state-ref state (append idp '(:scrolled-net)))))
    (is (state-ref state (append idp '(:scroll-effect-failed))))
    (is (null (elmtui.ui.api:view rv state :id-path idp))
        "Failed scrolling must not permit rendering into unavailable rows")))

(test above-cursor-overflow-scrolls-up
  (multiple-value-bind (rv idp statep state) (init-root :above-cursor 40 20 3 10)
    (declare (ignore statep))
    ;; Set terminal size and cursor pos for overflow logic context
    (setf (state-ref state (append idp '(:terminal-size))) '(40 20))
    (setf (state-ref state (append idp '(:cursor-pos))) '(10 3))
    ;; Set height larger than available rows above cursor (3)
    (setf (state-ref state (append idp '(:height))) 6)
    (setf (state-ref state (append idp '(:width))) 40)
    (setf (state-ref state (append idp '(:size-known))) t)
    (multiple-value-bind (patches new-state cmds)
        (upd rv idp state '(:cursorposition :col 10 :row 3))
      (declare (ignore patches new-state))
      (is-true (has-render-cmd-p cmds :scroll-up)))))

(test revert-scroll-on-shutdown
  (multiple-value-bind (rv idp o state) (init-root :below-cursor 80 24 12 10)
    (declare (ignore o))

    ;; Set terminal size and cursor pos for context
    (setf (state-ref state (append idp '(:terminal-size))) '(80 24))
    (setf (state-ref state (append idp '(:cursor-pos))) '(10 12))
    ;; Simulate issued scroll net = 5 and ensure on :appshutdown we scroll back up 5
    (setf (state-ref state (append idp '(:issued-scroll-net))) 5)
    (setf (state-ref state (append idp '(:width))) 80)
    (setf (state-ref state (append idp '(:height))) 12)
    (multiple-value-bind (s k cmds)
        (upd rv idp state '(:appshutdown))
      (declare (ignore s k))
      (is-true (has-render-cmd-p cmds :scroll-up 5)))))

(test child-update-is-derived-from-child-dsl-not-app-api-lookup
  (multiple-value-bind (rv idp _ state) (init-root :below-cursor 80 24 12 10)
    (declare (ignore _))
    (setf (state-ref state (append idp '(:child-dsl-spec)))
          '(:root-vp-mock-child :id :child1))
    (let ((original-get-component-instance
            (fdefinition 'elmtui.app.api:get-component-instance)))
      (unwind-protect
           (progn
             (setf (fdefinition 'elmtui.app.api:get-component-instance)
                   (lambda (&rest args)
                     (declare (ignore args))
                     (error "root-viewport should not call get-component-instance")))
             (multiple-value-bind (patches _new-state _cmds)
                 (upd rv idp state '(:custom :value 42))
               (declare (ignore _new-state _cmds))
               (is-true
                 (state-patch-p patches
                   (append idp '(:child1))
                   '(:child-handled-msg)
                   '(:custom :value 42)))))
        (setf (fdefinition 'elmtui.app.api:get-component-instance)
              original-get-component-instance)))))

(test malformed-child-dsl-spec-is-ignored
  (multiple-value-bind (rv idp _ state) (init-root :below-cursor 80 24 12 10)
    (declare (ignore _))
    ;; Matches inline viewport integration shape used by existing tests.
    (setf (state-ref state (append idp '(:child-dsl-spec))) '(:view nil))
    (finishes
      (upd rv idp state '(:cursorposition :col 1 :row 2)))))

(test default-anchor-below-cursor-and-shutdown-cleanup-contract
  "Regression contract: default root viewport behavior should anchor below cursor,
blank only its viewport on exit, and restore the startup cursor without global clears."
  (let* ((id :rv-default-contract)
         (id-path `(:components ,id))
         (rv (make-root-viewport id))
         (state (elmtui.state:make-application-state)))
    (multiple-value-bind (_component patches _cmds)
        (init rv :id-path id-path
             :dsl '(:root-viewport :id :rv-default-contract
                    :children ((:text :id :child :content "x"))))
      (declare (ignore _component _cmds))
      (elmtui.state:apply-patches state patches))
    (is (eq :below-cursor (state-ref state (append id-path '(:anchor))))
        "Default anchor must be :below-cursor when none is provided.")
    ;; Simulate startup-discovered cursor/viewport runtime state.
    (setf (state-ref state (append id-path '(:initial-cursor-pos))) '(17 9))
    (setf (state-ref state (append id-path '(:offset-x))) 4)
    (setf (state-ref state (append id-path '(:offset-y))) 8)
    (setf (state-ref state (append id-path '(:width))) 30)
    (setf (state-ref state (append id-path '(:height))) 10)
    (setf (state-ref state (append id-path '(:blank-on-exit))) t)
    (multiple-value-bind (_patches _state cmds)
        (upd rv id-path state '(:appshutdown))
      (declare (ignore _patches _state))
      (is-true (has-render-cmd-p cmds :blank-viewport)
               "Shutdown should blank only the viewport region.")
      (is-true (has-render-cmd-p cmds :set-cursor 9)
               "Shutdown should restore startup cursor row.")
      (is-false (has-render-cmd-p cmds :clear)
                "Shutdown must not emit full-screen clear.")
      (is-false (has-render-cmd-p cmds :clear-below-cursor)
                "Shutdown must not emit clear-below-cursor."))))

(defun run-root-viewport-anchor-behavior-tests () (run! 'elmtui/root-vp/behavior))
