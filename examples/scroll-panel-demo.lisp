;;; Scroll panel demo with keyboard-driven component commands.

(uiop:define-package :elmtui.examples.scroll-panel-demo
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.app.api #:run-application)
  (:import-from :elmtui.state.api #:make-update-result)
  (:import-from :elmtui.core.event-types #:key-event #:key-event-key)
  (:export #:run-scroll-panel-demo #:main))

(in-package :elmtui.examples.scroll-panel-demo)

(defun make-initial-content ()
  (loop for i from 1 to 80
        collect `(:text
                  :id ,(intern (format nil "ITEM-~D" i) :keyword)
                  :content ,(format nil "Line ~2,'0D: Scroll panel content" i)
                  :style (:padding-left 1))))

(defun scroll-panel-update (message app-state)
  (declare (ignore app-state))
  (labels ((quit ()
             (make-update-result :patches '(((:should-quit) t))))
           (cmd (payload)
             (make-update-result :commands (list `(:component-message :main-panel ,payload)))))
    (cond
      ((typep message 'key-event)
       (case (key-event-key message)
         ((:escape #\q #\Q) (quit))
         (:up (cmd '(:scroll-up 1)))
         (:down (cmd '(:scroll-down 1)))
         (:pageup (cmd '(:page-up)))
         (:pagedown (cmd '(:page-down)))
         (:home (cmd '(:scroll-to-top)))
         (:end (cmd '(:scroll-to-bottom)))
         (t (make-update-result))))
      ((and (listp message) (eq (first message) :app-quit-requested))
       (quit))
      (t
       (make-update-result)))))

(defun scroll-panel-view (_state)
  (declare (ignore _state))
  `(:container
    :id :scroll-demo-root
    :style (:display :flex :flex-direction :column :width :fill :height :fill)
    :children
    ((:scroll-panel
      :id :main-panel
      :width 60
      :height 20
      :content-height 80
      :show-scrollbar t
      :border-style :double
      :title "Scroll Panel Demo"
      :children ,(make-initial-content))
     (:text
      :id :help
      :content "Keys: Up/Down, PageUp/PageDown, Home/End, q/Esc to quit"
      :style (:margin-top 1)))))

(defapplication scroll-panel-demo-app
  :root-viewport-id :scroll-demo-root
  :root-component-dsl '(:layout :id :scroll-demo-root)
  :initial-state-plist '(:should-quit nil)
  :update-fn #'scroll-panel-update
  :view-fn #'scroll-panel-view)

(defun run-scroll-panel-demo (&key (backend-type :terminal))
  (run-application 'scroll-panel-demo-app :backend-type backend-type))

(defun main ()
  (run-scroll-panel-demo))
