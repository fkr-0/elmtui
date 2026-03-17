;;;===============================================================
;;; Glider Animation (maintained example)
;;;===============================================================

(uiop:define-package :elmtui.examples.glider
  (:use :cl :log4cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.core.event-types #:key-event #:key-event-key)
  (:import-from :elmtui.state.api #:state-ref #:make-update-result)
  (:export #:run-glider-animation))

(in-package :elmtui.examples.glider)

(defun %initial-state ()
  (list :x 2
        :y 2
        :dx 1
        :dy 1
        :w 60
        :h 18
        :tick 0
        :should-quit nil))

(defun %bounce-step (x y dx dy w h)
  (let* ((nx (+ x dx))
         (ny (+ y dy))
         (ndx dx)
         (ndy dy))
    (when (or (< nx 0) (>= nx w))
      (setf ndx (- ndx)
            nx (+ x ndx)))
    (when (or (< ny 0) (>= ny h))
      (setf ndy (- ndy)
            ny (+ y ndy)))
    (values nx ny ndx ndy)))

(defun glider-update (message state)
  (cond
    ((typep message 'key-event)
     (case (key-event-key message)
       ((:escape #\q #\Q) (make-update-result :patches '(((:should-quit) t))))
       (t (make-update-result))))
    ((and (listp message) (eq (first message) :tick))
     (let* ((x (state-ref state :x 0))
            (y (state-ref state :y 0))
            (dx (state-ref state :dx 1))
            (dy (state-ref state :dy 1))
            (w (state-ref state :w 60))
            (h (state-ref state :h 18))
            (tick (state-ref state :tick 0)))
       (multiple-value-bind (nx ny ndx ndy) (%bounce-step x y dx dy w h)
         (make-update-result
          :patches `(((:x) ,nx)
                     ((:y) ,ny)
                     ((:dx) ,ndx)
                     ((:dy) ,ndy)
                     ((:tick) ,(1+ tick)))))))
    ((and (listp message) (eq (first message) :app-quit-requested))
     (make-update-result :patches '(((:should-quit) t))))
    (t (make-update-result))))

(defun %trail-cell (x y i)
  `(:text
    :id ,(intern (format nil "TRAIL-~D" i) :keyword)
    :style (:position (:left ,x :top ,y) :fg-color :cyan)
    :content "·"))

(defun glider-view (state)
  (let* ((x (state-ref state :x 0))
         (y (state-ref state :y 0))
         (dx (state-ref state :dx 1))
         (dy (state-ref state :dy 1))
         (w (state-ref state :w 60))
         (h (state-ref state :h 18))
         (tick (state-ref state :tick 0)))
    `(:container
      :id :glider-root
      :style (:display :flex :flex-direction :column :width 80 :height 22 :padding 1)
      :children
      ((:text :content ,(format nil "glider-real: q/esc quit | pos=(~D,~D) vel=(~D,~D) tick=~D"
                                x y dx dy tick))
       (:container
        :id :arena
        :style (:position :relative :width ,w :height ,h :box :single)
        :children
        (,@(loop for i from 1 to 4
                 collect (%trail-cell (max 0 (- x i)) (max 0 (- y i)) i))
         (:text
          :id :glider
          :style (:position (:left ,x :top ,y) :fg-color :green :bold t)
          :content "█")))))))

(defapplication glider-animation-app
  :root-viewport-id :glider-root
  :root-component-dsl '(:root-viewport :id :glider-root)
  :initial-state-fn #'%initial-state
  :update-fn #'glider-update
  :view-fn #'glider-view)

(defun run-glider-animation (&key (backend-type :terminal))
  (log-info "glider-real: start backend=~S" backend-type)
  (run-glider-animation-app :platform backend-type))
