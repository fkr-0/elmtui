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

(defun scroll-panel-update (message state)
  "Page an 80-line text view without relying on a missing scroll-panel DSL tag."
  (let* ((key (and (typep message 'key-event) (key-event-key message)))
         (offset (elmtui.state.api:state-ref state :scroll-offset 0))
         (last-start (- 80 18)))
    (cond
      ((or (member key '(:escape :esc :q #\q #\Q) :test #'eql)
           (and (consp message) (eq (first message) :app-quit-requested)))
       (make-update-result :patches '(((:should-quit) t))))
      (key
       (let ((next (case key
                     ((:arrow-up :up) (1- offset))
                     ((:arrow-down :down) (1+ offset))
                     ((:page-up :pageup) (- offset 18))
                     ((:page-down :pagedown) (+ offset 18))
                     (:home 0)
                     (:end last-start)
                     (otherwise offset))))
         (make-update-result
          :patches (list (list '(:scroll-offset)
                               (max 0 (min last-start next)))))))
      (t (make-update-result)))))

(defun scroll-panel-view (state)
  (let* ((offset (elmtui.state.api:state-ref state :scroll-offset 0))
         (lines (subseq (make-initial-content) offset (+ offset 18))))
    `(:container :id :scroll-demo-content
       :style (:display :flex :flex-direction :column :width 70 :height 22)
       :children
       ((:text :id :heading :content "Scroll panel content")
        ,@lines
        (:text :id :help :content "Up/Down | PageUp/PageDown | Home/End | q: quit")))))

(defapplication scroll-panel-demo-app
  :root-viewport-id :scroll-demo-root
  :root-component-dsl '(:root-viewport :id :scroll-demo-root :child-dsl-spec (:view nil))
  :initial-state-plist '(:should-quit nil :scroll-offset 0)
  :update-fn #'scroll-panel-update
  :view-fn #'scroll-panel-view)

(defun run-scroll-panel-demo (&key (backend-type :terminal))
  (run-scroll-panel-demo-app :platform backend-type))


(defun main ()
  (run-scroll-panel-demo))
