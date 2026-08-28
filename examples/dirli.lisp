;;;===============================================================
;;; File: examples/dirli.lisp
;;;
;;; Description: A clean directory listing application using the
;;; modern ElmTUI API. Demonstrates widget integration, message
;;; handling, and state management.
;;;===============================================================

(uiop:define-package :elmtui.examples.dirli
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.ui.widgets.listbox
                #:init-listbox #:update-listbox #:view-listbox
                #:listbox-model-id #:listbox-model-items
                #:listbox-model-selected-index #:listbox-model-height
                #:listbox-model-on-select)
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-key #:key-event-modifiers)
  (:export #:run-dirli #:main))

(in-package :elmtui.examples.dirli)

;;;===============================================================
;;; Directory Operations
;;;===============================================================

(defun list-directory-contents (path)
  "List PATH with a parent entry, directories first, then files."
  (handler-case
      (let* ((path (uiop:ensure-directory-pathname path))
             (parent (uiop:pathname-parent-directory-pathname path))
             (parent-entry (unless (equal (namestring path) (namestring parent)) (list "../"))))
        (append parent-entry
                (mapcar (lambda (directory) (enough-namestring directory path))
                        (uiop:subdirectories path))
                (mapcar (lambda (file) (enough-namestring file path))
                        (uiop:directory-files path))))
    (error (condition)
      (log-error "Error listing directory ~A: ~A" path condition)
      nil)))


;;;===============================================================
;;; Helper Functions
;;;===============================================================

(defun regenerate-listbox-model (lb-model &key (items nil items-p) (selected-index nil selected-index-p) (height nil height-p))
  "Return a fresh listbox model while preserving unspecified fields."
  (init-listbox (listbox-model-id lb-model)
                :items (if items-p items (listbox-model-items lb-model))
                :height (if height-p height (listbox-model-height lb-model))
                :selected-index (if selected-index-p selected-index (listbox-model-selected-index lb-model))
                :on-select (listbox-model-on-select lb-model)))


(defun status-message-result (message)
  "Create an update result that sets only the status message."
  (make-update-result
    :patches `(((:status-message) ,message))))

;;;===============================================================
;;; Update Function
;;;===============================================================

(progn
  (defun %dirli-normalize-key (key)
    (case key
      ((:arrow-up :up) :up)
      ((:arrow-down :down) :down)
      ((:enter :return) :enter)
      (:page-up :page-up)
      (:page-down :page-down)
      (:home :home)
      (:end :end)
      (otherwise key)))

  (defun %dirli-navigate-result (app-state path)
    (handler-case
        (let* ((path (uiop:ensure-directory-pathname path))
               (new-items (list-directory-contents path))
               (lb-model (state-ref app-state :listbox-model))
               (new-model (regenerate-listbox-model lb-model
                                                     :items new-items
                                                     :selected-index (and new-items 0))))
          (make-update-result
           :patches (list (list '(:listbox-model) new-model)
                          (list '(:current-path) path)
                          (list '(:status-message) (format nil "Directory: ~A" path)))))
      (error (condition)
        (status-message-result (format nil "Error: ~A" condition)))))

  (defun %dirli-selected-result (app-state message)
    (let* ((lb-model (state-ref app-state :listbox-model))
           (selected-index (and lb-model (listbox-model-selected-index lb-model)))
           (selected-item (or (and (consp message) (getf (rest message) :item))
                              (and selected-index
                                   (nth selected-index (listbox-model-items lb-model)))))
           (current-path (state-ref app-state :current-path)))
      (cond
        ((null selected-item)
         (status-message-result "No item selected"))
        ((string= selected-item "../")
         (%dirli-navigate-result app-state
                                 (uiop:pathname-parent-directory-pathname current-path)))
        (t
         (let ((new-path (merge-pathnames selected-item current-path)))
           (cond
             ((uiop:directory-exists-p new-path)
              (%dirli-navigate-result app-state new-path))
             ((uiop:file-exists-p new-path)
              (status-message-result (format nil "File: ~A" selected-item)))
             (t
              (status-message-result (format nil "Cannot access: ~A" selected-item)))))))))

  (defun %dirli-resize-result (app-state message)
    (let* ((width (getf (rest message) :width 80))
           (height (getf (rest message) :height 24))
           (available-height (max 5 (- height 5)))
           (lb-model (state-ref app-state :listbox-model)))
      (make-update-result
       :patches (append
                 (when lb-model
                   (list (list '(:listbox-model)
                               (regenerate-listbox-model lb-model :height available-height))))
                 (list (list '(:terminal-width) width)
                       (list '(:terminal-height) height))))))

  (defun app-update (message app-state)
    "Handle directory navigation, selection, resize, and quit messages."
    (cond
      ((typep message 'key-event)
       (let ((key (key-event-key message))
             (modifiers (key-event-modifiers message))
             (lb-model (state-ref app-state :listbox-model)))
         (cond
           ((or (member key '(:q #\q #\Q) :test #'eql)
                (and (member :control modifiers)
                     (member key '(:q #\q) :test #'eql)))
            (make-update-result :patches '(((:should-quit) t))))
           ((null lb-model)
            (make-update-result))
           (t
            (multiple-value-bind (new-model commands)
                (update-listbox (list :listbox-key-press
                                      :key (%dirli-normalize-key key))
                                lb-model)
              (make-update-result
               :patches (list (list '(:listbox-model) new-model))
               :commands commands))))))
      ((or (eq message :item-selected)
           (and (consp message) (eq (first message) :item-selected)))
       (%dirli-selected-result app-state message))
      ((and (consp message) (eq (first message) :terminal-resized))
       (%dirli-resize-result app-state message))
      (t
       (make-update-result)))))



;;;===============================================================
;;; View Function
;;;===============================================================

(defun app-view (app-state)
  "Render the live directory listbox and status information."
  (let* ((current-path (state-ref app-state :current-path))
         (status-message (state-ref app-state :status-message ""))
         (terminal-width (state-ref app-state :terminal-width 80))
         (terminal-height (state-ref app-state :terminal-height 24))
         (lb-model (state-ref app-state :listbox-model)))
    `(:container :id :root
      :style (:width :fill :height :fill :display :flex :flex-direction :column :gap 1 :padding 1)
      :children
      ((:text :id :header :content ,(format nil "Dirli - ~A" current-path) :style (:fg-color :cyan :bold t))
       (:text :id :instructions :content "Up/Down: Navigate | Enter: Open | q: Quit" :style (:fg-color :gray))
       (:container :id :listbox-container :style (:width :fill :height :fill)
        :children (,(if lb-model
                        (view-listbox app-state :widget-id :main-listbox
                                      :items (listbox-model-items lb-model)
                                      :height (listbox-model-height lb-model)
                                      :selected-index (listbox-model-selected-index lb-model)
                                      :on-select '(:item-selected)
                                      :empty-text "Directory is empty"
                                      :width :fill)
                        '(:text :id :empty :content "Directory unavailable"))))
       (:text :id :status :content ,status-message :style (:fg-color :yellow))
       (:text :id :footer :content ,(format nil "Terminal: ~A x ~A" terminal-width terminal-height)
              :style (:fg-color :gray))))))


;;;===============================================================
;;; Application Definition
;;;===============================================================

(defun %dirli-initial-state ()
  (let* ((current-path (uiop:getcwd))
         (items (list-directory-contents current-path)))
    (list :current-path current-path
          :listbox-model (init-listbox
                          :main-listbox
                          :items items
                          :height 10
                          :selected-index (when items 0)
                          :on-select '(:item-selected))
          :status-message "Welcome to Dirli! Navigate directories with arrow keys."
          :should-quit nil
          :terminal-width 80
          :terminal-height 24)))

(defapplication dirli-app
  :root-viewport-id :dirli-vp
  :initial-state-fn #'%dirli-initial-state
  :root-component-dsl '(:container :id :root)
  :update-fn 'app-update
  :view-fn 'app-view)

;;;===============================================================
;;; Entry Points
;;;===============================================================

(defun run-dirli (&key (backend-type :terminal) platform-options argv)
  "Run Dirli through the generated application runner."
  (run-dirli-app :platform backend-type :platform-options platform-options :argv argv))


(defun main ()
  "Main entry point for the application."
  (run-dirli))

;; To run from REPL:
;; (ql:quickload :elmtui.examples.dirli)
;; (elmtui.examples.dirli:run-dirli)
