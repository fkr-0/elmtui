(uiop:define-package :elmtui.examples.pong-below-cursor
  (:use :cl :log4cl)
  (:import-from :alexandria #:clamp)
  (:import-from :elmtui.app.tea-core #:deftea-app)
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-key #:key-event-parts)
  (:export #:run-pong-below-cursor
           #:pong-transition
           #:pong-view
           #:pong-init))

(in-package :elmtui.examples.pong-below-cursor)

(defconstant +field-width+ 40)
(defconstant +field-height+ 7)
(defconstant +paddle-half-width+ 2)

(defun pong-init ()
  (values (list :ball-x 20
                :ball-y 2
                :vel-x 1
                :vel-y 1
                :paddle-x 20
                :score 0)
          nil))

(defun %move-paddle (model delta)
  (let* ((current (getf model :paddle-x 20))
         (next (clamp (+ current delta)
                      +paddle-half-width+
                      (- (1- +field-width+) +paddle-half-width+))))
    (values (list :ball-x (getf model :ball-x)
                  :ball-y (getf model :ball-y)
                  :vel-x (getf model :vel-x)
                  :vel-y (getf model :vel-y)
                  :paddle-x next
                  :score (getf model :score))
            nil)))

(defun %tick-update (model)
  (let* ((x (getf model :ball-x 20))
         (y (getf model :ball-y 2))
         (vx (getf model :vel-x 1))
         (vy (getf model :vel-y 1))
         (paddle-x (getf model :paddle-x 20))
         (score (getf model :score 0))
         (next-x (+ x vx))
         (next-y (+ y vy))
         (next-vx vx)
         (next-vy vy)
         (lost nil))
    (when (or (< next-x 0) (>= next-x +field-width+))
      (setf next-vx (- next-vx)
            next-x (+ x next-vx)))
    (when (< next-y 0)
      (setf next-vy 1
            next-y 0))
    (when (>= next-y +field-height+)
      (if (<= (abs (- next-x paddle-x)) +paddle-half-width+)
          (setf next-vy -1
                next-y (1- +field-height+)
                score (1+ score))
          (setf lost t)))
    (if lost
        (values (list* :should-quit t model) nil)
        (values (list :ball-x next-x
                      :ball-y next-y
                      :vel-x next-vx
                      :vel-y next-vy
                      :paddle-x paddle-x
                      :score score)
                nil))))

(defun pong-transition (message model)
  ;; Timer ticks arrive as non-key messages; check them first.
  (when (or (eql message :tick)
            (and (consp message) (eq (first message) :tick)))
    (return-from pong-transition (%tick-update model)))
  (multiple-value-bind (key char _mods) (key-event-parts message)
    (declare (ignore _mods))
    (cond
      ((or (member key '(:escape :esc) :test #'eq)
           (member char '(#\q #\Q)))
       (values (list* :should-quit t model) nil))
      ((or (member key '(:arrow-left :left) :test #'eq)
           (member char '(#\h #\H)))
       (%move-paddle model -1))
      ((or (member key '(:arrow-right :right) :test #'eq)
           (member char '(#\l #\L)))
       (%move-paddle model 1))
      (t (values model nil)))))

(defun %field-lines (model)
  (let* ((ball-x (getf model :ball-x 0))
         (ball-y (getf model :ball-y 0))
         (paddle-x (getf model :paddle-x 20))
         (rows (loop for _ from 0 below (1+ +field-height+)
                     collect (make-string +field-width+ :initial-element #\Space))))
    (when (and (<= 0 ball-y) (< ball-y (length rows))
               (<= 0 ball-x) (< ball-x +field-width+))
      (setf (char (nth ball-y rows) ball-x) #\O))
    (let ((paddle-row (nth +field-height+ rows)))
      (loop for x from (max 0 (- paddle-x +paddle-half-width+))
              to (min (1- +field-width+) (+ paddle-x +paddle-half-width+))
            do (setf (char paddle-row x) #\=)))
    rows))

(defun pong-view (model)
  (let ((score (getf model :score 0)))
    `(:container
       :id :pong-content
       :style (:display :flex :flex-direction :column :width 60 :height 12 :padding 0)
       :children
       ((:text :content ,(format nil "pong | score: ~D" score))
        (:text :content "controls: left/right or h/l | q to quit")
        (:text :content ,(format nil "+~A+" (make-string +field-width+ :initial-element #\-)))
        ,@(loop for row in (%field-lines model)
                collect `(:text :content ,(format nil "|~A|" row)))
        (:text :content ,(format nil "+~A+" (make-string +field-width+ :initial-element #\-)))))))

(deftea-app pong-below-cursor-app
  :init       #'pong-init
  :transition #'pong-transition
  :view       #'pong-view
  :root-viewport-id :pong-root
  :anchor     :below-cursor
  :height     12
  :subscriptions (lambda (model)
                   (declare (ignore model))
                   '(:timer (:interval 0.08 :message (:tick)))))

(defun run-pong-below-cursor (&key (backend-type :terminal))
  (log-info "pong-below-cursor: start backend=~S" backend-type)
  (run-pong-below-cursor-app :platform backend-type))
