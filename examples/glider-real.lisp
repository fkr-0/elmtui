(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :elmtui.examples.neon-glider)
    (load (merge-pathnames #P"neon-glider.lisp"
                           (or *load-truename* *compile-file-truename*)))))
(uiop:define-package :elmtui.examples.glider
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:state-ref)
  (:export #:run-glider-animation #:glider-update #:glider-view))
(in-package :elmtui.examples.glider)

(defun %initial-state ()
  (append (elmtui.examples.neon-glider:initial-state) '(:w 44 :h 13)))

(defun %bounce-step (x y dx dy w h)
  (elmtui.examples.neon-glider:bounce-step x y dx dy w h))

(defun glider-update (message state)
  (elmtui.examples.neon-glider:glider-update message state))

(defun glider-view (state)
  (elmtui.examples.neon-glider:glider-view state))

(defapplication glider-animation-app
  :root-viewport-id :glider-root
  :root-component-dsl '(:root-viewport :id :glider-root
                        :anchor :below-cursor :width 74 :height 23
                        :blank-on-exit t :child-dsl-spec (:view nil))
  :initial-state-fn #'%initial-state
  :update-fn #'glider-update
  :view-fn #'glider-view
  :subscriptions-fn (lambda (state)
                      (when (state-ref state :running t)
                        (list :timer (list :interval (state-ref state :period 0.12)
                                           :message (list :tick))))))

(defun run-glider-animation (&key (backend-type :terminal))
  (run-glider-animation-app :platform backend-type))
