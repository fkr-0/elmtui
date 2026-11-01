;;; Scroll panel demo with keyboard-driven component commands.

(uiop:define-package :elmtui.examples.scroll-panel-demo
  (:use :cl)
  (:import-from :elmtui.app.tea-core #:deftea-app)
  (:import-from :elmtui.keys #:key-event #:key-event-key)
  (:import-from :elmtui.core.event-types #:key-event-parts)
  (:export #:run-scroll-panel-demo #:main))

(in-package :elmtui.examples.scroll-panel-demo)

(defun make-initial-content ()
  (loop for i from 1 to 80
        collect `(:text
                  :id ,(intern (format nil "ITEM-~D" i) :keyword)
                  :content ,(format nil "Line ~2,'0D: Scroll panel content" i)
                  :style (:padding-left 1))))

(defun scroll-panel-transition (message model)
  "Page an 80-line text view without relying on a missing scroll-panel DSL tag."
  (let* ((offset (getf model :scroll-offset 0))
         (last-start (- 80 18)))
    (multiple-value-bind (key char _mods) (key-event-parts message)
      (declare (ignore _mods))
      (cond
        ((or (member key '(:escape :esc) :test #'eq)
             (member char '(#\q #\Q)))
         (values (list* :should-quit t model) nil))
        (key
         (let ((next (case key
                       ((:arrow-up :up) (1- offset))
                       ((:arrow-down :down) (1+ offset))
                       ((:page-up :pageup) (- offset 18))
                       ((:page-down :pagedown) (+ offset 18))
                       (:home 0)
                       (:end last-start)
                       (otherwise offset))))
           (values (list :scroll-offset (max 0 (min last-start next))) nil)))
        (t (values model nil))))))

(defun scroll-panel-view (model)
  (let* ((offset (getf model :scroll-offset 0))
         (lines (subseq (make-initial-content) offset (+ offset 18))))
    `(:container :id :scroll-demo-content
       :style (:display :flex :flex-direction :column :width 70 :height 22)
       :children
       ((:text :id :heading :content "Scroll panel content")
        ,@lines
        (:text :id :help :content "Up/Down | PageUp/PageDown | Home/End | q: quit")))))

(defun scroll-panel-init ()
  (values (list :scroll-offset 0) nil))

(deftea-app scroll-panel-demo-app
  :init       #'scroll-panel-init
  :transition #'scroll-panel-transition
  :view       #'scroll-panel-view
  :root-viewport-id :scroll-demo-root
  :anchor     :below-cursor)

(defun run-scroll-panel-demo (&key (backend-type :terminal))
  (run-scroll-panel-demo-app :platform backend-type))

(defun main ()
  (run-scroll-panel-demo))
