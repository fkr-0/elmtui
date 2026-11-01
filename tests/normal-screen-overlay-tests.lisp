;;; Regression tests for the two normal-screen P0 defects:
;;;  - B2 must frame the real pane cell (physical overlay compositing), and
;;;  - a pane resize must never lose or alter native tmux history.
;;; The real-tmux acceptance gates live in
;;; tests/e2e/example-overhaul-tmux-review-contracts.py and
;;; tests/e2e/tmux-hover-defect-regressions.py; these tests pin the units.

(uiop:define-package :elmtui.tests.normal-screen-overlay
  (:use :cl :fiveam)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
    #:make-virtual-buffer #:set-buffer-cell-at #:buffer-cell-at
    #:buffer-cell-char #:buffer-width #:buffer-height)
  (:import-from :elmtui.platform.tmux
    #:make-normal-screen-ledger #:normal-screen-ledger-pulled
    #:normal-screen-ledger-logical-height #:normal-screen-reconcile-history
    #:normal-screen-underlay #:normal-screen-overflow-chunks
    #:save-tmux-capture #:clear-saved-tmux-capture)
  (:export #:normal-screen-overlay-tests))

(in-package :elmtui.tests.normal-screen-overlay)

(def-suite normal-screen-overlay-tests
  :in elmtui.tests:elmtui-test
  :description "Physical B2 overlay compositing and resize-safe normal-screen history")

(in-suite normal-screen-overlay-tests)

;;; Helpers

(defun rows-buffer (width &rest rows)
  "A WIDTH-wide buffer whose rows start with the given strings."
  (let ((buffer (make-virtual-buffer width (length rows))))
    (loop for text in rows for row from 0
          do (loop for ch across text for col from 0 below width
                   do (set-buffer-cell-at buffer row col ch nil)))
    buffer))

(defun row-text (buffer row)
  (string-right-trim
   " " (coerce (loop for col below (buffer-width buffer)
                     collect (buffer-cell-char (buffer-cell-at buffer row col)))
               'string)))

(defun all-rows (buffer)
  (loop for row below (buffer-height buffer) collect (row-text buffer row)))

;;; Ledger: logical underlay = pulled history rows ++ launch capture

(test ledger-view-is-launch-capture-until-tmux-pulls-history
  (let ((ledger (make-normal-screen-ledger (rows-buffer 6 "A" "B" "C")
                                           :launch-history 10)))
    (is (equal '("A" "B" "C") (all-rows (normal-screen-underlay ledger 6 3))))
    (is (= 0 (normal-screen-ledger-pulled ledger)))
    (is (null (normal-screen-overflow-chunks ledger 3 6)))))

(test ledger-reconcile-prepends-only-freshly-pulled-history-rows
  "A height grow pulls scrollback onto the pane top; the ledger must record
exactly those rows so the launch capture is mapped below them."
  (let ((ledger (make-normal-screen-ledger (rows-buffer 4 "A" "B")
                                           :launch-history 10)))
    (normal-screen-reconcile-history ledger (rows-buffer 4 "H8" "H9" "XX") :history 8)
    (is (= 2 (normal-screen-ledger-pulled ledger)))
    (is (equal '("H8" "H9" "A" "B") (all-rows (normal-screen-underlay ledger 4 4))))
    ;; Same history size again: nothing new was pulled.
    (normal-screen-reconcile-history ledger (rows-buffer 4 "XX" "YY") :history 8)
    (is (= 4 (normal-screen-ledger-logical-height ledger)))
    ;; One more row pulled: only the new top row is prepended.
    (normal-screen-reconcile-history ledger (rows-buffer 4 "H7" "H8" "H9") :history 7)
    (is (equal '("H7" "H8" "H9" "A" "B")
               (all-rows (normal-screen-underlay ledger 4 5))))
    ;; Unknown history (tmux unavailable) never guesses.
    (normal-screen-reconcile-history ledger (rows-buffer 4 "ZZ") :history nil)
    (is (= 3 (normal-screen-ledger-pulled ledger)))))

(test ledger-overflow-chunks-hold-rows-deleted-by-a-shrink
  (let ((ledger (make-normal-screen-ledger (rows-buffer 3 "A" "B" "C" "D" "E")
                                           :launch-history nil)))
    (is (equal '("A" "B") (all-rows (normal-screen-underlay ledger 3 2))))
    (is (equal '(("C" "D") ("E"))
               (mapcar #'all-rows (normal-screen-overflow-chunks ledger 2 3))))
    (is (equal '(("B") ("C") ("D") ("E"))
               (mapcar #'all-rows (normal-screen-overflow-chunks ledger 1 3))))))

(test ledger-underlay-keeps-fallback-cells-outside-logical-rows
  "Rows a grow appended below the logical underlay come from the live pane."
  (let ((ledger (make-normal-screen-ledger (rows-buffer 3 "A") :launch-history nil)))
    (is (equal '("A" "LV" "LW")
               (all-rows (normal-screen-underlay ledger 3 3
                                                 (rows-buffer 3 "XX" "LV" "LW")))))))

;;; Compositor

(test underlay-region-copies-pane-cells-under-a-viewport
  (let ((region (elmtui.pipeline::%underlay-region
                 (rows-buffer 5 "ABCDE" "FGHIJ" "KLMNO") 1 1 3 2)))
    (is (equal '("GHI" "LMN") (all-rows region)))
    (is (null (elmtui.pipeline::%underlay-region
               (rows-buffer 5 "ABCDE") 3 0 3 1))
        "A region outside the underlay must not composite onto misaligned cells")))

(test protected-pulled-history-rows-are-reverted-to-underlay
  "Rows tmux pulled from scrollback are history: frame paint there is masked."
  (let ((frame (rows-buffer 3 "###" "###" "###"))
        (underlay (rows-buffer 3 "h1" "h2" "app")))
    (let ((elmtui.pipeline:*underlay-protected-rows* 2))
      (elmtui.pipeline::%mask-protected-rows frame underlay 0 0))
    (is (equal '("h1" "h2" "###") (all-rows frame))))
  (let ((frame (rows-buffer 3 "###"))
        (underlay (rows-buffer 3 "h1" "h2" "app")))
    ;; A viewport starting below the protected rows is untouched.
    (let ((elmtui.pipeline:*underlay-protected-rows* 2))
      (elmtui.pipeline::%mask-protected-rows frame underlay 0 2))
    (is (equal '("###") (all-rows frame)))))

(test render-to-buffer-composites-on-underlay-not-previous-frame
  "A moved overlay must not leave stale paint: unpainted cells revert to the
captured underlay even when the previous frame painted them."
  (let* ((underlay (rows-buffer 4 "abcd" "efgh"))
         (stale-front (rows-buffer 4 "┌─┐d" "│f│h"))
         (context (elmtui.contracts:make-app-context :front-buffer stale-front)))
    (setf (elmtui.contracts:ctx-viewport-rect context)
          (elmtui.view.geo:make-rectangle
           :pos (elmtui.view.geo:make-pos :x 0 :y 0)
           :size (elmtui.view.geo:make-size :w 4 :h 2))
          (elmtui.contracts:ctx-laid-out-tree context)
          (elmtui.contracts:make-laid-out-tree :root nil))
    (let ((elmtui.pipeline:*preserve-underlay* t)
          (elmtui.pipeline:*underlay-buffer* underlay))
      (elmtui.pipeline:render-to-buffer context))
    (is (equal '("abcd" "efgh")
               (all-rows (elmtui.contracts:ctx-back-buffer context))))))

(test frames-park-the-cursor-on-row-zero-only-after-output
  "Parking on row 0 makes a tmux height shrink delete bottom rows instead of
scrolling painted cells into scrollback; an empty diff writes nothing."
  (let ((original (symbol-function 'elmtui.platform.backend.terminal:send-sequence)))
    (flet ((moves (operations)
             (let ((calls '())
                   (backend (elmtui.platform.backend.terminal::make-terminal-instance
                             :stream (make-broadcast-stream)))
                   (elmtui.platform.backend.terminal.diff-renderer:*park-cursor-after-diff*
                     '(0 . 0)))
               (setf (elmtui.platform.backend.terminal::terminal-instance-width backend) 10
                     (elmtui.platform.backend.terminal::terminal-instance-height backend) 5)
               (unwind-protect
                    (progn
                      (setf (symbol-function 'elmtui.platform.backend.terminal:send-sequence)
                            (lambda (instance name &rest args)
                              (declare (ignore instance))
                              (when (eq name :cursor-set-position)
                                (push args calls))))
                      (elmtui.platform.backend.terminal.diff-renderer:apply-diff-to-backend
                       operations backend 3 0))
                 (setf (symbol-function 'elmtui.platform.backend.terminal:send-sequence)
                       original))
               (reverse calls))))
      (is (equal '((4 3) (1 1))
                 (moves '((:type :write-chars :row 0 :start-col 2 :chars "X" :style nil))))
          "write at physical row 3, then park at 1-based (1,1)")
      (is (null (moves '())) "an empty diff never moves the cursor"))))

;;; Shutdown restoration after a shrink

(test shutdown-after-shrink-scrolls-deleted-rows-back-in-order
  "A 4-row capture shown in a 2-row pane: rows A,B are repainted in place, then
C,D are appended by scrolling, which moves A,B into native history in order."
  (let* ((saved (rows-buffer 3 "A" "B" "C" "D"))
         (live (rows-buffer 3 "A" "#B"))
         (backend (elmtui.platform.backend.terminal::make-terminal-instance))
         (events '())
         (originals
           (list (cons 'elmtui.platform.tmux:tmux-available-p
                       (symbol-function 'elmtui.platform.tmux:tmux-available-p))
                 (cons 'elmtui.platform.tmux:make-buffer-from-tmux-styled
                       (symbol-function 'elmtui.platform.tmux:make-buffer-from-tmux-styled))
                 (cons 'elmtui.platform.tmux:tmux-history-size
                       (symbol-function 'elmtui.platform.tmux:tmux-history-size))
                 (cons 'elmtui.platform.driver::%resynchronize-live-tmux-geometry
                       (symbol-function 'elmtui.platform.driver::%resynchronize-live-tmux-geometry))
                 (cons 'elmtui.platform.driver::apply-diff-to-backend
                       (symbol-function 'elmtui.platform.driver::apply-diff-to-backend))
                 (cons 'elmtui.platform.api:scroll
                       (symbol-function 'elmtui.platform.api:scroll))
                 (cons 'elmtui.platform.driver::set-cursor-position
                       (symbol-function 'elmtui.platform.driver::set-cursor-position)))))
    (setf (elmtui.platform.backend.terminal::terminal-instance-width backend) 3
          (elmtui.platform.backend.terminal::terminal-instance-height backend) 2)
    (unwind-protect
         (progn
           (save-tmux-capture saved)
           (setf (symbol-function 'elmtui.platform.tmux:tmux-available-p) (lambda () t)
                 (symbol-function 'elmtui.platform.tmux:make-buffer-from-tmux-styled)
                 (lambda (w h &key mode) (declare (ignore w h mode)) live)
                 (symbol-function 'elmtui.platform.tmux:tmux-history-size) (lambda () nil)
                 (symbol-function 'elmtui.platform.driver::%resynchronize-live-tmux-geometry)
                 (lambda (b) b)
                 (symbol-function 'elmtui.platform.driver::apply-diff-to-backend)
                 (lambda (ops b row col)
                   (declare (ignore b))
                   (push (list :diff row col
                               (mapcar (lambda (op)
                                         (list (getf op :row)
                                               (string-right-trim " " (getf op :chars))))
                                       ops))
                         events)
                   t)
                 (symbol-function 'elmtui.platform.api:scroll)
                 (lambda (b n) (declare (ignore b)) (push (list :scroll n) events) t)
                 (symbol-function 'elmtui.platform.driver::set-cursor-position)
                 (lambda (b row col) (declare (ignore b)) (push (list :cursor row col) events) t))
           (let ((elmtui.platform.driver::*normal-screen-ledger* nil)
                 (elmtui.platform.driver::*last-cursor-pos* '(3 . 1)))
             (is-true (elmtui.platform.driver::%restore-saved-tmux-capture-on-backend backend)))
           (let ((events (reverse events)))
             ;; 1. painted cell (#) reverted in place
             (is (equal '(:diff 0 0) (subseq (first events) 0 3)))
             (is (equal '((1 "B")) (remove-if-not (lambda (op) (eql 1 (first op)))
                                                  (fourth (first events)))))
             ;; 2. move to the bottom row and scroll two rows into history
             (is (equal '((:cursor 1 0) (:scroll 2)) (subseq events 1 3)))
             ;; 3. write the deleted rows C, D into the freed bottom rows
             (is (equal '(:diff 0 0 ((0 "C") (1 "D"))) (fourth events)))
             ;; 4. original cursor row 3 is now physical row 3 - 2 scrolled = 1
             (is (equal '(:cursor 1 1) (fifth events)))))
      (clear-saved-tmux-capture)
      (loop for (name . fn) in originals do (setf (symbol-function name) fn)))))

;;; Cursor inspector physical B2

(defun insp (name &rest args)
  "Call cursor-inspector function NAME; examples load on demand, as in the
tmux example smoke tests, so the core test system does not depend on them."
  (unless (find-package :elmtui-examples.cursor-inspector)
    (asdf:load-system :elmtui-examples))
  (apply (uiop:find-symbol* name :elmtui-examples.cursor-inspector) args))

(defun inspector-view (state) (insp "CURSOR-INSPECTOR-VIEW" state))

(defun inspector-state (&key (x 5) (y 6) (mode :pane) (size '(100 35)))
  (list :lines (coerce (loop for n from 1 to 35
                             collect (format nil "VISIBLE-ROW-~2,'0D-ABCDEFGHIJ" n))
                       'vector)
        :cursor-x x :cursor-y y :mode mode :physical-overlay t
        :status "Ready" :title "CURSOR INSPECTOR" :tmux-enabled t
        :components (list :root (list :terminal-size size))))

(defun frame-rows (frame)
  "Map each painted top-level child of the overlay FRAME to its physical row.
Returns ((ROW . TEXTS)...) where TEXTS are the :text contents in that child."
  (let ((row 0) (result '()))
    (labels ((texts (node)
               (when (consp node)
                 (if (eq (first node) :text)
                     (list (getf (rest node) :content))
                     (mapcan #'texts (getf (rest node) :children))))))
      (dolist (child (getf (rest frame) :children) (nreverse result))
        (let ((height (getf (getf (rest child) :style) :height 1))
              (found (texts child)))
          (when found (push (cons row found) result))
          (incf row height))))))

(defun row-with (rows text)
  (car (find-if (lambda (entry) (some (lambda (s) (search text s)) (cdr entry))) rows)))

(test b2-physical-geometry-clips-at-pane-edges
  (is (equal '(:top 5 :bottom 7 :left 4 :right 6 :x 5 :y 6 :width 1)
             (insp "%B2-PHYSICAL-GEOMETRY" 5 6 1 100 35)))
  (is (equal '(:top 22 :bottom nil :left nil :right 1 :x 0 :y 23 :width 1)
             (insp "%B2-PHYSICAL-GEOMETRY" 0 23 1 80 24)))
  (is (equal '(:top nil :bottom 1 :left 77 :right nil :x 78 :y 0 :width 2)
             (insp "%B2-PHYSICAL-GEOMETRY" 78 0 2 80 24))
      "A wide glyph owns two interior columns")
  (is (null (insp "%B2-PHYSICAL-GEOMETRY" 5 40 1 80 24))))

(test overlay-view-paints-b2-on-the-real-pane-cell
  (let ((rows (frame-rows (inspector-view (inspector-state)))))
    (is (eql 5 (row-with rows "┌─┐")))
    (is (eql 6 (row-with rows "│")))
    (is (eql 7 (row-with rows "└─┘")))
    (is (eql 26 (row-with rows "B2 focus")) "panel sits at the pane bottom")
    (is (= 1 (count-if (lambda (entry) (some (lambda (text) (search "┌─┐" text))
                                             (cdr entry)))
                       rows))
        "exactly one B2 frame: no in-panel PREVIEW in physical mode")))

(test overlay-view-moves-panel-away-from-a-bottom-row-target
  (let ((rows (frame-rows (inspector-view (inspector-state :x 3 :y 23 :size '(80 24))))))
    (is (eql 22 (row-with rows "┌─┐")))
    (is (eql 0 (row-with rows "B2 focus")) "panel flips to the top, never covering B2")))

(test overlay-view-follows-snapshot-below-pulled-history-rows
  "After tmux pulls history onto the pane top, snapshot row Y is shown at Y+N:
B2 follows it and the panel never lands on the protected history rows."
  (let ((rows (let ((elmtui.pipeline:*underlay-protected-rows* 13))
                (frame-rows (inspector-view (inspector-state :x 5 :y 18))))))
    (is (eql 30 (row-with rows "┌─┐")) "B2 top border at snapshot row 18 + 13 - 1")
    (is (eql 13 (row-with rows "B2 focus"))
        "panel flips to the first unprotected row, not row 0")))

(test overlay-view-keeps-preview-in-scrollback-mode
  (let ((rows (frame-rows (inspector-view (inspector-state :mode :screen)))))
    (is (equal '(23) (mapcar #'car rows))
        "only the 12-row panel at the pane bottom is painted: scrollback rows are not pane rows")
    (is (row-with rows "[") "scrollback keeps the in-panel PREVIEW")))

;;; Inline (cursor-anchored) viewports

(test truncated-below-cursor-viewport-is-never-placed-over-shell-output
  "A 12-row :below-cursor viewport launched on the last pane row must be placed
on that row, not clamped 11 rows upward over existing history (wifi-inline
used to blank one history row this way before the truncation took effect)."
  (let ((height (elmtui.ui.widgets.root-viewport::%placement-height
                 :below-cursor 12 35 34 :truncate)))
    (is (= 1 height))
    (is (= 34 (elmtui.ui.widgets.root-viewport::compute-anchor-solution
               :below-cursor 68 height 100 35 34 0))))
  (is (= 12 (elmtui.ui.widgets.root-viewport::%placement-height
             :below-cursor 12 35 34 :scroll))
      ":scroll reserves rows by scrolling instead, so it keeps the full height")
  (is (= 5 (elmtui.ui.widgets.root-viewport::%placement-height
            :below-cursor 5 35 10 :truncate))
      "enough room below the cursor: untouched")
  (is (= 3 (elmtui.ui.widgets.root-viewport::%placement-height
            :above-cursor 12 35 3 :truncate))))
