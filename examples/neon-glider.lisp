(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :elmtui.examples.neon-kit)
    (load (merge-pathnames #P"neon-kit.lisp" (or *load-truename* *compile-file-truename*)))))
(uiop:define-package :elmtui.examples.neon-glider
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:state-ref #:make-update-result)
  (:import-from :elmtui.examples.neon-kit #:pressed-p #:quit-message-p #:screen #:line)
  (:export #:run-neon-glider #:initial-state #:glider-update #:glider-view #:bounce-step))
(in-package :elmtui.examples.neon-glider)
(defconstant +arena-width+ 44)
(defconstant +arena-height+ 13)
(defconstant +trail-length+ 8)
(defun initial-state ()
  (list :x 3 :y 9 :dx 1 :dy -1 :tick 0 :trail nil
        :running t :period 0.12 :should-quit nil))
(defun bounce-step (x y dx dy &optional (w +arena-width+) (h +arena-height+))
  (let ((nx (+ x dx)) (ny (+ y dy)))
    (when (or (< nx 0) (>= nx w))
      (setf dx (- dx) nx (+ x dx)))
    (when (or (< ny 0) (>= ny h))
      (setf dy (- dy) ny (+ y dy)))
    (values nx ny dx dy)))
(defun %patch (&rest pairs)
  (make-update-result
   :patches (loop for (name value) on pairs by #'cddr
                 collect (list (list name) value))))
(defun %tick-p (msg)
  (or (eq msg :tick) (and (consp msg) (eq (first msg) :tick))))
(defun %step (state)
  (let ((x (state-ref state :x 3))
        (y (state-ref state :y 9))
        (dx (state-ref state :dx 1))
        (dy (state-ref state :dy -1))
        (tick (state-ref state :tick 0))
        (trail (state-ref state :trail)))
    (multiple-value-bind (nx ny ndx ndy)
        (bounce-step x y dx dy)
      (%patch :x nx :y ny :dx ndx :dy ndy
              :tick (1+ tick)
              :trail (subseq (cons (list x y) trail)
                             0 (min +trail-length+ (1+ (length trail))))))))
(defun glider-update (message state)
  (cond
    ((or (quit-message-p message) (pressed-p message :char #\q :keys '(:escape)))
     (%patch :should-quit t))
    ((pressed-p message :char #\r)
     (apply #'%patch (initial-state)))
    ((or (pressed-p message :char #\Space) (pressed-p message :char #\p))
     (%patch :running (not (state-ref state :running t))))
    ((pressed-p message :char #\n)
     (if (state-ref state :running t) (make-update-result) (%step state)))
    ((pressed-p message :char #\+)
     (%patch :period (max 0.035 (- (state-ref state :period 0.12) 0.02))))
    ((pressed-p message :char #\-)
     (%patch :period (min 0.5 (+ (state-ref state :period 0.12) 0.02))))
    ((%tick-p message)
     (if (state-ref state :running t) (%step state) (make-update-result)))
    (t (make-update-result))))
(defparameter +telemetry+
  #("│ FLIGHT TRACK / 02         " "│                           "
    "│ ✦ PRIMARY SIGNAL         " "│ + COMET TRAIL            "
    "│ · BACKGROUND             " "│                           "
    "│ REFLECTION PHYSICS       " "│ EIGHT-FRAME MOTION TRAIL  "
    "│                           " "│ LIVE COORDINATE FEED      "
    "│ BOUNCING VECTOR          " "│                           "
    "│ TERMINAL GRAPHICS ONLY   "))
(defun %arena-line (state row)
  (let* ((x (state-ref state :x)) (y (state-ref state :y))
         (trail (state-ref state :trail))
         (text (make-string +arena-width+ :initial-element #\·)))
    (loop for (cx cy) in (reverse trail)
          for index from 0
          when (and (= cy row) (<= 0 cx) (< cx +arena-width+))
            do (setf (char text cx) (if (< index 3) #\+ #\•)))
    (when (= y row)
      (setf (char text x) #\✦))
    text))
(defun glider-view (state)
  (let* ((x (state-ref state :x)) (y (state-ref state :y))
         (dx (state-ref state :dx)) (dy (state-ref state :dy))
         (tick (state-ref state :tick))
         (running (state-ref state :running t))
         (period (state-ref state :period 0.12)))
    (screen :neon-glider-root
      (append
       (list
        (line " GLIDER  /  NEON FLIGHT CONTROL              ANIMATION 06  ✦" :title)
        (line (format nil " TICK ~5,'0D   POS ~2,'0D,~2,'0D   VELOCITY ~2D,~2D  ~A"
                      tick x y dx dy (if running "● MOVING" "◉ PAUSED")) :accent)
        (line " ┌──────────────────────────────────────────────┐  ┌─ SIGNAL ──────────┐" :border))
       (loop for row below +arena-height+
             collect (line (format nil " │~A│  ~A" (%arena-line state row)
                                   (aref +telemetry+ row))
                           (if (= row y) :signal :body)))
       (list
        (line " └──────────────────────────────────────────────┘  └─────────────────────┘" :border)
        (line " TRACKING / REFLECTIVE EDGES   •   COMET AFTERGLOW" :signal)
        (line (format nil " CLOCK ~DMS    VECTOR ~A / ~A    ~A"
                      (round (* 1000 period))
                      (if (plusp dx) "EAST" "WEST")
                      (if (plusp dy) "SOUTH" "NORTH")
                      (if running "RUNNING" "PAUSED")) :accent)
        (line " ────────────────────────────────────────────────────────────────" :border)
        (line " SPACE/P PAUSE   N STEP   +/- SPEED   R RESTART   Q/ESC QUIT" :footer)
        (line " DIFFERENTIAL DRAW    •    EVENT TIMERS    •    NATIVE TERMINAL" :muted)))
      :width 74 :height 23)))
(defapplication neon-glider-app
  :root-viewport-id :neon-glider-vp
  :root-component-dsl '(:root-viewport :id :neon-glider-vp
                        :anchor :below-cursor :width 74 :height 23
                        :blank-on-exit t :child-dsl-spec (:view nil))
  :initial-state-fn #'initial-state
  :update-fn #'glider-update
  :view-fn #'glider-view
  :subscriptions-fn (lambda (state)
                      (when (state-ref state :running t)
                        (list :timer (list :interval (state-ref state :period 0.12)
                                           :message (list :tick))))))
(defun run-neon-glider (&key (backend-type :terminal))
  (run-neon-glider-app :platform backend-type))
