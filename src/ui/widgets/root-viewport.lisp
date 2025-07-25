(uiop:define-package
    :elmtui.ui.widgets.root-viewport
  (:use :cl #:log4cl
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
                                 initial-child-spec
                                 dsl)
  "Return a *patch list* describing the component’s initial state."
  (declare (type list id-path initial-terminal-dimensions initial-cursor-pos)
           (type (or null list) initial-child-spec dsl))
  (check-type id-path list)
  (check-type initial-terminal-dimensions (cons (integer 0 *) (cons (integer 0 *) null)))
  (check-type initial-cursor-pos (cons (integer 0 *) (cons (integer 0 *) null)))

  (let* ((anchor (or (getf (getf dsl :props) :anchor) :below-cursor))
         (term-cols (first initial-terminal-dimensions))
         (term-rows (second initial-terminal-dimensions))
         (cursor-c (first initial-cursor-pos))
         (cursor-r (second initial-cursor-pos))
         (size-uninitialized (or (zerop term-cols) (zerop term-rows)))
         (patches nil)
         (commands nil))

    (log4cl:log-debug "Initializing root-viewport with ID ~A, anchor ~A, term-size ~Ax~A, cursor ~A"
                      (car id-path) anchor term-cols term-rows initial-cursor-pos)

    (multiple-value-bind (computed-width computed-height computed-offset-y computed-offset-x)
        (if size-uninitialized
            (values 1 1 0 0) ; Default to 1x1 if terminal size is unknown
            (if (member anchor '(:above-cursor :below-cursor))
                (multiple-value-bind (w h oy) (compute-view-size anchor term-cols term-rows cursor-r)
                  (values w h oy cursor-c))
                (multiple-value-bind (offset-y offset-x)
                    (compute-anchor-offset anchor term-cols term-rows term-cols term-rows cursor-r cursor-c)
                  (values term-cols term-rows offset-y offset-x))))

      (log4cl:log-debug "Computed viewport size: width ~A, height ~A, offset-x ~A, offset-y ~A"
                        computed-width computed-height computed-offset-x computed-offset-y)
      (setf patches
            (list
             (list (append id-path '(:type)) :root-viewport)
             (list (append id-path '(:state :width)) computed-width)
             (list (append id-path '(:state :height)) computed-height)
             (list (append id-path '(:state :offset-x)) computed-offset-x)
             (list (append id-path '(:state :offset-y)) computed-offset-y)
             (list (append id-path '(:state :anchor)) anchor)
             (list (append id-path '(:state :initial-cursor-pos)) initial-cursor-pos)
             (list (append id-path '(:state :terminal-size)) initial-terminal-dimensions)
             (list (append id-path '(:state :size-uninitialized)) size-uninitialized)
             (list (append id-path '(:state :child-dsl-spec)) initial-child-spec)
             (list (append id-path '(:state :dsl)) dsl))))

    (values component patches commands)))

;;; ---------------------------------------------------------------------------
;;; API – UPDATE
;;; ---------------------------------------------------------------------------

(defmethod elmtui.ui.api:update ((component root-viewport)
                                 state message
                                 &key id-path)
  "Handle :terminal-resized plus delegate all other messages downward."
  (declare (type list id-path) (type t state message))
  (check-type id-path list)
  (log-info "Called Update of ROOT-VIEWPORT: ~A ~A" state message)
  (flet ((patch (subkey value)
           `(,(append id-path subkey) ,value)))
    (let ((msg-list (ensure-list message)))
      (case (car msg-list)
        ;; ── Terminal resize ────────────────────────────────────────────────────
        (:terminal-resized
         (log-info "RESIZED!!!!!")
         (destructuring-bind (&key new-dimensions) (cdr msg-list)
           (let* ((term-cols (car new-dimensions))
                  (term-rows (cdr new-dimensions))
                  (anchor (get-path (append id-path '(:state :anchor)) state))
                  (initial-cursor-pos (get-path (append id-path '(:state :initial-cursor-pos)) state))
                  (cursor-c (first initial-cursor-pos))
                  (cursor-r (second initial-cursor-pos))
                  (new-width term-cols)
                  (new-height (nth-value 1 (compute-view-size anchor term-cols term-rows cursor-r)))
                  (offsets (multiple-value-list
                            (compute-anchor-offset anchor new-width new-height
                                                   term-cols term-rows
                                                   cursor-r cursor-c))))
             (list (patch '(:state :width) new-width)
                   (patch '(:state :height) new-height)
                   (patch '(:state :offset-y) (first offsets))
                   (patch '(:state :offset-x) (second offsets))
                   (patch '(:state :terminal-size) new-dimensions)
                   (patch '(:state :size-uninitialized) nil))))) ; Size is now known
        ;; ── Pass-through: send to child, keep accumulated patches ─────────────
        (t
         (let ((child (child-instance state id-path)))
           (when child
             (elmtui.ui.api:update child state message
                                   :id-path (append id-path
                                                    (list (slot-value child 'id)))))))))))

;;; ---------------------------------------------------------------------------
;;; API – VIEW
;;; ---------------------------------------------------------------------------

(defmethod elmtui.ui.api:view ((component root-viewport) state
                               &key id-path)
  (declare (type list id-path) (type t state))
  (check-type id-path list)
  (let* ((vp-state (get-path (append id-path '(:state)) state))
         (effective-id (getf vp-state :id (first id-path)))
         (size-uninitialized (getf vp-state :size-uninitialized)))

    (when size-uninitialized
      (log4cl:log-debug "Root-viewport ~A size is uninitialized. Skipping child view." effective-id)
      (return-from elmtui.ui.api:view
        `(:viewport :id ,effective-id :width 1 :height 1 :children nil)))

    (let* ((child-dsl-spec (getf vp-state :child-dsl-spec))
           (width (getf vp-state :width))
           (height (getf vp-state :height))
           (offset-x (getf vp-state :offset-x 0))
           (offset-y (getf vp-state :offset-y 0))
           (scroll-x (getf vp-state :scroll-x 0))
           (scroll-y (getf vp-state :scroll-y 0)))

      (unless child-dsl-spec
        (log4cl:log-warn "Root-viewport ~A has no child-dsl-spec in its state." effective-id)
        (return-from elmtui.ui.api:view
          `(:viewport :id ,effective-id
                      :width ,width :height ,height
                      :offset-x ,offset-x :offset-y ,offset-y
                      :children nil)))

      `(:viewport :id ,effective-id
                  :width ,width :height ,height
                  :offset-x ,offset-x :offset-y ,offset-y
                  :scroll-x ,scroll-x :scroll-y ,scroll-y
                  :children (list child-dsl-spec)))))
