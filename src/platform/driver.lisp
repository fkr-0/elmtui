;;; == src/platform/driver.lisp ===============================================
;;; Platform Driver - Generic Application Runner
;;;============================================================================

(uiop:define-package :elmtui.platform.driver
  (:use :cl :bt
        :elmtui.platform.input) ; For start-reader
  (:import-from :log4cl
                #:log-debug #:log-info #:log-warn #:log-error)
  (:import-from :elmtui.view.styled
                #:apply-stylesheet-to-tree)
  (:import-from :elmtui.view.layout
                #:layout-tree)
  (:import-from :elmtui.core.event-types
                #:key-event) ; For typep check
  (:import-from :elmtui.core.globals
                #:*app-sender*)
  ;; Removed elmtui.core.focus and elmtui.core.keymap imports as they were unused
  (:import-from :elmtui.state #:get-path)
  (:import-from :elmtui.view.geo
                #:make-rectangle #:make-pos #:make-size)
  (:import-from :elmtui.platform.api
                #:initialize-backend #:shutdown-backend
                ;; #:term-w #:term-h #:handle-backend-resize ; Not directly used here
                #:flush-output #:get-cursor-position #:set-cursor-position) ; #:clear-lines #:scroll-up #:scroll-down ; Not directly used here
  (:import-from :elmtui.platform.tree-renderer
                #:render-laid-out-tree-to-canvas)
  (:import-from :elmtui.platform.backend.terminal.diff-renderer
                #:compute-buffer-diff #:apply-diff-to-backend
                #:*compute-buffer-diff-first-call*)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:copy-virtual-buffer #:make-virtual-buffer
                #:buffer-width #:buffer-height)
  (:import-from :elmtui.app.api #:get-component-instance) ; Removed run-application, kept get-component-instance
  (:import-from :elmtui.core.loop
                #:publish #:start-loop #:elm-stop-loop)
  (:import-from :elmtui.core.async
                #:interpret-cmd)
  (:import-from :elmtui.ui.widgets.root-viewport
                #:get-cleanup-info) ; Removed root-viewport class import, not directly used
  (:import-from :cleve-elm.channel #:<-)) ; Import for receiving from channel

(in-package :elmtui.platform.driver)

;;; ---------------------------------------------------------------------------
;;; Global state (driver-level)
;;; ---------------------------------------------------------------------------

(defvar *backend* nil "Current platform backend instance.")
(defvar *input-thread* nil "Thread handling input events.")
(defvar *stop-input-fn* nil "Function to stop the input thread.")
(defvar *driver-initiated-shutdown-p* nil "T if driver requested shutdown.")
(defvar *previous-frame-buffer* nil "Buffer from the previous frame for diffing, matches root viewport dimensions.")
(defvar *current-app-model* nil "Holds the current application model (state).")
(defvar *root-viewport-id-path* nil "Full path to the root-viewport component's state map, e.g., '(:components :root-vp).")

;;; ---------------------------------------------------------------------------
;;; Helper utilities
;;; ---------------------------------------------------------------------------

(defun initialize-backend-with-publish-fn (backend-type tty-path publish-fn)
  (elmtui.platform.api:initialize-backend backend-type :publish-fn publish-fn :tty-path tty-path))

(defun start-input-reader-thread (backend-instance publish-fn)
  (multiple-value-bind (thread stop-fn)
      (start-reader backend-instance :event-handler publish-fn)
    (values thread stop-fn)))

;;; ---------------------------------------------------------------------------
;;; Application-state bootstrap
;;; ---------------------------------------------------------------------------

(defun initialize-app-model (app-spec publish-fn)
  (let* ((init-fn (getf app-spec :init-fn))
         (update-fn (getf app-spec :update-fn))
         (view-fn (getf app-spec :view-fn))
         (subs-fn (getf app-spec :subscriptions-fn)) ; Kept for potential future use
         (root-viewport-id (getf app-spec :root-viewport-id)))
    (unless (and init-fn update-fn view-fn)
      (error "App spec missing required functions: :init-fn, :update-fn, :view-fn"))
    (unless root-viewport-id
      (error "App spec missing :root-viewport-id"))
    ;; *root-viewport-id-path* is the full path from app-state root
    (setf *root-viewport-id-path* (list :components root-viewport-id))
    (log:info "DRIVER: Initializing application model for ~A... Root Viewport ID Path: ~S"
              (getf app-spec :name) *root-viewport-id-path*)
    (multiple-value-bind (initial-model initial-cmds) (funcall init-fn)
      (setf *current-app-model* initial-model)
      (setf elmtui.core.globals:*app-sender* publish-fn)
      (values update-fn view-fn subs-fn initial-model initial-cmds))))

(defun process-initial-commands (cmds)
  (when cmds
    (log:debug "DRIVER: Processing initial commands...")
    (dolist (cmd cmds)
      (interpret-cmd cmd)))) ; *app-sender* is used by interpret-cmd

;;; ---------------------------------------------------------------------------
;;; Previous Buffer Initialization
;;; ---------------------------------------------------------------------------
(defun setup-initial-previous-buffer (current-model)
  (unless *root-viewport-id-path*
    (error "Root viewport ID path not set before previous buffer initialization."))
  ;; The root viewport's behavioral state (width, height, offsets) is expected
  ;; to be under a :state key within its own component state map.
  ;; e.g., (:components <root-id> :state)
  (let* ((root-viewport-component-state-path (append *root-viewport-id-path* '(:state)))
         (root-viewport-behavioral-state (elmtui.state:get-path current-model root-viewport-component-state-path)))
    (unless root-viewport-behavioral-state
      (error (format nil "Root viewport behavioral state not found at ~S in model ~S" root-viewport-component-state-path current-model)))
    (let ((buffer-width (getf root-viewport-behavioral-state :width))
          (buffer-height (getf root-viewport-behavioral-state :height)))
      (unless (and (integerp buffer-width) (> buffer-width 0)
                   (integerp buffer-height) (> buffer-height 0))
        (error (format nil "Root viewport width or height not found or invalid in state: ~S" root-viewport-behavioral-state)))
      (log:info "DRIVER: Initializing previous frame buffer. Dimensions: ~Ax~A from root-viewport state."
                buffer-width buffer-height)
      (setf *previous-frame-buffer* (make-virtual-buffer buffer-width buffer-height))
      (setf elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* t)
      (log:info "DRIVER: Previous frame buffer initialized."))))

;;; ---------------------------------------------------------------------------
;;; Rendering Frame Logic
;;; ---------------------------------------------------------------------------
(defun render-frame (view-fn current-model backend-instance)
  (log:debug "DRIVER: --- Starting Render Frame ---")
  (unless *root-viewport-id-path*
    (log:error "DRIVER: Root viewport ID path not set.")
    (return-from render-frame))

  (let* ((root-viewport-component-state-path (append *root-viewport-id-path* '(:state)))
         (root-viewport-state (elmtui.state:get-path current-model root-viewport-component-state-path))
         (viewport-width (getf root-viewport-state :width))
         (viewport-height (getf root-viewport-state :height))
         (viewport-offset-x (getf root-viewport-state :offset-x 0)) ; Default to 0
         (viewport-offset-y (getf root-viewport-state :offset-y 0))) ; Default to 0

    (unless (and (integerp viewport-width) (> viewport-width 0)
                 (integerp viewport-height) (> viewport-height 0)
                 (numberp viewport-offset-x) (numberp viewport-offset-y))
      (log:error "DRIVER: Root viewport dimensions or offsets not found or invalid in state: ~S" root-viewport-state)
      (return-from render-frame))

    (unless *previous-frame-buffer*
      (log:warn "DRIVER: Previous frame buffer is nil. Attempting to initialize.")
      (setup-initial-previous-buffer current-model)
      (unless *previous-frame-buffer*
        (log:error "DRIVER: Failed to initialize previous frame buffer in render-frame.")
        (return-from render-frame)))

    (when (or (/= (elmtui.platform.backend.common.virtual-buffer:buffer-width *previous-frame-buffer*) viewport-width)
              (/= (elmtui.platform.backend.common.virtual-buffer:buffer-height *previous-frame-buffer*) viewport-height))
      (log:info "DRIVER: Root viewport size changed. Re-initializing previous frame buffer. Old: ~Ax~A, New: ~Ax~A"
                (elmtui.platform.backend.common.virtual-buffer:buffer-width *previous-frame-buffer*)
                (elmtui.platform.backend.common.virtual-buffer:buffer-height *previous-frame-buffer*)
                viewport-width viewport-height)
      (setf *previous-frame-buffer* (make-virtual-buffer viewport-width viewport-height))
      (setf elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* t))

    (let* ((raw-ui-tree (funcall view-fn current-model))
           (styled-tree (apply-stylesheet-to-tree raw-ui-tree (elmtui.state:get-path current-model '(:current-stylesheet) nil)))
           (layout-constraints (make-rectangle :pos (make-pos :x 0 :y 0)
                                               :size (make-size :w viewport-width
                                                                :h viewport-height)))
           (laid-out-tree (layout-tree styled-tree layout-constraints))
           (current-frame-buffer (make-virtual-buffer viewport-width viewport-height)))

      (log:debug "DRIVER: UI tree processed. Rendering to current_frame_buffer (~Ax~A)." viewport-width viewport-height)
      (elmtui.platform.tree-renderer:render-laid-out-tree-to-canvas laid-out-tree current-frame-buffer)
      (log:debug "DRIVER: Laid-out tree rendered to current frame buffer.")

      (log:debug "DRIVER: Computing buffer diff. Current: (~Ax~A), Previous: (~Ax~A)"
                 viewport-width viewport-height
                 (if *previous-frame-buffer* (elmtui.platform.backend.common.virtual-buffer:buffer-width *previous-frame-buffer*) "N/A")
                 (if *previous-frame-buffer* (elmtui.platform.backend.common.virtual-buffer:buffer-height *previous-frame-buffer*) "N/A"))

      (let ((diff-ops (compute-buffer-diff *previous-frame-buffer* current-frame-buffer)))
        (log:debug "DRIVER: Buffer diff computed. ~A operations." (length diff-ops))

        (when diff-ops
          (log:debug "DRIVER: Applying diff. Viewport terminal offset (row, col): (~A, ~A)." viewport-offset-y viewport-offset-x)
          (if (typep backend-instance 'elmtui.platform.backend.terminal:terminal-instance)
              (apply-diff-to-backend diff-ops backend-instance viewport-offset-y viewport-offset-x)
              (log:warn "DRIVER: apply-diff-to-backend called with non-terminal backend instance. Diff not applied.")))
        (log:debug "DRIVER: Diff applied (or skipped) to backend."))

      (setf *previous-frame-buffer* (copy-virtual-buffer current-frame-buffer))
      (log:debug "DRIVER: Current frame buffer stored as previous.")))
  (log:debug "DRIVER: --- Finished Render Frame ---"))

;;; ---------------------------------------------------------------------------
;;; Main Application Loop & Lifecycle
;;; ---------------------------------------------------------------------------
(defun app-loop (app-spec backend-instance)
  (let* ((publish-fn (lambda (event &key target-channel-name) (publish event :target-channel-name target-channel-name))) ; Ensure publish can take channel name
         (*driver-initiated-shutdown-p* nil)
         ;; focus-manager removed as it was unused
         (app-message-queue (getf app-spec :message-queue)))

    (unless app-message-queue
      (error "App spec missing :message-queue"))

    (multiple-value-bind (update-fn view-fn subs-fn initial-model initial-cmds)
        (initialize-app-model app-spec publish-fn)
      (declare (ignore subs-fn)) ; Explicitly ignore if not used

      (setf *current-app-model* initial-model)
      (process-initial-commands initial-cmds) ; publish-fn is implicitly via *app-sender*

      (setup-initial-previous-buffer *current-app-model*)

      (let ((message-processor (lambda (msg)
                                 (log:debug "DRIVER: Processing message: ~S" msg)
                                 (log:trace "DRIVER: Model before message: ~S" *current-app-model*)

                                 (multiple-value-bind (new-model cmds)
                                     (funcall update-fn *current-app-model* msg)
                                   (setf *current-app-model* new-model)
                                   (when cmds (dolist (cmd cmds) (interpret-cmd cmd))))

                                 (render-frame view-fn *current-app-model* backend-instance)
                                 (log:trace "DRIVER: Model after message: ~S" *current-app-model*))))
        ;; Initial render
        (render-frame view-fn *current-app-model* backend-instance)
        (log:info "DRIVER: Application started. Entering main event loop.")

        (loop
          (let ((msg (cleve-elm.channel:<- app-message-queue))) ; Use cleve-elm:<- to receive from channel
            (when (or (eq msg :quit)
                      (and (consp msg) (eq (car msg) :quit))
                      (and (typep msg 'elmtui.core.event-types:key-event)
                           (eql (elmtui.core.event-types:key-event-key msg) #\q)))
              (log:info "DRIVER: Quit message received in app-loop: ~S. Initiating shutdown." msg)
              (setf *driver-initiated-shutdown-p* t)
              (elm-stop-loop)
              (return))
            (funcall message-processor msg))))))
  (log:info "DRIVER: Application event loop exited."))

(defun shutdown-platform ()
  (log:info "DRIVER: Shutting down platform...")
  (when *stop-input-fn*
    (funcall *stop-input-fn*)
    (setf *stop-input-fn* nil))
  (when *input-thread*
    (ignore-errors (join-thread *input-thread*)) ; Add timeout to join-thread
    (unless (bt:thread-alive-p *input-thread*)
      (setf *input-thread* nil))
    (when *input-thread*
      (log:warn "DRIVER: Input thread did not terminate cleanly, attempting to destroy.")
      (ignore-errors (bt:destroy-thread *input-thread*))
      (setf *input-thread* nil)))


  (when (and *root-viewport-id-path* *current-app-model* *backend*)
    (let* ((root-vp-instance (get-component-instance *current-app-model* *root-viewport-id-path*))
           (cleanup-info (if root-vp-instance
                             (elmtui.ui.widgets.root-viewport:get-cleanup-info
                              root-vp-instance
                              (car (last *root-viewport-id-path*)) ; Pass the ID part of the path
                              *current-app-model*)
                             (progn
                               (log:warn "DRIVER: Root viewport instance not found for cleanup. ID Path: ~S" *root-viewport-id-path*)
                               nil))))
      (when cleanup-info
        (log:info "DRIVER: Performing cleanup based on root-viewport info: ~S" cleanup-info)
        (let ((initial-cursor-row (getf cleanup-info :initial-cursor-row 0))
              (anchor (getf cleanup-info :anchor :top-left)))
          (cond
            ((or (eq anchor :below-cursor) (eq anchor :above-cursor))
             (elmtui.platform.api:set-cursor-position *backend* initial-cursor-row 0))
            (t (elmtui.platform.api:set-cursor-position *backend* 0 0))))
        (elmtui.platform.api:flush-output *backend*))))

  (when *backend*
    (shutdown-backend *backend*)
    (setf *backend* nil))
  (setf *current-app-model* nil
        *previous-frame-buffer* nil
        *root-viewport-id-path* nil
        elmtui.platform.backend.terminal.diff-renderer:*compute-buffer-diff-first-call* t)
  (log:info "DRIVER: Platform shutdown complete."))

(defun run-app-platform (app-spec
                         &key (backend-type :terminal) (tty-path "/dev/tty")
                         ;; These canvas-* args are now handled by root-viewport init
                         &allow-other-keys) ; Allow other keys to be passed through if necessary
  (setf *backend* (initialize-backend-with-publish-fn backend-type tty-path
                                                      (lambda (ev &key target-channel-name)
                                                        (publish ev :target-channel-name target-channel-name))))
  (multiple-value-bind (input-thread stop-fn)
      (start-input-reader-thread *backend*
                                 (lambda (ev &key target-channel-name)
                                   (publish ev :target-channel-name target-channel-name)))
    (setf *input-thread* input-thread
          *stop-input-fn* stop-fn))
  (unwind-protect
       (progn
         (elmtui.core.loop:start-loop) ; Ensure the core event loop is started
         (app-loop app-spec *backend*))
    (shutdown-platform)
    (elm-stop-loop))) ; Ensure core loop is also signaled to stop
