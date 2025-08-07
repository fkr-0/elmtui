(uiop:define-package
    :elmtui.ui.widgets.root-viewport
  (:use :cl #:log4cl
        :elmtui.ui.api
   :elmtui.ui.widgets.viewport)
  (:import-from :elmtui.utils :ensure-list)
  (:import-from :elmtui.tea-state :state-ref)
  (:import-from :elmtui.tea-state.msg
                #:msg-data #:msg-type)
  (:import-from :elmtui.app.api
                #:get-component-instance)
  (:import-from :elmtui.app.system-events
                #:terminalresized-system-event
                #:cursorpositionchanged-system-event)
  ;; (:import-from :elmtui.core.event-types
  ;;               #:key-left #:key-right #:key-up #:key-down)
  (:export #:root-viewport
           #:get-cleanup-info
           #:make-root-viewport
           #:anchor-type))

(in-package :elmtui.ui.widgets.root-viewport)

;;; ---------------------------------------------------------------------------
;;; Types
;;; ---------------------------------------------------------------------------

(deftype anchor-type ()
  "Legal positions for the root-viewport relative to the terminal or cursor."
  '(member :top-left  :top   :top-right
    :left      :center :right
    :bottom-left :bottom :bottom-right
    :below-cursor :above-cursor))

;;; ---------------------------------------------------------------------------
;;; Class
;;; ---------------------------------------------------------------------------

(defclass root-viewport (viewport)
  ()
  (:documentation
   "Stateless root viewport component. All mutable attributes (size,
   offsets, scroll‑state, anchor, initial cursor position, etc.) are maintained
   in the external application state as *patches* rather than CLOS slots."))

;;; ---------------------------------------------------------------------------
;;; Helper functions
;;; ---------------------------------------------------------------------------

(defun %clamp (val min max)
  (max min (min max val)))

(defun compute-anchor-offset (anchor viewport-width viewport-height term-cols term-rows cursor-row cursor-col)
  "Return (offset-y offset-x) for ANCHOR given viewport & terminal geometry."
  (declare (type anchor-type anchor)
           (type (integer 0 *) viewport-width viewport-height term-cols term-rows cursor-row cursor-col))
  (ecase anchor
    (:top-left      (values 0 0))
    (:top           (values 0 (floor (- term-cols viewport-width) 2)))
    (:top-right     (values 0 (- term-cols viewport-width)))
    (:left          (values (floor (- term-rows viewport-height) 2) 0))
    (:center        (values (floor (- term-rows viewport-height) 2)
                            (floor (- term-cols viewport-width) 2)))
    (:right         (values (floor (- term-rows viewport-height) 2)
                            (- term-cols viewport-width)))
    (:bottom-left   (values (- term-rows viewport-height) 0))
    (:bottom        (values (- term-rows viewport-height)
                            (floor (- term-cols viewport-width) 2)))
    (:bottom-right  (values (- term-rows viewport-height)
                            (- term-cols viewport-width)))
    (:below-cursor  (values (min (1+ cursor-row) (- term-rows viewport-height))
                            (%clamp cursor-col 0 (- term-cols viewport-width))))
    (:above-cursor  (values (%clamp (- cursor-row viewport-height) 0 (- term-rows viewport-height))
                            (%clamp cursor-col 0 (- term-cols viewport-width))))) )

(defun compute-view-size (anchor term-cols term-rows cursor-row)
  "Return three values: width height offset-y for ANCHOR variant requiring dynamic height."
  (ecase anchor
    (:below-cursor (values term-cols (max 1 (- term-rows cursor-row 1)) 0))
    (:above-cursor (values term-cols (max 1 cursor-row) 0))
    (t             (values term-cols term-rows 0))) )

(defun child-instance (state id-path)
  "Return the live child component instance, or NIL when absent."
  (let* ((child-spec (get-path (append id-path '(:child)) state)))
    (when (and (consp child-spec) (keywordp (car child-spec)))
      (get-component-instance (append id-path (list (car child-spec))) state))))

;;; ---------------------------------------------------------------------------
;;; Factory
;;; ---------------------------------------------------------------------------

(defun make-root-viewport (id &key (anchor :below-cursor) (initial-cursor-pos '(0 . 0)))
  (declare (ignore anchor initial-cursor-pos))
  (make-instance 'root-viewport :id id))

;;; ---------------------------------------------------------------------------
;;; INIT – sets up stub state until first terminal & cursor info arrive
;;; ---------------------------------------------------------------------------

(defmethod elmtui.ui.api:init ((component root-viewport)
                               &key id-path
                                 initial-terminal-dimensions
                                 initial-cursor-pos
                                 initial-child-spec
                                 dsl)
  (let* ((anchor (or (getf (getf dsl :props) :anchor) :below-cursor))
         (term-cols (or (first initial-terminal-dimensions) 0))
         (term-rows (or (second initial-terminal-dimensions) 0))
         (cursor-c  (or (first initial-cursor-pos) 0))
         (cursor-r  (or (second initial-cursor-pos) 0))
         (size-known (and (> term-cols 0) (> term-rows 0)))
         (pos-known  (and (> cursor-c 0)  (> cursor-r 0)))
         (width  (if size-known term-cols 1))
         (height (if size-known term-rows 1))
         (offset-x 0)
         (offset-y 0))

    ;; If both size and cursor pos known compute offsets immediately
    (when (and size-known pos-known)
      (multiple-value-setq (offset-y offset-x)
        (compute-anchor-offset anchor width height term-cols term-rows cursor-r cursor-c)))

    (values component
            (list ;; component registration
             (list (append id-path '(:type)) :root-viewport)
             ;; geometry
             (list (append id-path '(:state :width))  width)
             (list (append id-path '(:state :height)) height)
             (list (append id-path '(:state :offset-x)) offset-x)
             (list (append id-path '(:state :offset-y)) offset-y)
             ;; flags/metadata
             (list (append id-path '(:state :anchor)) anchor)
             (list (append id-path '(:state :terminal-size)) (list term-cols term-rows))
             (list (append id-path '(:state :cursor-pos))  (list cursor-c cursor-r))
             (list (append id-path '(:state :size-known))  size-known)
             (list (append id-path '(:state :pos-known))   pos-known)
             (list (append id-path '(:state :child-dsl-spec)) initial-child-spec)
             (list (append id-path '(:state :dsl)) dsl))
            nil)))

;;; ---------------------------------------------------------------------------
;;; UPDATE – handle terminal/cursor updates & arrow‑key scrolling
;;; ---------------------------------------------------------------------------

(defmethod elmtui.ui.api:update ((component root-viewport) message state &key id-path)
  (log-info "ROOT-UPDATE: ~A ~A"
            (msg-type message) (msg-data message))
  (flet ((patch (subkey value) `(,(append id-path subkey) ,value)))
    (let* ((st-path (append id-path '(:state)))
           (anchor   (get-path (append st-path '(:anchor)) state))
           (term-size (get-path (append st-path '(:terminal-size)) state '(0 0)))
           (cursor-pos (get-path (append st-path '(:cursor-pos)) state '(0 0)))
           (width  (get-path (append st-path '(:width)) state 1))
           (height (get-path (append st-path '(:height)) state 1))
           (offset-x (get-path (append st-path '(:offset-x)) state 0))
           (offset-y (get-path (append st-path '(:offset-y)) state 0))
           (own-patches nil))

      (case (msg-type message)
        ;; -------------------------------------------------------------------
        (:terminalresized
         (let* ((cols (msg-data message :width))
                (rows (msg-data message :height)))
           (when (and cols rows (> cols 0) (> rows 0))
             (setf term-size (list cols rows)
                   width cols height rows)
             ;; recompute offset if we already know cursor position
             (when (get-path (append st-path '(:pos-known)) state)
               (multiple-value-bind (new-oy new-ox)
                   (compute-anchor-offset anchor width height cols rows (second cursor-pos) (first cursor-pos))
                 (setf offset-x new-ox offset-y new-oy)
                 (push (patch '(:offset-x) offset-x) own-patches)
                 (push (patch '(:offset-y) offset-y) own-patches)))
             (push (patch '(:terminal-size) term-size) own-patches)
             (push (patch '(:width) width) own-patches)
             (push (patch '(:height) height) own-patches)
             (push (patch '(:size-known) t) own-patches))))
        ;; -------------------------------------------------------------------
        (:cursorpositionchanged
         (let ((c (msg-data message :col))
               (r (msg-data message :row)))
           (when (and c r (> c 0) (> r 0))
             (setf cursor-pos (list c r))
             ;; recompute offset if we already know size
             (when (get-path (append st-path '(:size-known)) state)
               (multiple-value-bind (new-oy new-ox)
                   (compute-anchor-offset anchor width height (first term-size) (second term-size) r c)
                 (setf offset-x new-ox offset-y new-oy)
                 (push (patch '(:offset-x) offset-x) own-patches)
                 (push (patch '(:offset-y) offset-y) own-patches)))
             (push (patch '(:cursor-pos) cursor-pos) own-patches)
             (push (patch '(:pos-known) t) own-patches))))
        ;; -------------------------------------------------------------------
        ((list :key-right :key-left :key-up :key-down)
         ;; Arrow key panning – independent of anchor
         (let ((cols (first term-size)) (rows (second term-size)))
           (case (msg-type message)
             (:key-right (incf offset-y))
             (:key-left  (decf offset-y))
             (:key-up   (decf offset-x))
             (:key-down  (incf offset-x)))
           ;; clamp so viewport remains inside terminal bounds
           (setf offset-x (%clamp offset-x 0 (max 0 (- rows height)))
                 offset-y (%clamp offset-y 0 (max 0 (- cols width))))
           (push (patch '(:offset-x) offset-x) own-patches)
           (push (patch '(:offset-y) offset-y) own-patches)))
        ;; -------------------------------------------------------------------
        (t nil))

      ;; propagate message downstream
      (log-info "PROPAGATE: ~A to child at ~S"
                (msg-type message) (append id-path '(:child)))
      (multiple-value-bind (child-patches child-cmds)
          (let ((child (child-instance state id-path)))
            (log-info "Child instance at ~S: ~S"
                      (append id-path '(:child)) child)
            (when child
              (elmtui.ui.api:update child message state :id-path (append id-path (list (slot-value child 'id)))) ) )
        (values (nconc own-patches child-patches) child-cmds)))) )

;;; ---------------------------------------------------------------------------
;;; VIEW – convert state into DSL for renderer
;;; ---------------------------------------------------------------------------
(defmethod elmtui.ui.api:view ((component root-viewport) state
                               &key id-path children &allow-other-keys)
  (declare (type list id-path) (type t state))
  (check-type id-path list)
  (log4cl:log-debug "Rendering root-viewport with ID path: ~A" id-path)
  (let* ((vp-state (get-path (append id-path '(:state)) state))
         (effective-id (state-ref vp-state :id (first (last id-path))))
         (size-uninitialized (state-ref vp-state :size-uninitialized)))

    (when size-uninitialized
      (log4cl:log-debug "Root-viewport ~A size is uninitialized. Skipping child view." effective-id)
      (return-from elmtui.ui.api:view
        `(:layout :id ,effective-id :width 1 :height 1 :children nil)))

    (let* ((children-from-args children)
           (child-from-state (state-ref vp-state :child-dsl-spec))
           (final-children (or children-from-args
                               (when child-from-state (list child-from-state))))
           (width (state-ref vp-state :width))
           (height (state-ref vp-state :height))
           (offset-x (state-ref vp-state :offset-x 0))
           (offset-y (state-ref vp-state :offset-y 0))
           (scroll-x (state-ref vp-state :scroll-x 0))
           (scroll-y (state-ref vp-state :scroll-y 0))
           (effective-id-viewport (intern (format nil "ROOT-VIEWPORT-~A" effective-id) :keyword)))

      (unless final-children
        (log4cl:log-warn "Root-viewport ~A has no children." effective-id))

      `(:viewport :id ,effective-id-viewport
                  :style (:width ,width :height ,height
                          :offset-x ,offset-x :offset-y ,offset-y
                          :scroll-x ,scroll-x :scroll-y ,scroll-y)
                  :children ,final-children))))
;; (defmethod elmtui.ui.api:view ((component root-viewport) state &key id-path)
;;   (log-info "ROOT-VIEW: ~A" id-path)
;;   (let ((dud nil))
;;     (elmtui.update-dsl:with-read-only-cycle
;;         (ctx state)
;;       (let* ((vp-state (elmtui.tea-state:state-ref  state (append id-path '(:state))))
;;              (width     (elmtui.tea-state:state-ref vp-state :width 1))
;;              (height    (elmtui.tea-state:state-ref vp-state :height 1))
;;              (offset-x  (elmtui.tea-state:state-ref vp-state :offset-x 0))
;;              (offset-y  (elmtui.tea-state:state-ref vp-state :offset-y 0))
;;              (child-dsl (elmtui.tea-state:state-ref vp-state :child-dsl-spec))
;;              (vp-id (first (last id-path))))
;;                                         ;(or (elmtui.tea-state:state-ref vp-state :id) (first id-path))))
;;         (setf dud `(:root-viewport :id ,vp-id
;;                                    :width ,width :height ,height
;;                                    :offset-x ,offset-x :offset-y ,offset-y
;;                                    :children ,(when child-dsl (list child-dsl))))))
;;     (log-info "ROOT-VIEW: ~A -> ~S"
;;               id-path
;;               dud)
;;     dud)
;;   )
;;; ---------------------------------------------------------------------------
;;; Cleanup stub (future use)
;;; ---------------------------------------------------------------------------

(defun get-cleanup-info (state id-path)
  (declare (ignore state id-path))
  nil)

;; (defcomponent-dsl :root-viewport root-viewport)
