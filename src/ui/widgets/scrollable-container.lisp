;;;===============================================================
;;; File: src/ui/widgets/scrollable-container.lisp
;;; Scrollable Container Widget Implementation
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.scrollable-container
  (:use :cl)
  (:import-from :elmtui.view.styled
   :make-styled-node)
  (:import-from :elmtui.ui.widgets.utils #:clamp) ; Ensure clamp is imported
  (:export
   :scrollable-container-model :make-scrollable-container-model
   :init-scrollable-container-model
   :update-scrollable-container-model
   :view-scrollable-container-model
   :scrollable-container-msg))
(in-package :elmtui.ui.widgets.scrollable-container)

;;;-----------------------------------------------------------------------------
;;; Scrollable Container Widget
;;;-----------------------------------------------------------------------------

(defstruct scrollable-container-model
  (id nil :read-only t)
  (scroll-top 0 :type integer) ; Can be integer as it's pixel/char offset
  (scroll-left 0 :type integer)
  (viewport-width 0 :type unsigned-byte)  ; Determined by layout
  (viewport-height 0 :type unsigned-byte) ; Determined by layout
  (content-width 0 :type unsigned-byte)   ; Determined by actual content size
  (content-height 0 :type unsigned-byte)  ; Determined by actual content size
  (disabled-p nil :type boolean)
  (focused-p nil :type boolean) ; If it can be focused to scroll with keyboard
  (show-scrollbar-x :auto) ; :auto, :always, :never
  (show-scrollbar-y :auto)) ; :auto, :always, :never

(defun init-scrollable-container-model (&key id (scroll-top 0) (scroll-left 0)
                                          (viewport-width 0) (viewport-height 0)
                                          (content-width 0) (content-height 0)
                                          (disabled-p nil) (initially-focused-p nil)
                                          (show-scrollbar-x :auto) (show-scrollbar-y :auto))
  "Initializes a scrollable container model. Returns (values model commands)."
  (let ((model (make-scrollable-container-model
                :id (or id (gensym "SCROLLABLE-"))
                :scroll-top scroll-top :scroll-left scroll-left
                :viewport-width viewport-width :viewport-height viewport-height
                :content-width content-width :content-height content-height
                :disabled-p disabled-p :focused-p initially-focused-p ; Store initial focus state
                :show-scrollbar-x show-scrollbar-x :show-scrollbar-y show-scrollbar-y))
        (cmds nil))
    (when initially-focused-p
      (push `(:dispatch (:request-focus :widget-id ,(scrollable-container-model-id model))) cmds))
    (values model (nreverse cmds))))

;; Scrollable-specific messages (internal)
(deftype scrollable-msg-type ()
  '(member :scroll :set-scroll :key-press :focus :blur :update-dimensions))

(deftype scrollable-container-msg ()
  `(cons (eql :scrollable-event)
    (cons scrollable-msg-type list)))

(defun update-scrollable-container-model (model msg &key on-scroll)
  "Update function for a scrollable container.
   MODEL: The current scrollable-container-model.
   MSG: An internal message.
   ON-SCROLL: Message to dispatch when scroll position changes. Payload: (:scroll-top <y> :scroll-left <x>).
   Returns (values new-model cmd-list)."
  (declare (type list msg)) ; Declare type for msg
  (if (scrollable-container-model-disabled-p model)
      (return-from update-scrollable-container-model (values model nil)))

   (unless (typep msg 'scrollable-container-msg)
     (return-from update-scrollable-container-model (values model nil)))

   (let ((event-type (second msg))
         (payload (cddr msg)))
     (let ((current-st (scrollable-container-model-scroll-top model))
           (current-sl (scrollable-container-model-scroll-left model))
           (vp-w (scrollable-container-model-viewport-width model))
           (vp-h (scrollable-container-model-viewport-height model))
           (c-w (scrollable-container-model-content-width model))
           (c-h (scrollable-container-model-content-height model))
           (new-st current-st) (new-sl current-sl)
           (new-vp-w vp-w) (new-vp-h vp-h)
           (new-c-w c-w) (new-c-h c-h)
           (new-focused-p (scrollable-container-model-focused-p model))
           (commands nil)
           (scrolled-p nil))
       ;; Add type declarations
       (declare (type integer current-st current-sl new-st new-sl)
                (type unsigned-byte vp-w vp-h c-w c-h new-vp-w new-vp-h new-c-w new-c-h)
                (type boolean new-focused-p scrolled-p)
                (type list commands payload))

       (case event-type
         (:scroll
         (let ((dx (getf payload :delta-x 0))
               (dy (getf payload :delta-y 0)))
           (setf new-sl (+ current-sl dx))
           (setf new-st (+ current-st dy))
           (setf scrolled-p t)))
        (:set-scroll
         (setf new-sl (getf payload :x current-sl))
         (setf new-st (getf payload :y current-st))
         (setf scrolled-p t))
        (:key-press
         (when new-focused-p ; Check internal focus state
           (let ((key (getf payload :key)))
             (case key
               (:up-arrow (setf new-st (- current-st 1)) (setf scrolled-p t))
               (:down-arrow (setf new-st (+ current-st 1)) (setf scrolled-p t))
               (:left-arrow (setf new-sl (- current-sl 1)) (setf scrolled-p t))
               (:right-arrow (setf new-sl (+ current-sl 1)) (setf scrolled-p t))
               (:page-up (setf new-st (- current-st vp-h)) (setf scrolled-p t))
               (:page-down (setf new-st (+ current-st vp-h)) (setf scrolled-p t))
               (:home
                (setf new-st 0) ; Scroll to top
                (setf new-sl 0) ; Scroll to left-most
                (setf scrolled-p t))
               (:end
                (setf new-st (max 0 (- c-h vp-h))) ; Scroll to bottom
                (setf new-sl (max 0 (- c-w vp-w))) ; Scroll to right-most
                (setf scrolled-p t))))))
        (:focus (setf new-focused-p t))
        (:blur (setf new-focused-p nil))
        (:update-dimensions
         (setf new-vp-w (getf payload :viewport-width vp-w))
         (setf new-vp-h (getf payload :viewport-height vp-h))
         (setf new-c-w (getf payload :content-width c-w))
         (setf new-c-h (getf payload :content-height c-h))
         ;; If dimensions change, re-clamp scroll positions
         (setf scrolled-p t)))

      ;; Apply clamping using potentially updated dimensions
      (when scrolled-p
        (setf new-sl (clamp new-sl 0 (max 0 (- new-c-w new-vp-w))))
        (setf new-st (clamp new-st 0 (max 0 (- new-c-h new-vp-h)))))

      ;; Check if scroll position actually changed after clamping
      (let ((scroll-changed (or (not (= new-sl current-sl)) (not (= new-st current-st)))))
        (when (and scroll-changed on-scroll)
          (push (list :dispatch (append on-scroll (list :scroll-left new-sl :scroll-top new-st))) commands))

        ;; Return new model only if state changed
        (if (or scroll-changed
                (not (eql new-focused-p (scrollable-container-model-focused-p model)))
                (not (= new-vp-w vp-w)) (not (= new-vp-h vp-h))
                (not (= new-c-w c-w)) (not (= new-c-h c-h)))
            (values (make-scrollable-container-model
                     :id (scrollable-container-model-id model)
                     :scroll-top new-st
                     :scroll-left new-sl
                     :viewport-width new-vp-w
                     :viewport-height new-vp-h
                     :content-width new-c-w
                     :content-height new-c-h
                     :disabled-p (scrollable-container-model-disabled-p model)
                     :focused-p new-focused-p
                     :show-scrollbar-x (scrollable-container-model-show-scrollbar-x model)
                     :show-scrollbar-y (scrollable-container-model-show-scrollbar-y model))
                    (nreverse commands))
            (values model (nreverse commands)))))))

(defun view-scrollable-container-model (model dispatch-fn child-content-view &key (props nil) focused-p)
  "View function for a scrollable container.
   MODEL: The current scrollable-container-model.
   DISPATCH-FN: Function to send internal scrollable messages.
   CHILD-CONTENT-VIEW: The pre-rendered UI node tree of the content to be scrolled.
   FOCUSED-P: Boolean indicating if this widget currently has focus.
   PROPS: Plist for additional view properties.
   Returns a styled-ui-node description for the container."
  (declare (ignore dispatch-fn focused-p)) ; Add ignore for unused parameters

  ;; Conceptual: The child-content-view needs to be placed inside this container.
  ;; The container itself gets a size from layout (model.viewport-width/height).
  ;; The child-content-view has its own natural size (model.content-width/height).

  ;; TODO: Implement actual scrolling visualization:
  ;; 1. Create a wrapper node for child-content-view. Apply a transform/offset style
  ;;    to this wrapper based on (- model.scroll-left) and (- model.scroll-top).
  ;; 2. The main container node should have style properties like :overflow :hidden
  ;;    which the layout/render engine uses for clipping.
  ;; 3. Render scrollbar nodes (e.g., as siblings or overlays) if needed, based on
  ;;    overflow state and :show-scrollbar-x/y style properties. Scrollbars would
  ;;    need their own view logic and dispatch scroll messages on interaction.

  (let ((is-focused (scrollable-container-model-focused-p model))) ; Use internal focus state
    ;; TODO: Add event handlers for scroll wheel, keyboard (if focused)
    ;; Refactored props construction using append
    (make-styled-node :type :scrollable-container
                      :props (append (list :role :group ; or other appropriate role
                                           :scroll-top (scrollable-container-model-scroll-top model)
                                           :scroll-left (scrollable-container-model-scroll-left model)
                                           :content-width (scrollable-container-model-content-width model)
                                           :content-height (scrollable-container-model-content-height model)
                                           :viewport-width (scrollable-container-model-viewport-width model)
                                           :viewport-height (scrollable-container-model-viewport-height model)
                                           :show-scrollbar-x (scrollable-container-model-show-scrollbar-x model)
                                           :show-scrollbar-y (scrollable-container-model-show-scrollbar-y model)
                                           :aria-disabled (if (scrollable-container-model-disabled-p model) "true" "false"))
                                     (when is-focused (list :focused "true")) ; is-focused is now used
                                     props
                                     (list :id (scrollable-container-model-id model)))
                      ;; Child view is passed in, render engine needs to clip/offset it
                      :children (list child-content-view))))
