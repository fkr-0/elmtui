;;;; Two-player Pong, ported from nilmsp-tea/poc-apps/pong.nl.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :elmtui.examples.neon-kit)
    (load (merge-pathnames #P"neon-kit.lisp"
                           (or *load-truename* *compile-file-truename*)))))
(uiop:define-package :elmtui.examples.neon-pong
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:state-ref #:make-update-result)
  (:import-from :elmtui.examples.neon-kit
                #:pressed-p #:quit-message-p #:screen #:line)
  (:export #:run-neon-pong #:pong-update #:pong-view #:initial-state))
(in-package :elmtui.examples.neon-pong)

(defconstant +width+ 34)
(defconstant +height+ 12)
(defconstant +paddle-size+ 3)

(defun initial-state ()
  (list :ball-x 17 :ball-y 6 :dx 1 :dy 1 :left-y 4 :right-y 4
        :left-score 0 :right-score 0 :served t :should-quit nil))

(defun %patch (&rest pairs)
  (make-update-result
   :patches (loop for (name value) on pairs by #'cddr
                  collect (list (list name) value))))

(defun %clamp (n lo hi)
  (max lo (min hi n)))

(defun %step (state)
  (unless (state-ref state :served)
    (return-from %step (make-update-result)))
  (let* ((x (state-ref state :ball-x))
         (y (state-ref state :ball-y))
         (dx (state-ref state :dx))
         (dy (state-ref state :dy))
         (nx (+ x dx))
         (ny (+ y dy))
         (left-y (state-ref state :left-y))
         (right-y (state-ref state :right-y)))
    (when (or (< ny 0) (>= ny +height+))
      (setf dy (- dy) ny (+ y dy)))
    (cond
      ((and (<= nx 0) (< dx 0) (<= left-y ny (+ left-y (1- +paddle-size+))))
       (setf dx 1 nx 1))
      ((and (>= nx (1- +width+)) (> dx 0)
            (<= right-y ny (+ right-y (1- +paddle-size+))))
       (setf dx -1 nx (- +width+ 2))))
    (cond ((< nx 0)
           (%patch :right-score (1+ (state-ref state :right-score))
                   :ball-x 17 :ball-y 6 :served nil))
          ((>= nx +width+)
           (%patch :left-score (1+ (state-ref state :left-score))
                   :ball-x 17 :ball-y 6 :served nil))
          (t (%patch :ball-x nx :ball-y ny :dx dx :dy dy)))))

(defun pong-update (message state)
  (cond
    ((or (quit-message-p message)
         (pressed-p message :char #\q :keys '(:escape)))
     (%patch :should-quit t))
    ((pressed-p message :char #\w)
     (%patch :left-y (%clamp (1- (state-ref state :left-y)) 0
                             (- +height+ +paddle-size+))))
    ((pressed-p message :char #\s)
     (%patch :left-y (%clamp (1+ (state-ref state :left-y)) 0
                             (- +height+ +paddle-size+))))
    ((pressed-p message :char #\i)
     (%patch :right-y (%clamp (1- (state-ref state :right-y)) 0
                              (- +height+ +paddle-size+))))
    ((pressed-p message :char #\k)
     (%patch :right-y (%clamp (1+ (state-ref state :right-y)) 0
                              (- +height+ +paddle-size+))))
    ((pressed-p message :char #\Space) (%patch :served t))
    ((or (eql message :tick)
         (and (consp message) (eq (first message) :tick)))
     (%step state))
    (t (make-update-result))))

(defun %rally-line (state y)
  (let ((body (make-string +width+ :initial-element #\Space))
        (x (state-ref state :ball-x)))
    (setf (char body 17) #\┊)
    (when (<= (state-ref state :left-y) y
              (+ (state-ref state :left-y) (1- +paddle-size+)))
      (setf (char body 0) #\▓))
    (when (<= (state-ref state :right-y) y
              (+ (state-ref state :right-y) (1- +paddle-size+)))
      (setf (char body (1- +width+)) #\▓))
    (when (and (= y (state-ref state :ball-y))
               (<= 0 x) (< x +width+))
      (setf (char body x) #\●))
    body))

(defparameter +telemetry+
  #("│ ROUND / 01                │"
    "│                           │"
    "│ W / S    PLAYER ONE       │"
    "│ I / K    PLAYER TWO       │"
    "│                           │"
    "│ SPACE    SERVE            │"
    "│ Q        EXIT             │"
    "│                           │"
    "│ ●  REAL-TIME PHYSICS      │"
    "│ ◉  LOCAL MULTIPLAYER      │"
    "│                           │"
    "│ 140ms GAME CLOCK          │"))

(defun pong-view (state)
  (screen
   :neon-pong-root
   (append
    (list (line " PONG  /  NEON CIRCUIT                          ARCADE 01  ● LIVE" :title)
          (line (format nil " PLAYER 01   ~2,'0D          VERSUS           ~2,'0D   PLAYER 02"
                        (state-ref state :left-score)
                        (state-ref state :right-score)) :accent)
          (line (format nil " ╭~A╮  ╭ MATCH DATA ───────────────╮"
                        (make-string +width+ :initial-element #\─)) :border))
    (loop for y below +height+
          collect (line (format nil " │~A│  ~A"
                                (%rally-line state y) (aref +telemetry+ y))
                        (if (= y (state-ref state :ball-y)) :signal :body)))
    (list
     (line (format nil " ╰~A╯  ╰────────────────────────────╯"
                   (make-string +width+ :initial-element #\─)) :border)
     (line (if (state-ref state :served)
               " Match underway   ●   Rally in progress"
               " Press SPACE to serve   ◆   Ready for kickoff") :signal)
     (line " ◉ NO NETWORK   ◆ NO IDLE REDRAWS   ● LOCAL MATCH ENGINE" :muted)
     (line " PICK UP THE PACE  /  BUILD YOUR STREAK" :accent)
     (line " ─────────────────────────────────────────────────────────────" :border)
     (line " W/S  LEFT    I/K  RIGHT    SPACE  SERVE    Q  QUIT" :footer)
     (line " SESSION 01   •   PLAYER VS PLAYER   •   140ms PHYSICS" :muted)))
   :height 23))

(defapplication neon-pong-app
  :root-viewport-id :neon-pong-vp
  :root-component-dsl '(:root-viewport :id :neon-pong-vp
                        :anchor :below-cursor :width 74 :height 23
                        :blank-on-exit t :child-dsl-spec (:view nil))
  :initial-state-fn #'initial-state
  :update-fn #'pong-update
  :view-fn #'pong-view
  :subscriptions-fn (lambda (_state)
                      (declare (ignore _state))
                      '(:timer (:interval 0.14 :message (:tick)))))

(defun run-neon-pong (&key (backend-type :terminal))
  (run-neon-pong-app :platform backend-type))
