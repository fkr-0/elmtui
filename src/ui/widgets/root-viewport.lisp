(uiop:define-package
    :elmtui.ui.widgets.root-viewport
  (:use :cl
   :elmtui.ui.api
        :elmtui.ui.widgets.viewport)
  (:import-from :elmtui.utils :ensure-list)
  (:import-from :elmtui.app.api
                #:get-component-instance)
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
  () ;; Removed slots: anchor, initial-cursor-row, initial-cursor-col
  (:documentation
   "Stateless root viewport component. All mutable attributes (size,
offsets, scroll-state, anchor, initial cursor position, etc.) are maintained
in the external application state as *patches* rather than CLOS slots."))

;;; ---------------------------------------------------------------------------
;;; Helpers
;;; ---------------------------------------------------------------------------

(defun compute-anchor-offset (anchor viewport-width viewport-height term-cols term-rows cursor-row cursor-col)
  "Compute (offset-y, offset-x) for the root-viewport based on anchor, terminal size, viewport size, and cursor position."
  (declare (type anchor-type anchor)
           (type (integer 0 *) viewport-width viewport-height term-cols term-rows cursor-row cursor-col))
  (check-type anchor anchor-type)
  (check-type viewport-width (integer 0 *))
  (check-type viewport-height (integer 0 *))
  (check-type term-cols (integer 0 *))
  (check-type term-rows (integer 0 *))
  (check-type cursor-row (integer 0 *))
  (check-type cursor-col (integer 0 *))
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
                            (max 0 (min cursor-col (- term-cols viewport-width)))))
    (:above-cursor  (values (max 0 (- cursor-row viewport-height))
                            (max 0 (min cursor-col (- term-cols viewport-width)))))))

(defun compute-view-size (anchor term-cols term-rows cursor-row)
  "Return three values: width height offset-y."
  (declare (type anchor-type anchor)
           (type (integer 0 *) term-cols term-rows cursor-row))
  (check-type anchor anchor-type)
  (check-type term-cols (integer 0 *))
  (check-type term-rows (integer 0 *))
  (check-type cursor-row (integer 0 *))
  (ecase anchor
    (:below-cursor (values term-cols (- term-rows cursor-row 1) 0))
    (:above-cursor (values term-cols cursor-row                 0))
    ((:top-left :top :top-right
                :left :center :right
      :bottom-left :bottom :bottom-right)
     ;; Full screen; renderer handles offset mapping.
     (values term-cols term-rows 0))))

(defun child-instance (state id-path)
  "Return the live child component instance, or NIL when absent.
   Assumes the child's specification is stored at (append id-path '(:child))
   and the first element of this spec is the child's ID (a keyword)."
  (let ((child-spec (get-path (append id-path '(:child))state )))
    (when (and child-spec (consp child-spec)) ; Ensure spec is a non-nil list
      (let ((child-id (car child-spec)))
        ;; Ensure ID is a keyword, which is the convention for component IDs.
        (when (keywordp child-id)
          (let ((child-actual-id-path (append id-path (list child-id))))
            (get-component-instance child-actual-id-path state)))))))

;;; ---------------------------------------------------------------------------
;;; Instantiation
;;; ---------------------------------------------------------------------------

;; Removed initialize-instance :after method as it was setting slots that no longer exist.
;; The :anchor and :initial-cursor-pos initargs to make-instance in make-root-viewport
;; will be effectively ignored by root-viewport's own make-instance, which is fine,
;; as the elmtui.ui.api:init method is responsible for setting these values in the app state.

(defun make-root-viewport (id
                           &key (anchor :below-cursor)
                             (initial-cursor-pos '(0 . 0)))
  "Convenience factory. Creates a root-viewport instance with the given ID.
   Anchor and initial cursor position are configured via the 'init' method."
  (declare (ignore anchor initial-cursor-pos)) ; These are handled by the init method
  (make-instance 'root-viewport :id id))

;;; ---------------------------------------------------------------------------
;;; API – INIT
;;; ---------------------------------------------------------------------------

(defmethod elmtui.ui.api:init ((component root-viewport)
                               &key id-path
                                 initial-terminal-dimensions
                                 initial-cursor-pos
                                 initial-child-spec ; This is the DSL for the child content
                                 dsl) ; The dsl for the root-viewport itself
  "Return a *patch list* describing the component’s initial state.
Initial child spec is stored in state for the view method to use."
  (declare (type list id-path initial-terminal-dimensions initial-cursor-pos)
           (type (or null list) initial-child-spec dsl) ; child-spec and dsl can be complex forms
           ) ; dsl for root-viewport itself might not be needed if all info comes from direct args
  (check-type id-path list)
  (check-type initial-terminal-dimensions (cons (integer 0 *) (cons (integer 0 *) null)))
  (check-type initial-cursor-pos (cons (integer 0 *) (cons (integer 0 *) null)))
  ;; initial-child-spec can be any valid DSL, so not strictly checking its structure here beyond list/null
  ;; dsl for root-viewport itself also not strictly checked beyond list/null
  (let* ((anchor (or (getf (getf dsl :props) :anchor) ; Get anchor from the root-viewport's own DSL if provided
                     :below-cursor))
         (term-rows (second initial-terminal-dimensions))
         (term-cols (first initial-terminal-dimensions))
         (cursor-r (second initial-cursor-pos))
         (cursor-c (first initial-cursor-pos))
         (patches nil)
         (commands nil))

    (log4cl:log-debug "Initializing root-viewport with ID ~A, anchor ~A, cursor position ~A"
                      (first id-path) anchor initial-cursor-pos)
    ;; Calculate viewport size and offset based on anchor and terminal dimensions
    (multiple-value-bind (computed-width computed-height computed-offset-y computed-offset-x)
        (if (member anchor '(:above-cursor :below-cursor))
            (multiple-value-bind (w h oy) (compute-view-size anchor term-cols term-rows cursor-r)
              (values w h oy cursor-c)) ; x-offset for these is cursor-c or derived
            (multiple-value-bind (offset-y offset-x)
                (compute-anchor-offset anchor term-cols term-rows term-cols term-rows cursor-r cursor-c) ; placeholder vp-w/h
              (values term-cols term-rows offset-y offset-x))) ; For non-cursor anchors, assume full size for now

      (progn
        (log4cl:log-debug "Computed viewport size: width ~A, height ~A, offset-x ~A, offset-y ~A"
                          computed-width computed-height computed-offset-x computed-offset-y)
        ;; (log4cl:log-debug "Setting patches: ~A%"
        ;;                   (list
        ;;                    (list (append id-path '(:state :width)) computed-width)
        ;;                    (list (append id-path '(:state :height)) computed-height)
        ;;                    (list (append id-path '(:state :offset-x)) computed-offset-x)
        ;;                    (list (append id-path '(:state :offset-y)) computed-offset-y)
        ;;                    (list (append id-path '(:state :anchor)) anchor)
        ;;                    (list (append id-path '(:state :initial-cursor-pos)) initial-cursor-pos)
        ;;                    ;; Store the initial-child-spec (which is a DSL tree) in the state.
        ;;                    ;; The `view` method of root-viewport will use this.
        ;;                    (list (append id-path '(:state :child-dsl-spec)) initial-child-spec)
        ;;                    ;; Store the original DSL of the root-viewport itself for completeness
        ;;                    (list (append id-path '(:state :dsl)) dsl)))
        (setf patches
              (list
               (list (append id-path '(:state :width)) computed-width)
               (list (append id-path '(:state :height)) computed-height)
               (list (append id-path '(:state :offset-x)) computed-offset-x)
               (list (append id-path '(:state :offset-y)) computed-offset-y)
               (list (append id-path '(:state :anchor)) anchor)
               (list (append id-path '(:state :initial-cursor-pos)) initial-cursor-pos)
               ;; Store the initial-child-spec (which is a DSL tree) in the state.
               ;; The `view` method of root-viewport will use this.
               (list (append id-path '(:state :child-dsl-spec)) initial-child-spec)
               ;; Store the original DSL of the root-viewport itself for completeness
               (list (append id-path '(:state :dsl)) dsl)))))

    ;; No direct child component instantiation or init here.
    ;; The `view` method will use the :child-dsl-spec.

    (values patches commands)))

;;; ---------------------------------------------------------------------------
;;; API – UPDATE
;;; ---------------------------------------------------------------------------

(defmethod elmtui.ui.api:update ((component root-viewport)
                                 state message
                                 &key id-path)
  "Handle :terminal-resized plus delegate all other messages downward."
  (declare (type list id-path) (type t state message)) ; state and message can be complex
  (check-type id-path list)
  (flet ((patch (subkey value)
           `(,(append id-path subkey) ,value)))
    (case (ensure-list message)
      ;; ── Terminal resize ────────────────────────────────────────────────────
      ((:terminal-resized)
       (destructuring-bind (&key new-dimensions) (cdr message)
         (let* ((term-cols (car new-dimensions))
                (term-rows (cdr new-dimensions))
                (anchor    (get-path (append id-path '(:state :anchor)) state ))
                (cursor-row (get-path (append id-path '(:state :initial-cursor-row)) state ))
                (cursor-col (get-path (append id-path '(:state :initial-cursor-col)) state ))
                (new-width  term-cols) ; root-viewport width is usually term-cols
                (new-height (nth-value 1 (compute-view-size anchor
                                                            term-cols
                                                            term-rows
                                                            cursor-row)))
                (offsets (multiple-value-list
                          (compute-anchor-offset anchor new-width new-height
                                                 term-cols term-rows
                                                 cursor-row cursor-col))))
           (list (patch '(:state :width)  new-width)
                 (patch '(:state :height) new-height)
                 (patch '(:state :offset-y) (first offsets))
                 (patch '(:state :offset-x) (second offsets))))))
      ;; ── Pass-through: send to child, keep accumulated patches ─────────────
      (t
       (let ((child (child-instance state id-path)))
         (when child
           (elmtui.ui.api:update child state message
                                 :id-path (append id-path
                                                  (list (slot-value child 'id))))))))))

;;; ---------------------------------------------------------------------------
;;; API – VIEW
;;; ---------------------------------------------------------------------------

(defmethod elmtui.ui.api:view ((component root-viewport) state
                               &key id-path)
  (declare (type list id-path) (type t state)) ; state can be complex
  (check-type id-path list)
  (let* ((vp-state (get-path (append id-path '(:state)) state ))
         (child-dsl-spec (getf vp-state :child-dsl-spec)) ; Get the child's DSL
         (width (getf vp-state :width))
         (height (getf vp-state :height))
         (offset-x (getf vp-state :offset-x 0))
         (offset-y (getf vp-state :offset-y 0))
         (scroll-x (getf vp-state :scroll-x 0))
         (scroll-y (getf vp-state :scroll-y 0))
         (effective-id (getf vp-state :id (first id-path)))) ; Fallback for id

    (unless child-dsl-spec
      (log4cl:log-warn "Root-viewport ~A has no child-dsl-spec in its state." effective-id)
      ;; Return a minimal viewport DSL if no child is specified
      (return-from elmtui.ui.api:view
        `(:viewport :id ,effective-id
                    :width ,width :height ,height
                    :offset-x ,offset-x :offset-y ,offset-y
                    :children nil)))

    ;; Construct the viewport DSL, embedding the child-dsl-spec as its content.
    ;; The actual rendering of child-dsl-spec happens when this whole view tree is processed.
    `(:viewport :id ,effective-id
                :width ,width :height ,height
                :offset-x ,offset-x :offset-y ,offset-y
                :scroll-x ,scroll-x :scroll-y ,scroll-y
                ;; The child-dsl-spec is typically a single DSL form.
                ;; The :children of a :viewport expects a list of DSL forms.
                :children (list child-dsl-spec))))
