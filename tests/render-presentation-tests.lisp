(uiop:define-package :elmtui.tests.render-presentation
  (:use :cl :fiveam)
  (:export #:render-presentation-tests))
(in-package :elmtui.tests.render-presentation)
(def-suite render-presentation-tests :in elmtui.tests:elmtui-test
  :description "Swappable presentation with deterministic in-memory frames.")
(in-suite render-presentation-tests)

(defclass rejecting-presenter () ())
(defmethod elmtui.render.presentation:presenter-ready-p ((presenter rejecting-presenter))
  (declare (ignore presenter)) t)
(defmethod elmtui.render.presentation:present-diff
    ((presenter rejecting-presenter) operations row col)
  (declare (ignore presenter operations row col)) nil)

(test recording-presenter-captures-only-changed-cells
  (let* ((front (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 4 1))
         (back (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer front))
         (presenter (elmtui.render.presentation:make-recording-presenter))
         (ctx (elmtui.contracts:make-app-context :backend presenter :front-buffer front))
         (elmtui.platform.backend.terminal.diff-renderer::*compute-buffer-diff-first-call* nil))
    (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at back 0 2 #\X nil)
    (setf (elmtui.contracts:ctx-back-buffer ctx) back)
    (is (eq ctx (elmtui.pipeline:display-buffer ctx)))
    (is (eq back (elmtui.contracts:ctx-front-buffer ctx)))
    (let* ((records (elmtui.render.presentation:recorded-presentations presenter))
           (operation (first (getf (first records) :operations))))
      (is (= 1 (length records)))
      (is (eq :write-chars (getf operation :type)))
      (is (= 0 (getf operation :row)))
      (is (= 2 (getf operation :start-col)))
      (is (string= "X" (getf operation :chars))))
    (elmtui.pipeline:display-buffer ctx)
    (is (= 1 (length (elmtui.render.presentation:recorded-presentations presenter))))))

(test recording-presenter-emits-no-ops-for-equal-frames
  (let* ((front (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 2 1))
         (back (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer front))
         (presenter (elmtui.render.presentation:make-recording-presenter))
         (ctx (elmtui.contracts:make-app-context :backend presenter :front-buffer front))
         (elmtui.platform.backend.terminal.diff-renderer::*compute-buffer-diff-first-call* nil))
    (setf (elmtui.contracts:ctx-back-buffer ctx) back)
    (is-false (elmtui.render.presentation:compute-frame-operations front back))
    (is (eq ctx (elmtui.pipeline:display-buffer ctx)))
    (is-false (elmtui.render.presentation:recorded-presentations presenter))
    (is (eq presenter (elmtui.render.presentation:clear-recordings presenter)))))

(test recording-presenter-rebases-mismatched-dimensions
  (let* ((front (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 2 1))
         (back (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 3 1))
         (presenter (elmtui.render.presentation:make-recording-presenter))
         (ctx (elmtui.contracts:make-app-context :backend presenter :front-buffer front))
         (elmtui.platform.backend.terminal.diff-renderer::*compute-buffer-diff-first-call* nil))
    (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at back 0 2 #\Z nil)
    (setf (elmtui.contracts:ctx-back-buffer ctx) back)
    (elmtui.pipeline:display-buffer ctx)
    (let ((operation (first (getf (first (elmtui.render.presentation:recorded-presentations presenter)) :operations))))
      (is (= 2 (getf operation :start-col)))
      (is (string= "Z" (getf operation :chars))))
    (is (eq back (elmtui.contracts:ctx-front-buffer ctx)))))

(test rejected-presentation-preserves-previous-front-frame
  (let* ((front (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 2 1))
         (back (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer front))
         (ctx (elmtui.contracts:make-app-context
               :backend (make-instance 'rejecting-presenter) :front-buffer front))
         (elmtui.platform.backend.terminal.diff-renderer::*compute-buffer-diff-first-call* nil))
    (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at back 0 0 #\Q nil)
    (setf (elmtui.contracts:ctx-back-buffer ctx) back)
    (signals error (elmtui.pipeline:display-buffer ctx))
    (is (eq front (elmtui.contracts:ctx-front-buffer ctx)))))

(test unavailable-presenter-skips-display
  (let* ((front (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 1 1))
         (back (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer front))
         (ctx (elmtui.contracts:make-app-context :backend nil :front-buffer front)))
    (setf (elmtui.contracts:ctx-back-buffer ctx) back)
    (is (eq ctx (elmtui.pipeline:display-buffer ctx)))
    (is (eq front (elmtui.contracts:ctx-front-buffer ctx)))))

(test recorder-preserves-origin-and-chronological-order
  (let* ((front (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 3 1))
         (middle (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer front))
         (next (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer front))
         (recorder (elmtui.render.presentation:make-recording-presenter))
         (elmtui.platform.backend.terminal.diff-renderer::*compute-buffer-diff-first-call* nil))
    (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at middle 0 0 #\A nil)
    (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at next 0 2 #\B nil)
    (multiple-value-bind (operations acknowledged)
        (elmtui.render.presentation:present-frame recorder front middle
           :origin-row 5 :origin-col 7)
      (is-true acknowledged)
      (is (= 1 (length operations))))
    (elmtui.render.presentation:present-frame recorder middle next
       :origin-row 6 :origin-col 8)
    (let ((records (elmtui.render.presentation:recorded-presentations recorder)))
      (is (equal '(5 6) (mapcar (lambda (entry) (getf entry :row)) records)))
      (is (equal '(7 8) (mapcar (lambda (entry) (getf entry :col)) records)))
      (is (string= "A" (getf (first (getf (first records) :operations)) :chars))))
    (elmtui.render.presentation:clear-recordings recorder)
    (is-false (elmtui.render.presentation:recorded-presentations recorder))))

(test terminal-presenter-delegates-to-legacy-diff-backend
  (let* ((stream (make-string-output-stream))
         (backend (elmtui.platform.backend.terminal::make-terminal-instance :stream stream))
         (front (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 3 1))
         (back (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer front))
         (ctx (elmtui.contracts:make-app-context :backend backend :front-buffer front))
         (called nil)
         (orig (symbol-function
                'elmtui.platform.backend.terminal.diff-renderer:apply-diff-to-backend))
         (elmtui.platform.backend.terminal.diff-renderer::*compute-buffer-diff-first-call* nil))
    (unwind-protect
         (progn
           (setf (symbol-function
                  'elmtui.platform.backend.terminal.diff-renderer:apply-diff-to-backend)
                 (lambda (ops device row col)
                   (setf called (list ops device row col))
                   t))
           (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at back 0 1 #\R nil)
           (setf (elmtui.contracts:ctx-back-buffer ctx) back)
           (is-true (elmtui.render.presentation:presenter-ready-p backend))
           (elmtui.pipeline:display-buffer ctx)
           (is (eq backend (second called)))
           (is (= 0 (third called)))
           (is (= 0 (fourth called)))
           (is (string= "R" (getf (first (first called)) :chars)))
           (is (eq back (elmtui.contracts:ctx-front-buffer ctx)))
           (setf called nil)
           (elmtui.pipeline:display-buffer ctx)
           (is-false called))
      (setf (symbol-function
             'elmtui.platform.backend.terminal.diff-renderer:apply-diff-to-backend)
            orig))))

(test replaying-frame-operations-reconstructs-target-cells
  "All changed cells are reconstructible from the frame diff."
  (let* ((front (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 7 3))
         (back (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer front))
         (replay (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer front))
         (elmtui.platform.backend.terminal.diff-renderer::*compute-buffer-diff-first-call* nil))
    (dolist (change '((0 0 #\A) (0 1 #\B) (1 5 #\C) (2 2 #\D) (2 6 #\E)))
      (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at
       back (first change) (second change) (third change) nil))
    (let ((operations (elmtui.render.presentation:compute-frame-operations front back)))
      (is (plusp (length operations)))
      (dolist (operation operations)
        (elmtui.platform.backend.common.virtual-buffer:write-string-to-buffer
         replay (getf operation :row) (getf operation :start-col)
         (getf operation :chars) (getf operation :style))))
    (loop for row below 3 do
      (loop for col below 7 do
        (is (elmtui.platform.backend.common.virtual-buffer:buffer-cell-equal-p
             (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at replay row col)
             (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at back row col)))))))

(test pure-diff-repeated-and-interleaved-frames-are-deterministic
  "Neither per-process first-call flags nor another frame affects the result."
  (let* ((blank (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 3 1))
         (a (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer blank))
         (b (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer blank)))
    (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at a 0 0 #\A nil)
    (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at b 0 2 #\B nil)
    (multiple-value-bind (first first-metrics)
        (elmtui.render.diff:compute-buffer-diff nil a)
      (is (= 1 (length first)))
      (is (= 1 (elmtui.render.diff:diff-metrics-full-redraws first-metrics)))
      (elmtui.render.diff:compute-buffer-diff nil b)
      (multiple-value-bind (again again-metrics)
          (elmtui.render.diff:compute-buffer-diff nil a)
        (is (equalp first again))
        (is (= (elmtui.render.diff:diff-metrics-cells-changed first-metrics)
               (elmtui.render.diff:diff-metrics-cells-changed again-metrics)))))
    (multiple-value-bind (operations stats)
        (elmtui.render.diff:compute-buffer-diff a a)
      (is-false operations)
      (is (= 0 (elmtui.render.diff:diff-metrics-full-redraws stats)))
      (is (= 3 (elmtui.render.diff:diff-metrics-cells-compared stats))))))

(test pure-diff-initial-redraw-policy-is-explicit
  "Even an identical existing frame can request a full redraw explicitly."
  (let ((frame (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 4 2)))
    (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at frame 0 1 #\X nil)
    (multiple-value-bind (operations stats)
        (elmtui.render.diff:compute-buffer-diff frame frame :initial-frame-p t)
      (is (= 1 (length operations)))
      (is (= 1 (getf (first operations) :start-col)))
      (is (string= "X" (getf (first operations) :chars)))
      (is (= 8 (elmtui.render.diff:diff-metrics-cells-compared stats)))
      (is (= 1 (elmtui.render.diff:diff-metrics-cells-changed stats)))
      (is (= 1 (elmtui.render.diff:diff-metrics-batches stats)))
      (is (= 1 (elmtui.render.diff:diff-metrics-full-redraws stats))))
    (is-false (elmtui.render.diff:compute-buffer-diff frame frame))
    (is-false (elmtui.render.presentation:compute-frame-operations frame frame))))

(test pure-diff-rejects-mismatched-incremental-frames
  (let ((front (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 2 1))
        (back (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 3 1)))
    (signals elmtui.render.diff:buffers-not-compatible-error
      (elmtui.render.diff:compute-buffer-diff front back))
    (multiple-value-bind (ops stats)
        (elmtui.render.presentation:compute-frame-operations front back)
      (is-false ops)
      (is (= 1 (elmtui.render.diff:diff-metrics-full-redraws stats))))))

(test pure-diff-background-policy-and-legacy-stats-isolation
  "Plain background stays untouched, styled spaces paint, and stats remain local."
  (let* ((back (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 3 1))
         (styled (elmtui.platform.backend.common.ansi-styling:make-terminal-style))
         (before (elmtui.platform.backend.terminal.diff-renderer:get-rendering-stats)))
    (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at
     back 0 1 #\Space styled)
    (multiple-value-bind (operations metrics)
        (elmtui.render.diff:compute-buffer-diff nil back)
      (is (= 1 (length operations)))
      (is (= 1 (getf (first operations) :start-col)))
      (is (string= " " (getf (first operations) :chars)))
      (is (= 3 (elmtui.render.diff:diff-metrics-cells-compared metrics)))
      (is (= 1 (elmtui.render.diff:diff-metrics-cells-changed metrics)))
      (is (= 1 (elmtui.render.diff:diff-metrics-batches metrics))))
    (is (equalp before
                (elmtui.platform.backend.terminal.diff-renderer:get-rendering-stats))
        "The pure diff must not change even legacy diagnostic statistics.")))
