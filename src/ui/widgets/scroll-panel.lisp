;;;===============================================================
;;; File: src/ui/widgets/scroll-panel.lisp
;;; Virtual Scroll Panel Component
;;;
;;; A panel that provides virtual scrolling without moving terminal scroll.
;;; Content is clipped based on scroll offset, with optional scrollbar.
;;;===============================================================

(uiop:define-package :elmtui.ui.widgets.scroll-panel
  (:use :cl :alexandria :elmtui.ui.defcomponent)
  (:import-from :elmtui.ui.api
    #:component #:id-from-path
    #:init #:update #:view #:make-state-patch)
  (:import-from :elmtui.state.api
    #:make-update-result
    #:get-path
    #:state-ref
    #:update-result-patches
    #:update-result-commands)
  (:export #:scroll-panel
    #:make-scroll-panel))

(in-package :elmtui.ui.widgets.scroll-panel)

;;;---------------------------------------------------------------
;;; Scroll Panel Component
;;;---------------------------------------------------------------

(defcomponent scroll-panel ()
  ()
  (:state
    ;; Dimensions
    (width 40 :type integer :documentation "Width of the scroll panel"
      :initarg :width :accessor scroll-panel-width)
    (height 20 :type integer :documentation "Height of the scroll panel (visible area)"
      :initarg :height :accessor scroll-panel-height)

    ;; Content
    (content-height 100 :type integer :documentation "Total height of content"
      :initarg :content-height :accessor scroll-panel-content-height)
    (children-dsl (list) :type list :documentation "Child DSL nodes"
      :initarg :children :accessor scroll-panel-children)

    ;; Scrolling state
    (scroll-y 0 :type integer :documentation "Vertical scroll offset (0 = top)"
      :initarg :scroll-y :accessor scroll-panel-scroll-y)

    ;; Display options
    (show-scrollbar t :type boolean :documentation "Whether to show scrollbar"
      :initarg :show-scrollbar :accessor scroll-panel-show-scrollbar)
    (border-style :single :type keyword :documentation "Border style (:none, :single, :double)"
      :initarg :border-style :accessor scroll-panel-border-style)
    (title nil :type (or null string) :documentation "Optional title"
      :initarg :title :accessor scroll-panel-title)

    ;; Styling
    (background-color nil :type (or null string keyword)
      :initarg :background-color :accessor scroll-panel-background-color)
    (border-color nil :type (or null string keyword)
      :initarg :border-color :accessor scroll-panel-border-color)
    (scrollbar-char "█" :type string :documentation "Character for scrollbar"
      :initarg :scrollbar-char :accessor scroll-panel-scrollbar-char))

  (:documentation "A panel with virtual scrolling - content moves, terminal doesn't scroll.")
  (:on-unhandled-message :log)

  (:init (props self-id-path)
    ;; All properties handled by defcomponent automatically
    (values nil nil))

  (:update (message local-state app-state self-id-path)
    ;; (case (first message)
    ;; Scroll commands
    (:scroll-to (target)
      (let ((new-y (max 0 (min target
                            (- (state-ref local-state :content-height)
                              (state-ref local-state :height))))))
        (values `(:scroll-y ,new-y) nil)))

    (:scroll-by (amount)
      (let* ((delta amount)
              (current-y (state-ref local-state :scroll-y 0))
              (max-scroll (max 0 (- (state-ref local-state :content-height)
                                   (state-ref local-state :height))))
              (new-y (max 0 (min (+ current-y delta) max-scroll))))
        (values `(:scroll-y ,new-y) nil)))

    (:scroll-up (lines)
      (let* ((lines (or lines 1))
              (current-y (state-ref local-state :scroll-y 0))
              (new-y (max 0 (- current-y lines))))
        (values `(:scroll-y ,new-y) nil)))

    (:scroll-down (lines)
      (let* ((lines (or lines 1))
              (current-y (state-ref local-state :scroll-y 0))
              (max-scroll (max 0 (- (state-ref local-state :content-height)
                                   (state-ref local-state :height))))
              (new-y (min (+ current-y lines) max-scroll)))
        (values `(:scroll-y ,new-y) nil)))

    (:page-up ()
      (let* ((current-y (state-ref local-state :scroll-y 0))
              (page-size (state-ref local-state :height))
              (new-y (max 0 (- current-y page-size))))
        (values `(:scroll-y ,new-y) nil)))

    (:page-down ()
      (let* ((current-y (state-ref local-state :scroll-y 0))
              (page-size (state-ref local-state :height))
              (max-scroll (max 0 (- (state-ref local-state :content-height)
                                   (state-ref local-state :height))))
              (new-y (min (+ current-y page-size) max-scroll)))
        (values `(:scroll-y ,new-y) nil)))

    (:scroll-to-top ()
      (values `(:scroll-y 0) nil))

    (:scroll-to-bottom ()
      (let ((max-scroll (max 0 (- (state-ref local-state :content-height)
                                 (state-ref local-state :height)))))
        (values `(:scroll-y ,max-scroll) nil)))

    ;; Update content
    (:set-content (new-children new-content-height)
      (let ((new-height (or new-content-height (state-ref local-state :content-height))))
        (values `(:children-dsl ,new-children :content-height ,new-height) nil)))

    ;; Resize
    (:set-dimensions (width height)
      (let ((new-width width)
             (new-height height))
        (values `(:width ,new-width :height ,new-height) nil)))

    (:otherwise
      (values nil nil)))

  (:view (local-state app-state self-id-path children)
    (let* ((width (state-ref local-state :width 40))
            (height (state-ref local-state :height 20))
            (scroll-y (state-ref local-state :scroll-y 0))
            (content-height (state-ref local-state :content-height height))
            (show-scrollbar (state-ref local-state :show-scrollbar t))
            (border-style (state-ref local-state :border-style :single))
            (title (state-ref local-state :title))
            (children-dsl (or children (state-ref local-state :children-dsl)))
            (bg-color (state-ref local-state :background-color))
            (border-color (state-ref local-state :border-color))
            (scrollbar-char (or (state-ref local-state :scrollbar-char) "█"))

            ;; Calculate scrollbar position
            (scrollable-p (> content-height height))
            (scroll-percent (if scrollable-p
                              (/ scroll-y (- content-height height))
                              0))
            (scrollbar-y (if scrollable-p
                           (floor (* scroll-percent (- height 2))) ; -2 for borders
                           0))

            ;; Determine effective content area width
            (content-width (- width (if (and show-scrollbar scrollable-p) 3 2))) ; borders + scrollbar
            (content-height-visible (- height 2)) ; borders

            ;; Build the DSL
            (container-id (intern (format nil "SCROLL-PANEL-~A" (id-from-path self-id-path)) :keyword)))

      `(:container
         :id ,container-id
         :style (:width ,width
                  :height ,height
                  :overflow :hidden  ; Clip content
                  ,@(when bg-color `(:background-color ,bg-color)))
         :children
         (;; Border box
           (:box
             :id ,(intern (format nil "~A-BORDER" container-id) :keyword)
             :style (:width ,width
                      :height ,height
                      :border-style ,border-style
                      ,@(when border-color `(:border-color ,border-color))
                      ,@(when title `(:border-title ,title)))
             :children
             (;; Content viewport (clipped area)
               (:container
                 :id ,(intern (format nil "~A-CONTENT" container-id) :keyword)
                 :style (:width ,content-width
                          :height ,content-height-visible
                          :offset-x 1  ; Inside border
                          :offset-y 1
                          :scroll-y ,scroll-y  ; Virtual scroll offset
                          :overflow :hidden)
                 :children ,children-dsl)

               ;; Scrollbar (if enabled and content is scrollable)
               ,@(when (and show-scrollbar scrollable-p)
                   `((:text
                       :id ,(intern (format nil "~A-SCROLLBAR" container-id) :keyword)
                       :content ,scrollbar-char
                       :style (:position :absolute
                                :x ,(- width 2)  ; Right edge inside border
                                :y ,(+ 1 scrollbar-y)  ; Inside border + scroll position
                                :color :white
                                :background-color :gray))))))))))) ; Close defcomponent

;;;---------------------------------------------------------------
;;; Constructor
;;;---------------------------------------------------------------

(defun make-scroll-panel (id &rest initargs)
  "Create a scroll-panel component instance.

  Parameters:
    ID - Keyword identifier for the component
    INITARGS - Initialization arguments (width, height, content-height, etc.)"
  (declare (ignore initargs))
  (make-instance 'scroll-panel :id id))
