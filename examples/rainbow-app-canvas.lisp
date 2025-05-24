;;;===============================================================
;;; File: examples/rainbow-app-canvas.lisp
;;; Example application demonstrating canvas positioning with rainbow stripes
;;;===============================================================
(uiop:define-package :elmtui.examples.rainbow-app-canvas
  (:use :cl :alexandria :log4cl)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.ui.widgets.utils
                #:widget-focused-p #:defwidget-view)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.runtime #:def-elm-app #:run-app)
  (:import-from :elmtui.style-lib.rule #:defrule)
  (:import-from :elmtui.style-lib.sheet #:defstylesheet)
  (:import-from :elmtui.state.update #:defupdate)
  (:export
   :main
   :main-below-cursor
   :main-above-cursor
   :main-top-left
   :main-top-right
   :main-bottom-middle
   :main-center
   :main-interactive
   :run-rainbow-canvas-app))

(in-package :elmtui.examples.rainbow-app-canvas)

;;;--------------------------------------------------------------
;;; Canvas Configuration Definitions
;;;--------------------------------------------------------------

(defparameter *canvas-configs* 
  '((:below-cursor  
     :use-canvas t
     :canvas-anchor :top-left 
     :canvas-growth :down
     :canvas-initial-size (20 10)
     :title "Below Cursor")
    
    (:above-cursor  
     :use-canvas t
     :canvas-anchor :bottom-left 
     :canvas-growth :up
     :canvas-initial-size (20 10)
     :title "Above Cursor")
    
    (:top-left      
     :use-canvas t
     :canvas-anchor :top-left
     :canvas-growth :fixed
     :canvas-initial-size (20 10)
     :title "Top Left")
    
    (:top-right     
     :use-canvas t
     :canvas-anchor :top-right
     :canvas-growth :fixed
     :canvas-initial-size (20 10)
     :title "Top Right")
    
    (:bottom-middle 
     :use-canvas t
     :canvas-anchor :bottom
     :canvas-growth :fixed
     :canvas-initial-size (30 8)
     :title "Bottom Middle")
    
    (:center        
     :use-canvas t
     :canvas-anchor :center
     :canvas-growth :fixed
     :canvas-initial-size (25 15)
     :title "Center")
    
    (:interactive   
     :use-canvas t
     :canvas-anchor :cursor
     :canvas-growth :dynamic
     :canvas-initial-size (30 10)
     :title "Interactive - Resize with Arrow Keys"))
  "Different canvas configurations for demonstration.")

;;;--------------------------------------------------------------
;;; Stylesheet Definition
;;;--------------------------------------------------------------

(defvar *rainbow-colors-with-names* '((:red "red-stripe" (255 0 0))
                                     (:pink "pink-stripe" (255 192 203))
                                     (:orange "orange-stripe" (255 165 0))
                                     (:yellow "yellow-stripe" (255 255 0))
                                     (:green "green-stripe" (0 255 0))
                                     (:blue "blue-stripe" (0 0 255))
                                     (:indigo "indigo-stripe" (75 0 130))
                                     (:violet "violet-stripe" (238 130 238)))
  "List of colors and their corresponding class names for stripes.")

;; Add canvas-specific styles
(defun generate-stripe-rules-forms ()
  "Generates a list of defrule forms for stripes."
  (append
   ;; Canvas container style
   (list 
    (defrule "canvas-container"
      :border-style :single
      :padding-left 1
      :padding-right 1
      :padding-top 1
      :padding-bottom 1)
    
    (defrule "canvas-title"
      :text-color (elmtui.style-lib.styles:rgb '(255 255 255))
      :background-color (elmtui.style-lib.styles:rgb '(50 50 50))
      :width :fill
      :text-align :center)
    
    (defrule "canvas-hint"
      :text-color (elmtui.style-lib.styles:rgb '(180 180 180))
      :width :fill
      :text-align :center))
   
   ;; Rainbow stripe styles
   (loop for (color-name class-name rgb) in *rainbow-colors-with-names*
         collect (defrule class-name
                   :background-color (elmtui.style-lib.styles:rgb rgb)
                   :height 1
                   :width :fill))))

;; Define the stylesheet for the rainbow app
(defparameter *rainbow-canvas-stylesheet*
  (defstylesheet (generate-stripe-rules-forms)))

;;;--------------------------------------------------------------
;;; Application Definition
;;;--------------------------------------------------------------

(defun app-init (config)
  "Initializes the application model with specified canvas configuration."
  (let* ((config-info (cdr (assoc config *canvas-configs*)))
         (canvas-title (getf config-info :title "Rainbow Canvas Demo"))
         (initial-width (first (getf config-info :canvas-initial-size '(30 10))))
         (initial-height (second (getf config-info :canvas-initial-size '(30 10)))))
    
    (values
     ;; Initial application state
     (list :current-stylesheet *rainbow-canvas-stylesheet*
           :should-quit nil
           :canvas-config config
           :canvas-title canvas-title
           :canvas-width initial-width
           :canvas-height initial-height
           :resize-mode (eq config :interactive))
     ;; No initial commands
     nil)))

(defupdate app-update (app-state message)
  "Handles updates to the application state based on messages."
  (log-debug "Received message: ~S" message)
  
  (cond
    ;; Quit on 'q' key
    ((and (typep message 'elmtui.core.event-types:key-event)
          (eql (elmtui.core.event-types:key-event-key message) #\q))
     (values (list :should-quit t) nil))
    
    ;; Handle arrow keys for resizing in interactive mode
    ((and (typep message 'elmtui.core.event-types:key-event)
          (elmtui.state:state-ref app-state :resize-mode))
     (let ((key (elmtui.core.event-types:key-event-key message))
           (current-width (elmtui.state:state-ref app-state :canvas-width))
           (current-height (elmtui.state:state-ref app-state :canvas-height)))
       
       (cond
         ((eql key :up)
          (values (list :canvas-height (max 3 (1- current-height))) nil))
         ((eql key :down)
          (values (list :canvas-height (min 20 (1+ current-height))) nil))
         ((eql key :left)
          (values (list :canvas-width (max 10 (1- current-width))) nil))
         ((eql key :right)
          (values (list :canvas-width (min 50 (1+ current-width))) nil))
         (t nil))))
    
    ;; Default: no state change
    (t nil)))

(defun rainbow-canvas-view (app-state dispatch-fn)
  "Creates the UI view with rainbow stripes in a canvas."
  (log-info "Creating rainbow canvas view. Config: ~S" 
           (elmtui.state:state-ref app-state :canvas-config))
  
  (let ((canvas-title (elmtui.state:state-ref app-state :canvas-title))
        (resize-mode (elmtui.state:state-ref app-state :resize-mode)))
    
    (make-styled-node
     :type :container
     :props (list :id :canvas-main-container
                  :direction :column
                  :height :fill
                  :width :fill
                  :classes "canvas-container")
     :children 
     (list
      ;; Title bar
      (make-styled-node
       :type :text
       :props (list :id :canvas-title
                    :classes "canvas-title"
                    :text canvas-title))
      
      ;; Rainbow stripes container
      (make-styled-node
       :type :container
       :props (list :id :rainbow-stripes
                    :direction :column
                    :height :fill
                    :width :fill)
       :children (loop for (color-name class-name rgb-val) in *rainbow-colors-with-names*
                      collect (make-styled-node
                               :type :container
                               :props (list :id (intern (format nil "STRIPE-~A" (string color-name)) :keyword)
                                           :classes class-name)
                               :children nil)))
      
      ;; Instruction hint at bottom if in resize mode
      (when resize-mode
        (make-styled-node
         :type :text
         :props (list :id :canvas-hint
                      :classes "canvas-hint"
                      :text "Arrow keys to resize, q to quit")))))))

;; Define app versions for each canvas configuration
(def-elm-app rainbow-canvas-app
  :init (lambda () (app-init :below-cursor))
  :update #'app-update
  :view #'rainbow-canvas-view)

;;;--------------------------------------------------------------
;;; Entry Point Functions
;;;--------------------------------------------------------------

(defun run-with-config (config-key)
  "Run the rainbow canvas app with the specified configuration."
  (let* ((config (cdr (assoc config-key *canvas-configs*)))
         (use-canvas (getf config :use-canvas t))
         (canvas-anchor (getf config :canvas-anchor :cursor))
         (canvas-growth (getf config :canvas-growth :down))
         (canvas-size (getf config :canvas-initial-size '(30 10))))
    
    (log-info "Starting Rainbow Canvas App with config: ~S" config-key)
    (log-info "Canvas settings: anchor=~S, growth=~S, size=~S" 
              canvas-anchor canvas-growth canvas-size)
    
    (elmtui.runtime:run-app 
     :app-name 'rainbow-canvas-app
     :init-fn (lambda () (app-init config-key))
     :use-canvas use-canvas
     :canvas-anchor canvas-anchor
     :canvas-growth canvas-growth
     :canvas-initial-size canvas-size)))

;; Entry points for different canvas configurations
(defun main-below-cursor ()
  "Run with below-cursor configuration"
  (run-with-config :below-cursor))

(defun main-above-cursor ()
  "Run with above-cursor configuration"
  (run-with-config :above-cursor))

(defun main-top-left ()
  "Run with top-left configuration"
  (run-with-config :top-left))

(defun main-top-right ()
  "Run with top-right configuration"
  (run-with-config :top-right))

(defun main-bottom-middle ()
  "Run with bottom-middle configuration"
  (run-with-config :bottom-middle))

(defun main-center ()
  "Run with center configuration"
  (run-with-config :center))

(defun main-interactive ()
  "Run with interactive configuration that allows resizing"
  (run-with-config :interactive))

;; Default main function for standard usage
(defun main ()
  "Run the default rainbow canvas example (interactive mode)"
  (main-interactive))