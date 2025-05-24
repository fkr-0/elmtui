;;;===============================================================
;;; File: src/runtime.lisp
;;; Runtime Assembly & Entrypoint with Canvas Support
;;;===============================================================
(uiop:define-package :elmtui.runtime
  (:use :cl :alexandria :log4cl)
  ;; State Management
  (:import-from :elmtui.state #:application-state #:make-application-state #:*app-state* #:state-ref)
  (:import-from :ut.state.state #:set-state #:merge-state) ; Internal state management functions
  ;; Core Systems
  (:import-from :elmtui.core.globals #:*app-sender*)
  (:import-from :elmtui.core.loop #:start-loop #:elm-stop-loop #:elm-event-loop-active-p #:enqueue-event #:*event-loop*)
  (:import-from :cleve-elm.event-loop #:dequeue-event) ; Import dequeue-event directly
  (:import-from :elmtui.core.async #:interpret-cmd)
  (:import-from :elmtui.core.events #:cmd #:make-message)
  (:import-from :elmtui.state.msg #:make-update-focusable-ids-app-msg) ; Constructor for the message
  ;; Platform Abstraction
  (:import-from :elmtui.platform.driver #:run-application) ; Import run-application
  ;; Styling & Layout
  (:import-from :elmtui.view.styled #:apply-stylesheet-to-tree)
  (:import-from :elmtui.view.layout #:layout-tree)
  (:import-from :elmtui.view.geo #:make-rectangle #:make-pos #:make-size) ; For screen rect
  ;; UI Utilities
  (:export :def-elm-app
   :run-app))
(in-package :elmtui.runtime)

(defvar *current-app-name* nil "Holds the name of the currently defined Elm app.")
(defvar *current-app-runner* nil "Holds the main run function of the defined Elm app.")

(defmacro def-elm-app (name &key init update view subscriptions)
  "Defines an ElmTUI application.
   [Original documentation]
   
   Added support for terminal canvas positioning."
  (let ((run-func-name (symbolicate "RUN-" name)))
    ;; Removed unused gensyms
    `(progn
       (defun ,run-func-name (&key 
                            (platform :terminal) 
                            platform-options
                            ;; Add canvas options
                            (use-canvas nil)
                            (canvas-anchor :cursor)
                            (canvas-growth :down)
                            (canvas-initial-size nil)
                            (canvas-max-size nil))
         ;; Bind function designators locally
         (let ((effective-init-fn ,init)
               (effective-update-fn ,update)
               (effective-view-fn ,view)
               (effective-subscriptions-fn ,subscriptions))
           (log:info "Running ElmTUI application: ~A via elmtui.platform.driver:run-application (Platform: ~A, Canvas: ~A)"
                    ',name platform use-canvas)
           (let ((app-spec (list :name ',name
                                 :init-fn effective-init-fn
                                 :update-fn effective-update-fn
                                 :view-fn effective-view-fn
                                 :subscriptions-fn effective-subscriptions-fn)))
             ;; Delegate to the platform driver with canvas options
             (elmtui.platform.driver:run-application 
              app-spec
              :backend-type platform
              :tty-path (getf platform-options :tty-path "/dev/tty")
              :use-canvas use-canvas
              :canvas-anchor canvas-anchor
              :canvas-growth canvas-growth
              :canvas-initial-size canvas-initial-size
              :canvas-max-size canvas-max-size))))

       ;; Set this app as the default runnable one
       (setf *current-app-name* ',name)
       (setf *current-app-runner* #',run-func-name)
       ',name)))

(defun run-app (&rest args &key (app-name *current-app-name*) &allow-other-keys)
  "Runs the defined ElmTUI application.
   Defaults to the most recently defined app via def-elm-app.
   Passes keyword arguments (like :platform) to the specific run-<app-name> function."
  (let ((runner (or (when app-name (symbol-function (symbolicate "RUN-" app-name)))
                    *current-app-runner*)))
    (if runner
        (apply runner (remove-from-plist args :app-name))
        (error "No ElmTUI application defined or specified to run."))))



;; (def-elm-app my-app)
