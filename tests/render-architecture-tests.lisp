(uiop:define-package :elmtui.tests.render-architecture
  (:use :cl :fiveam)
  (:export #:render-architecture-tests))
(in-package :elmtui.tests.render-architecture)

(def-suite render-architecture-tests
  :in elmtui.tests:elmtui-test
  :description "Architectural boundaries and frame-diff replay properties.")
(in-suite render-architecture-tests)

(test pure-diff-compiles-before-terminal-adapter
  "Architecture contract: pure diff module has no terminal-output dependency."
  (let* ((asd (uiop:read-file-string (asdf:system-relative-pathname "elmtui" "elmtui.asd")))
         (source (uiop:read-file-string
                  (asdf:system-relative-pathname "elmtui" "src/platform/render/diff.lisp")))
         (core-location (search "(:file \"render/diff\")" asd))
         (terminal-location (search "(:file \"backend/terminal/diff-renderer\")" asd)))
    (is-true core-location)
    (is-true terminal-location)
    (when (and core-location terminal-location)
      (is (< core-location terminal-location)))
    (is-false (search "elmtui.platform.backend.terminal" source))
    (is-false (search "apply-diff-to-backend" source))
    (is-false (search "*current-rendering-stats*" source))
    (is-false (search "*compute-buffer-diff-first-call*" source))))

(test deterministic-diff-replay-property-across-frame-shapes
  "Replaying operations on an old frame reconstructs the next frame."
  (loop for trial below 32 do
    (let* ((width (1+ (mod (* trial 7) 13)))
           (height (1+ (mod trial 5)))
           (front (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer width height))
           (back (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer front))
           (replay (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer front))
           (changed 0))
      (loop for row below height do
        (loop for col below width do
          (when (zerop (mod (+ (* row 7) (* col 5) trial) 3))
            (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at
             back row col (code-char (+ 65 (mod (+ row col trial) 26))) nil)
            (incf changed))))
      (multiple-value-bind (ops metrics)
          (elmtui.render.diff:compute-buffer-diff front back)
        (is (= (* width height) (elmtui.render.diff:diff-metrics-cells-compared metrics)))
        (is (= changed (elmtui.render.diff:diff-metrics-cells-changed metrics)))
        (is (= (length ops) (elmtui.render.diff:diff-metrics-batches metrics)))
        (dolist (op ops)
          (is (eq :write-chars (getf op :type)))
          (loop for char across (getf op :chars)
                for col from (getf op :start-col) do
                  (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at
                   replay (getf op :row) col char (getf op :style)))))
      (loop for row below height do
        (loop for col below width do
          (is (elmtui.platform.backend.common.virtual-buffer:buffer-cell-equal-p
               (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at replay row col)
               (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at back row col))))))))

(defclass transient-presenter ()
  ((calls :accessor transient-presenter-calls :initform 0)
   (last-operations :accessor transient-presenter-operations :initform nil)))
(defmethod elmtui.render.presentation:presenter-ready-p ((presenter transient-presenter))
  (declare (ignore presenter))
  t)
(defmethod elmtui.render.presentation:present-diff
    ((presenter transient-presenter) operations row col)
  (declare (ignore row col))
  (incf (transient-presenter-calls presenter))
  (when (> (transient-presenter-calls presenter) 1)
    (setf (transient-presenter-operations presenter) operations)
    t))

(test rejected-frame-can-be-retried-without-losing-diff
  (let* ((front (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 3 1))
         (back (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer front))
         (presenter (make-instance 'transient-presenter))
         (ctx (elmtui.contracts:make-app-context :backend presenter :front-buffer front)))
    (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at back 0 1 #\R nil)
    (setf (elmtui.contracts:ctx-back-buffer ctx) back)
    (signals error (elmtui.pipeline:display-buffer ctx))
    (is (eq front (elmtui.contracts:ctx-front-buffer ctx)))
    (is (= 1 (transient-presenter-calls presenter)))
    (elmtui.pipeline:display-buffer ctx)
    (is (eq back (elmtui.contracts:ctx-front-buffer ctx)))
    (is (= 2 (transient-presenter-calls presenter)))
    (is (string= "R" (getf (first (transient-presenter-operations presenter)) :chars)))
    (elmtui.pipeline:display-buffer ctx)
    (is (= 2 (transient-presenter-calls presenter)))))

(test deprecated-redraw-global-cannot-change-diff-results
  "The compatibility variable must not implicitly select initial-frame policy."
  (let* ((front (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 3 1))
         (back (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer front)))
    (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at back 0 1 #\V nil)
    (let ((a (let ((elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* t))
               (elmtui.render.diff:compute-buffer-diff front back)))
          (b (let ((elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* nil))
               (elmtui.render.diff:compute-buffer-diff front back))))
      (is (equalp a b)))
    (let* ((terminal (elmtui.platform.backend.terminal::make-terminal-instance :stream (make-broadcast-stream)))
           (before (elmtui.platform.backend.terminal:terminal-output-statistics terminal)))
      (elmtui.render.presentation:compute-frame-operations front back)
      (is (equalp before
                  (elmtui.platform.backend.terminal:terminal-output-statistics terminal))))
    (let* ((legacy-a (let ((elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* t))
                       (elmtui.platform.backend.terminal.diff-renderer:compute-buffer-diff
                        front back :initial-frame-p nil)))
           (legacy-b (let ((elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* nil))
                       (elmtui.platform.backend.terminal.diff-renderer:compute-buffer-diff
                        front back :initial-frame-p nil))))
      (is (equalp legacy-a legacy-b)))))

(test presentation-exposes-per-call-metrics-without-global-accounting
  (let* ((back (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 5 1))
         (presenter (elmtui.render.presentation:make-recording-presenter))
         (terminal (elmtui.platform.backend.terminal::make-terminal-instance :stream (make-broadcast-stream)))
         (before (elmtui.platform.backend.terminal:terminal-output-statistics terminal)))
    (elmtui.platform.backend.common.virtual-buffer:set-buffer-cell-at back 0 3 #\S nil)
    (multiple-value-bind (operations acknowledged metrics)
        (elmtui.render.presentation:present-frame presenter nil back)
      (is-true acknowledged)
      (is (= 1 (length operations)))
      (is (= 5 (elmtui.render.diff:diff-metrics-cells-compared metrics)))
      (is (= 1 (elmtui.render.diff:diff-metrics-cells-changed metrics)))
      (is (= 1 (elmtui.render.diff:diff-metrics-full-redraws metrics))))
    (is (equalp before
                (elmtui.platform.backend.terminal:terminal-output-statistics terminal)))
    (is (= 1 (length (elmtui.render.presentation:recorded-presentations presenter))))))

(test distinct-terminal-instances-own-independent-output-counters
  (let* ((one (elmtui.platform.backend.terminal::make-terminal-instance :stream (make-broadcast-stream)))
         (two (elmtui.platform.backend.terminal::make-terminal-instance :stream (make-broadcast-stream)))
         (operations '((:type :write-chars :row 0 :start-col 0 :chars "ABC" :style nil)
                       (:type :write-chars :row 0 :start-col 3 :chars "D" :style nil))))
    (elmtui.platform.backend.terminal.diff-renderer:apply-diff-to-backend operations one 0 0)
    (let ((first (elmtui.platform.backend.terminal:terminal-output-statistics one))
          (other (elmtui.platform.backend.terminal:terminal-output-statistics two)))
      (is (= 2 (elmtui.platform.backend.terminal:terminal-output-stats-ops-processed first)))
      (is (= 4 (elmtui.platform.backend.terminal:terminal-output-stats-chars-written first)))
      (is (= 1 (elmtui.platform.backend.terminal:terminal-output-stats-cursor-moves-applied first)))
      (is (= 0 (elmtui.platform.backend.terminal:terminal-output-stats-ops-processed other)))
      (is (= 0 (elmtui.platform.backend.terminal:terminal-output-stats-chars-written other)))
      (setf (elmtui.platform.backend.terminal:terminal-output-stats-chars-written first) 900)
      (is (= 4 (elmtui.platform.backend.terminal:terminal-output-stats-chars-written
                (elmtui.platform.backend.terminal:terminal-output-statistics one)))))
    (elmtui.platform.backend.terminal.diff-renderer:apply-diff-to-backend
     '((:type :write-chars :row 1 :start-col 1 :chars "XY" :style nil)) two 0 0)
    (is (= 2 (elmtui.platform.backend.terminal:terminal-output-stats-chars-written
              (elmtui.platform.backend.terminal:terminal-output-statistics two))))
    (let ((empty (elmtui.platform.backend.terminal:reset-terminal-output-statistics one)))
      (is (= 0 (elmtui.platform.backend.terminal:terminal-output-stats-ops-processed empty)))
      (is (= 0 (elmtui.platform.backend.terminal:terminal-output-stats-chars-written
                (elmtui.platform.backend.terminal:terminal-output-statistics one))))
      (is (= 2 (elmtui.platform.backend.terminal:terminal-output-stats-chars-written
                (elmtui.platform.backend.terminal:terminal-output-statistics two)))))))

(test deleted-process-global-diagnostics
  (let ((package (find-package :elmtui.platform.backend.terminal.diff-renderer)))
    (dolist (name '("GET-RENDERING-STATS" "RESET-RENDERING-STATS"
                    "*CURRENT-RENDERING-STATS*" "RENDERING-STATS"))
      (is-false (find-symbol name package)))))

(test output-counters-on-partial-writer-error-and-idle
  (let* ((one (elmtui.platform.backend.terminal::make-terminal-instance :stream (make-broadcast-stream)))
         (two (elmtui.platform.backend.terminal::make-terminal-instance :stream (make-broadcast-stream)))
         (empty (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 3 1)))
    (is-false (elmtui.render.presentation:present-frame one empty empty))
    (is (= 0 (elmtui.platform.backend.terminal:terminal-output-stats-chars-written
              (elmtui.platform.backend.terminal:terminal-output-statistics one))))
    (signals error
      (elmtui.platform.backend.terminal.diff-renderer:apply-diff-to-backend
       '((:type :write-chars :row 0 :start-col 0 :chars "A" :style nil)
         (:type :not-supported)) one 0 0))
    (is (= 1 (elmtui.platform.backend.terminal:terminal-output-stats-ops-processed
              (elmtui.platform.backend.terminal:terminal-output-statistics one))))
    (is (= 1 (elmtui.platform.backend.terminal:terminal-output-stats-chars-written
              (elmtui.platform.backend.terminal:terminal-output-statistics one))))
    (is (= 0 (elmtui.platform.backend.terminal:terminal-output-stats-chars-written
              (elmtui.platform.backend.terminal:terminal-output-statistics two))))))
