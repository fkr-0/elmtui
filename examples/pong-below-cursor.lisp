(uiop:define-package :elmtui.examples.pong-below-cursor
  (:use :cl :log4cl)
  (:import-from :alexandria #:clamp)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.app.api #:run-application)
  (:import-from :elmtui.core.event-types #:key-event #:key-event-key)
  (:import-from :elmtui.state.api #:state-ref #:make-update-result)
  (:export #:run-pong-below-cursor
           #:pong-update
           #:pong-view
           #:%initial-state))

(in-package :elmtui.examples.pong-below-cursor)

(defconstant +field-width+ 40)
(defconstant +field-height+ 7)
(defconstant +paddle-half-width+ 2)

(defun %initial-state ()
  (list :ball-x 20
        :ball-y 2
        :vel-x 1
        :vel-y 1
        :paddle-x 20
        :score 0
        :should-quit nil))

(defun %quit-result ()
  (make-update-result :patches '(((:should-quit) t))))

(defun %move-paddle (state delta)
  (let* ((current (state-ref state :paddle-x 20))
         (next (clamp (+ current delta)
                      +paddle-half-width+
                      (- (1- +field-width+) +paddle-half-width+))))
    (make-update-result :patches `(((:paddle-x) ,next)))))

(defun %tick-update (state)
  (let* ((x (state-ref state :ball-x 20))
         (y (state-ref state :ball-y 2))
         (vx (state-ref state :vel-x 1))
         (vy (state-ref state :vel-y 1))
         (paddle-x (state-ref state :paddle-x 20))
         (score (state-ref state :score 0))
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
        (%quit-result)
        (make-update-result :patches `(((:ball-x) ,next-x)
                                       ((:ball-y) ,next-y)
                                       ((:vel-x) ,next-vx)
                                       ((:vel-y) ,next-vy)
                                       ((:score) ,score))))))

(defun pong-update (message app-state)
  (cond
    ((typep message 'key-event)
     (let ((key (key-event-key message)))
       (cond
         ((member key '(#\q #\Q #\Escape) :test #'eql)
          (%quit-result))
         ((member key '(:left #\h #\H) :test #'eql)
          (%move-paddle app-state -1))
         ((member key '(:right #\l #\L) :test #'eql)
          (%move-paddle app-state 1))
         (t
          (make-update-result)))))
    ((or (eql message :tick)
         (and (listp message) (eq (first message) :tick)))
     (%tick-update app-state))
    ((and (listp message) (eq (first message) :app-quit-requested))
     (%quit-result))
    (t
     (make-update-result))))

(defun %field-lines (state)
  (let* ((ball-x (state-ref state :ball-x 0))
         (ball-y (state-ref state :ball-y 0))
         (paddle-x (state-ref state :paddle-x 20))
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

(defun pong-view (state)
  (let ((score (state-ref state :score 0)))
    `(:container
       :id :pong-root
       :style (:display :flex :flex-direction :column :width 60 :height 12 :padding 0)
       :children
       ((:text :content ,(format nil "pong | score: ~D" score))
        (:text :content "controls: left/right or h/l | q to quit")
        (:text :content ,(format nil "+~A+" (make-string +field-width+ :initial-element #\-)))
        ,@(loop for row in (%field-lines state)
                collect `(:text :content ,(format nil "|~A|" row)))
        (:text :content ,(format nil "+~A+" (make-string +field-width+ :initial-element #\-)))))))

(defapplication pong-below-cursor-app
  :root-viewport-id :pong-root
  :root-component-dsl '(:root-viewport :id :pong-root
                        :anchor :below-cursor
                        :width 60
                        :height 12
                        :blank-on-exit t
                        :child-dsl-spec (:view nil))
  :initial-state-fn #'%initial-state
  :update-fn #'pong-update
  :view-fn #'pong-view
  :subscriptions-fn (lambda (_state)
                      (declare (ignore _state))
                      '(:timer (:interval 0.08 :message (:tick)))))

(defun run-pong-below-cursor (&key (backend-type :terminal))
  (log-info "pong-below-cursor: start backend=~S" backend-type)
  (run-application 'pong-below-cursor-app :backend-type backend-type))
