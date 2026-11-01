;;;===============================================================
;;; File: examples/file-watcher.lisp
;;; Example: Watch a file and display its modification status.
;;;
;;; Usage:
;;;   (asdf:load-system :elmtui-examples)
;;;   (elmtui.examples.file-watcher:run-file-watcher)
;;;
;;; Then modify /tmp/elmtui-watch-demo.txt in another terminal to
;;; see the app react.
;;;===============================================================

(uiop:define-package :elmtui.examples.file-watcher
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
  (:export #:run-file-watcher))

(in-package :elmtui.examples.file-watcher)

(defparameter *watch-path* "/tmp/elmtui-watch-demo.txt")

(defun %initial-state ()
  ;; Create the file if it doesn't exist
  (unless (probe-file *watch-path*)
    (with-open-file (f *watch-path* :direction :output :if-exists :supersede)
      (write-string "Edit me!" f)))
  (list :should-quit nil
        :event-count 0
        :last-event nil
        :last-path nil
        :status "Watching..."))

(defun file-watcher-update (msg state)
  (cond
    ;; File change notification from the :file-watch subscription
    ((and (consp msg) (eq (first msg) :file-changed))
     (let ((event (getf (rest msg) :event))
           (path (getf (rest msg) :path))
           (count (1+ (or (state-ref state :event-count) 0))))
       (make-update-result
        :patches `(((:event-count) ,count)
                   ((:last-event) ,event)
                   ((:last-path) ,path)
                   ((:status) ,(format nil "~A: ~A (#~D)" event path count))))))
    ;; Periodic tick to show the app is alive
    ((and (consp msg) (eq (first msg) :tick))
     (make-update-result))
    ;; Quit
    ((and (consp msg) (eq (first msg) :app-quit-requested))
     (make-update-result :patches '(((:should-quit) t))))
    (t (make-update-result))))

(defun file-watcher-view (state)
  (let ((status (or (state-ref state :status) "Idle"))
        (count (or (state-ref state :event-count) 0))
        (last-event (or (state-ref state :last-event) "-")))
    `(:container :id :root
       :style (:display :block :width 60 :height 7 :padding 1
               :bg-color :black :fg-color :white)
       :children
       ((:text :id :title
          :style (:fg-color :cyan)
          :content "File Watcher Demo")
        (:text :id :path-label
          :content ,(format nil "Path: ~A" *watch-path*))
        (:text :id :status-label
          :content ,(format nil "Status: ~A" status))
        (:text :id :event-label
          :content ,(format nil "Events: ~D  Last: ~A" count last-event))
        (:text :id :help
          :style (:fg-color :yellow)
          :content "Edit the file in another terminal. Press q to quit.")))))

(defun file-watcher-subscriptions (state)
  (declare (ignore state))
  (list
   ;; Watch the file for changes (polls every 0.5s by default)
   `(:file-watch (:path ,*watch-path* :message (:file-changed)))
   ;; Keep-alive tick to show the app is responsive
   '(:every (:seconds 1.0 :message (:tick)))))

(defapplication file-watcher-app
  :root-viewport-id :fw-root
  :root-component-dsl
  '(:root-viewport :id :fw-root :anchor :below-cursor
    :width 60 :height 7 :blank-on-exit t
    :child-dsl-spec (:view nil))
  :initial-state-fn #'%initial-state
  :update-fn #'file-watcher-update
  :view-fn #'file-watcher-view
  :subscriptions-fn #'file-watcher-subscriptions)

(defun run-file-watcher (&key (backend-type :terminal))
  (run-file-watcher-app :platform backend-type))
