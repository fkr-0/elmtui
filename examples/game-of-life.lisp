(uiop:define-package :elmtui.examples.game-of-life
  (:use :cl :alexandria :log4cl)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.ui.widgets.utils
                #:widget-focused-p #:defwidget-view)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.runtime #:def-elm-app #:run-app)
  (:import-from :elmtui.style-lib.rule #:defrule)
  (:import-from :elmtui.style-lib.sheet #:defstylesheet)
  (:import-from :elmtui.state.update #:defupdate)
  (:export
   :main
   :run-game-of-life-app))

(in-package :elmtui.examples.game-of-life)

;;;-------------------------------------------------------------- 
;;; Stylesheet Definition 
;;;--------------------------------------------------------------
(defstylesheet game-of-life-stylesheet
  (defrule "cell-alive"
    :background-color (elmtui.style-lib.styles:rgb '(0 255 0))
    :width 1
    :height 1)
  (defrule "cell-dead"
    :background-color (elmtui.style-lib.styles:rgb '(0 0 0))
    :width 1
    :height 1)
  (defrule ".status-bar"
    :background-color (elmtui.style-lib.styles:rgb '(50 50 50))
    :color (elmtui.style-lib.styles:rgb '(255 255 255))
    :padding 1
    :height 1))

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

(defun app-init ()
  "Initializes the application model."
  (multiple-value-bind (width height)
      (elmtui.platform.api:get-terminal-dimensions)
    (let ((grid-width (max 10 (- width 2)))
          (grid-height (max 10 (- height 2))))
      (values
       ;; Initial application state
       (list :current-stylesheet game-of-life-stylesheet
             :grid (get-glider-pattern)
             :generation 0
             :running t
             :speed 5 ; updates per second
             :last-update-time (get-internal-real-time)
             :should-quit nil)
       ;; No initial commands
       nil))))

(defupdate app-update (app-state message)
  "Handles updates to the application state based on messages."
  (let ((grid (getf app-state :grid))
        (generation (getf app-state :generation))
        (running (getf app-state :running))
        (speed (getf app-state :speed))
        (last-update-time (getf app-state :last-update-time))
        (current-time (get-internal-real-time)))
    
    (cond
      ;; Handle tick messages for simulation updates
      ((eq message :tick)
       (if running
           (let ((time-delta (/ (- current-time last-update-time) 
                                internal-time-units-per-second)))
             (if (>= time-delta (/ 1 speed))
                 (values (list :grid (next-generation grid)
                               :generation (1+ generation)
                               :last-update-time current-time)
                         '((:delay 0.05 :tick)))
                 (values nil '((:delay 0.05 :tick)))))
           (values nil '((:delay 0.2 :tick)))))
      
      ;; Toggle running state with space
      ((and (listp message) (eq (first message) :key-event)
            (char= (third message) #\Space))
       (values (list :running (not running)) nil))
      
      ;; Increase speed with '+'
      ((and (listp message) (eq (first message) :key-event)
            (char= (third message) #\+))
       (values (list :speed (min 20 (+ speed 1))) nil))
      
      ;; Decrease speed with '-'
      ((and (listp message) (eq (first message) :key-event)
            (char= (third message) #\-))
       (values (list :speed (max 1 (- speed 1))) nil))
      
      ;; Reset with 'r'
      ((and (listp message) (eq (first message) :key-event)
            (char= (third message) #\r))
       (multiple-value-bind (width height)
           (elmtui.platform.api:get-terminal-dimensions)
         (let ((grid-width (max 10 (- width 2)))
               (grid-height (max 10 (- height 2))))
           (values (list :grid (make-random-grid grid-width grid-height)
                         :generation 0)
                   nil))))
      
      ;; Quit with 'q'
      ((and (listp message) (eq (first message) :key-event)
            (char= (third message) #\q))
       (values (list :should-quit t) nil))
      
      ;; Handle struct-based key events
      ((typep message 'elmtui.core.event-types:key-event)
       (let ((key (elmtui.core.event-types:key-event-key message))
             (char (elmtui.core.event-types:key-event-char message)))
         (cond
           ((char= char #\Space)
            (values (list :running (not running)) nil))
           ((char= char #\+)
            (values (list :speed (min 20 (+ speed 1))) nil))
           ((char= char #\-)
            (values (list :speed (max 1 (- speed 1))) nil))
           ((char= char #\r)
            (multiple-value-bind (width height)
                (elmtui.platform.api:get-terminal-dimensions)
              (let ((grid-width (max 10 (- width 2)))
                    (grid-height (max 10 (- height 2))))
                (values (list :grid (make-random-grid grid-width grid-height)
                              :generation 0)
                        nil))))
           ((char= char #\q)
            (values (list :should-quit t) nil))
           (t (values nil nil)))))
      
      ;; Default: no state change
      (t (values nil (when (not (getf app-state :should-quit)) 
                       '((:delay 0.05 :tick))))))))

(defun game-of-life-view (app-state dispatch-fn)
  "Renders the Game of Life grid and status bar."
  (let ((grid (getf app-state :grid))
        (generation (getf app-state :generation))
        (running (getf app-state :running))
        (speed (getf app-state :speed)))
    
    (multiple-value-bind (term-width term-height)
        (elmtui.platform.api:get-terminal-dimensions)
      
      (let* ((grid-height (array-dimension grid 0))
             (grid-width (array-dimension grid 1))
             (status-text (format nil " Gen: ~A | ~A | Speed: ~A | Space: Toggle | +/-: Speed | r: Reset | q: Quit"
                                  generation
                                  (if running "Running" "Paused")
                                  speed)))
        
        ;; Main container
        (make-styled-node
         :type :container
         :props (list :id :game-of-life-container
                      :direction :vertical
                      :height :fill
                      :width :fill)
         :children 
         (list
          ;; Grid display
          (make-styled-node
           :type :container
           :props (list :id :grid-container
                        :direction :vertical
                        :height (- term-height 1)  ; Leave space for status bar
                        :width term-width)
           :children
           (loop for y below grid-height collect
                (make-styled-node
                 :type :container
                 :props (list :id (intern (format nil "ROW-~A" y) :keyword)
                              :direction :horizontal)
                 :children
                 (loop for x below grid-width collect
                      (make-styled-node
                       :type :container
                       :props (list :id (intern (format nil "CELL-~A-~A" y x) :keyword)
                                    :classes (if (= (aref grid y x) 1)
                                               "cell-alive"
                                               "cell-dead"))
                       :children nil)))))
          
          ;; Status bar
          (make-styled-node
           :type :text
           :props (list :id :status-bar
                        :classes "status-bar"
                        :text status-text))))))))

(def-elm-app game-of-life-app
  :init #'app-init
  :update #'app-update
  :view #'game-of-life-view)

(defun main ()
  "Run the Game of Life application."
  (elmtui.runtime:run-app :app-name 'game-of-life-app))

(defun run-game-of-life-app ()
  "Run the Game of Life application."
  (main))
