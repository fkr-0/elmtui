(uiop:define-package :elmtui.examples.root-viewport-test-app
  (:use :cl)
  (:import-from :elmtui.app.tea-core #:deftea-app)
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-key #:key-event-char #:key-event-parts)
  (:export #:main #:run-root-viewport-test-app))

(in-package :elmtui.examples.root-viewport-test-app)

(defconstant +rect-width+ 10)
(defconstant +rect-height+ 5)
(defparameter +rect-color+ '(0 255 0))

(defun root-viewport-test-transition (message model)
  (let* ((x (getf model :offset-x 10))
         (y (getf model :offset-y 5)))
    (labels ((move (nx ny)
               (values (list :offset-x (max 0 nx) :offset-y (max 0 ny)) nil))
             (quit ()
               (values (list* :should-quit t model) nil)))
      (multiple-value-bind (key char _mods) (key-event-parts message)
        (declare (ignore _mods))
        (cond
          ((or (eq key :left) (eql key :arrow-left)) (move (1- x) y))
          ((or (eq key :right) (eql key :arrow-right)) (move (1+ x) y))
          ((or (eq key :up) (eql key :arrow-up)) (move x (1- y)))
          ((or (eq key :down) (eql key :arrow-down)) (move x (1+ y)))
          ((or (member key '(:escape :esc) :test #'eq)
               (member char '(#\q #\Q)))
           (quit))
          (t (values model nil)))))))

(defun root-viewport-test-view (model)
  (let ((x (getf model :offset-x 10))
        (y (getf model :offset-y 5)))
    `(:container :id :rv-root :style (:display :flex :flex-direction :column)
      :children
      ((:text :id :help :content "Arrows move the block, q/Esc quits")
       (:container :id :moving-rect
        :style (:offset-x ,x :offset-y ,y :width ,+rect-width+ :height ,+rect-height+ :bg-color ,+rect-color+))))))

(defun root-viewport-test-init ()
  (values (list :offset-x 10 :offset-y 5) nil))

(deftea-app root-viewport-test-app
  :init       #'root-viewport-test-init
  :transition #'root-viewport-test-transition
  :view       #'root-viewport-test-view
  :root-viewport-id :movable-root-vp
  :anchor     :below-cursor)

(defun main ()
  (run-root-viewport-test-app))
