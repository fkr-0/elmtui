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
   Canvas is now used by default.
 
    Args:
      NAME: Symbol naming the application.
      INIT: A function designator (#'my-init) that takes no arguments and returns
            (values initial-model initial-commands-list).
      UPDATE: A function designator (#'my-update) that takes (app-state message)
              and returns commands-list. It uses set-state! internally.
      VIEW: A function designator (#'my-view) that takes (app-state) and returns
            a UI-NODE tree.
      SUBSCRIPTIONS: (Optional) A function designator (#'my-subscriptions) that takes (app-state)
                     and returns a list of subscriptions (e.g., for timers, external events).
 
    Generates:
      - A `run-<NAME>` function to start and manage the application lifecycle.
     - Sets `*current-app-name*` and `*current-app-runner*` for the default `run-app`."
  (let ((run-func-name (symbolicate "RUN-" name)))
    `(progn
       (defun ,run-func-name (&key 
                                (platform :terminal)
                                platform-options
                                ;; Canvas options (use-canvas removed)
                                (canvas-anchor :top-left) ; Default anchor
                                (canvas-growth :fixed)    ; Default strategy for full-screen/fixed
                                (canvas-fixed-pos nil)    ; Default to (0,0) if strategy is :fixed & this is nil
                                (canvas-initial-size nil) ; Default to full screen in driver if nil
                                (canvas-max-size nil))
         (let ((effective-init-fn ,init)
               (effective-update-fn ,update)
               (effective-view-fn ,view)
               (effective-subscriptions-fn ,subscriptions))
           (log:info "Running ElmTUI application: ~A via elmtui.platform.driver:run-application (Platform: ~A, Canvas is mandatory)"
                     ',name platform)
           (let ((app-spec (list :name ',name
                                 :init-fn effective-init-fn
                                 :update-fn effective-update-fn
                                 :view-fn effective-view-fn
                                 :subscriptions-fn effective-subscriptions-fn)))
             (elmtui.platform.driver:run-application 
              app-spec
              :backend-type platform
              :tty-path (getf platform-options :tty-path "/dev/tty")
              ;; :use-canvas is removed
              :canvas-anchor canvas-anchor
              :canvas-growth canvas-growth
              :canvas-fixed-pos canvas-fixed-pos
              :canvas-initial-size canvas-initial-size
              :canvas-max-size canvas-max-size))))

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
