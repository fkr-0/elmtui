;;;===============================================================
;;; File: examples/keymap-app.lisp
;;; Example application demonstrating keymap usage
;;;===============================================================
(uiop:define-package :elmtui.examples.keymap-app
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-info #:log-debug #:log-warn)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.ui.api #:update)
  (:import-from :elmtui.ui.widgets.label #:label)
  (:import-from :elmtui.ui.widgets.counter #:counter)
  (:import-from :elmtui.keymaps #:keymap! #:add-keybinding)
  (:export #:main))

(in-package :elmtui.examples.keymap-app)

(defparameter *counter-a-id* :counter-a)
(defparameter *info-label-id* :info-label)

(declaim (ftype (function () list) app-component-keymaps))

;;;--------------------------------------------------------------
;;; Application Definition
;;;--------------------------------------------------------------



(defun app-init ()
  "Initializes the application model."
  `(:demo-components ((,*info-label-id* (:type label
                                    :text "Keymap Demo App. Focus counter and press + or - or Enter. C-q to quit."
                                    :id ,*info-label-id*))
                 (,*counter-a-id* (:type counter
                                   :id ,*counter-a-id*
                                   :value 10
                                   ;; Counter's own keymap is usually part of its own state,
                                   ;; but app-component-keymaps is how this app provides it.
                                   )))
    :focus-manager (:current-focus-id ,*counter-a-id*
                    :focusable-elements (,*counter-a-id*))
    :should-quit nil
    ;; This is where component-specific keymaps are stored for this app.
    :component-keymaps ,(app-component-keymaps)))

;; (define-keymap *editor-keymap*
;;   ("C-a" :type :message :target '(:select-all) :description "Select All")
;;   ("C-c" :type :message :target '(:copy) :description "Copy")
;;   ("C-v" :type :message :target '(:paste) :description "Paste")
;;   ("C-x" :type :message :target '(:cut) :description "Cut")
;;   ("C-z" :type :message :target '(:undo) :description "Undo")
;;   ("C-y" :type :message :target '(:redo) :description "Redo"))

(defun app-component-keymaps ()
  "Defines keymaps specific to components, returned as an alist (id . keymap)."
  (let ((km (keymap! :counter-a-keymap)))
    (add-keybinding km "+"    :type :message :target `(:dispatch-to-component ,*counter-a-id* :increment) :description "incr")
    (add-keybinding km "-"    :type :message :target `(:dispatch-to-component ,*counter-a-id* :decrement) :description "decr")
    (add-keybinding km "Enter" :type :message :target `(:dispatch-to-component ,*counter-a-id* :reset)     :description "reset")
    (list (cons *counter-a-id* km))))


(defun app-update (message app-state)
  "Apply counter commands to demo state, leaving framework :components alone."
  (let ((tag (and (consp message) (first message))))
    (cond
      ((and (eq tag :dispatch-to-component)
            (eq (second message) *counter-a-id*))
       (let* ((entries (state-ref app-state :demo-components))
              (next (copy-tree entries))
              (counter (second (assoc *counter-a-id* next)))
              (action (third message))
              (value (getf counter :value 10)))
         (setf (getf counter :value)
               (case action
                 (:increment (1+ value))
                 (:decrement (1- value))
                 (:reset 0)
                 (otherwise value)))
         (make-update-result :patches (list (list '(:demo-components) next)))))
      ((eq tag :app-quit-requested)
       (make-update-result :patches '(((:should-quit) t))))
      (t (make-update-result)))))

(defun component-state (app-state component-id)
  "Return COMPONENT-ID state from this example's alist-backed :components model."
  (second (assoc component-id (state-ref app-state :demo-components))))

(defun app-view (app-state)
  "Present a counter as ordinary visible terminal text."
  (let* ((info (component-state app-state *info-label-id*))
         (counter (component-state app-state *counter-a-id*)))
    `(:container :id :keymap-content
       :style (:display :flex :flex-direction :column :width 78 :height 4)
       :children
       ((:text :id :help :content ,(getf info :text))
        (:text :id :counter-value
               :content ,(format nil "Counter [COUNTER-A]: ~D"
                                 (getf counter :value 0)))))))

(defapplication keymap-example-app
  :root-viewport-id :my-root-viewport
  :root-component-dsl
  '(:root-viewport :id :my-root-viewport
    :anchor :below-cursor :child-dsl-spec (:view nil))
  :initial-state-fn #'app-init
  :update-fn #'app-update
  :view-fn #'app-view
  :command-processor-fn #'(lambda (command mq state cfg)
                            (declare (ignore command mq state cfg))
                            nil))

(defun main ()
  "Run the keymap example application."
  (run-keymap-example-app))
