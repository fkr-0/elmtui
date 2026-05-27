;;;===============================================================
;;; Tmux Hover Demo
;;;===============================================================

(uiop:define-package :elmtui-examples.tmux-hover-demo
  (:use :cl :log4cl)
  (:import-from :alexandria #:clamp)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.core.event-types
                #:key-event
                #:key-event-key)
  (:import-from :elmtui.state.api
                #:state-ref
                #:make-update-result)
  (:import-from :elmtui.core.async
                #:cmd-async)
  (:import-from :elmtui.platform.tmux
                #:tmux-available-p
                #:capture-lines)
  (:export #:run-tmux-hover-demo))

(in-package :elmtui-examples.tmux-hover-demo)

(defun %initial-state ()
  (let* ((tmux? (tmux-available-p))
         (capture-result (when tmux?
                           (handler-case
                               (capture-lines :mode :pane)
                             (error (e)
                               (list :error e)))))
         (capture-error (and (consp capture-result)
                             (eq (first capture-result) :error)
                             (second capture-result)))
         (lines (if capture-error #() (or capture-result #()))))
    (list :tmux-enabled tmux?
          :lines lines
          :status-message (cond
                            (capture-error (format nil "tmux capture failed: ~A" capture-error))
                            (tmux? "tmux capture loaded")
                            (t "tmux is not available"))
          :cursor-x 0
          :cursor-y 0
          :should-quit nil)))

(defun %line-at (lines row)
  (if (and lines (<= 0 row) (< row (length lines)))
      (aref lines row)
      ""))

(defun %clamp-cursor-to-lines (lines cursor-x cursor-y)
  (let* ((safe-lines (or lines #()))
         (max-y (max 0 (1- (length safe-lines))))
         (new-y (clamp cursor-y 0 max-y))
         (line (%line-at safe-lines new-y))
         (max-x (max 0 (1- (length line))))
         (new-x (clamp cursor-x 0 max-x)))
    (values new-x new-y)))

(defun %bounded-cursor (state dx dy)
  (let* ((lines (state-ref state :lines #()))
         (old-x (state-ref state :cursor-x 0))
         (old-y (state-ref state :cursor-y 0)))
    (%clamp-cursor-to-lines lines (+ old-x dx) (+ old-y dy))))

(defun hover-update (message app-state)
  (cond
    ((typep message 'key-event)
     (let ((key (key-event-key message)))
       (cond
         ((or (eql key #\q) (eql key #\Escape))
          (make-update-result :patches '(((:should-quit) t))))
         ((member key '(:up #\k #\K) :test #'eql)
          (multiple-value-bind (x y) (%bounded-cursor app-state 0 -1)
            (make-update-result :patches `(((:cursor-x) ,x) ((:cursor-y) ,y)))))
         ((member key '(:down #\j #\J) :test #'eql)
          (multiple-value-bind (x y) (%bounded-cursor app-state 0 1)
            (make-update-result :patches `(((:cursor-x) ,x) ((:cursor-y) ,y)))))
         ((member key '(:left #\h #\H) :test #'eql)
          (multiple-value-bind (x y) (%bounded-cursor app-state -1 0)
            (make-update-result :patches `(((:cursor-x) ,x) ((:cursor-y) ,y)))))
         ((member key '(:right #\l #\L) :test #'eql)
          (multiple-value-bind (x y) (%bounded-cursor app-state 1 0)
            (make-update-result :patches `(((:cursor-x) ,x) ((:cursor-y) ,y)))))
         ((member key '(#\r #\R) :test #'eql)
          ;; TEA: I/O must not happen in update-fn; dispatch capture as a command.
          (make-update-result
           :commands
           (list
            (cmd-async
             (lambda (progress-callback)
               (declare (ignore progress-callback))
               (handler-case
                   (if (tmux-available-p)
                       (capture-lines :mode :pane)
                       (list :tmux-lines-error "tmux is not available"))
                 (error (e)
                   (list :tmux-lines-error (format nil "~A" e)))))
             :on-complete
             (lambda (result)
               (if (and (consp result)
                        (eq (first result) :tmux-lines-error))
                   result
                   (list :tmux-lines-result result)))))))
         (t
          (make-update-result)))))
    ((and (listp message) (eq (first message) :tmux-lines-result))
     (let ((lines (second message)))
       (multiple-value-bind (x y)
           (%clamp-cursor-to-lines lines
                                   (state-ref app-state :cursor-x 0)
                                   (state-ref app-state :cursor-y 0))
         (make-update-result
          :patches `(((:lines) ,lines)
                     ((:status-message) "tmux capture refreshed")
                     ((:cursor-x) ,x)
                     ((:cursor-y) ,y))))))
    ((and (listp message) (eq (first message) :tmux-lines-error))
     (make-update-result
      :patches `(((:lines) ,#())
                 ((:status-message) ,(format nil "tmux capture failed: ~A" (second message))))))
    ((and (listp message) (eq (first message) :app-quit-requested))
     (make-update-result :patches '(((:should-quit) t))))
    (t
     (make-update-result))))

(defun hover-view (state)
  (let* ((lines (state-ref state :lines #()))
         (row (state-ref state :cursor-y 0))
         (col (state-ref state :cursor-x 0))
         (line (%line-at lines row))
         (char (if (and (< col (length line)) (<= 0 col)) (aref line col) #\Space))
         (tmux? (state-ref state :tmux-enabled nil))
         (status (state-ref state :status-message nil)))
    `(:container
       :id :tmux-hover-root
       :style (:display :flex :flex-direction :column :padding 1 :width 80 :height 10)
       :children
       ((:text :content ,(format nil "tmux-hover-demo ~A" (if tmux? "[TMUX]" "[NO-TMUX]")))
        (:text :content ,(or status "Move: arrows or h/j/k/l | r refresh | q quit"))
        (:text :content "Move: arrows or h/j/k/l | r refresh | q quit")
        (:text :content ,(format nil "Cursor: (~D, ~D) char=~C" col row char))
        (:text :content ,(format nil "Line: ~A" line))))))

(defapplication tmux-hover-app
  :root-viewport-id :tmux-hover-root
  :root-component-dsl '(:root-viewport :id :tmux-hover-root)
  :initial-state-fn #'%initial-state
  :update-fn #'hover-update
  :view-fn #'hover-view)

(defun run-tmux-hover-demo (&key (backend-type :terminal) (mode :pane))
  (log-info "tmux-hover-demo: start backend=~S mode=~S" backend-type mode)
  (run-tmux-hover-app
   :platform backend-type
   :platform-options (list :prefill-from-tmux t
                           :tmux-prefill-mode mode)))
