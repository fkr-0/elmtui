(in-package #:elmtui.contracts)

;; STAGE 6: Display the back buffer, handling diffing.
(define-stage display-buffer
    (list list) ; context -> context (with side-effects)
    (context)
  (let* ((back-buffer (getf context :back-buffer))
         (front-buffer (getf context :front-buffer))
         (backend (getf context :backend))
         (origin-x (getf context :origin-x 0))
         (origin-y (getf context :origin-y 0)))
    (let ((diff (elmtui.platform.backend.terminal.diff-renderer:compute-buffer-diff front-buffer back-buffer)))
      (elmtui.platform.backend.terminal.diff-renderer:apply-diff-to-backend diff backend origin-x origin-y)
      ;; The new front-buffer for the next frame is the current back-buffer
      (list* :front-buffer (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer back-buffer) context))))
