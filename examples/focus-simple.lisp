(uiop:define-package :elmtui.examples.focus-simple
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-info)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.ui.widgets.listbox
                #:init-listbox #:update-listbox #:view-listbox
                #:listbox-model-height #:listbox-model-items
                #:listbox-model-selected-index #:listbox-model-on-select
                #:listbox-model-id
                #:msg-listbox-key-press)
  (:export #:run-focus-simple))

(in-package :elmtui.examples.focus-simple)

(defparameter *listbox-id* :choices)
(defparameter *ok-id* :btn-ok)
(defparameter *cancel-id* :btn-cancel)

(defun %initial-state ()
  (multiple-value-bind (lb _cmd)
      (init-listbox *listbox-id* :items '("a" "b" "c") :height 5 :selected-index 0 :on-select '(:lb-selected))
    (declare (ignore _cmd))
    (list :components
          (list (cons *listbox-id* lb)
                (cons *ok-id*     '(:type :button :label "OK"))
                (cons *cancel-id* '(:type :button :label "Cancel")))
          :focus-manager (list :current-focus-id *listbox-id* :focusable-elements (list *listbox-id* *ok-id* *cancel-id*))
          :component-keymaps (list
                              (cons *listbox-id*
                                    (let ((km (elmtui.keymaps:keymap!  :lb)))
                                      (elmtui.keymaps:add-keybinding km "Tab"   :type :message :target '(:focus-next))
                                      (elmtui.keymaps:add-keybinding km "S-Tab" :type :message :target '(:focus-prev))
                                      (elmtui.keymaps:add-keybinding km "Up"    :type :message :target `(:dispatch-to-component ,*listbox-id* :up))
                                      (elmtui.keymaps:add-keybinding km "Down"  :type :message :target `(:dispatch-to-component ,*listbox-id* :down))
                                      km))
                              (cons *ok-id*
                                    (let ((km (elmtui.keymaps:keymap!  :ok)))
                                      (elmtui.keymaps:add-keybinding km "Enter" :type :message :target '(:ok))
                                      (elmtui.keymaps:add-keybinding km "Tab"   :type :message :target '(:focus-next))
                                      (elmtui.keymaps:add-keybinding km "S-Tab" :type :message :target '(:focus-prev))
                                      km))
                              (cons *cancel-id*
                                    (let ((km (elmtui.keymaps:keymap!  :cancel)))
                                      (elmtui.keymaps:add-keybinding km "Enter" :type :message :target '(:cancel))
                                      (elmtui.keymaps:add-keybinding km "Tab"   :type :message :target '(:focus-next))
                                      (elmtui.keymaps:add-keybinding km "S-Tab" :type :message :target '(:focus-prev))
                                      km)))
          :exit-code 0)))

(defun app-update (message app-state)
  "Handle focus-demo semantic messages without mutating application state."
  (let ((patches nil) (commands nil))
    (labels ((ret () (make-update-result :patches (nreverse patches) :commands (nreverse commands)))
             (components () (state-ref app-state :components))
             (focus-manager () (state-ref app-state :focus-manager)))
      (let ((tag (if (consp message) (first message) message)))
        (case tag
          (:lb-selected (push '((:should-quit) t) patches))
          (:ok (push '((:should-quit) t) patches))
          (:cancel
           (push '((:should-quit) t) patches)
           (push '((:exit-code) 1) patches))
          (:dispatch-to-component
           (let ((target (second message))
                 (action (third message)))
             (cond
               ((eq target *ok-id*) (push '(:ok) commands))
               ((eq target *cancel-id*) (push '(:cancel) commands))
               (t
                (let ((lb (cdr (assoc *listbox-id* (components)))))
                  (when lb
                    (multiple-value-bind (new-lb ignored-commands)
                        (update-listbox (list msg-listbox-key-press
                                              :key (case action
                                                     (:up :up)
                                                     (:down :down)
                                                     (otherwise action)))
                                        lb)
                      (declare (ignore ignored-commands))
                      (let* ((new-components (copy-alist (components)))
                             (entry (assoc *listbox-id* new-components)))
                        (setf (cdr entry) new-lb)
                        (push (list :components new-components) patches)))))))))
          (:focus-next
           (let* ((fm (copy-list (focus-manager)))
                  (ids (getf fm :focusable-elements))
                  (cur (getf fm :current-focus-id))
                  (pos (position cur ids))
                  (next (if pos (nth (mod (1+ pos) (length ids)) ids) (first ids))))
             (setf (getf fm :current-focus-id) next)
             (push (list '(:focus-manager) fm) patches)))
          (:focus-prev
           (let* ((fm (copy-list (focus-manager)))
                  (ids (getf fm :focusable-elements))
                  (cur (getf fm :current-focus-id))
                  (pos (position cur ids))
                  (prev (if pos (nth (mod (1- pos) (length ids)) ids) (first ids))))
             (setf (getf fm :current-focus-id) prev)
             (push (list '(:focus-manager) fm) patches)))))
      (ret))))


(defun app-view (app-state)
  `(:container :id :root
               :style (:display :flex :flex-direction :column :width :fill :height :fill)
               :children ((:container :style (:display :flex :flex-direction :row)
                                      :children ((:container :style (:width :fill :height :fill)
                                                             :children ((,(view-listbox app-state :widget-id *listbox-id*))))
                                                 (:container :style (:display :flex :flex-direction :column :width 10)
                                                             :children ((:button :id ,*ok-id* :label "OK")
                                                                        (:button :id ,*cancel-id* :label "Cancel"))))))))

(defapplication focus-simple-app
  :root-viewport-id :focus-root
  :initial-state-fn #'%initial-state
  :root-component-dsl '(:layout :id :root)
  :update-fn 'app-update
  :view-fn 'app-view)

(defun run-focus-simple (&key (backend-type :terminal) platform-options argv)
  "Run the focus/listbox example with the generated application runner."
  (run-focus-simple-app :platform backend-type :platform-options platform-options :argv argv))
