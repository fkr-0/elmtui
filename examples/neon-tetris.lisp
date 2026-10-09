;;;; Four-shape falling-block game, ported from nilmsp-tea/poc-apps/tetris.nl.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :elmtui.examples.neon-kit)
    (load (merge-pathnames #P"neon-kit.lisp"
                           (or *load-truename* *compile-file-truename*)))))
(uiop:define-package :elmtui.examples.neon-tetris
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:state-ref #:make-update-result)
  (:import-from :elmtui.examples.neon-kit
                #:pressed-p #:quit-message-p #:screen #:line)
  (:export #:run-neon-tetris #:tetris-update #:tetris-view
           #:initial-state #:piece-cells #:collision-p #:clear-rows))
(in-package :elmtui.examples.neon-tetris)

(defconstant +well-width+ 10)
(defconstant +well-height+ 16)

(defun empty-well ()
  (map 'vector (lambda (_) (declare (ignore _))
                 (make-string +well-width+ :initial-element #\.))
       (make-list +well-height+)))

(defun initial-state ()
  (list :well (empty-well) :x 4 :y 0 :shape 0 :rot 0
        :lines 0 :piece-id 0 :ended nil :should-quit nil))

(defun %patch (&rest pairs)
  (make-update-result
   :patches (loop for (name value) on pairs by #'cddr
                  collect (list (list name) value))))

(defun piece-cells (shape rot)
  "Return local cell coordinates for O, I, T or L (two orientations)."
  (case shape
    (0 '((0 0) (1 0) (0 1) (1 1)))
    (1 (if (zerop rot)
           '((1 0) (1 1) (1 2) (1 3))
           '((0 1) (1 1) (2 1) (3 1))))
    (2 (if (zerop rot)
           '((1 0) (0 1) (1 1) (2 1))
           '((1 0) (0 1) (1 1) (1 2))))
    (3 (if (zerop rot)
           '((0 0) (0 1) (1 1) (2 1))
           '((0 0) (0 1) (0 2) (1 2))))
    (otherwise (error "Invalid tetromino shape: ~S" shape))))

(defun collision-p (well shape rot x y)
  (some (lambda (cell)
          (destructuring-bind (dx dy) cell
            (let ((cx (+ x dx)) (cy (+ y dy)))
              (or (< cx 0) (>= cx +well-width+)
                  (>= cy +well-height+)
                  (and (>= cy 0)
                       (char= (char (aref well cy) cx) #\#))))))
        (piece-cells shape rot)))

(defun clear-rows (well)
  "Return a new well and the count of cleared rows, top padded with empties."
  (let* ((kept (loop for row across well
                     unless (every (lambda (ch) (char= ch #\#)) row)
                       collect (copy-seq row)))
         (cleared (- +well-height+ (length kept))))
    (values (concatenate 'vector
                         (map 'vector (lambda (_) (declare (ignore _))
                                        (make-string +well-width+
                                                     :initial-element #\.))
                              (make-list cleared))
                         (coerce kept 'vector))
            cleared)))

(defun %lock-piece (state)
  (let* ((well (map 'vector #'copy-seq (state-ref state :well)))
         (shape (state-ref state :shape))
         (rot (state-ref state :rot))
         (x (state-ref state :x))
         (y (state-ref state :y)))
    (dolist (cell (piece-cells shape rot))
      (destructuring-bind (dx dy) cell
        (let ((cx (+ x dx)) (cy (+ y dy)))
          (when (and (<= 0 cx) (< cx +well-width+)
                     (<= 0 cy) (< cy +well-height+))
            (setf (char (aref well cy) cx) #\#)))))
    (multiple-value-bind (next-well cleared) (clear-rows well)
      (let* ((next-id (1+ (state-ref state :piece-id)))
             (next-shape (mod next-id 4)))
        (%patch :well next-well :lines (+ cleared (state-ref state :lines))
                :piece-id next-id :shape next-shape :rot 0 :x 4 :y 0
                :ended (collision-p next-well next-shape 0 4 0))))))

(defun %fall (state)
  (if (state-ref state :ended)
      (make-update-result)
      (if (collision-p (state-ref state :well)
                       (state-ref state :shape) (state-ref state :rot)
                       (state-ref state :x) (1+ (state-ref state :y)))
          (%lock-piece state)
          (%patch :y (1+ (state-ref state :y))))))

(defun %move (state dx)
  (let ((x (+ dx (state-ref state :x))))
    (if (collision-p (state-ref state :well)
                     (state-ref state :shape) (state-ref state :rot)
                     x (state-ref state :y))
        (make-update-result)
        (%patch :x x))))

(defun %rotate (state)
  (when (zerop (state-ref state :shape))
    (return-from %rotate (make-update-result)))
  (let ((new-rot (- 1 (state-ref state :rot))))
    (if (collision-p (state-ref state :well) (state-ref state :shape)
                     new-rot (state-ref state :x) (state-ref state :y))
        (make-update-result)
        (%patch :rot new-rot))))

(defun tetris-update (message state)
  (cond
    ((or (quit-message-p message)
         (pressed-p message :char #\q :keys '(:escape)))
     (%patch :should-quit t))
    ((pressed-p message :char #\r)
     (apply #'%patch (initial-state)))
    ((state-ref state :ended) (make-update-result))
    ((pressed-p message :char #\a :keys '(:left :arrow-left)) (%move state -1))
    ((pressed-p message :char #\d :keys '(:right :arrow-right)) (%move state 1))
    ((pressed-p message :char #\w :keys '(:up :arrow-up)) (%rotate state))
    ((pressed-p message :char #\s :keys '(:down :arrow-down)) (%fall state))
    ((or (eq message :tick)
         (and (consp message) (eq (first message) :tick))) (%fall state))
    (t (make-update-result))))

(defun %ghost-y (state)
  (let ((landing (state-ref state :y))
        (well (state-ref state :well))
        (shape (state-ref state :shape))
        (rot (state-ref state :rot))
        (x (state-ref state :x)))
    (unless (state-ref state :ended)
      (loop until (collision-p well shape rot x (1+ landing))
            do (incf landing)))
    landing))

(defun %piece-at-p (shape rot x y ox oy)
  (member (list (- x ox) (- y oy)) (piece-cells shape rot) :test #'equal))

(defun %well-row (state row ghost-y)
  (let* ((well (state-ref state :well))
         (shape (state-ref state :shape))
         (rot (state-ref state :rot))
         (x (state-ref state :x))
         (y (state-ref state :y))
         (ended (state-ref state :ended)))
    (with-output-to-string (out)
      (dotimes (col +well-width+)
        (write-string
         (cond ((char= (char (aref well row) col) #\#) "██")
               ((and (not ended) (%piece-at-p shape rot col row x y)) "██")
               ((and (not ended) (%piece-at-p shape rot col row x ghost-y)) "░░")
               (t "··"))
         out)))))

(defparameter +telemetry+
  #("│ STACK  /  IN PROGRESS     │"
    "│                           │"
    "│ A / D   SLIDE             │"
    "│ W       ROTATE            │"
    "│ S       SOFT DROP         │"
    "│ Q       QUIT              │"
    "│                           │"
    "│ ───────────────────────── │"
    "│                           │"
    "│ ▓  SOLID PIECE            │"
    "│ ░  GHOST LANDING          │"
    "│                           │"
    "│ FOUR SHAPES / O I T L     │"
    "│                           │"
    "│ 140ms GRAVITY CLOCK       │"
    "│ R       RESET             │"))

(defun tetris-view (state)
  (let ((ghost-y (%ghost-y state)))
    (screen
     :neon-tetris-root
     (append
      (list (line " TETRIS  /  STACK LAB                           ARCADE 02  ◉ LIVE"
                  :title)
            (line (format nil " 10 × 16 GRID    LINES ~3,'0D    SHAPE ~D    PHASE ~D"
                          (state-ref state :lines)
                          (state-ref state :shape)
                          (state-ref state :piece-id)) :accent)
            (line " ╔════════════════════╗   ╭─ STATUS / TELEMETRY ──────╮"
                  :border))
      (loop for y below +well-height+
            collect (line (format nil " ║~A║   ~A"
                                  (%well-row state y ghost-y) (aref +telemetry+ y))
                          (if (= y (state-ref state :y)) :signal :body)))
      (list (line " ╚════════════════════╝   ╰────────────────────────────╯"
                  :border)
            (line (if (state-ref state :ended)
                      " GAME OVER   ◆   Press R to restart"
                      " Four-shape falling blocks   ●   Keep stacking")
                  (if (state-ref state :ended) :danger :signal))
            (line " ────────────────────────────────────────────────────────────"
                  :border)
            (line " A/D  MOVE    W  ROTATE    S  DROP    R  RESET    Q  QUIT"
                  :footer)))
     :height 24)))

(defapplication neon-tetris-app
  :root-viewport-id :neon-tetris-vp
  :root-component-dsl '(:root-viewport :id :neon-tetris-vp
                        :anchor :below-cursor :width 74 :height 24
                        :blank-on-exit t :child-dsl-spec (:view nil))
  :initial-state-fn #'initial-state
  :update-fn #'tetris-update
  :view-fn #'tetris-view
  :subscriptions-fn (lambda (_state)
                      (declare (ignore _state))
                      '(:timer (:interval 0.14 :message (:tick)))))

(defun run-neon-tetris (&key (backend-type :terminal))
  (run-neon-tetris-app :platform backend-type))
