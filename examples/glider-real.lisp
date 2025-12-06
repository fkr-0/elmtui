;;; Elmtui Glider Animation
;;; A glider moving from bottom-right to top-left, only destroying content where it passes

(uiop:define-package :elmtui.examples.glider
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-info)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.tea-state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.ui.widgets.layout #:defcomponent-dsl)
  (:import-from :elmtui.ui.widgets.panel #:defcomponent-dsl)
  (:import-from :elmtui.core.defaults #:default-keymap)
  (:export #:run-glider-animation))

(in-package :elmtui.examples.glider)

;;;===================================================================
;; Glider Animation Logic
;;;===================================================================

;; Glider patterns for Conway's Game of Life
(defparameter +glider-patterns+
  '(((1 0) (2 1) (0 2) (1 2) (2 2))    ; Phase 1: pointing up
    ((0 0) (1 1) (2 1) (0 2) (2 2))    ; Phase 2: pointing right
    ((2 0) (0 1) (1 1) (2 1) (2 2))    ; Phase 3: pointing down
    ((0 0) (0 1) (1 1) (2 1) (0 2))    ; Phase 4: pointing left
    ((1 0) (2 1) (0 2) (1 2) (2 2))))   ; Phase 5: back to phase 1

(defparameter +terminal-size+ '(80 24))

(defun get-glider-phase (phase)
  "Get glider pattern for current phase."
  (nth (mod phase (length +glider-patterns+)) +glider-patterns+))

(defun get-glider-bounds (pattern)
  "Get bounding box of glider pattern."
  (let ((xs (mapcar #'first pattern))
        (ys (mapcar #'second pattern)))
    (list (1+ (- (apply #'max xs) (apply #'min xs)))
          (1+ (- (apply #'max ys) (apply #'min ys))))))

;;;===================================================================
;; Animation State Management
;;;===================================================================

(defun make-initial-glider-state ()
  "Create initial animation state."
  `(:position (,(1- (first +terminal-size+)) . ,(1- (second +terminal-size+))) ; Start bottom-right
    :velocity (-1 . -1)  ; Move up-left
    :phase 0             ; Current glider phase
    :frame-count 0       ; Animation frame counter
    :speed 2             ; Move every 2 frames
    :trail '()           ; Previous positions for trail effect
    :max-trail-length 8  ; How many trail cells to keep
    :tick-interval 0.05)) ; Animation speed in seconds

(defun update-glider-position (position velocity)
  "Update glider position and handle boundary collisions."
  (let* ((new-pos (cons (+ (car position) (car velocity))
                        (+ (cdr position) (cdr velocity))))
         (term-w (first +terminal-size+))
         (term-h (second +terminal-size+))
         (new-velocity velocity))

    ;; Check boundaries and bounce
    (cond
      ((<= (car new-pos) 0) ; Hit left edge
       (setf (car new-velocity) 1) ; Reverse x velocity
       (setf (car new-pos) 1))
      ((>= (car new-pos) term-w) ; Hit right edge
       (setf (car new-velocity) -1) ; Reverse x velocity
       (setf (car new-pos) (1- term-w)))
      ((<= (cdr new-pos) 0) ; Hit top edge
       (setf (cdr new-velocity) 1) ; Reverse y velocity
       (setf (cdr new-pos) 1))
      ((>= (cdr new-pos) term-h) ; Hit bottom edge
       (setf (cdr new-velocity) -1) ; Reverse y velocity
       (setf (cdr new-pos) (1- term-h))))

    (values new-pos new-velocity)))

(defun update-glider-app (message app-state)
  "Update glider animation state."
  (let ((frame-count (state-ref app-state :frame-count 0))
        (speed (state-ref app-state :speed 2))
        (position (state-ref app-state :position (cons 0 0)))
        (velocity (state-ref app-state :velocity (cons 0 0)))
        (phase (state-ref app-state :phase 0))
        (trail (state-ref app-state :trail '()))
        (max-trail (state-ref app-state :max-trail-length 8)))

    (case (first message)
      ;; Animation tick
      (:tick
       (let ((new-frame-count (1+ frame-count)))
         (if (zerop (mod new-frame-count speed))
             ;; Update position on this frame
             (multiple-value-bind (new-pos new-vel)
                 (update-glider-position position velocity)
               (let ((new-trail (cons position (subseq trail 0 (min max-trail (length trail))))))
                 (make-update-result
                   :state `(:position ,new-pos
                            :velocity ,new-vel
                            :phase ,(1+ phase)
                            :frame-count ,new-frame-count
                            :trail ,new-trail
                            :max-trail-length ,max-trail
                            :tick-interval ,(state-ref app-state :tick-interval 0.05)))))
             ;; Just increment frame count and phase
             (make-update-result
               :state `(:position ,position
                        :velocity ,velocity
                        :phase ,(1+ phase)
                        :frame-count ,new-frame-count
                        :trail ,trail
                        :max-trail-length ,max-trail
                        :tick-interval ,(state-ref app-state :tick-interval 0.05))))))

      ;; HJKL navigation commands
      (:move-left
       (make-update-result
         :state (plist-alist (append (alist-plist app-state) `(:velocity (-1 . 0))))))

      (:move-down
       (make-update-result
         :state (plist-alist (append (alist-plist app-state) `(:velocity (0 . 1))))))

      (:move-up
       (make-update-result
         :state (plist-alist (append (alist-plist app-state) `(:velocity (0 . -1))))))

      (:move-right
       (make-update-result
         :state (plist-alist (append (alist-plist app-state) `(:velocity (1 . 0))))))

      ;; Speed controls
      (:speed-up
       (make-update-result
         :state (plist-alist (append (alist-plist app-state)
                                     `(:speed ,(max 1 (1- speed)))))))

      (:speed-down
       (make-update-result
         :state (plist-alist (append (alist-plist app-state)
                                     `(:speed ,(min 10 (1+ speed)))))))

      ;; Trail controls
      (:longer-trail
       (make-update-result
         :state (plist-alist (append (alist-plist app-state)
                                     `(:max-trail-length ,(min 20 (1+ max-trail)))))))

      (:shorter-trail
       (make-update-result
         :state (plist-alist (append (alist-plist app-state)
                                     `(:max-trail-length ,(max 0 (1- max-trail)))))))

      (:clear-trail
       (make-update-result
         :state (plist-alist (append (alist-plist app-state) '(:trail ())))))

      ;; Key events
      (:key-event
       (let ((key (second message)))
         (case key
           ((:q :escape :c-c) (make-update-result :commands '(:quit)))
           (:h (update-glider-app '(:move-left) app-state))
           (:j (update-glider-app '(:move-down) app-state))
           (:k (update-glider-app '(:move-up) app-state))
           (:l (update-glider-app '(:move-right) app-state))
           (:+ (update-glider-app '(:speed-down) app-state))
           (:kp-add (update-glider-app '(:speed-down) app-state))
           (:-- (update-glider-app '(:speed-up) app-state))
           (:kp-subtract (update-glider-app '(:speed-up) app-state))
           (:t (update-glider-app '(:longer-trail) app-state))
           (:T (update-glider-app '(:shorter-trail) app-state))
           (:c (update-glider-app '(:clear-trail) app-state))
           (otherwise (make-update-result)))))

      ;; Screen resize
      (:screen-resized
       (destructuring-bind (&key width height) (second message)
         (setf (first +terminal-size+) width)
         (setf (second +terminal-size+) height)
         (make-update-result)))

      (otherwise (make-update-result)))))

;;;===================================================================
;; Glider View
;;;===================================================================

(defun render-glider-cell (text style)
  "Render a single glider cell with appropriate styling."
  `(:text :content ,text :style ,style))

(defun render-glider-at-position (position phase style)
  "Render glider pattern at given position."
  (let ((pattern (get-glider-phase phase))
        (cells '()))
    (dolist (cell pattern)
      (let ((x (+ (car position) (first cell)))
            (y (+ (cdr position) (second cell))))
        (when (and (>= x 0) (< x (first +terminal-size+))
                   (>= y 0) (< y (second +terminal-size+)))
          (push (render-glider-cell "█" style) cells))))
    (nreverse cells)))

(defun render-glider-view (app-state)
  "Render the glider animation view."
  (let* ((position (state-ref app-state :position (cons 0 0)))
         (phase (state-ref app-state :phase 0))
         (trail (state-ref app-state :trail '()))
         (velocity (state-ref app-state :velocity (cons 0 0)))
         (speed (state-ref app-state :speed 2))
         (trail-len (state-ref app-state :max-trail-length 8))
         (frame-count (state-ref app-state :frame-count 0))
         (glider-style '(:foreground :green :bold t))
         (trail-style '(:foreground :blue)))

    `(:root-viewport :id :main-viewport
      :anchor :top-left
      :children
      (;; Status bar at top
       (:panel :id :status-panel
        :style (:width ,(first +terminal-size+) :height 2)
        :children
        ((:text :id :info-text
          :content ,(format nil "Pos: ~D,~D | Vel: ~D,~D | Speed: ~D | Trail: ~D | Frame: ~D | hjkl:dir +/-:speed q:quit"
                          (car position) (cdr position)
                          (car velocity) (cdr velocity)
                          speed
                          trail-len
                          frame-count))
         (:text :id :velocity-indicator
          :content ,(format nil "→~A↓~A←~A↑"
                         (if (= (car velocity) 1) "" " ")
                         (if (= (cdr velocity) 1) "" " ")
                         (if (= (car velocity) -1) "" " ")
                         (if (= (cdr velocity) -1) "" " "))
          :style (:foreground :cyan))))

       ;; Trail cells (rendered first so glider appears on top)
       ,@(when trail
           (mapcar (lambda (trail-pos trail-phase)
                     `(:panel :id ,(intern (format nil "TRAIL-~A-~A" (car trail-pos) (cdr trail-pos)))
                       :style (:position (:left ,(car trail-pos) :top ,(cdr trail-pos)))
                       :children ,(render-glider-at-position trail-pos (+ trail-phase (length trail)) trail-style)))
                   trail
                   (iota (length trail))))

       ;; Current glider position
       (:panel :id :glider-panel
        :style (:position (:left ,(car position) :top ,(cdr position)))
        :children ,(render-glider-at-position position phase glider-style))))))

(defun view-glider-app (app-state)
  "Main view function for glider application."
  (render-glider-view app-state))

;;;===================================================================
;; Glider Application
;;;===================================================================

(elmtui.app:defapplication glider-animation
  :initial-state-plist (make-initial-glider-state)
  :update-fn #'update-glider-app
  :view-fn #'view-glider-app
  :keymap (default-keymap)
  :subscriptions-fn (lambda (model)
                      ;; Subscribe to timer ticks for animation
                      `(:timer (:interval ,(state-ref model :tick-interval 0.05)
                               :message (:tick)))))

;;;===================================================================
;; Run the Animation
;;;===================================================================

(defun run-glider-animation ()
  "Run the glider animation."
  (format t "~%Elmtui Glider Animation~%")
  (format t "Watch the glider move around the terminal!~%")
  (format t "It bounces off edges and leaves a trail.~%~%")
  (format t "Controls:~%")
  (format t "  hjkl  - Change direction (left/down/up/right)~%")
  (format t "  +/-   - Speed control (slower/faster)~%")
  (format t "  t/T   - Trail length (longer/shorter)~%")
  (format t "  c     - Clear trail~%")
  (format t "  q     - Quit~%~%")

  (elmtui.app:run-application 'glider-animation))

;;;===================================================================
;; Entry Point
;;;===================================================================

(defun main ()
  "Main entry point for glider animation example."
  (run-glider-animation))

;; Uncomment to run when loaded:
;; (main)