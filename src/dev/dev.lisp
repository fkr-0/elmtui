;;;===============================================================
;;; File: src/dev/dev.lisp
;;; ElmTUI Dev Examples & Concept Documentation

;;; Example 1: Message Validation and Restarts
;; Demonstrates message contract validation, error signaling, and DRY restarts.

(in-package :cl)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (uiop:define-package :elmtui.dev
    (:use :cl :elmtui.core.events :elmtui.core.conditions :elmtui.view.core
          :elmtui.view.layout :elmtui.view.styled :elmtui.view.layout.grid
     :elmtui.view.geo) ; Added :elmtui.view.geo
    (:export :example-flexbox-layout
     :example-grid-layout
             :send-foo-message
     :dev-main
             :run-faulty-async
     :demo-event-loop)))

(in-package :elmtui.dev)

;;;-----------------------------------------------------------------------------
;;; Interactive Example: Flexbox Layout
;;;-----------------------------------------------------------------------------

;; (defun example-flexbox-layout ()
;;   "Interactive example demonstrating flexbox layout."
;;   (let* ((child1 (make-styled-node :type :text :props '(:content "Child 1" :flex-grow 1)))
;;          (child2 (make-styled-node :type :text :props '(:content "Child 2" :flex-grow 2)))
;;          (child3 (make-styled-node :type :text :props '(:content "Child 3" :flex-grow 1)))
;;          (container (make-styled-node :type :container
;;                                       :props '(:display :flex :flex-direction :row)
;;                                       :children (list child1 child2 child3)))
;;          (screen-rect (make-instance 'rectangle :x 0 :y 0 :w 800 :h 600))) ; Use make-instance
;;     (layout-tree container screen-rect)
;;     (format t "Flexbox Layout Example:~%")
;;     (dolist (child (ui-node-children container))
;;       (format t "Child: ~A~%" (ui-node-props child)))))

;; ;;;-----------------------------------------------------------------------------
;; ;;; Interactive Example: CSS Grid Layout
;; ;;;-----------------------------------------------------------------------------

;; (defun example-grid-layout ()
;;   "Interactive example demonstrating CSS Grid layout."
;;   (let* ((child1 (make-styled-node :type :text :props '(:content "A" :grid-area "header")))
;;          (child2 (make-styled-node :type :text :props '(:content "B" :grid-area "main")))
;;          (child3 (make-styled-node :type :text :props '(:content "C" :grid-area "sidebar")))
;;          (child4 (make-styled-node :type :text :props '(:content "D" :grid-area "footer")))
;;          (container (make-styled-node :type :container
;;                                       :props '(:display :grid
;;                                                :grid-template-areas '(("header" "header" "header")
;;                                                                       ("main" "sidebar" "sidebar")
;;                                                                       ("footer" "footer" "footer"))
;;                                                :grid-template-columns '(:fr 1 :fr 2 :fr 1)
;;                                                :grid-template-rows '(:auto :auto :auto))
;;                                       :children (list child1 child2 child3 child4)))
;;          (screen-rect (make-instance 'rectangle :x 0 :y 0 :w 800 :h 600))) ; Use make-instance
;;     (layout-tree container screen-rect)
;;     (format t "Grid Layout Example:~%")
;;     (dolist (child (ui-node-children container))
;;       (format t "Child: ~A~%" (ui-node-props child)))))

;; ;;; Register a message contract for type :foo
;; (setf (gethash :foo elmtui.core.events:*message-contracts*)
;;       (lambda (msg) (and (listp (elmtui.core.events:message-data msg))
;;                          (member :bar (elmtui.core.events:message-data msg)))))

;; (defun make-foo-message (data)
;;   (elmtui.core.events:make-message :foo data))

;; (defun send-foo-message (target data)
;;   "Send a :foo message, demonstrating contract validation and restarts."
;;   (elmtui.core.conditions:with-message-restarts (c)
;;     (let ((msg (make-foo-message data)))
;;       (elmtui.core.events:send-message target msg))))

;; ;;; Example usage:
;; ;; (send-foo-message some-relay '(:bar 42))   ;; Valid
;; ;; (send-foo-message some-relay '(:baz 99))   ;; Triggers contract error, allows skip/replace/retry

;; ;;; Example 2: Async Task with Error and Restarts
;; ;; Demonstrates async task error handling, rollback, and custom result restarts.

;; (defun faulty-task ()
;;   (error "Simulated async failure."))

;; (defun run-faulty-async ()
;;   "Run an async task that fails, demonstrating async restarts."
;;   (elmtui.core.conditions:with-async-restarts (c)
;;     (let ((cmd (elmtui.core.async:cmd-async #'faulty-task)))
;;       (elmtui.core.async:interpret-cmd cmd)
;;       (elmtui.core.async:await-cmd cmd))))

;; ;;; Example usage:
;; ;; (run-faulty-async)
;; ;; On error, choose to ignore, rollback, replace, provide result, or retry.

;; ;;; Example 3: Event Loop with Subscriber, Error Handling, and Removal
;; ;; Demonstrates event loop, subscriber registration, error isolation, and removal.

;; (defvar *received* nil)

;; (defun my-event-handler (event)
;;   (push (elmtui.core.events:message-data event) *received*)
;;   (when (equal (elmtui.core.events:message-data event) :fail)
;;     (error "Handler error for demonstration.")))

;; (defun demo-event-loop ()
;;   "Start event loop, add subscriber, publish events, and handle errors."
;;   (elmtui.core.loop:start-loop)
;;   (let ((token (elmtui.core.loop:subscribe :demo #'my-event-handler)))
;;     (declare (ignore token)) ; Ignore unused variable
;;     ;; Publish valid event
;;     (elmtui.core.loop:publish (elmtui.core.events:make-message :demo :ok))
;;     ;; Publish event that triggers handler error (handled by conditions)
;;     (elmtui.core.loop:publish (elmtui.core.events:make-message :demo :fail))
;;     ;; Remove subscriber (dynamic removal, not yet implemented)
;;     ;; (elmtui.core.loop:unsubscribe token)
;;     (elmtui.core.loop:elm-stop-loop)))

;; ;;; Example usage:
;; ;; (demo-event-loop)
;; ;; Observe error isolation and instrumentation in the event loop.

;; ;;; Concept Summary:
;; ;; - Message contracts are registered and enforced at runtime.
;; ;; - DRY restart macros allow interactive or programmatic recovery from errors.
;; ;; - Async tasks and event loop handlers are robust to errors, supporting rollback, replacement, and custom results.
;; ;; - All critical operations are instrumented and log failures for debugging.

;; (defun dev-main ()
;;   (format t "Running ElmTUI Dev Examples...~%"))


;; set app-message-processor
;; (let ((ufn (getf
;;             elmtui.platform.driver::*app-spec* :update-fn)))
;; (setf elmtui.core.globals:*app-message-processor*
;;             (lambda (msg)

;;               (log:debug "DRIVER: Processing message in app-message-processor: ~S" msg)
;;               (apply ufn (list elmtui.platform.driver::*current-app-model* msg)))))
;; enqueue term size update
;; (funcall (elmtui.platform.backend.terminal::terminal-instance-publish-fn
;;           elmtui.platform.driver::*backend*) (list :terminal-resized :new-dimensions (list 33 33)))
;; (elmtui.core.loop:start-loop )
;; (elmtui.platform.driver::render-frame
;;  elmtui.platform.driver::*app-spec*
;;  elmtui.platform.driver::*current-app-model*
;;  elmtui.platform.driver::*backend*)
;; elmtui.platform.driver::*last-ctx*
(defun buffer->string (buffer)
  "Convert a virtual buffer to a string representation."
  (let ((rows-count (elmtui.platform.backend.common.virtual-buffer:buffer-height buffer))
        (cols-count (elmtui.platform.backend.common.virtual-buffer:buffer-width buffer)))
    (with-output-to-string
        (a)
      (dotimes (row rows-count)
        (progn
          (dotimes (col cols-count)
            (let ((cell (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at buffer row col)))
              (format t "~c" (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell))))
          (format t "~%")))
      (format t "~%"))))

(defmacro with-buffer-dump ((buffer) &body body)
  `(handler-bind
       ((error (lambda (c)
                 (format *error-output* "~%Buffer state on error:~%~A"
                         (buffer->string ,buffer))
                 (invoke-debugger c))))
     ,@body))
