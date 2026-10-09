(uiop:define-package :elmtui.ui.widgets.viewport
  (:use :cl :log4cl)
  (:import-from :elmtui.utils
    #:get-path #:set-path)
  (:import-from :elmtui.state.update
    #:make-update-context
    #:sref
    #:context-patches
    #:context-commands)
  (:import-from :elmtui.state.msg
    #:msg-data #:msg-type)
  (:import-from :elmtui.ui.api #:id-from-path
    #:view #:init #:update
    #:component #:make-state-patch
    #:component-state-map-path
    #:instantiate-component-from-dsl)
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
                   ;; (:up
                   ;;   (decf new-issued amount)
                   ;;   (push `(:render :scroll-up ,amount) commands))
                   )))
              (truncate-height (limit)
                (setf new-height (max 1 limit))))
      ;; Simple overflow for non-cursor anchored viewport
      (let ((excess (max 0 (- height rows))))
        (when (> excess 0)
          (case overflow-policy
            (:scroll nil) ; inner scrolling moves content, never the physical terminal
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

(defun %child-spec-id (child-spec)
  "Extract :id from CHILD-SPEC DSL list when props form a proper plist."
  (let ((props (and (consp child-spec) (rest child-spec))))
    (and (listp props)
      (evenp (length props))
      (getf props :id))))

(defun %valid-child-dsl-spec-p (child-spec)
  "Return true when CHILD-SPEC has a keyword tag and a well-formed plist tail."
  (let ((props (and (consp child-spec) (rest child-spec))))
    (and (consp child-spec)
      (keywordp (first child-spec))
      (listp props)
      (evenp (length props)))))

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
        (let* ((c-id (or (%child-spec-id initial-child-spec)
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
                ;; Child's canonical id-path for its own init is (:components <child-id>)
                (child-id-path-for-child-init (list :components c-id))
                (child-instance (instantiate-component-from-dsl initial-child-spec child-id-path-for-child-init)))

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

          (when child-instance
            (multiple-value-bind (initialized-child current-child-patches current-child-commands) ; Renamed to avoid conflict
              (apply #'init child-instance :id-path child-id-path-for-child-init child-initargs)
              (declare (ignore initialized-child))
              (setf child-id c-id)          ; Store ID for state
              (setf child-patches current-child-patches)
              (setf child-commands current-child-commands)))))

      (values component
        (append
          (list (make-state-patch (component-state-map-path id-path) ; Path to the viewport's own component registration
                  `(:type ,(type-of component)
                     :id ,component-id
                     :width ,(or initial-width 80)
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
                     :dsl ,dsl
                     :child-dsl-spec ,initial-child-spec
                     ;; Store child ID directly under the viewport's component state
                     :child-id ,child-id
                     )))
          child-patches) ; Patches for the child component itself
        child-commands))))

(defmethod update ((component viewport) message state &key id-path)
  (declare (ignore component))
  (log-info "viewport: update id-path=~a message=~a" id-path message)
  (let* ((ctx (make-update-context state :base-path (component-state-map-path id-path)))
         (render-commands '())
         (extra-patches nil)
         (extra-commands nil))
    (labels ((apply-overflow ()
               (let* ((height (sref ctx :height 24))
                      (overflow-policy (sref ctx :overflow-policy :scroll))
                      (issued (sref ctx :issued-scroll-net 0)))
                 (multiple-value-bind (new-height new-issued cmds)
                     (%overflow-effects height 100 overflow-policy issued)
                   (when new-height (setf (sref ctx :height) new-height))
                   (when new-issued (setf (sref ctx :issued-scroll-net) new-issued))
                   (dolist (cmd cmds)
                     (push cmd render-commands)))))
             (propagate-to-child ()
               (let* ((child-spec (sref ctx :child-dsl-spec))
                      (child-id (%child-spec-id child-spec)))
                 (when (and (%valid-child-dsl-spec-p child-spec) (keywordp child-id))
                   (let* ((child-id-path (list :components child-id))
                          (child-instance (instantiate-component-from-dsl child-spec child-id-path)))
                     (when child-instance
                       (let* ((result (update child-instance message state :id-path child-id-path))
                              (child-patches (and (typep result 'elmtui.state.api:update-result)
                                               (elmtui.state.api:ur-patches result)))
                              (child-commands (and (typep result 'elmtui.state.api:update-result)
                                                (elmtui.state.api:ur-commands result))))
                         (when child-patches
                           (setf extra-patches (nconc extra-patches child-patches)))
                         (when child-commands
                           (setf extra-commands (nconc extra-commands child-commands))))))))))
      (when (listp message)
        (case (msg-type message)
          (:scroll-to
           (setf (sref ctx :offset-x) (msg-data message :x 0))
           (setf (sref ctx :offset-y) (msg-data message :y 0))
           (apply-overflow))
          (:set-child
           (let* ((raw-child-spec (msg-data message :spec))
                  (new-child-spec (and (%valid-child-dsl-spec-p raw-child-spec) raw-child-spec))
                  (old-child-id (sref ctx :child-id))
                  (new-child-id (%child-spec-id new-child-spec)))
             (when old-child-id
               (push `(:destroy-component-state ,(list :components old-child-id)) render-commands))
             (when (and new-child-spec (keywordp new-child-id))
               (let* ((child-props (cddr new-child-spec))
                      (child-id-path (list :components new-child-id))
                      (child-instance (instantiate-component-from-dsl new-child-spec child-id-path)))
                 (when child-instance
                   (multiple-value-bind (_ init-patches init-commands)
                       (apply #'init child-instance :id-path child-id-path child-props)
                     (declare (ignore _))
                     (when init-patches
                       (setf extra-patches (nconc extra-patches init-patches)))
                     (when init-commands
                       (setf extra-commands (nconc extra-commands init-commands)))))))
             (setf (sref ctx :child-dsl-spec) new-child-spec)
             (setf (sref ctx :child-id) new-child-id)))
          (:set-dimensions
           (let ((new-width (msg-data message :width))
                 (new-height (msg-data message :height)))
             (when new-width (setf (sref ctx :width) new-width))
             (when new-height (setf (sref ctx :height) new-height))
             (let ((w (sref ctx :width nil))
                   (h (sref ctx :height nil)))
               (when (and w h (> w 0) (> h 0))
                 (setf (sref ctx :size-known) t)))
             (apply-overflow)))
          (:set-clipping
           (setf (sref ctx :clipping) (and (msg-data message :enabled) t)))
          (:scroll-by
           (let ((dx (or (msg-data message :dx) 0))
                 (dy (or (msg-data message :dy) 0)))
             (setf (sref ctx :scroll-x) (+ (sref ctx :scroll-x 0) dx))
             (setf (sref ctx :scroll-y) (+ (sref ctx :scroll-y 0) dy))
             (apply-overflow)))
          (otherwise
           (propagate-to-child))))
      (let* ((ctx-patches (context-patches ctx))
             (ctx-commands (context-commands ctx))
             (all-commands (nconc (nreverse render-commands) ctx-commands extra-commands)))
        (elmtui.state.api:make-update-result
          :patches (append ctx-patches extra-patches)
          :commands all-commands)))))

(defmethod view ((component viewport) state &key id-path (children nil) &allow-other-keys)
  (declare (type list id-path) (type t state))
  (log-debug "viewport: rendering component at path ~S with children ~S" id-path children)
  (let* ((vp-state (get-path (component-state-map-path id-path) state))
          (size-known (%state-value vp-state :size-known))
          (width (%state-value vp-state :width))
          (height (%state-value vp-state :height))
          (effective-id (or (%state-value vp-state :id) (first (last id-path)))))
    ;; Guard view until basic readiness conditions are met.
    (unless (or size-known
              (and width height (> width 0) (> height 0)))
      (log-debug "Viewport ~A waiting for size/position; skipping view." effective-id)
      (return-from view nil))
    (let* ((children-from-args children)
            (child-from-state (%state-value vp-state :child-dsl-spec))
            (final-children (or children-from-args
                              (cond
                                ((null child-from-state) nil)
                                ((%valid-child-dsl-spec-p child-from-state)
                                  (list child-from-state))
                                (t (list child-from-state)))))
            (width (or width 1))
            (height (or height 1))
            (offset-x (%state-value vp-state :offset-x 0))
            (offset-y (%state-value vp-state :offset-y 0))
            (scroll-x (%state-value vp-state :scroll-x 0))
            (scroll-y (%state-value vp-state :scroll-y 0))
            (clipping (%state-value vp-state :clipping))
            (effective-id-viewport (let* ((name (string-upcase (string effective-id)))
                                           (pref "VIEWPORT-"))
                                     (if (uiop:string-prefix-p pref name)
                                       effective-id
                                       (intern (concatenate 'string pref name) :keyword)))))
      (unless final-children
        (log-debug "Viewport ~A has no children." effective-id))
      `(:viewport :id ,effective-id-viewport
         :style (:width ,width :height ,height
                  :offset-x ,offset-x :offset-y ,offset-y
                  :scroll-x ,scroll-x :scroll-y ,scroll-y
                  :overflow ,(if clipping :hidden :visible))
         :children ,final-children))))
