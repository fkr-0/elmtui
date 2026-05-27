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
  `(:components ((,*info-label-id* (:type label
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


(defun app-update (message app-state) ; Flipped order to convention: message, app-state
  "Main application update function."
  (declare (ignorable message))
  (let ((patches nil)
        (commands nil)
        (msg-type (if (listp message) (first message) message)))
    (case msg-type
      (:dispatch-to-component
       (let* ((target-component-id (second message))
              (component-action (cddr message))
              (component-instance (elmtui.app.api:get-component-instance  target-component-id app-state))
              (component-state-path (list :components target-component-id))
              (component-state (state-ref app-state component-state-path)))
         (if (and component-instance component-state)
             (multiple-value-bind (comp-patches comp-commands)
                 ;; Pass the action directly, not as a list if it's already the action keyword
                 (update component-instance (if (consp component-action) (first component-action) component-action) app-state :id-path component-state-path)
               (when comp-patches
                 (push `(,component-state-path ,comp-patches) patches))
               (setf commands (append comp-commands commands)))
             (log-warn "KEYMAP-APP: No component or state found for ID ~S to dispatch message ~S"
                       target-component-id component-action))))
      (:app-quit-requested
       (push '(:should-quit t) patches)
       (log-info "KEYMAP-APP: Quit requested by message: ~S" message))
      (:key-event ; This case should ideally not be hit if keymaps are comprehensive
       (log-debug "KEYMAP-APP: Unhandled raw key event (should be caught by keymaps): ~S" message))
      (otherwise
       (log-debug "KEYMAP-APP: Unhandled message: ~S" message)))
    (make-update-result :patches (nreverse patches) :commands commands)))

(defun component-state (app-state component-id)
  "Return COMPONENT-ID state from this example's alist-backed :components model."
  (second (assoc component-id (getf app-state :components))))

(defun app-view (app-state)
  "Main application view function using current keyword-headed DSL nodes."
  (let ((info-st (component-state app-state *info-label-id*))
        (counter-st (component-state app-state *counter-a-id*)))
    `(:layout :style (:display :flex :flex-direction :row :spacing 1)
      :children
      ((:label :id ,*info-label-id*
               :text ,(getf info-st :text))
       (:counter :id ,*counter-a-id*
                 :value ,(getf counter-st :value))))))

(defapplication keymap-example-app
  :root-viewport-id :my-root-viewport
  :root-component-dsl
  '(:layout :id :keymap-root-layout
    :style (:display :flex :flex-direction :column :spacing 1)
    :children
    ((:label :id :info-label
             :text "Keymap Demo App. Focus counter and press + or - or Enter. C-q to quit.")
     (:counter :id :counter-a :value 10)))
  :initial-state-fn #'app-init
  :update-fn #'app-update
  :view-fn #'app-view
  :command-processor-fn #'(lambda (command mq state cfg)
                            (declare (ignore command mq state cfg))
                            nil))

(defun main ()
  "Run the keymap example application."
  (run-keymap-example-app))
