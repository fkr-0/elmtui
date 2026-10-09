(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :elmtui.examples.neon-kit)
    (load (merge-pathnames #P"neon-kit.lisp" (or *load-truename* *compile-file-truename*)))))
(uiop:define-package :elmtui.examples.neon-life
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:state-ref #:make-update-result)
  (:import-from :elmtui.examples.neon-kit #:pressed-p #:quit-message-p #:screen #:line)
  (:export #:run-neon-life #:initial-state #:life-update #:life-view
           #:next-generation #:population #:glider-grid #:count-neighbors))
(in-package :elmtui.examples.neon-life)
(defconstant +width+ 36)
(defconstant +height+ 16)
(defun glider-grid ()
  (let ((g (make-array (list +height+ +width+) :element-type 'bit :initial-element 0)))
    (dolist (cell '((3 2) (4 3) (2 4) (3 4) (4 4) (23 8) (24 9) (22 10) (23 10) (24 10) (13 11) (14 11) (15 11)))
      (setf (aref g (second cell) (first cell)) 1))
    g))
(defun count-neighbors (grid x y)
  (let ((n 0) (w (array-dimension grid 1)) (h (array-dimension grid 0)))
    (dolist (dy '(-1 0 1))
      (dolist (dx '(-1 0 1))
        (unless (and (zerop dx) (zerop dy))
          (incf n (aref grid (mod (+ y dy) h) (mod (+ x dx) w))))))
    n))
(defun next-generation (grid)
  (let* ((h (array-dimension grid 0)) (w (array-dimension grid 1))
         (next (make-array (list h w) :element-type 'bit :initial-element 0)))
    (dotimes (y h)
      (dotimes (x w)
        (let ((n (count-neighbors grid x y)))
          (setf (aref next y x)
                (if (or (= n 3) (and (= n 2) (= 1 (aref grid y x)))) 1 0)))))
    next))
(defun population (grid)
  (loop for y below (array-dimension grid 0)
        sum (loop for x below (array-dimension grid 1) count (= (aref grid y x) 1))))
(defun initial-state ()
  (list :grid (glider-grid) :generation 0 :running t :period 0.18 :should-quit nil))
(defun %patch (&rest pairs)
  (make-update-result
   :patches (loop for (name value) on pairs by #'cddr
                  collect (list (list name) value))))
(defun %tick-p (msg)
  (or (eq msg :tick) (and (consp msg) (eq (first msg) :tick))))
(defun %step (state)
  (%patch :grid (next-generation (state-ref state :grid))
          :generation (1+ (state-ref state :generation 0))))
(defun life-update (message state)
  (cond
    ((or (quit-message-p message) (pressed-p message :char #\q :keys '(:escape)))
     (%patch :should-quit t))
    ((pressed-p message :char #\r) (%patch :grid (glider-grid) :generation 0 :running t))
    ((or (pressed-p message :char #\Space) (pressed-p message :char #\p))
     (%patch :running (not (state-ref state :running t))))
    ((pressed-p message :char #\n)
     (if (state-ref state :running t) (make-update-result) (%step state)))
    ((pressed-p message :char #\+)
     (%patch :period (max 0.06 (- (state-ref state :period 0.18) 0.03))))
    ((pressed-p message :char #\-)
     (%patch :period (min 0.8 (+ (state-ref state :period 0.18) 0.03))))
    ((%tick-p message)
     (if (state-ref state :running t) (%step state) (make-update-result)))
    (t (make-update-result))))
(defparameter +telemetry+
  #("│ OBSERVATORY / 01          " "│                           "
    "│ TWO DRIFTING GLIDERS      " "│ ONE PERIOD-2 BLINKER      "
    "│                           " "│ B3 / S23 RULESET         "
    "│ TOROIDAL TOPOLOGY        " "│                           "
    "│ █  LIVE ORGANISM         " "│ ·  DORMANT CELL          "
    "│                           " "│ 36 × 16 CELL MATRIX      "
    "│                           " "│ DIFFERENTIAL RENDER      "
    "│                           " "│ CONWAY / IN MOTION       "))
(defun %grid-row (grid y)
  (coerce (loop for x below (array-dimension grid 1)
                collect (if (= 1 (aref grid y x)) #\█ #\·)) 'string))
(defun life-view (state)
  (let* ((grid (state-ref state :grid))
         (generation (state-ref state :generation 0))
         (running (state-ref state :running t))
         (n (population grid))
         (period (state-ref state :period 0.18)))
    (screen :neon-life-root
      (append
       (list
        (line " LIFE.EXE  /  NEON BIOSPHERE               SIMULATION 05  ●" :title)
        (line (format nil " GEN ~5,'0D    LIVE ~3,'0D    STATE ~A    CLOCK ~DMS"
                      generation n (if running "RUNNING" "PAUSED") (round (* 1000 period))) :accent)
        (line " ┌──────────────────────────────────────┐  ┌─ LIFE TELEMETRY ──────┐" :border))
       (loop for y below +height+
             collect (line (format nil " │~A│  ~A" (%grid-row grid y) (aref +telemetry+ y))
                           (if (zerop (mod y 3)) :signal :body)))
       (list
        (line " └──────────────────────────────────────┘  └───────────────────────┘" :border)
        (line (if running " ● CELLULAR REACTIONS ACTIVE   /   SPACE TO FREEZE"
                         " ◉ FROZEN IN TIME              /   N TO STEP") :signal)
        (line " ────────────────────────────────────────────────────────────────" :border)
        (line " SPACE/P PAUSE   N STEP   +/- SPEED   R RESEED   Q/ESC EXIT" :footer)
        (line " TOROIDAL GRID   •   DIFFERENTIAL DRAW   •   LOCAL SIMULATION" :muted)))
      :width 74 :height 24)))
(defapplication neon-life-app
  :root-viewport-id :neon-life-vp
  :root-component-dsl '(:root-viewport :id :neon-life-vp
                        :anchor :below-cursor :width 74 :height 24
                        :blank-on-exit t :child-dsl-spec (:view nil))
  :initial-state-fn #'initial-state
  :update-fn #'life-update
  :view-fn #'life-view
  :subscriptions-fn (lambda (state)
                      (when (state-ref state :running t)
                        (list :timer (list :interval (state-ref state :period 0.18)
                                           :message (list :tick))))))
(defun run-neon-life (&key (backend-type :terminal))
  (run-neon-life-app :platform backend-type))
