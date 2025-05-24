;;;===============================================================
;;; File: src/view/animation.lisp
;;; Animation Framework for ELMTUI
;;;===============================================================
(uiop:define-package :elmtui.view.animation
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:import-from :cleve-elm.channel
   :make-channel :-> :<- :select :gogo
                :channel-take! :channel-put!)
  (:import-from :elmtui.core.async
                #:spawn-worker
                #:cmd-async)
  (:import-from :elmtui.core.event-async
                #:schedule-event
                #:schedule-repeating-event)
  (:export
   ;; Animation structure
   #:animation
   #:make-animation
   #:animation-id
   #:animation-start-time
   #:animation-duration
   #:animation-easing-fn
   #:animation-update-fn
   #:animation-complete-fn
   #:animation-progress
   #:animation-active-p

   ;; Animation system
   #:register-animation
   #:unregister-animation
   #:start-animation
   #:stop-animation
   #:process-animations

   ;; Animation creation functions
   #:create-animation
   #:create-transition
   #:create-sequence
   #:create-parallel

   ;; Easing functions
   #:linear-easing
   #:ease-in
   #:ease-out
   #:ease-in-out
   #:bounce
   #:elastic

   ;; Animation manager
   #:initialize-animation-system
   #:start-animation-system
   #:stop-animation-system))

(in-package :elmtui.view.animation)

;;;-----------------------------------------------------------------------------
;;; Animation Structure
;;;-----------------------------------------------------------------------------

(defstruct animation
  "Represents an animation that can be applied to a view."
  (id (gensym "ANIMATION-") :type symbol :read-only t)
  (start-time (get-universal-time) :type integer)
  (duration 1.0 :type float)
  (easing-fn #'identity :type function)
  (update-fn nil :type function)
  (complete-fn nil :type function)
  (progress 0.0 :type float)
  (active-p t :type boolean))

;;;-----------------------------------------------------------------------------
;;; Animation Registry
;;;-----------------------------------------------------------------------------

(defvar *animations* (make-hash-table :test 'eq)
  "Maps animation IDs to animation structures.")

(defun register-animation (animation)
  "Registers an animation to be processed by the animation system."
  (setf (gethash (animation-id animation) *animations*) animation)
  animation)

(defun unregister-animation (animation-or-id)
  "Removes an animation from the registry."
  (etypecase animation-or-id
    (animation (remhash (animation-id animation-or-id) *animations*))
    (symbol (remhash animation-or-id *animations*))))

(defun get-animation (id)
  "Returns the animation with the given ID, or NIL if not found."
  (gethash id *animations*))

;;;-----------------------------------------------------------------------------
;;; Animation Control
;;;-----------------------------------------------------------------------------

(defun start-animation (animation)
  "Starts or restarts an animation."
  (setf (animation-start-time animation) (get-universal-time))
  (setf (animation-progress animation) 0.0)
  (setf (animation-active-p animation) t)
  (register-animation animation)
  animation)

(defun stop-animation (animation-or-id)
  "Stops an animation without calling its complete function."
  (let ((anim (etypecase animation-or-id
                (animation animation-or-id)
                (symbol (get-animation animation-or-id)))))
    (when anim
      (setf (animation-active-p anim) nil)
      (unregister-animation anim))))

;;;-----------------------------------------------------------------------------
;;; Animation Processing
;;;-----------------------------------------------------------------------------

(defun process-animations (delta-time)
  "Processes all active animations, updating their progress.
   Should be called on each frame with the time elapsed since the last frame."
  (maphash
   (lambda (id animation)
     (when (animation-active-p animation)
       ;; Update progress
       (let* ((old-progress (animation-progress animation))
              (new-progress (min 1.0 (+ old-progress (/ delta-time (animation-duration animation)))))
              (eased-progress (funcall (animation-easing-fn animation) new-progress)))

         ;; Call update function
         (when (animation-update-fn animation)
           (funcall (animation-update-fn animation) eased-progress))

         ;; Update stored progress
         (setf (animation-progress animation) new-progress)

         ;; Check if complete
         (when (>= new-progress 1.0)
           (setf (animation-active-p animation) nil)
           (when (animation-complete-fn animation)
             (funcall (animation-complete-fn animation)))
           (remhash id *animations*)))))
   *animations*))

;;;-----------------------------------------------------------------------------
;;; Animation Creation
;;;-----------------------------------------------------------------------------

(defun create-animation (duration update-fn &key (easing-fn #'linear-easing) complete-fn)
  "Creates and registers a new animation.

   DURATION: Duration in seconds.
   UPDATE-FN: Function called on each frame with progress (0.0-1.0).
   EASING-FN: Optional easing function to transform progress.
   COMPLETE-FN: Optional function called when animation completes.

   Returns the animation structure."
  (let ((anim (make-animation :duration duration
                              :easing-fn easing-fn
                              :update-fn update-fn
                              :complete-fn complete-fn)))
    (register-animation anim)))

(defun create-transition (start-value end-value duration update-fn &key (easing-fn #'linear-easing) complete-fn)
  "Creates an animation that transitions between two values.

   START-VALUE: The initial value.
   END-VALUE: The final value.
   DURATION: Duration in seconds.
   UPDATE-FN: Function called on each frame with the interpolated value.
   EASING-FN: Optional easing function to transform progress.
   COMPLETE-FN: Optional function called when animation completes.

   Returns the animation structure."
  (let ((delta (- end-value start-value)))
    (create-animation
     duration
     (lambda (progress)
       (funcall update-fn (+ start-value (* delta progress))))
     :easing-fn easing-fn
     :complete-fn complete-fn)))

(defun create-sequence (animations &key complete-fn)
  "Creates an animation that runs a sequence of animations one after another.

   ANIMATIONS: A list of animations to run in sequence.
   COMPLETE-FN: Optional function called when the sequence completes.

   Returns a list of animations with the complete-fn of each set to start the next."
  (when animations
    ;; Calculate total duration
    (let ((total-duration 0))
      (dolist (anim animations)
        (incf total-duration (animation-duration anim)))

      ;; Chain animations together
      (loop for (anim next) on animations
            for prev-complete-fn = (animation-complete-fn anim)
            when next
              do (setf (animation-complete-fn anim)
                       (lambda ()
                         ;; Call previous complete-fn if any
                         (when prev-complete-fn
                           (funcall prev-complete-fn))
                         ;; Start next animation
                         (start-animation next))))

      ;; Set final complete-fn
      (when complete-fn
        (let ((final-anim (alexandria:lastcar animations))
              (final-prev-fn (animation-complete-fn (alexandria:lastcar animations))))
          (setf (animation-complete-fn final-anim)
                (lambda ()
                  ;; Call previous complete-fn if any
                  (when final-prev-fn
                    (funcall final-prev-fn))
                  ;; Call sequence complete-fn
                  (funcall complete-fn)))))

      ;; Return first animation (when started, it will chain to the rest)
      (first animations))))

(defun create-parallel (animations &key complete-fn)
  "Creates an animation that runs multiple animations in parallel.

   ANIMATIONS: A list of animations to run in parallel.
   COMPLETE-FN: Optional function called when all animations complete.

   Returns a new animation that manages the parallel execution."
  (when animations
    ;; Find the longest duration
    (let ((max-duration 0)
          (active-count (length animations)))

      ;; Find maximum duration among animations
      (dolist (anim animations)
        (when (> (animation-duration anim) max-duration)
          (setf max-duration (animation-duration anim))))

      ;; Create a counter for completed animations
      (let ((completed-mutex (bt:make-lock))
            (completed-count 0))

        ;; Wrap each animation's complete-fn to track completion
        (dolist (anim animations)
          (let ((orig-complete-fn (animation-complete-fn anim)))
            (setf (animation-complete-fn anim)
                  (lambda ()
                    ;; Call original complete-fn if any
                    (when orig-complete-fn
                      (funcall orig-complete-fn))

                    ;; Increment completed count
                    (bt:with-lock-held (completed-mutex)
                      (incf completed-count)

                      ;; If all animations are complete, call the group complete-fn
                      (when (and (= completed-count active-count) complete-fn)
                        (funcall complete-fn)))))))

        ;; Start all animations
        (dolist (anim animations)
          (start-animation anim))

        ;; Return the animations
        animations))))

;;;-----------------------------------------------------------------------------
;;; Easing Functions
;;;-----------------------------------------------------------------------------

(defun linear-easing (x)
  "Linear easing function. Input and output progress are the same."
  x)

(defun ease-in (x &optional (power 2))
  "Ease-in easing function. Starts slow and accelerates."
  (expt x power))

(defun ease-out (x &optional (power 2))
  "Ease-out easing function. Starts fast and decelerates."
  (- 1 (expt (- 1 x) power)))

(defun ease-in-out (x &optional (power 2))
  "Ease-in-out easing function. Starts slow, speeds up, then slows down again."
  (cond
    ((< x 0.5) (* 0.5 (expt (* 2 x) power)))
    (x (- 1 (* 0.5 (expt (* 2 (- 1 x)) power))))))

(defun bounce (x)
  "Bounce easing function. Simulates bouncing at the end."
  (let ((t2 (- 1 x)))
    (- 1 (* t2 t2 (+ 2.75 (* t2 t2 2.5))))))

(defun elastic (x)
  "Elastic easing function. Overshoots and bounces back."
  (let ((p 0.3)
        (s (* 0.3 0.25)))
    (- (* (expt 2 (* -10 x)) (sin (/ (* (- x s) 2 pi) p)))
       0.0001)))

;;;-----------------------------------------------------------------------------
;;; Animation System
;;;-----------------------------------------------------------------------------

(defvar *animation-channel* nil
  "Channel for animation system messages.")

(defvar *animation-worker* nil
  "Worker thread for animation processing.")

(defvar *animation-timer-id* nil
  "ID of the animation timer.")

(defvar *animation-system-active* nil
  "Flag indicating whether the animation system is active.")

(defun initialize-animation-system ()
  "Initializes the animation system."
  (log-info "Initializing animation system")
  (setf *animation-channel* (make-channel :capacity 10 :name "animation-channel")))

(defun start-animation-system (&key (fps 60))
  "Starts the animation processing system.
   FPS: Target frames per second for animation updates."
  (log-info "Starting animation system at ~A FPS" fps)

  ;; Initialize if needed
  (unless *animation-channel*
    (initialize-animation-system))

  ;; Set active flag
  (setf *animation-system-active* t)

  ;; Calculate update interval
  (let ((interval-ms (/ 1000 fps)))

    ;; Start worker thread
    (setf *animation-worker*
          (spawn-worker
           (lambda ()
             (animation-processing-loop interval-ms))
           :name "animation-processor"))

    ;; Start animation timer
    (schedule-repeating-event
     (list :animation-tick (get-internal-real-time))
     interval-ms
     nil)))

(defun stop-animation-system ()
  "Stops the animation processing system."
  (log-info "Stopping animation system")
  (when *animation-system-active*
    (setf *animation-system-active* nil)
    ;; The animation loop will exit on next iteration
    ))

(defun animation-processing-loop (interval-ms)
  "Main animation processing loop.
   INTERVAL-MS: Target interval between animation updates in milliseconds."
  (log-info "Animation processing loop started with interval ~A ms" interval-ms)

  (let ((last-time (get-internal-real-time)))
    ;; Process animations until stopped
    (loop while *animation-system-active* do
      ;; Wait for animation tick or timeout
      (let ((msg (channel-take! *animation-channel* :timeout 0.016))) ; 16ms ~ 60fps
        (when (and msg (consp msg) (eq (first msg) :animation-tick))
          (let* ((current-time (get-internal-real-time))
                 (delta-seconds (/ (- current-time last-time)
                                   internal-time-units-per-second)))

            ;; Process animations with the elapsed time
            (process-animations delta-seconds)

            ;; Update last time
            (setf last-time current-time)))))))
