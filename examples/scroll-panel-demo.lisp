;;;===============================================================
;;; File: examples/scroll-panel-demo.lisp
;;; Scroll Panel Demo
;;;
;;; Demonstrates the virtual scroll panel component with scrollbar.
;;;===============================================================

(uiop:define-package :elmtui.examples.scroll-panel-demo
  (:use :cl)
  (:import-from :elmtui.app
                #:defapplication-contracted)
  (:import-from :elmtui.ui.widgets.scroll-panel
                #:make-scroll-panel)
  (:export #:run-scroll-panel-demo))

(in-package :elmtui.examples.scroll-panel-demo)

;;;---------------------------------------------------------------
;;; Application State
;;;---------------------------------------------------------------

(defun make-initial-content ()
  "Generate a list of text items for scrolling."
  (loop for i from 1 to 50
        collect `(:text
                  :id ,(intern (format nil "ITEM-~D" i) :keyword)
                  :content ,(format nil "Line ~2,'0D: This is scrollable content" i)
                  :style (:padding-left 2))))

;;;---------------------------------------------------------------
;;; Application Definition
;;;---------------------------------------------------------------

(defapplication-contracted scroll-panel-demo
  :root-dsl '(:scroll-panel
              :id :main-panel
              :width 60
              :height 20
              :content-height 50
              :show-scrollbar t
              :border-style :double
              :title "Scroll Panel Demo"
              :border-color :cyan
              :children ((:container
                          :id :content-container
                          :style (:flex-direction :column)
                          :children nil))) ; Will be set in init
  
  :initial-state (:scroll-position 0
                  :content-items nil)
  
  :message-schema scroll-panel-demo-msg
  :messages ((KeyPress :key keyword)
             (ScrollTo :position integer)
             (Quit))
  
  :update
  (case (first message)
    (:key-press
     (let ((key (second message)))
       (case key
         (:down
          (values model
                  (list `(:component-message :main-panel (:scroll-down 1)))))
         (:up
          (values model
                  (list `(:component-message :main-panel (:scroll-up 1)))))
         (:page-down
          (values model
                  (list `(:component-message :main-panel (:page-down)))))
         (:page-up
          (values model
                  (list `(:component-message :main-panel (:page-up)))))
         (:home
          (values model
                  (list `(:component-message :main-panel (:scroll-to-top)))))
         (:end
          (values model
                  (list `(:component-message :main-panel (:scroll-to-bottom)))))
         (#\q
          (values (list* :should-quit t model) nil))
         (otherwise
          (values model nil)))))
    
    (otherwise
     (values model nil)))
  
  :view
  (let ((content-items (make-initial-content)))
    `(:container
      :id :root
      :style (:flex-direction :column
              :background-color :black)
      :children ((:scroll-panel
                  :id :main-panel
                  :width 60
                  :height 20
                  :content-height 50
                  :show-scrollbar t
                  :border-style :double
                  :title "Scroll Panel Demo - Use Arrow Keys to Scroll"
                  :border-color :cyan
                  :children ,content-items)
                 
                 (:text
                  :id :help
                  :content "Keys: ↑/↓=Line  PgUp/PgDn=Page  Home/End=Top/Bottom  Q=Quit"
                  :style (:margin-top 1
                          :color :yellow)))))
  
  :subscriptions
  (declare (ignore model))
  nil)

;;;---------------------------------------------------------------
;;; Run Demo
;;;---------------------------------------------------------------

(defun run-scroll-panel-demo ()
  "Run the scroll panel demonstration."
  (format t "Starting scroll panel demo...~%")
  (format t "Use arrow keys to scroll, Page Up/Down for pages, Home/End for top/bottom~%")
  (format t "Press Q to quit~%~%")
  ;; Implementation would call the application runner
  ;;(run-application 'scroll-panel-demo)
  )
