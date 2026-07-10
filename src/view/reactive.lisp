;;;===============================================================
;;; File: src/view/reactive.lisp
;;; Reactive View System Integration with Async Infrastructure
;;;===============================================================
(uiop:define-package :elmtui.view.reactive
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info)
  (:import-from :cl-events.channel
                #:make-channel
                #:->
                #:<-)
  (:import-from :elmtui.state.api
                #:application-state)
  (:import-from :cl-state.observer
                #:add-observer
                #:remove-observer)
  (:import-from :elmtui.core.async
                #:spawn-worker
                #:cmd-async)
  (:import-from :elmtui.view.core
                #:ui-node)
  (:export
   #:create-reactive-view
   #:with-reactive-rendering
   #:view-invalidated-p
   #:invalidate-view
   #:register-view-dependency
   #:make-view-task
   ;; Animation helpers exposed for TEA-driven ticks
   #:create-animation
   #:process-animations
   #:linear-easing #:ease-in #:ease-out #:ease-in-out #:bounce #:elastic
   #:next-frame-cmd))
(in-package :elmtui.view.reactive)

;;;-----------------------------------------------------------------------------
;;; Reactive View Configuration
;;;-----------------------------------------------------------------------------

(defvar *active-view-channels* (make-hash-table :test 'equal)
  "Maps view IDs to their update channels.")

(defvar *view-dependencies* (make-hash-table :test 'equal)
  "Maps view IDs to their state dependencies.")

(defvar *view-invalidation-debounce* 100
  "Debounce time in milliseconds for view invalidation.")

;;;-----------------------------------------------------------------------------
;;; Core Reactive View Functions
;;;-----------------------------------------------------------------------------

(defclass reactive-view ()
  ((id :initarg :id :reader view-id)
   (app-state :initarg :app-state :accessor view-app-state)
   (render-fn :initarg :render-fn :accessor view-render-fn)
   (invalidated :initform t :accessor view-invalidated-p)
   (update-channel :initform (make-channel) :reader view-update-channel)
   ;; Stores (state-path . callback-fn) pairs for cleanup.
   (observers :initform nil :accessor view-observers)
   (last-render :initform nil :accessor view-last-render)
   (debounce-timer :initform nil :accessor view-debounce-timer)))

(defun create-reactive-view (id app-state render-fn)
  "Creates a new reactive view that updates when its dependencies change.

   ID: Unique identifier for the view.
   APP-STATE: The application state to observe.
   RENDER-FN: Function that renders the view (app-state -> ui-node).

   Returns the reactive-view instance."
  (let ((view (make-instance 'reactive-view
                             :id id
                             :app-state app-state
                             :render-fn render-fn)))
    ;; Store in the global registry
    (setf (gethash id *active-view-channels*) (view-update-channel view))

    ;; Return the view
    view))
(defun invalidate-view (view)
  "Marks a reactive view as needing to be re-rendered.
   Returns a command to schedule a render with debouncing."
  (check-type view reactive-view)

  ;; Mark as invalidated
  (setf (view-invalidated-p view) t)

  ;; Only return a command if not already debouncing
  (unless (view-debounce-timer view)
    (setf (view-debounce-timer view) t)
    ;; Return a command to handle the debounce and send the update
    (let ((view-id (view-id view))
          (channel (view-update-channel view)))
      (log:debug "Invalidating reactive view: ~A" view-id)
      (elmtui.core.async:cmd-async
       (lambda ()
         ;; Wait for debounce period
         (sleep (/ *view-invalidation-debounce* 1000.0))
         ;; Send update message
         (-> channel :render)
         ;; Reset debounce timer, then re-check for changes missed during debounce
         (setf (view-debounce-timer view) nil)
         (when (view-invalidated-p view)
           (setf (view-invalidated-p view) nil)
           (setf (view-debounce-timer view) t)
           (let ((channel (view-update-channel view)))
             (elmtui.core.async:cmd-async
              (lambda ()
                (sleep (/ *view-invalidation-debounce* 1000.0))
                (-> channel :render)
                (setf (view-debounce-timer view) nil))))))))))
;; (defun invalidate-view (view)
;;   "Marks a reactive view as needing to be re-rendered.
;;    Schedules a render with debouncing to avoid thrashing."
;;   (check-type view reactive-view)

;;   ;; Mark as invalidated
;;   (setf (view-invalidated-p view) t)

;;   ;; Send invalidation message to the view's channel
;;   (let ((channel (view-update-channel view)))
;;     ;; Only send if not already debouncing
;;     (when (not (view-debounce-timer view))
;;       (setf (view-debounce-timer view) t)
;;       ;; Schedule actual send with debouncing
;;       (let ((view-id (view-id view)))
;;         (log:debug "Invalidating reactive view: ~A" view-id)
;;         (cmd-async
;;          (lambda ()
;;            ;; Wait for debounce period
;;            (sleep (/ *view-invalidation-debounce* 1000.0))
;;            ;; Send update message
;;            (channel-put! channel :render)
;;            ;; Reset debounce timer
;;            (setf (view-debounce-timer view) nil)))))))

(defun register-view-dependency (view state-path)
  "Registers a state path that the view depends on.
   When the state at this path changes, the view will be invalidated.

   VIEW: The reactive-view instance.
   STATE-PATH: A keyword, symbol, or list representing the path in the app-state."
  (check-type view reactive-view)

  (let ((view-id (view-id view))
        (app-state (view-app-state view)))

    ;; Store the dependency
    (pushnew state-path (gethash view-id *view-dependencies*) :test 'equal)

    ;; Add observer for this state path
    (let ((callback (lambda (old-value new-value)
                      (declare (ignore old-value new-value))
                      (invalidate-view view))))
      (add-observer app-state state-path callback)
      ;; Store binding so cleanup can remove the exact observer.
      (push (cons state-path callback) (view-observers view))
      callback)))

(defun make-view-task (view dispatch-fn)
  "Creates a task function that handles rendering for a reactive view.

   VIEW: The reactive-view instance.
   DISPATCH-FN: Function to dispatch messages from the view.

   Returns a function that can be run in a worker thread."
  (check-type view reactive-view)

  (lambda ()
    (let ((channel (view-update-channel view)))
      (loop
        ;; Wait for a message on the view's channel
        (let ((msg (<- channel)))
          (case msg
            (:render
             ;; Only render if the view is invalidated
             (when (view-invalidated-p view)
               (log:debug "Rendering reactive view: ~A" (view-id view))

               ;; Render the view
               (let* ((app-state (view-app-state view))
                      (render-fn (view-render-fn view))
                      (new-view (funcall render-fn app-state dispatch-fn)))

                 ;; Store the result and mark as valid
                 (setf (view-last-render view) new-view)
                 (setf (view-invalidated-p view) nil)

                 ;; Send the result to the main thread
                 (funcall dispatch-fn `(:view-updated ,(view-id view) ,new-view)))))

            (:shutdown
             ;; Clean up and exit the loop
             (log:debug "Shutting down reactive view: ~A" (view-id view))
             (return-from nil))

            (otherwise
             (log:warn "Unknown message for reactive view ~A: ~S"
                       (view-id view) msg))))))))

(defun cleanup-reactive-view (view)
  "Cleans up a reactive view, removing observers and channels."
  (check-type view reactive-view)

  (let ((view-id (view-id view))
        (app-state (view-app-state view)))

    ;; Remove from global registry
    (remhash view-id *active-view-channels*)
    (remhash view-id *view-dependencies*)

    ;; Remove all observers
    (dolist (binding (view-observers view))
      (remove-observer app-state (car binding) (cdr binding)))

    ;; Send shutdown message to the view's channel
    (-> (view-update-channel view) :shutdown)))

;;;-----------------------------------------------------------------------------
;;; Rendering in Background Threads
;;;-----------------------------------------------------------------------------

(defun start-reactive-rendering (view dispatch-fn)
  "Starts background rendering for a reactive view.

   Returns a worker thread that can be used to stop rendering."
  (check-type view reactive-view)

  ;; Create the rendering task
  (let ((task (make-view-task view dispatch-fn)))

    ;; Spawn a worker thread to run the task
    (log:debug "Starting reactive rendering for view: ~A" (view-id view))
    (spawn-worker task :name (format nil "view-renderer-~A" (view-id view)))))

(defmacro with-reactive-rendering ((view-var app-state render-fn dispatch-fn
                                    &key dependencies)
                                   &body body)
  "Executes body with a reactive view that updates when its dependencies change.

   VIEW-VAR: Symbol to bind to the reactive view instance.
   APP-STATE: The application state to observe.
   RENDER-FN: Function that renders the view (app-state -> ui-node).
   DISPATCH-FN: Function to dispatch messages from the view.
   DEPENDENCIES: List of state paths that the view depends on.

   Example:
     (with-reactive-rendering (counter-view app-state #'render-counter dispatch-fn
                                          :dependencies '(counter-model))
       (add-view-to-layout counter-view main-layout)
       (process-events))"

  (let ((view-id-sym (gensym "VIEW-ID"))
        (worker-sym (gensym "WORKER")))
    `(let* ((,view-id-sym (gensym "REACTIVE-VIEW-"))
            (,view-var (create-reactive-view ,view-id-sym ,app-state ,render-fn))
            (,worker-sym nil))
       (unwind-protect
            (progn
              ;; Register dependencies
              ,@(loop for dep in dependencies
                      collect `(register-view-dependency ,view-var ,dep))

              ;; Start background rendering
              (setf ,worker-sym (start-reactive-rendering ,view-var ,dispatch-fn))

              ;; Execute body
              ,@body)

         ;; Cleanup
         (when ,worker-sym
           (cleanup-reactive-view ,view-var))))))

;;;-----------------------------------------------------------------------------
;;; Animation Support
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

(defvar *animations* (make-hash-table :test 'eq)
  "Maps animation IDs to animation structures.")

(defun register-animation (animation)
  "Registers an animation to be processed by the animation system."
  (setf (gethash (animation-id animation) *animations*) animation)
  animation)

(defun create-animation (duration update-fn &key (easing-fn #'identity) complete-fn)
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

(defun process-animations (delta-time)
  "Processes all active animations, updating their progress.
   Should be called on each frame with the time elapsed since the last frame."
  (let ((completed-ids nil))
    (maphash
     (lambda (id animation)
       (when (animation-active-p animation)
         ;; Update progress
         (let* ((old-progress (animation-progress animation))
                (new-progress (min 1.0 (+ old-progress (/ delta-time (animation-duration animation)))))
                (eased-progress (funcall (animation-easing-fn animation) new-progress)))

           ;; Call update function
           (funcall (animation-update-fn animation) eased-progress)

           ;; Update stored progress
           (setf (animation-progress animation) new-progress)

           ;; Check if complete
           (when (>= new-progress 1.0)
             (setf (animation-active-p animation) nil)
             (when (animation-complete-fn animation)
               (funcall (animation-complete-fn animation)))
             (push id completed-ids)))))
     *animations*)
    ;; Remove completed animations after iteration
    (dolist (id completed-ids)
      (remhash id *animations*))))

;;; Easing helpers
(defun linear-easing (x) x)
(defun ease-in (x &optional (power 2)) (expt x power))
(defun ease-out (x &optional (power 2)) (- 1 (expt (- 1 x) power)))
(defun ease-in-out (x &optional (power 2))
  (cond
    ((< x 0.5) (* 0.5 (expt (* 2 x) power)))
    (t (- 1 (* 0.5 (expt (* 2 (- 1 x)) power))))))
(defun bounce (x)
  (let ((t2 (- 1 x)))
    (- 1 (* t2 t2 (+ 2.75 (* t2 t2 2.5))))))
(defun elastic (x)
  (let ((p 0.3)
        (s (* 0.3 0.25)))
    (- (* (expt 2 (* -10 x)) (sin (/ (* (- x s) 2 pi) p))) 0.0001)))

;;; TEA-tick helper: schedule a message after 1/fps seconds
(defun next-frame-cmd (&key (fps 60) (message :animation-tick))
  "Return a command that asynchronously sleeps for 1/FPS seconds, then emits MESSAGE.
   Use via (nconc commands (list (reactive:next-frame-cmd :fps 60 :message :tick)))."
  (let ((interval (/ 1.0 (max 1 fps))))
    (elmtui.core.async:cmd-async
     (lambda (_progress) (declare (ignore _progress)) (sleep interval) :ok)
     :on-complete (lambda (_res) (declare (ignore _res)) message))))
