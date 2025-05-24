;;;===============================================================
;;; File: src/ui/widgets/scrollable-container.lisp
;;; Standardized Elm-style Scrollable Container Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.scrollable-container
  (:use :cl)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.core.async #:cmd-async)
  (:import-from :elmtui.core.events #:send-message)
  (:import-from :elmtui.ui.widgets.utils
                #:defwidget-view
                #:with-widget-model
                #:widget-focused-p)
  (:export #:scrollable-container-model #:make-scrollable-container-model ; Struct and constructor
           ;; Accessors
           #:scrollable-container-model-id
           #:scrollable-container-model-scroll-top
           #:scrollable-container-model-scroll-left
           #:scrollable-container-model-viewport-width
           #:scrollable-container-model-viewport-height
           #:scrollable-container-model-content-width
           #:scrollable-container-model-content-height
           #:scrollable-container-model-disabled
           #:scrollable-container-model-show-scrollbar-x
           #:scrollable-container-model-show-scrollbar-y
           #:scrollable-container-model-on-scroll
           ;; Core TEA functions
           #:init-scrollable-container #:update-scrollable-container #:view-scrollable-container
           ;; Message types
           #:msg-scroll-container-scroll
           #:msg-scroll-container-set-scroll
           #:msg-scroll-container-key-press
           #:msg-scroll-container-update-dimensions))
(in-package :elmtui.ui.widgets.scrollable-container)

;;;---------------------------------------------------------------
;;; Helper Functions
;;;---------------------------------------------------------------
(defun clamp (value min max)
  "Clamps value between min and max."
  (max min (min value max)))

;;;---------------------------------------------------------------
;;; Model
;;;---------------------------------------------------------------
(defstruct (scrollable-container-model (:constructor %make-scrollable-container-model))
  "Model for a scrollable container widget.
   ID: Unique identifier.
   SCROLL-TOP: Vertical scroll position.
   SCROLL-LEFT: Horizontal scroll position.
   VIEWPORT-WIDTH: Visible width of the container.
   VIEWPORT-HEIGHT: Visible height of the container.
   CONTENT-WIDTH: Total width of the content.
   CONTENT-HEIGHT: Total height of the content.
   DISABLED: Whether scrolling is disabled.
   SHOW-SCROLLBAR-X: When to show horizontal scrollbar (:auto, :always, :never).
   SHOW-SCROLLBAR-Y: When to show vertical scrollbar (:auto, :always, :never).
   ON-SCROLL: Message to send when scroll position changes."
  (id (error "ID must be provided.") :type T :read-only t)
  (scroll-top 0 :type integer)
  (scroll-left 0 :type integer)
  (viewport-width 0 :type unsigned-byte)
  (viewport-height 0 :type unsigned-byte)
  (content-width 0 :type unsigned-byte)
  (content-height 0 :type unsigned-byte)
  (disabled nil :type boolean)
  (show-scrollbar-x :auto)
  (show-scrollbar-y :auto)
  (on-scroll nil :type T))

;;;---------------------------------------------------------------
;;; Messages (Keywords)
;;;---------------------------------------------------------------
(defparameter msg-scroll-container-scroll :scroll-container-scroll)
(defparameter msg-scroll-container-set-scroll :scroll-container-set-scroll)
(defparameter msg-scroll-container-key-press :scroll-container-key-press)
(defparameter msg-scroll-container-update-dimensions :scroll-container-update-dimensions)

;;;---------------------------------------------------------------
;;; Init
;;;---------------------------------------------------------------
(defun init-scrollable-container (id &key
                                          (scroll-top 0)
                                          (scroll-left 0)
                                          (viewport-width 0)
                                          (viewport-height 0)
                                          (content-width 0)
                                          (content-height 0)
                                          (disabled nil)
                                          (show-scrollbar-x :auto)
                                          (show-scrollbar-y :auto)
                                          (on-scroll nil))
  "Initializes a new scrollable container model.
   Returns (values scrollable-container-model initial-command)."
  (values (%make-scrollable-container-model
           :id id
           :scroll-top scroll-top
           :scroll-left scroll-left
           :viewport-width viewport-width
           :viewport-height viewport-height
           :content-width content-width
           :content-height content-height
           :disabled disabled
           :show-scrollbar-x show-scrollbar-x
           :show-scrollbar-y show-scrollbar-y
           :on-scroll on-scroll)
          nil))

;;;---------------------------------------------------------------
;;; Update
;;;---------------------------------------------------------------
(defun update-scrollable-container (msg model)
  "Updates the scrollable container model based on a message.
   MSG: The message to process.
   MODEL: The current scrollable-container-model instance.
   Returns (values new-model command-list)."
  (check-type model scrollable-container-model)

  ;; If container is disabled, return unchanged
  (when (scrollable-container-model-disabled model)
    (return-from update-scrollable-container (values model nil)))

  (let ((new-model (copy-structure model))
        (commands nil)
        (scroll-changed nil))

    (etypecase msg
      ;; (:scroll-container-scroll :delta-x <dx> :delta-y <dy>)
      ((cons (eql msg-scroll-container-scroll))
       (let ((dx (getf (rest msg) :delta-x 0))
             (dy (getf (rest msg) :delta-y 0)))
         (incf (scrollable-container-model-scroll-left new-model) dx)
         (incf (scrollable-container-model-scroll-top new-model) dy)
         (setf scroll-changed t)))

      ;; (:scroll-container-set-scroll :x <x> :y <y>)
      ((cons (eql msg-scroll-container-set-scroll))
       (let ((new-x (getf (rest msg) :x))
             (new-y (getf (rest msg) :y)))
         (when new-x
           (setf (scrollable-container-model-scroll-left new-model) new-x)
           (setf scroll-changed t))
         (when new-y
           (setf (scrollable-container-model-scroll-top new-model) new-y)
           (setf scroll-changed t))))

      ;; (:scroll-container-key-press :key <key>)
      ((cons (eql msg-scroll-container-key-press))
       (let ((key (getf (rest msg) :key)))
         (case key
           ((:up :k)
            (decf (scrollable-container-model-scroll-top new-model) 1)
            (setf scroll-changed t))
           ((:down :j)
            (incf (scrollable-container-model-scroll-top new-model) 1)
            (setf scroll-changed t))
           ((:left :h)
            (decf (scrollable-container-model-scroll-left new-model) 1)
            (setf scroll-changed t))
           ((:right :l)
            (incf (scrollable-container-model-scroll-left new-model) 1)
            (setf scroll-changed t))
           ((:page-up)
            (decf (scrollable-container-model-scroll-top new-model)
                  (scrollable-container-model-viewport-height new-model))
            (setf scroll-changed t))
           ((:page-down)
            (incf (scrollable-container-model-scroll-top new-model)
                  (scrollable-container-model-viewport-height new-model))
            (setf scroll-changed t))
           ((:home)
            (setf (scrollable-container-model-scroll-top new-model) 0)
            (setf (scrollable-container-model-scroll-left new-model) 0)
            (setf scroll-changed t))
           ((:end)
            (setf (scrollable-container-model-scroll-top new-model)
                  (max 0 (- (scrollable-container-model-content-height new-model)
                            (scrollable-container-model-viewport-height new-model))))
            (setf (scrollable-container-model-scroll-left new-model)
                  (max 0 (- (scrollable-container-model-content-width new-model)
                            (scrollable-container-model-viewport-width new-model))))
            (setf scroll-changed t)))))

      ;; (:scroll-container-update-dimensions :viewport-width <vw> :viewport-height <vh>
      ;;                                      :content-width <cw> :content-height <ch>)
      ((cons (eql msg-scroll-container-update-dimensions))
       (let ((vw (getf (rest msg) :viewport-width))
             (vh (getf (rest msg) :viewport-height))
             (cw (getf (rest msg) :content-width))
             (ch (getf (rest msg) :content-height)))
         (when vw (setf (scrollable-container-model-viewport-width new-model) vw))
         (when vh (setf (scrollable-container-model-viewport-height new-model) vh))
         (when cw (setf (scrollable-container-model-content-width new-model) cw))
         (when ch (setf (scrollable-container-model-content-height new-model) ch))
         (setf scroll-changed t))))

    ;; Apply clamping to scroll positions
    (when scroll-changed
      (let ((max-scroll-left (max 0 (- (scrollable-container-model-content-width new-model)
                                       (scrollable-container-model-viewport-width new-model))))
            (max-scroll-top (max 0 (- (scrollable-container-model-content-height new-model)
                                      (scrollable-container-model-viewport-height new-model)))))
        (setf (scrollable-container-model-scroll-left new-model)
              (clamp (scrollable-container-model-scroll-left new-model) 0 max-scroll-left))
        (setf (scrollable-container-model-scroll-top new-model)
              (clamp (scrollable-container-model-scroll-top new-model) 0 max-scroll-top))

        ;; Generate on-scroll command if needed
        (when (scrollable-container-model-on-scroll new-model)
          (let ((on-scroll-msg (scrollable-container-model-on-scroll new-model)))
            (if (listp on-scroll-msg)
                (push (cmd-async #'send-message
                                 (append on-scroll-msg
                                         (list :scroll-left (scrollable-container-model-scroll-left new-model)
                                               :scroll-top (scrollable-container-model-scroll-top new-model))))
                      commands)
                (push (cmd-async #'send-message on-scroll-msg) commands))))))

    (values new-model commands)))

;;;---------------------------------------------------------------
;;; View (STANDARDIZED FORMAT)
;;;---------------------------------------------------------------
(defwidget-view view-scrollable-container
    (app-state :widget-id-var widget
               :model-var model
               :add-args
     (scroll-top scroll-left
                 viewport-width viewport-height
                 content-width content-height
                 show-scrollbar-x show-scrollbar-y
                 disabled on-scroll
                 tooltip aria-label
                 class
                 children)
               :documentation
     "Creates a UI representation of a scrollable container.
   APP-STATE: The application state.
   WIDGET-ID: The unique ID for this container (required).
   SCROLL-TOP: Vertical scroll position.
   SCROLL-LEFT: Horizontal scroll position.
   VIEWPORT-WIDTH: Visible width of the container.
   VIEWPORT-HEIGHT: Visible height of the container.
   CONTENT-WIDTH: Total width of the content.
   CONTENT-HEIGHT: Total height of the content.
   SHOW-SCROLLBAR-X: When to show horizontal scrollbar (:auto, :always, :never).
   SHOW-SCROLLBAR-Y: When to show vertical scrollbar (:auto, :always, :never).
   DISABLED: Whether scrolling is disabled.
   ON-SCROLL: Message to send when scroll position changes.
   TOOLTIP: Optional tooltip text to display on hover.
   ARIA-LABEL: Accessibility label for screen readers.
   CLASS: Additional CSS classes to apply.
   CHILDREN: Content to be scrolled.")

  ;; Determine effective values from model and/or provided props
  (let* ((effective-scroll-top (or scroll-top
                                   (when model (scrollable-container-model-scroll-top model))
                                   0))
         (effective-scroll-left (or scroll-left
                                    (when model (scrollable-container-model-scroll-left model))
                                    0))
         (effective-viewport-width (or viewport-width
                                       (when model (scrollable-container-model-viewport-width model))
                                       0))
         (effective-viewport-height (or viewport-height
                                        (when model (scrollable-container-model-viewport-height model))
                                        0))
         (effective-content-width (or content-width
                                      (when model (scrollable-container-model-content-width model))
                                      0))
         (effective-content-height (or content-height
                                       (when model (scrollable-container-model-content-height model))
                                       0))
         (effective-show-scrollbar-x (or show-scrollbar-x
                                         (when model (scrollable-container-model-show-scrollbar-x model))
                                         :auto))
         (effective-show-scrollbar-y (or show-scrollbar-y
                                         (when model (scrollable-container-model-show-scrollbar-y model))
                                         :auto))
         (effective-disabled (or disabled
                                 (when model (scrollable-container-model-disabled model))
                                 nil))
         (effective-on-scroll (or on-scroll
                                  (when model (scrollable-container-model-on-scroll model))
                                  nil))
         (is-focused (widget-focused-p model widget))

         ;; Determine if scrollbars should be visible based on content overflow and settings
         (content-overflows-x (> effective-content-width effective-viewport-width))
         (content-overflows-y (> effective-content-height effective-viewport-height))
         (show-x-scrollbar (case effective-show-scrollbar-x
                             (:auto content-overflows-x)
                             (:always t)
                             (:never nil)))
         (show-y-scrollbar (case effective-show-scrollbar-y
                             (:auto content-overflows-y)
                             (:always t)
                             (:never nil)))

         ;; Build CSS classes
         (base-class "scrollable-container")
         (focused-class (when is-focused "scrollable-container-focused"))
         (disabled-class (when effective-disabled "scrollable-container-disabled"))
         (overflow-x-class (when content-overflows-x "scrollable-container-overflow-x"))
         (overflow-y-class (when content-overflows-y "scrollable-container-overflow-y"))
         (custom-class class)
         (all-classes (remove nil (list base-class focused-class disabled-class
                                        overflow-x-class overflow-y-class custom-class))))

    ;; Create the styled node representing the scrollable container
    (make-styled-node
     :type :scrollable-container
     :props (list* :id widget
                   :scroll-top effective-scroll-top
                   :scroll-left effective-scroll-left
                   :viewport-width effective-viewport-width
                   :viewport-height effective-viewport-height
                   :content-width effective-content-width
                   :content-height effective-content-height
                   :show-scrollbar-x show-x-scrollbar
                   :show-scrollbar-y show-y-scrollbar
                   :disabled effective-disabled
                   :on-scroll effective-on-scroll
                   :focusable (not effective-disabled)
                   :class (format nil "~{~A~^ ~}" all-classes)
                   :aria-role "scrollbox"
                   ;; Include optional properties only if provided
                   (append
                    (when tooltip (list :title tooltip))
                    (when aria-label (list :aria-label aria-label))))
     :children children)))

;;;---------------------------------------------------------------
;;; Backward Compatibility Wrapper
;;;---------------------------------------------------------------
;; This is a temporary function to maintain backward compatibility
;; during transition to the new widget pattern
;; (defun view-scrollable-container (model dispatch-fn child-content-view &key props focused-p)
;;   "DEPRECATED: Use view-scrollable-container instead."
;;   (warn "view-scrollable-container is deprecated. Use view-scrollable-container with app-state and :widget-id instead.")
;;   (make-styled-node
;;    :type :scrollable-container
;;    :props (append
;;            (list :id (scrollable-container-model-id model)
;;                  :scroll-top (scrollable-container-model-scroll-top model)
;;                  :scroll-left (scrollable-container-model-scroll-left model)
;;                  :viewport-width (scrollable-container-model-viewport-width model)
;;                  :viewport-height (scrollable-container-model-viewport-height model)
;;                  :content-width (scrollable-container-model-content-width model)
;;                  :content-height (scrollable-container-model-content-height model)
;;                  :show-scrollbar-x (scrollable-container-model-show-scrollbar-x model)
;;                  :show-scrollbar-y (scrollable-container-model-show-scrollbar-y model)
;;                  :disabled (scrollable-container-model-disabled model)
;;                  :focusable (not (scrollable-container-model-disabled model))
;;                  :aria-role "scrollbox"
;;                  :class (if focused-p "scrollable-container scrollable-container-focused" "scrollable-container"))
;;            props)
;;    :children (list child-content-view)))
