(uiop:define-package :elmtui.examples.game-of-life
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.app.api #:run-application)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.core.event-types #:key-event #:key-event-char)
  (:export #:run-game-of-life-app #:main))

(in-package :elmtui.examples.game-of-life)

(defun get-glider-pattern ()
  (let ((grid (make-array '(20 40) :element-type 'bit :initial-element 0)))
    (setf (aref grid 1 2) 1
          (aref grid 2 3) 1
          (aref grid 3 1) 1
          (aref grid 3 2) 1
          (aref grid 3 3) 1)
    grid))

(defun count-neighbors (grid x y width height)
  (let ((count 0))
    (dolist (dy '(-1 0 1))
      (dolist (dx '(-1 0 1))
        (unless (and (zerop dx) (zerop dy))
          (let ((nx (mod (+ x dx) width))
                (ny (mod (+ y dy) height)))
            (incf count (aref grid ny nx))))))
    count))

(defun next-generation (grid)
  (let* ((height (array-dimension grid 0))
         (width (array-dimension grid 1))
         (new-grid (make-array (list height width) :element-type 'bit :initial-element 0)))
    (dotimes (y height)
      (dotimes (x width)
        (let ((neighbors (count-neighbors grid x y width height))
              (cell (aref grid y x)))
          (setf (aref new-grid y x)
                (cond
                  ((and (= cell 1) (or (= neighbors 2) (= neighbors 3))) 1)
                  ((and (= cell 0) (= neighbors 3)) 1)
                  (t 0))))))
    new-grid))

(defun game-of-life-update (message app-state)
  (let ((grid (state-ref app-state :grid))
        (generation (state-ref app-state :generation 0))
        (running (state-ref app-state :running t)))
    (cond
      ((eq message :tick)
       (if running
           (make-update-result
            :patches `(((:grid) ,(next-generation grid))
                       ((:generation) ,(1+ generation))))
           (make-update-result)))
      ((typep message 'key-event)
       (let ((ch (key-event-char message)))
         (cond
           ((char= ch #\Space)
            (make-update-result :patches `(((:running) ,(not running)))))
           ((char= ch #\r)
            (make-update-result :patches `(((:grid) ,(get-glider-pattern))
                                           ((:generation) 0))))
           ((char= ch #\q)
            (make-update-result :patches '(((:should-quit) t))))
           (t
            (make-update-result)))))
      ((and (listp message) (eq (first message) :app-quit-requested))
       (make-update-result :patches '(((:should-quit) t))))
      (t
       (make-update-result)))))

(defun grid-row->string (grid y width)
  (coerce
   (loop for x below width
         collect (if (eql 1 (aref grid y x)) #\# #\.))
   'string))

(defun game-of-life-view (app-state)
  (let* ((grid (state-ref app-state :grid))
         (height (array-dimension grid 0))
         (width (array-dimension grid 1))
         (generation (state-ref app-state :generation 0))
         (running (state-ref app-state :running t))
         (status (format nil "Gen: ~D | ~A | Space:Pause r:Reset q:Quit"
                         generation
                         (if running "Running" "Paused"))))
    `(:container
      :id :gol-root
      :style (:display :flex :flex-direction :column)
      :children
      ((:text :id :status :content ,status)
       ,@(loop for y below height
               collect `(:text
                         :id ,(intern (format nil "ROW-~D" y) :keyword)
                         :content ,(grid-row->string grid y width)))))))

(defun %game-of-life-initial-state ()
  (list :grid (get-glider-pattern)
        :generation 0
        :running t
        :should-quit nil))

(defapplication game-of-life-app
  :root-viewport-id :gol-root-vp
  :initial-state-fn #'%game-of-life-initial-state
  :root-component-dsl '(:layout :id :gol-root)
  :update-fn #'game-of-life-update
  :view-fn #'game-of-life-view)

(defun main ()
  (run-game-of-life-app))
