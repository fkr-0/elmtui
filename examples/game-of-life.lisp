(uiop:define-package :elmtui.examples.game-of-life
  (:use :cl :alexandria :log4cl)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :cl-styles.api #:defrule #:defstylesheet #:rgb)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.app #:defapplication)
  (:export #:run-game-of-life-app))

(in-package :elmtui.examples.game-of-life)

;;;-------------------------------------------------------------- 
;;; Stylesheet Definition 
;;;--------------------------------------------------------------
(defstylesheet game-of-life-stylesheet
  (defrule ("cell-alive") :background-color (rgb 0 255 0) :width 1 :height 1)
  (defrule ("cell-dead")  :background-color (rgb 0 0 0)   :width 1 :height 1)
  (defrule ("status-bar") :background-color (rgb 50 50 50) :color (rgb 255 255 255)
           :padding 1 :height 1))

;;;--------------------------------------------------------------
;;; Game of Life Logic
;;;--------------------------------------------------------------

(defun make-random-grid (width height &optional (density 0.3))
  "Create a new random grid of the specified dimensions."
  (let ((grid (make-array (list height width) :element-type 'bit :initial-element 0)))
    (dotimes (y height)
      (dotimes (x width)
        (when (< (random 1.0) density)
          (setf (aref grid y x) 1))))
    grid))

(defun count-neighbors (grid x y width height)
  "Count the number of live neighbors for the cell at (x, y)."
  (let ((count 0))
    (dolist (dy '(-1 0 1))
      (dolist (dx '(-1 0 1))
        (unless (and (zerop dx) (zerop dy))
          (let ((nx (mod (+ x dx) width))
                (ny (mod (+ y dy) height)))
            (incf count (aref grid ny nx))))))
    count))

(defun next-generation (grid)
  "Compute the next generation of the Game of Life grid."
  (let* ((height (array-dimension grid 0))
         (width (array-dimension grid 1))
         (new-grid (make-array (list height width) :element-type 'bit :initial-element 0)))
    (dotimes (y height)
      (dotimes (x width)
        (let ((neighbors (count-neighbors grid x y width height))
              (cell (aref grid y x)))
          (setf (aref new-grid y x)
                (cond ((and (= cell 1) (or (= neighbors 2) (= neighbors 3))) 1)
                      ((and (= cell 0) (= neighbors 3)) 1)
                      (t 0))))))
    new-grid))

(defun get-glider-pattern ()
  "Return a grid with a glider pattern."
  (let ((grid (make-array '(20 40) :element-type 'bit :initial-element 0)))
    ;; Add a glider at top left
    (setf (aref grid 1 2) 1
          (aref grid 2 3) 1
          (aref grid 3 1) 1
          (aref grid 3 2) 1
          (aref grid 3 3) 1)
    grid))

;;;--------------------------------------------------------------
;;; Application Definition
;;;--------------------------------------------------------------

(defun %initial-state ()
  (list :current-stylesheet game-of-life-stylesheet
        :grid (get-glider-pattern)
        :generation 0
        :running t
        :speed 5
        :hue 0
        :last-update-time (get-internal-real-time)
        :should-quit nil))

(defun app-update (message app-state)
  "Updates model -> update-result."
  (let ((grid (state-ref app-state :grid))
        (generation (state-ref app-state :generation))
        (running (state-ref app-state :running))
        (speed (state-ref app-state :speed))
        (hue (state-ref app-state :hue))
        (last-update-time (state-ref app-state :last-update-time))
        (now (get-internal-real-time)))
    (labels ((ret (&key patch commands)
               (make-update-result :patches patch :commands commands)))
      (cond
        ((eq message :tick)
         (if running
             (let ((dt (/ (- now last-update-time) internal-time-units-per-second)))
               (if (>= dt (/ 1 speed))
                   (ret :patch `((:grid ,(next-generation grid))
                                 (:generation ,(1+ generation))
                                 (:hue ,(mod (+ hue 10) 360))
                                 (:last-update-time ,now))
                        :commands (list (elmtui.view.reactive:next-frame-cmd :fps (max 1 (* 2 speed)) :message :tick)))
                   (ret :commands (list (elmtui.view.reactive:next-frame-cmd :fps (max 1 (* 2 speed)) :message :tick)))))
             (ret :commands (list (elmtui.view.reactive:next-frame-cmd :fps 5 :message :tick)))))
        ((and (listp message) (eq (first message) :key-event))
         (let ((ch (third message)))
           (cond
             ((char= ch #\Space) (ret :patch `((:running ,(not running)))))
             ((char= ch #\+)      (ret :patch `((:speed ,(min 20 (1+ speed))))))
             ((char= ch #\-)      (ret :patch `((:speed ,(max 1 (1- speed))))))
             ((char= ch #\r)      (ret :patch '((:grid NIL) (:generation 0))) ; reset to be handled below
              )
             ((char= ch #\q)      (ret :patch '((:should-quit t))))
             (t (ret)))))
        ((typep message 'elmtui.core.event-types:key-event)
         (let ((ch (elmtui.core.event-types:key-event-char message)))
           (cond
             ((char= ch #\Space) (ret :patch `((:running ,(not running)))))
             ((char= ch #\+)      (ret :patch `((:speed ,(min 20 (1+ speed))))))
             ((char= ch #\-)      (ret :patch `((:speed ,(max 1 (1- speed))))))
             ((char= ch #\r)      (ret :patch `((:grid ,(get-glider-pattern)) (:generation 0))))
             ((char= ch #\q)      (ret :patch '((:should-quit t))))
             (t (ret)))))
        (t (ret :commands (unless (state-ref app-state :should-quit)
                             (list (elmtui.view.reactive:next-frame-cmd :fps (max 1 (* 2 speed)) :message :tick)))))))))

(defun game-of-life-view (app-state)
  (flet ((hsv->rgb (h s v)
           (let* ((h (/ (mod h 360) 60.0))
                  (c (* v s))
                  (x (* c (- 1 (abs (- (mod h 2) 1)))))
                  (m (- v c))
                  (r-g-b (cond
                           ((< h 1) (list c x 0))
                           ((< h 2) (list x c 0))
                           ((< h 3) (list 0 c x))
                           ((< h 4) (list 0 x c))
                           ((< h 5) (list x 0 c))
                           (t        (list c 0 x)))) )
             (mapcar (lambda (p) (round (* 255 (+ p m)))) r-g-b))))
  (let* ((grid (state-ref app-state :grid))
         (h (array-dimension grid 0))
         (w (array-dimension grid 1))
         (generation (state-ref app-state :generation))
         (running (state-ref app-state :running))
         (speed (state-ref app-state :speed))
         (hue (state-ref app-state :hue))
         (status (format nil "Gen: ~A | ~A | Speed: ~A | Space: Toggle | +/-: Speed | r: Reset | q: Quit"
                         generation (if running "Running" "Paused") speed)))
    `(:container :id :gol-root :style (:display :flex :flex-direction :column :width :fill :height :fill)
      :children
      ((:container :id :grid :style (:display :flex :flex-direction :column :width :fill :height :fill)
         :children ,(loop for y below h collect
                          `(:container :id ,(intern (format nil "ROW-~A" y) :keyword)
                            :style (:display :flex :flex-direction :row)
                            :children ,(loop for x below w collect
                                             (let ((alive (eql 1 (aref grid y x))))
                                               (if alive
                                                   (let ((rgb (hsv->rgb hue 1.0 1.0)))
                                                     `(:container :id ,(intern (format nil "CELL-~A-~A" y x) :keyword)
                                                       :style (:bg-color ,rgb :width 1 :height 1)))
                                                   `(:container :id ,(intern (format nil "CELL-~A-~A" y x) :keyword)
                                                     :classes ("cell-dead"))))))))
       (:text :id :status :classes ("status-bar") :content ,status)))))

(defapplication game-of-life-app
  :root-viewport-id :gol-root-vp
  :initial-state-plist (%initial-state)
  :root-component-dsl '(:layout :id :gol-root)
  :update-fn 'app-update
  :view-fn 'game-of-life-view
  :subscriptions-fn (lambda (_model) (declare (ignore _model)) nil))

(defun run-game-of-life-app ()
  (log-info "Game of Life app registered. Launch via your runner (e.g., run.sh)."))
