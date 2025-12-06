;;;===============================================================
;;; Example: Cursor Inspector using the main Elmtui stack
;;;===============================================================

(uiop:define-package :elmtui-examples.cursor-inspector
  (:use :cl)
  (:import-from :elmtui.app
    #:defapplication
    #:run-application)
  (:import-from :elmtui.tea-state
    #:make-update-result
    #:state-ref)
  (:import-from :elmtui.core.event-types
    #:key-event
    #:key-event-key)
  (:import-from :elmtui.platform.tmux
    #:tmux-available-p
    #:capture-pane-string)
  (:export #:run-cursor-inspector))

(in-package :elmtui-examples.cursor-inspector)

(defparameter +default-width+ 80)
(defparameter +default-height+ 24)

(defun %split-lines (content)
  (let ((lines (uiop:split-string (or content "")
                 :separator '(#\Newline)
                 )))
    (coerce lines 'vector)))

(defun capture-lines (&key (mode :pane))
  (if (tmux-available-p)
    (%split-lines (capture-pane-string :mode mode))
    (make-array 0 :element-type 'string)))

(defun initial-inspector-state ()
  (let ((tmux? (tmux-available-p))
         (mode :pane))
    (let ((lines (capture-lines :mode mode)))
      `(:tmux-enabled ,tmux?
         :cursor-x 0
         :cursor-y 0
         :lines ,lines
         :mode ,mode
         :last-refresh ,(get-universal-time)))))

(defun %line-count (lines)
  (length lines))

(defun %line-at (lines row)
  (if (and lines (< row (length lines)))
    (aref lines row)
    ""))

(defun %line-length (lines row)
  (length (%line-at lines row)))

(defun %clamp (value min-value max-value)
  (max min-value (min max-value value)))

(defun %move-cursor (state dx dy)
  (let* ((lines (state-ref state :lines))
          (current-x (state-ref state :cursor-x))
          (current-y (state-ref state :cursor-y))
          (new-y (%clamp (+ current-y dy) 0 (max 0 (1- (%line-count lines)))))
          (max-x (max 0 (1- (%line-length lines new-y))))
          (new-x (%clamp (+ current-x dx) 0 max-x)))
    (make-update-result :patches `((:cursor-x ,new-x)
                                    (:cursor-y ,new-y)))))

(defun refresh-capture (state)
  (let ((mode (state-ref state :mode)))
    (make-update-result
      :patches `((:lines ,(capture-lines :mode mode))
                  (:last-refresh ,(get-universal-time))))))

(defun cursor-inspector-update (message app-state)
  (cond
    ((and (typep message 'key-event)
       (eq (key-event-key message) #\q))
      (make-update-result :patches '((:should-quit t))))

    ((and (typep message 'key-event)
       (eq (key-event-key message) #\r))
      (refresh-capture app-state))

    ((and (typep message 'key-event)
       (eq (key-event-key message) #\R))
      (refresh-capture app-state))

    ((and (typep message 'key-event)
       (member (key-event-key message) '(#\h #\H)))
      (%move-cursor app-state -1 0))
    ((and (typep message 'key-event)
       (member (key-event-key message) '(#\l #\L)))
      (%move-cursor app-state 1 0))
    ((and (typep message 'key-event)
       (member (key-event-key message) '(#\k #\K)))
      (%move-cursor app-state 0 -1))
    ((and (typep message 'key-event)
       (member (key-event-key message) '(#\j #\J)))
      (%move-cursor app-state 0 1))

    (t
      (make-update-result))))

(defun format-line-with-cursor (line cursor-x cursor-y row)
  (if (/= row cursor-y)
    line
    (let* ((len (length line))
            (pos (min cursor-x (max 0 (1- (max len 1)))))
            (left (subseq line 0 (min pos len)))
            (right (if (< pos len) (subseq line pos) ""))
            (cursor-char (if (< pos len) (aref line pos) #\Space)))
      (format nil "~A[~C]~A" left cursor-char right))))

(defun render-snapshot-lines (lines cursor-x cursor-y)
  (loop for row from 0 below (min 20 (length lines)) collect
    (let ((line (format-line-with-cursor
                  (%line-at lines row) cursor-x cursor-y row)))
      `(:text :style (:width :fill)
         :content ,(format nil "~3,'0d: ~A" row line)))))

(defun describe-cell (lines cursor-x cursor-y)
  (let* ((line (%line-at lines cursor-y))
          (len (length line))
          (char (if (and (< len 1)
                      (>= cursor-x len))
                  #\Space
                  (if (< cursor-x len)
                    (aref line cursor-x)
                    #\Space))))
    (list
      `(:text :content ,(format nil "Cursor: (~D, ~D)" cursor-x cursor-y))
      `(:text :content ,(format nil "Char Code: ~D" (char-code char)))
      `(:text :content ,(format nil "Printable: ~A"
                          (if (graphic-char-p char) char " ")))
      `(:text :content ,(format nil "Line length: ~D" len)))))

(defun cursor-inspector-view (app-state &key root-id)
  (declare (ignore root-id))
  (let* ((tmux? (state-ref app-state :tmux-enabled))
          (cursor-x (state-ref app-state :cursor-x))
          (cursor-y (state-ref app-state :cursor-y))
          (lines (state-ref app-state :lines)))
    (if (not tmux?)
      `(:container
         :style (:border t :padding 1 :width 60 :height 6)
         :children ((:text :content "tmux is not available.")
                     (:text :content "Start the app inside tmux to enable inspection.")))
      `(:container
         :style (:padding 1 :direction :row :gap 2)
         :children
         ((:container :style (:border t :padding 1 :width 80 :height 22
                               :flex-direction :column :overflow :hidden)
            :children
            ,(or (render-snapshot-lines lines cursor-x cursor-y)
               (list '(:text :content "No capture available"))))
           (:container :style (:border t :padding 1 :width 40 :height 22
                                :flex-direction :column :gap 1)
             :children
             (,@(describe-cell lines cursor-x cursor-y)
               (:text :content (format nil "Snapshot lines: ~D" (length lines)))
               (:text :content "Controls: h/j/k/l move, r refresh, q quit"))))))))

(defapplication cursor-inspector-app
  :root-viewport-id :cursor-inspector-root
  :initial-state-plist (initial-inspector-state)
  :root-component-dsl '(:layout :id :cursor-inspector-root)
  :update-fn 'cursor-inspector-update
  :view-fn 'cursor-inspector-view)

(defun run-cursor-inspector (&key (prefill-from-tmux t) (tmux-mode :pane) (backend-type :terminal))
  "Launch the cursor inspector example."
  (elmtui.app.api:run-application 'cursor-inspector-app
    :backend-type backend-type
    :platform-options (list :prefill-from-tmux prefill-from-tmux
                        :tmux-prefill-mode tmux-mode)))
