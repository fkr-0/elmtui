(uiop:define-package :elmtui.ui.widgets.viewport
  (:use :cl :log4cl )
  ;;(:import-from :elmtui.view.dsl #:defcomponent-dsl)
  (:import-from :elmtui.utils
                #:ensure-keyword)
  (:import-from :elmtui.app.api
                #:get-component-instance #:destroy-component-state)
  (:import-from :elmtui.ui.api #:id-from-path
                #:view
                #:get-path #:component #:make-state-patch)
  (:import-from :elmtui.view.geo #:rectangle)
  (:export
   #:viewport
   #:make-viewport))

(in-package :elmtui.ui.widgets.viewport)

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
(defmethod init ((component viewport) &key id-path initial-width initial-height initial-offset-x initial-offset-y initial-child-spec dsl &allow-other-keys)
  (let ((component-id (id-from-path id-path))
        (child-patches nil)
        (child-commands nil)
        (child-id nil)) ; To store child ID for state
    (when initial-child-spec
      (let* ((child-type (first initial-child-spec))
             (id-key (second initial-child-spec))
             (c-id (if (and id-key (eq id-key :id))
                       (third initial-child-spec)
                       (error "Viewport init: child-spec ~S missing :id keyword or value." initial-child-spec)))
             (child-initargs (cdddr initial-child-spec))

             (child-instance (make-instance child-type :id c-id))
             ;; Child's canonical id-path for its own init is (:components <child-id>)
             (child-id-path-for-child-init (list :components c-id)))

        (unless (keywordp c-id) (error "Viewport init: child ID ~S must be a keyword." c-id))

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
                                       :state (:width ,initial-width
                                               :height ,initial-height
                                               :offset-x ,(or initial-offset-x 0)
                                               :offset-y ,(or initial-offset-y 0)
                                               :dsl ,dsl)
                                       ;; Store child ID directly under the viewport's component state
                                       :child-id ,child-id
                                       )))
             child-patches) ; Patches for the child component itself
            child-commands)))

(defmethod update ((component viewport) state message &key id-path)
  (let ((viewport-component-state-path id-path) ; Path to the viewport component's own registration
        (viewport-attrs-path (append id-path '(:state))) ; Path to viewport's attributes (width, height, offset)
        (patches nil)
        (commands nil))
    (typecase message
      ((cons (eql :scroll-to))
       (destructuring-bind (new-x new-y) (cdr message)
         (push (make-state-patch (append viewport-attrs-path '(:offset-x)) new-x) patches)
         (push (make-state-patch (append viewport-attrs-path '(:offset-y)) new-y) patches)))
      ((cons (eql :set-child))
       (let* ((new-child-spec (cdr message)) ; e.g., '(:label :id :my-label :text "Hi") or nil
              (old-child-id (get-path state (append viewport-component-state-path '(:child-id))))
              (new-child-id (when new-child-spec (getf new-child-spec :id))))

         (when old-child-id
           ;; Add command to destroy old child's state
           (push `(:destroy-component-state ,(list :components old-child-id)) commands))

         (if new-child-spec
             (let* ((child-type (first new-child-spec))
                    (child-id-keyword (ensure-keyword (getf new-child-spec :id)))
                    (child-props (loop for (k v) on (cddr new-child-spec) by #'cddr ; remove type and :id key
                                       collect k collect v))
                    (child-instance (make-instance child-type :id child-id-keyword))
                    ;; Child's canonical id-path for its own init is (:components <child-id>)
                    (child-id-path-for-init (list :components child-id-keyword)))
               (multiple-value-bind (init-comp init-patches init-commands)
                   (apply #'init child-instance :id-path child-id-path-for-init child-props)
                 (declare (ignore init-comp))
                 (setf patches (append init-patches patches))
                 (setf commands (append init-commands commands))))
             ;; else new-child-spec is nil, meaning remove child
             (setf new-child-id nil))

         ;; Patch to update the child ID reference in the viewport's state
         (push (make-state-patch (append viewport-component-state-path '(:child-id)) new-child-id) patches)))

      ((cons (eql :set-dimensions))
       (destructuring-bind (new-width new-height) (cdr message)
         (push (make-state-patch (append viewport-attrs-path '(:width)) new-width) patches)
         (push (make-state-patch (append viewport-attrs-path '(:height)) new-height) patches)))
      (t
       ;; Propagate to child if it exists
       (let* ((child-id (get-path state (append viewport-component-state-path '(:child-id))))) ; Get child-id from viewport's state
         (when child-id
           (let* ((child-canonical-id-path (list :components child-id)) ; Canonical path to child's registration
                  (child-instance (get-component-instance child-canonical-id-path state)))
             (when child-instance
               (multiple-value-bind (child-patches child-commands)
                   (update child-instance state message :id-path child-canonical-id-path)
                 (setf patches (append child-patches patches))
                 (setf commands (append child-commands commands))))))))
      )
    (values patches commands)))

(defmethod view ((component viewport) (state elmtui.tea-state:application-state) &key id-path (children nil) &allow-other-keys)
  (let* ((viewport-component-registration (get-path id-path state )) ; Get the whole registration for this viewport component
         (viewport-attrs (getf viewport-component-registration :state)) ; Get the :state sub-plist with width, height, offsets
         ;; (child-id (getf viewport-component-registration :child-id))
         (children-from-args children)
         (child-from-state (elmtui.tea-state:state-ref viewport-attrs :child-dsl-spec))
         (final-children (or children-from-args
                             (when child-from-state (list child-from-state))))

         ) ; Get child-id from viewport's direct registration
    (list :container
          :id (gensym "VIEWPORT-CONTAINER-")
          :style `(:width ,(getf viewport-attrs :width 80)
                   :height ,(getf viewport-attrs :height 24)
                   :offset-x ,(getf viewport-attrs :offset-x 0)
                   :offset-y ,(getf viewport-attrs :offset-y 0))

          :children final-children
          ;; (cond
          ;;   ((null children) nil)
          ;;   ((and (= 1 (length children))
          ;;         (listp (first children))
          ;;         (keywordp (first (first children))))
          ;;    ;; Single DSL node, wrap in a list
          ;;    children)
          ;;   (t
          ;;    ;; Multiple children, wrap in a container node
          ;;    (list (list :container
          ;;                :id (gensym (format nil "VIEWPORT-~A-CHILDREN-LAYOUT" (id-from-path id-path)))
          ;;                :children children))))
          )))
