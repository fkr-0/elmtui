(uiop:define-package :elmtui.ui.widgets.viewport
  (:use :cl :log4cl)
  (:import-from :elmtui.utils
    #:ensure-keyword #:get-path #:set-path)
  (:import-from :elmtui.update-dsl :with-cycle :cmd> :state> :cstate>)
  (:import-from :elmtui.tea-state :state-ref)
  (:import-from :elmtui.tea-state.msg
    #:msg-data #:msg-type)
  (:import-from :elmtui.app.api
    #:get-component-instance #:destroy-component-state)
  (:import-from :elmtui.ui.api #:id-from-path
    #:view #:init #:update
    #:component #:make-state-patch)
  (:import-from :elmtui.view.geo #:rectangle)
  (:import-from :elmtui.core.errors
    #:component-error #:signal-component-not-found
    #:with-error-context #:error-with-context)
  (:export
    #:viewport
    #:make-viewport))

(in-package :elmtui.ui.widgets.viewport)

;;; ---------------------------------------------------------------------------
;;; Shared Utilities
;;; ---------------------------------------------------------------------------

(defun %state-value (state key &optional default)
  "Read KEY from STATE handling hash tables, plists, or NIL gracefully."
  (cond
    ((hash-table-p state)
      (multiple-value-bind (value present) (gethash key state)
        (if present value default)))
    ((listp state)
      (getf state key default))
    (t default)))

(defun %clamp (val min max) (max min (min max val)))

(defun %overflow-effects (height rows overflow-policy issued)
  "Return NEW-HEIGHT, NEW-ISSUED and overflow render commands based on current
geometry.  NIL means the value should remain unchanged."
  (let ((new-height nil)
         (commands nil)
         (new-issued issued))
    (labels ((emit-scroll (dir amount)
               (when (> amount 0)
                 (ecase dir
                   (:down
                     (incf new-issued amount)
                     (push `(:render :scroll-down ,amount) commands))
                   (:up
                     (decf new-issued amount)
                     (push `(:render :scroll-up ,amount) commands)))))
              (truncate-height (limit)
                (setf new-height (max 1 limit))))
      ;; Simple overflow for non-cursor anchored viewport
      (let ((excess (max 0 (- height rows))))
        (when (> excess 0)
          (case overflow-policy
            (:scroll (emit-scroll :down excess))
            (:truncate (truncate-height (min height rows))))))
      (values new-height (if (/= new-issued issued) new-issued nil)
        (nreverse commands)))))

;;;---------------------------------------------------------------
;;; Viewport Component
;;;---------------------------------------------------------------
(defclass viewport (component)
  ()
  (:documentation "A component that manages a scrollable view of a single child component.
Its behavioral state (offsets, dimensions) is in app-state.
It stores the ID of its child component in app-state under :child."))

(defun make-viewport (&key id)
  (make-instance 'viewport :id id))

;;;---------------------------------------------------------------
;;; Component API Implementation (New TEA-aligned)
;;;---------------------------------------------------------------
(defmethod init ((component viewport) &key id-path initial-width initial-height initial-offset-x initial-offset-y initial-child-spec dsl clipping scroll-x scroll-y &allow-other-keys)
  (with-error-context (:operation "viewport-init" :component-id (id-from-path id-path) :module "ui.widgets.viewport")
    (let ((component-id (id-from-path id-path))
           (child-patches nil)
           (child-commands nil)
           (child-id nil)) ; To store child ID for state
      (when initial-child-spec
        (let* ((child-type (first initial-child-spec))
                (id-key (second initial-child-spec))
                (c-id (if (and id-key (eq id-key :id))
                        (third initial-child-spec)
                        (error-with-context
                          'component-error
                          :component-type "viewport"
                          :operation "init"
                          :component-id component-id
                          :context (format nil "child-spec ~S missing :id keyword or value." initial-child-spec)
                          :suggestions '("Ensure child-spec has format: (type :id child-id &rest args)"
                                          "Check that :id keyword is provided and has a value"
                                          "Example: (:my-button :id :my-btn :label \"Click\")"))))
                (child-initargs (cdddr initial-child-spec))

                (child-instance (make-instance child-type :id c-id))
                ;; Child's canonical id-path for its own init is (:components <child-id>)
                (child-id-path-for-child-init (list :components c-id)))

          (unless (keywordp c-id)
            (error-with-context
              'component-error
              :component-type "viewport"
              :operation "init"
              :component-id component-id
              :context (format nil "Child ID ~S must be a keyword." c-id)
              :suggestions '("Use keyword symbols for component IDs like :my-button"
                              "Component IDs should start with a colon (:)"
                              "Example: :my-component-id")))

          (multiple-value-bind (initialized-child current-child-patches current-child-commands) ; Renamed to avoid conflict
            (apply #'init child-instance :id-path child-id-path-for-child-init child-initargs)
            (declare (ignore initialized-child))
            (setf child-id c-id)          ; Store ID for state
            (setf child-patches current-child-patches)
            (setf child-commands current-child-commands))))

      (values component
        (append
          (list (make-state-patch id-path ; Path to the viewport's own component registration
                  `(:type ,(type-of component)
                     :id ,component-id
                     ;; Viewport specific state attributes under a :state sub-plist
                     :state (:width ,(or initial-width 80)
                              :height ,(or initial-height 24)
                              :offset-x ,(or initial-offset-x 0)
                              :offset-y ,(or initial-offset-y 0)
                              :scroll-x ,(or scroll-x 0)
                              :scroll-y ,(or scroll-y 0)
                              :clipping ,(and clipping t)
                              :overflow-policy :scroll
                              :issued-scroll-net 0
                              :size-known nil
                              :pos-known nil
                              :dsl ,dsl)
                     ;; Store child ID directly under the viewport's component state
                     :child-id ,child-id
                     )))
          child-patches) ; Patches for the child component itself
        child-commands))))

(defmethod update ((component viewport) message state &key id-path)
  (log-info "viewport: update id-path=~a message=~a" id-path message)
  (let ((render-commands '()))
    (multiple-value-bind (_new-state patches commands)
      (with-cycle (ctx state :component-path id-path)
        (labels
          ((apply-overflow ()
             "Apply overflow effects and collect scroll commands."
             (let* ((height (cstate> :height 24))
                     (overflow-policy (cstate> :overflow-policy :scroll))
                     (issued (cstate> :issued-scroll-net 0)))
               (multiple-value-bind (new-height new-issued cmds)
                 (%overflow-effects height 100 overflow-policy issued) ; Assume 100 rows for simplicity
                 (when new-height (setf (cstate> :height) new-height))
                 (when new-issued (setf (cstate> :issued-scroll-net) new-issued))
                 (dolist (cmd cmds)
                   (when cmd (push cmd render-commands))))))
            (propagate-to-child ()
              "Propagate message to child if it exists."
              (let ((child-id (cstate> :child-id)))
                (when child-id
                  (let* ((child-canonical-id-path (list :components child-id))
                          (child-instance (get-component-instance child-canonical-id-path state)))
                    (when child-instance
                      (multiple-value-bind (c1 c2)
                        (update child-instance message state :id-path child-canonical-id-path)
                        (let ((child-patches nil)
                               (child-commands nil))
                          (cond
                            ((typep c1 'elmtui.tea-state.api:update-result)
                              (setf child-patches (elmtui.tea-state.api:ur-patches c1))
                              (setf child-commands (elmtui.tea-state.api:ur-commands c1)))
                            ((and (listp c1) (listp c2))
                              (setf child-patches c1)
                              (setf child-commands c2)))
                          (when child-patches
                            (dolist (patch child-patches)
                              (cmd> (lambda () `(:state-patch ,patch)))))
                          (when child-commands
                            (dolist (cmd child-commands)
                              (when cmd (push cmd render-commands))))))))))
              
              (when (listp message)
                (case (msg-type message)
                  (:scroll-to
                    (let ((new-x (msg-data message :x 0))
                           (new-y (msg-data message :y 0)))
                      (setf (cstate> :offset-x) new-x)
                      (setf (cstate> :offset-y) new-y)
                      (apply-overflow)))
                  (:set-child
                    (let* ((new-child-spec (msg-data message :spec))
                            (old-child-id (cstate> :child-id))
                            (new-child-id (when new-child-spec (getf new-child-spec :id))))
                      (when old-child-id
                        (push `(:destroy-component-state ,(list :components old-child-id)) render-commands))
                      (if new-child-spec
                        (let* ((child-type (first new-child-spec))
                                (child-id-keyword (ensure-keyword (getf new-child-spec :id)))
                                (child-props (loop for (k v) on (cddr new-child-spec) by #'cddr
                                               collect k collect v))
                                (child-instance (make-instance child-type :id child-id-keyword))
                                (child-id-path-for-init (list :components child-id-keyword)))
                          (multiple-value-bind (init-comp init-patches init-commands)
                            (apply #'init child-instance :id-path child-id-path-for-init child-props)
                            (declare (ignore init-comp))
                            (when init-patches
                              (dolist (patch init-patches)
                                (cmd> (lambda () `(:state-patch ,patch)))))
                            (when init-commands
                              (dolist (cmd init-commands)
                                (when cmd (push cmd render-commands))))))
                        (setf new-child-id nil))
                      (setf (cstate> :child-id) new-child-id)))
                  (:set-dimensions
                    (let ((new-width (msg-data message :width))
                           (new-height (msg-data message :height)))
                      (when new-width (setf (cstate> :width) new-width))
                      (when new-height (setf (cstate> :height) new-height))
                      (apply-overflow)))
                  (:set-clipping
                    (let ((flag (msg-data message :enabled)))
                      (setf (cstate> :clipping) (and flag t))))
                  (:scroll-by
                    (let ((dx (or (msg-data message :dx) 0))
                           (dy (or (msg-data message :dy) 0)))
                      (setf (cstate> :scroll-x) (+ (cstate> :scroll-x 0) dx))
                      (setf (cstate> :scroll-y) (+ (cstate> :scroll-y 0) dy))
                      (apply-overflow)))
                  (otherwise
                    (propagate-to-child)))))))
        (let* ((command-payloads
                 (remove nil
                   (mapcar (lambda (cmd)
                             (when (typep cmd 'elmtui.update-dsl.api:command)
                               (funcall (elmtui.update-dsl.api::command-thunk cmd))))
                     commands)))
                (all-commands (nconc (nreverse render-commands) command-payloads)))
          (log-info "viewport ~A produced ~A patches and ~A commands."
            id-path patches (length all-commands))
          (elmtui.tea-state:make-update-result :patches patches :commands all-commands))))))

(defmethod view ((component viewport) state &key id-path (children nil) &allow-other-keys)
  (declare (type list id-path) (type t state))
  (log-info "viewport: rendering component at path ~S with children ~S" id-path children)
  (let* ((vp-state (get-path (append id-path '(:state)) state))
          (size-known (%state-value vp-state :size-known))
          (pos-known (%state-value vp-state :pos-known))
          (effective-id (or (%state-value vp-state :id) (first (last id-path)))))
    ;; Guard view until basic readiness conditions are met
    (unless (or size-known pos-known ; Allow viewport to render if either dimension is known
              (and (%state-value vp-state :width) (%state-value vp-state :height)))
      (log-debug "Viewport ~A waiting for size/position; returning NIL view." effective-id)
      (return-from view nil))
    (let* ((children-from-args children)
            (child-from-state (%state-value vp-state :child-dsl-spec))
            (final-children (or children-from-args
                              (cond
                                ((null child-from-state) nil)
                                ((and (listp child-from-state)
                                   (keywordp (first child-from-state)))
                                  (list child-from-state))
                                (t (list child-from-state)))))
            (width (%state-value vp-state :width 80))
            (height (%state-value vp-state :height 24))
            (offset-x (%state-value vp-state :offset-x 0))
            (offset-y (%state-value vp-state :offset-y 0))
            (scroll-x (%state-value vp-state :scroll-x 0))
            (scroll-y (%state-value vp-state :scroll-y 0))
            (clipping (%state-value vp-state :clipping))
            (effective-id-viewport (intern (format nil "VIEWPORT-~A" effective-id) :keyword)))
      (unless final-children
        (log-warn "Viewport ~A has no children." effective-id))
      `(:viewport :id ,effective-id-viewport
         :style (:width ,width :height ,height
                  :offset-x ,offset-x :offset-y ,offset-y
                  :scroll-x ,scroll-x :scroll-y ,scroll-y
                  :overflow ,(if clipping :hidden :visible))
         :children ,final-children))))
