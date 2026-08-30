(uiop:define-package :elmtui.tests.terminal-lifecycle
  (:use :cl :fiveam)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:make-virtual-buffer
                #:fill-buffer-region
                #:buffer-cell-at
                #:buffer-cell-char)
  (:import-from :elmtui.platform.backend.terminal.diff-renderer
                #:compute-buffer-diff
                #:*compute-buffer-diff-first-call*)
  (:import-from :cl-state.core
                #:make-state
                #:state-ref)
  (:import-from :cl-state.patch
                #:apply-patches)
  (:import-from :elmtui.ui.api
                #:init
                #:view)
  (:import-from :elmtui.ui.widgets.root-viewport
                #:make-root-viewport)
  (:import-from :uiop #:read-file-string)
  (:export #:terminal-lifecycle-suite))

(in-package :elmtui.tests.terminal-lifecycle)

(def-suite terminal-lifecycle-suite
  :in elmtui.tests:elmtui-test
  :description "Tests falsifying 5 terminal lifecycle bugs in the TUI framework.")

(in-suite terminal-lifecycle-suite)

(test first-render-background-cells-must-not-produce-write-ops
  "Bug 1: background spaces must not emit write ops on first render."
  (let* ((width 10)
         (height 5)
         (front (make-virtual-buffer width height))
         (back  (make-virtual-buffer width height))
         (*compute-buffer-diff-first-call* t))
    (fill-buffer-region back 0 0 width height #\Space nil)
    (let ((diff (compute-buffer-diff front back)))
      (is (null diff)
          "Expected zero write ops for background spaces; got ~A ops." (length diff)))))

(test stty-sane-error-must-not-appear-on-stdout
  "Bug 2: stty sane must not route stderr to :output; use :error nil."
  (let* ((src (uiop:read-file-string
                (asdf:system-relative-pathname
                  "elmtui"
                  "src/platform/backend/terminal/terminal.lisp")))
         (stty-pos (search "run-program" src))
         (stty-section (when stty-pos
                         (subseq src stty-pos
                           (min (+ stty-pos 200) (length src))))))
    (is-true stty-section
      "shutdown-backend stty run-program call not found in terminal.lisp")
    (is-false (search ":error :output" stty-section)
      "stty sane must not route stderr to :output; use :error nil.")))

(test root-viewport-ready-without-terminalresized-event
  "Bug 4: root-viewport must have size-known=t and return non-nil view after init."
  (let* ((rv (make-root-viewport :test-rv-id))
         (id-path '(:components :test-rv-id))
         (state (make-state)))
    (multiple-value-bind (component init-patches _cmds)
        (init rv
          :id-path id-path
          :initial-terminal-dimensions '(80 24)
          :initial-cursor-pos '(0 0))
      (declare (ignore component _cmds))
      (apply-patches state init-patches))
    (let ((size-known (state-ref state '(:components :test-rv-id :size-known))))
      (is-true size-known
        "root-viewport must have size-known=t after init")
      (let ((view-result (view rv state :id-path id-path)))
        (is-true view-result
          "root-viewport view must return non-nil DSL immediately after init")))))

(test shutdown-must-restore-cursor-to-initial-position
  "Bug 3: shutdown-platform must use *last-cursor-pos* to restore cursor position."
  (let ((src (uiop:read-file-string
               (asdf:system-relative-pathname
                 "elmtui"
                 "src/platform/driver.lisp"))))
    (is-true (search "set-cursor-position" src)
      "driver.lisp references set-cursor-position at all")
    (let ((shutdown-start (search "(defun shutdown-platform" src))
          (restore-phrase "*last-cursor-pos*"))
      (when shutdown-start
        (let ((shutdown-section
                (subseq src shutdown-start
                  (min (+ shutdown-start 2000) (length src)))))
          (is-true (search restore-phrase shutdown-section)
            "shutdown-platform must use *last-cursor-pos* to restore cursor position"))))))

(test raw-mode-must-be-fully-restored-on-shutdown
  "Bug 5: close-input-source must call disable-raw-char-mode or disable-raw-mode."
  (let ((src (uiop:read-file-string
               (asdf:system-relative-pathname
                 "elmtui"
                 "cl-inputs/src/input/device/tty.lisp"))))
    (is-true (search "disable-raw-char-mode" src)
      "tty.lisp must reference disable-raw-char-mode at all")
    (let ((close-start (search "(defun close-input-source" src)))
      (when close-start
        (let ((close-section
                (subseq src close-start
                  (min (+ close-start 1000) (length src)))))
          (is-true (or (search "disable-raw-char-mode" close-section)
                       (search "disable-raw-mode" close-section))
            "close-input-source must call disable-raw-char-mode or disable-raw-mode"))))))

(test get-cursor-position-must-return-row-first-zero-indexed
  "Bug 6: get-cursor-position must return (row col) using the device's zero-indexed tracked coordinates."
  (asdf:load-system :cl-inputs)
  (let ((device (cl-inputs.device.tty:make-tty-device)))
    (setf (slot-value device 'cl-inputs.device.tty::cursor-row) 7
          (slot-value device 'cl-inputs.device.tty::cursor-col) 13)
    (multiple-value-bind (row col)
        (cl-inputs.terminal.api:get-cursor-position device)
      (is (= 7 row)
          "get-cursor-position must return row as its first value")
      (is (= 13 col)
          "get-cursor-position must return column as its second value"))))


(test pipeline-offset-must-not-use-spurious-state-key
  "Bug 7: %root-viewport-offset must read :offset-x directly, not via :state sub-key."
  (let* ((src (uiop:read-file-string
                (asdf:system-relative-pathname
                  "elmtui"
                  "src/pipeline.lisp")))
         (fn-start (search "%root-viewport-offset" src)))
    (is-true fn-start
      "%root-viewport-offset must exist in pipeline.lisp")
    (when fn-start
      (let ((fn-section (subseq src fn-start (min (+ fn-start 400) (length src)))))
        (is-false (search "'(:state)" fn-section)
          "%root-viewport-offset must not append '(:state) to path (offsets not stored there)")))))

(test process-tree-stage-must-set-dsl-tree
  "Bug 8: process-tree-stage must set ctx-dsl-tree so offset lookup can find the viewport id."
  (let* ((src (uiop:read-file-string
                (asdf:system-relative-pathname
                  "elmtui"
                  "src/pipeline.lisp")))
         (stage-start (search "(define-stage process-tree-stage" src)))
    (is-true stage-start
      "(define-stage process-tree-stage must exist in pipeline.lisp")
    (when stage-start
      (let ((stage-section (subseq src stage-start (min (+ stage-start 1500) (length src)))))
        (is-true (search "ctx-dsl-tree" stage-section)
          "process-tree-stage must set ctx-dsl-tree before calling viewport-rect")))))

(test cursorposition-event-must-be-one-indexed
  "Bug 9: cursorposition event must carry 1-indexed values for %cursor->index in root-viewport."
  (let* ((driver-src (uiop:read-file-string
                       (asdf:system-relative-pathname
                         "elmtui"
                         "src/platform/driver.lisp")))
         (emit-start (search "%emit-startup-cursorposition" driver-src)))
    (is-true emit-start
      "%emit-startup-cursorposition must exist in driver.lisp")
    (when emit-start
      (let ((emit-section (subseq driver-src emit-start
                             (min (+ emit-start 1500) (length driver-src)))))
        (is-true (or (search "(1+ col)" emit-section)
                     (search "(1+ row)" emit-section))
          "cursorposition event in driver must add 1 to convert 0-indexed to 1-indexed")))))

