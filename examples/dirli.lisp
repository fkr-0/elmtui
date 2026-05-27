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
  "List directory contents with directories first, marked with trailing /."
  (handler-case
      (append
        ;; Directories first, with trailing slash
        (mapcar (lambda (d)
                  (concatenate 'string (enough-namestring d path) "/"))
                (uiop:subdirectories path))
        ;; Then files
        (mapcar (lambda (f)
                  (enough-namestring f path))
                (uiop:directory-files path)))
    (error (e)
      (log-error "Error listing directory ~A: ~A" path e)
      (list (format nil "Error listing ~A" path)))))

;;;===============================================================
;;; Helper Functions
;;;===============================================================

(defun regenerate-listbox-model (lb-model &key items selected-index height)
  "Regenerate a listbox model with selective field updates."
  (init-listbox
    (listbox-model-id lb-model)
    :items (or items (listbox-model-items lb-model))
    :height (or height (listbox-model-height lb-model))
    :selected-index (or selected-index (listbox-model-selected-index lb-model))
    :on-select (listbox-model-on-select lb-model)))

(defun status-message-result (message)
  "Create an update result that sets only the status message."
  (make-update-result
    :patches `(((:status-message) ,message))))

;;;===============================================================
;;; Update Function
;;;===============================================================

(defun app-update (message app-state)
  "Handle application messages following Elm architecture."
  (labels
      ((quit-result ()
         (make-update-result :patches '((:should-quit t))))
       (navigate-to-directory (path)
         (handler-case
             (let* ((new-items (list-directory-contents path))
                    (lb-model (state-ref app-state :listbox-model))
                    (new-lb-model (regenerate-listbox-model
                                   lb-model
                                   :items new-items
                                   :selected-index (when new-items 0))))
               (make-update-result
                :patches `(((:listbox-model) ,new-lb-model)
                           (:current-path ,path)
                           (:status-message
                            ,(format nil "Directory: ~A"
                                     (enough-namestring
                                      path
                                      (uiop:pathname-parent-directory-pathname path)))))))
           (error (e)
             (status-message-result (format nil "Error: ~A" e))))))
    (cond
      ((typep message 'key-event)
       (let ((key (key-event-key message)))
         (if (or (member key '(:q :Q #\q #\Q) :test #'eql)
                 (and (stringp key) (or (string= key "q") (string= key "Q")))
                 (and (characterp key)
                      (or (char= key #\q) (char= key #\Q))
                      (member :control (key-event-modifiers message))))
             (quit-result)
             (let* ((lb-model (state-ref app-state :listbox-model)))
               (multiple-value-bind (new-lb-model lb-cmds)
                   (update-listbox `(:listbox-key-press :key ,key) lb-model)
                 (make-update-result
                  :patches `(((:listbox-model) ,new-lb-model))
                  :commands lb-cmds))))))
      ((eq message :item-selected)
       (let* ((lb-model (state-ref app-state :listbox-model))
              (selected-idx (and lb-model (listbox-model-selected-index lb-model)))
              (item (when (and lb-model selected-idx)
                      (nth selected-idx (listbox-model-items lb-model))))
              (current-path (state-ref app-state :current-path)))
         (cond
           ((null lb-model)
            (status-message-result "Listbox is not initialized yet"))
           ((not item)
            (status-message-result "No item selected"))
           (t
            (let ((new-path (merge-pathnames item current-path)))
              (cond
                ((string= item "../")
                 (navigate-to-directory
                  (uiop:pathname-parent-directory-pathname current-path)))
                ((uiop:directory-exists-p new-path)
                 (navigate-to-directory new-path))
                ((uiop:file-exists-p new-path)
                 (status-message-result (format nil "File: ~A" item)))
                (t
                 (status-message-result
                  (format nil "Cannot access: ~A" item)))))))))
      ((and (consp message) (eq (first message) :terminal-resized))
       (let* ((msg-data (rest message))
              (term-height (getf msg-data :height))
              (available-height (max 5 (- term-height 5)))
              (lb-model (state-ref app-state :listbox-model))
              (current-height (and lb-model (listbox-model-height lb-model))))
         (cond
           ((null lb-model)
            (make-update-result))
           ((= available-height current-height)
            (make-update-result))
           (t
            (let ((new-lb-model (regenerate-listbox-model
                                  lb-model
                                  :height available-height)))
               (make-update-result
                :patches `(((:listbox-model) ,new-lb-model)
                           (:terminal-width ,(getf msg-data :width))
                           (:terminal-height ,(getf msg-data :height)))))))))
      (t
       (make-update-result)))))

;;;===============================================================
;;; View Function
;;;===============================================================

(defun app-view (app-state)
  "Render the directory listing application."
  (let* ((current-path (state-ref app-state :current-path))
         (status-message (state-ref app-state :status-message))
         (terminal-width (state-ref app-state :terminal-width))
         (terminal-height (state-ref app-state :terminal-height)))
    `(:container
       :id :root
       :style (:width :fill
               :height :fill
               :display :flex
               :flex-direction :column
               :gap 1
               :padding 1)
       :children
       ((:text
         :id :header
         :content ,(format nil "Dirli - ~A" current-path)
         :style (:fg-color :cyan :bold t))
        (:text
         :id :instructions
         :content "↑↓: Navigate | Enter: Open | C-q: Quit"
         :style (:fg-color :gray))
        (:container
         :id :listbox-container
         :style (:width :fill :height :fill)
         :children
         ((:text
           :id :listbox-placeholder
           :content "Loading..."
           :style (:width :fill :height :fill :text-align :center))))
        (:text
         :id :status
         :content ,status-message
         :style (:fg-color :yellow))
        (:text
         :id :footer
         :content ,(format nil "Terminal: ~A x ~A"
                           terminal-width
                           terminal-height)
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

(defun run-dirli (&rest args)
  "Run the Dirli directory listing application."
  (apply #'elmtui.app.api:run-application 'dirli-app args))

(defun main ()
  "Main entry point for the application."
  (run-dirli))

;; To run from REPL:
;; (ql:quickload :elmtui.examples.dirli)
;; (elmtui.examples.dirli:run-dirli)
