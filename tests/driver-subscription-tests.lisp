(uiop:define-package :elmtui.tests.driver-subscriptions
  (:use :cl :fiveam)
  (:import-from :elmtui.core.globals #:*app-sender*)
  (:import-from :elmtui.platform.tmux
    #:save-tmux-capture
    #:clear-saved-tmux-capture)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
    #:make-virtual-buffer
    #:set-buffer-cell-at
    #:buffer-cell-at
    #:buffer-cell-char))

(in-package :elmtui.tests.driver-subscriptions)

(def-suite driver-subscription-tests
  :in elmtui.tests:elmtui-test
  :description "Driver-level subscription lifecycle tests")

(in-suite driver-subscription-tests)

(test driver-startup-message-buffer-replays-events-in-order
  (let* ((state (elmtui.platform.driver::make-startup-message-buffer-state))
         (processor (elmtui.platform.driver::startup-message-buffer-processor state))
         (replayed '()))
    (funcall processor '(:cursorposition :col 1 :row 2))
    (funcall processor '(:terminalresized :width 120 :height 40))
    (is (= 2 (elmtui.platform.driver::startup-message-buffer-count state)))
    (elmtui.platform.driver::drain-startup-message-buffer
     state
     (lambda (msg) (push msg replayed)))
    (is (equal (nreverse replayed)
               '((:cursorposition :col 1 :row 2)
                 (:terminalresized :width 120 :height 40))))
    (is (= 0 (elmtui.platform.driver::startup-message-buffer-count state)))))

(test driver-refresh-installs-and-cancels-timer-subscription
  (let ((captured nil)
        (old-sender *app-sender*))
    (unwind-protect
         (progn
           (setf *app-sender*
                 (lambda (msg)
                   (push msg captured)))
           (elmtui.platform.driver::%clear-app-subscriptions)
           (elmtui.platform.driver::%refresh-app-subscriptions
            '(:subscriptions-fn '(lambda (_model)
                                   (declare (ignore _model))
                                   '(:timer (:interval 0.02 :message (:tick)))))
            nil)
           (sleep 0.08)
           (is (plusp (length captured)))
           (is (find '(:tick) captured :test #'equal))
           (elmtui.platform.driver::%refresh-app-subscriptions
            '(:subscriptions-fn '(lambda (_model)
                                   (declare (ignore _model))
                                   nil))
            nil)
           (is (= 0 (hash-table-count elmtui.platform.driver::*active-app-subscriptions*))))
      (elmtui.platform.driver::%clear-app-subscriptions)
      (setf *app-sender* old-sender))))

(test driver-restore-saved-capture-applies-physical-diff
  "Restoration patches the visible pane, not a stale cached front buffer."
  (let* ((front (make-virtual-buffer 4 1))
         (back (make-virtual-buffer 4 1))
         (snapshot (make-virtual-buffer 4 1))
         (painted (make-virtual-buffer 4 1))
         (backend (elmtui.platform.backend.terminal::make-terminal-instance
                   :front-buffer front
                   :back-buffer back))
         (orig-diff (symbol-function 'elmtui.platform.driver::compute-buffer-diff))
         (orig-apply (symbol-function 'elmtui.platform.driver::apply-diff-to-backend))
         (orig-tmux-p (symbol-function 'elmtui.platform.tmux:tmux-available-p))
         (orig-make-styled (symbol-function 'elmtui.platform.tmux:make-buffer-from-tmux-styled))
         (orig-resync (symbol-function 'elmtui.platform.driver::%resynchronize-live-tmux-geometry))
         (diff-called nil)
         (apply-called nil))
    (unwind-protect
         (progn
           (set-buffer-cell-at front 0 0 #\A nil)
           (set-buffer-cell-at painted 0 0 #\A nil)
           (set-buffer-cell-at snapshot 0 0 #\B nil)
           (save-tmux-capture snapshot)
           (setf (symbol-function 'elmtui.platform.tmux:tmux-available-p)
                 (lambda () t))
           (setf (symbol-function 'elmtui.platform.tmux:make-buffer-from-tmux-styled)
                 (lambda (_w _h &key mode)
                   (declare (ignore _w _h mode))
                   painted))
           (setf (symbol-function 'elmtui.platform.driver::%resynchronize-live-tmux-geometry)
                 (lambda (_b) (declare (ignore _b)) nil))
           (setf (symbol-function 'elmtui.platform.driver::compute-buffer-diff)
                 (lambda (_old _new)
                   (declare (ignore _old _new))
                   (setf diff-called t)
                   '((:type :write-chars :row 0 :start-col 0 :chars "B" :style nil))))
           (setf (symbol-function 'elmtui.platform.driver::apply-diff-to-backend)
                 (lambda (_diff _backend _row _col)
                   (declare (ignore _diff _backend _row _col))
                   (setf apply-called t)
                   t))
           (is-true (elmtui.platform.driver::%restore-saved-tmux-capture-on-backend backend))
           (is-true diff-called)
           (is-true apply-called)
           ;; The physical pane was diffed through APPLY-DIFF-TO-BACKEND.
           ;; Do not mutate the old viewport-local front buffer as a side effect.
           (is (char= #\A (buffer-cell-char (buffer-cell-at front 0 0)))))
      (clear-saved-tmux-capture)
      (setf (symbol-function 'elmtui.platform.driver::compute-buffer-diff) orig-diff)
      (setf (symbol-function 'elmtui.platform.driver::apply-diff-to-backend) orig-apply)
      (setf (symbol-function 'elmtui.platform.tmux:tmux-available-p) orig-tmux-p)
      (setf (symbol-function 'elmtui.platform.tmux:make-buffer-from-tmux-styled) orig-make-styled)
      (setf (symbol-function 'elmtui.platform.driver::%resynchronize-live-tmux-geometry) orig-resync))))

(test terminal-backend-initial-publish-keeps-row-col-order
  "Regression: startup cursor event from terminal backend init must preserve
the same (row,col) ordering as the backend cursor API."
  (let* ((orig-device-output-stream (symbol-function 'cl-inputs.device.api:device-output-stream))
         (orig-make-ready-input-source (symbol-function 'cl-inputs.api:make-ready-input-source))
         (orig-get-cursor-position (symbol-function 'cl-inputs.terminal.api:get-cursor-position))
         (orig-get-terminal-size (symbol-function 'cl-inputs.terminal.api:get-terminal-size))
         (orig-hide-cursor (symbol-function 'cl-inputs.terminal.api:hide-cursor))
         (orig-flush-output (symbol-function 'cl-inputs.terminal.api:flush-output))
         (orig-setup-signals (symbol-function 'elmtui.platform.backend.terminal::setup-terminal-signal-handlers))
         (events '()))
    (unwind-protect
         (progn
           (setf (symbol-function 'cl-inputs.device.api:device-output-stream)
                 (lambda (_dev)
                   (declare (ignore _dev))
                   *standard-output*))
           (setf (symbol-function 'cl-inputs.api:make-ready-input-source)
                 (lambda (&key device)
                   (declare (ignore device))
                   :mock-input-source))
           ;; get-cursor-position returns 0-indexed (row, col);
           ;; the publish event adds 1 to convert to 1-indexed for root-viewport.
           (setf (symbol-function 'cl-inputs.terminal.api:get-cursor-position)
                 (lambda (_dev)
                   (declare (ignore _dev))
                   (values 7 33)))
           (setf (symbol-function 'cl-inputs.terminal.api:get-terminal-size)
                 (lambda (_dev)
                   (declare (ignore _dev))
                   (values 100 40)))
           (setf (symbol-function 'cl-inputs.terminal.api:hide-cursor)
                 (lambda (_dev)
                   (declare (ignore _dev))
                   t))
           (setf (symbol-function 'cl-inputs.terminal.api:flush-output)
                 (lambda (_dev)
                   (declare (ignore _dev))
                   t))
           (setf (symbol-function 'elmtui.platform.backend.terminal::setup-terminal-signal-handlers)
                 (lambda (_instance _publish-fn)
                   (declare (ignore _instance _publish-fn))
                   t))
           (elmtui.platform.backend.terminal:make-terminal-instance-for-device
            :device :mock-device
            :publish-fn (lambda (evt) (push evt events)))
           (let ((cursor-event (find-if (lambda (evt)
                                          (and (consp evt)
                                               (eq (car evt) :cursorposition)))
                                        (reverse events))))
             (is-true cursor-event)
             (is (= 8 (getf (cdr cursor-event) :row))
               "row must be 1-indexed (0-indexed 7 + 1 = 8) for root-viewport %cursor->index")
             (is (= 34 (getf (cdr cursor-event) :col))
               "col must be 1-indexed (0-indexed 33 + 1 = 34) for root-viewport %cursor->index")))
      (setf (symbol-function 'cl-inputs.device.api:device-output-stream) orig-device-output-stream
            (symbol-function 'cl-inputs.api:make-ready-input-source) orig-make-ready-input-source
            (symbol-function 'cl-inputs.terminal.api:get-cursor-position) orig-get-cursor-position
            (symbol-function 'cl-inputs.terminal.api:get-terminal-size) orig-get-terminal-size
            (symbol-function 'cl-inputs.terminal.api:hide-cursor) orig-hide-cursor
            (symbol-function 'cl-inputs.terminal.api:flush-output) orig-flush-output
            (symbol-function 'elmtui.platform.backend.terminal::setup-terminal-signal-handlers) orig-setup-signals))))
