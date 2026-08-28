;;;===============================================================
;;; Example: Cursor Inspector using the main Elmtui stack
;;;
;;; A modern refactoring following elm-tui best practices with:
;;; - Object-only message handling (key-event)
;;; - Logging via log4cl for debugging
;;; - Modern API patterns from elmtui.state.api
;;; - Clean etypecase message dispatch
;;;===============================================================

(uiop:define-package :elmtui-examples.cursor-inspector
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.app
                #:defapplication)
  (:import-from :elmtui.state.api
                #:make-update-result
                #:state-ref)
  (:import-from :elmtui.core.event-types
                #:key-event
                #:key-event-key)
  (:import-from :elmtui.platform.tmux
                #:tmux-available-p
                #:capture-lines)
  (:export #:run-cursor-inspector))

(in-package :elmtui-examples.cursor-inspector)

;;;===============================================================
;;; Helper Functions
;;;===============================================================

(defun %split-lines (content)
  "Convert content string to a vector of lines."
  (let ((lines (uiop:split-string (or content "")
                                  :separator '(#\Newline))))
    (coerce lines 'vector)))

(defun initial-inspector-state ()
  "Create the initial application state."
  (let ((tmux? (tmux-available-p))
        (mode :pane))
    (log-info "cursor-inspector: Initializing with tmux-available=~S, mode=~S"
              tmux? mode)
    (let ((lines (if tmux?
                     (capture-lines :mode mode)
                     #())))
      `(:tmux-enabled ,tmux?
        :cursor-x 0
        :cursor-y 0
        :lines ,lines
        :mode ,mode
        :last-refresh ,(get-universal-time)))))

(defun %line-count (lines)
  "Get the number of lines."
  (length lines))

(defun %line-at (lines row)
  "Get the line at a given row, safely handling out of bounds."
  (if (and lines (< row (length lines)))
      (aref lines row)
      ""))

(defun %line-length (lines row)
  "Get the length of the line at a given row."
  (length (%line-at lines row)))

;;;===============================================================
;;; Update Function
;;;===============================================================

(defun cursor-inspector-update (message app-state)
  "Handle application messages following Elm architecture."
  (labels
    ;; Helper: Create quit result
    ((quit-result ()
       (log-info "cursor-inspector: Quit requested")
       (make-update-result :patches '(((:should-quit) t))))

     ;; Helper: Move cursor by dx/dy with bounds checking
     (move-cursor (dx dy)
       (let* ((lines (state-ref app-state :lines #()))
              (current-x (state-ref app-state :cursor-x 0))
              (current-y (state-ref app-state :cursor-y 0))
              (new-y (clamp (+ current-y dy) 0 (max 0 (1- (%line-count lines)))))
              (max-x (max 0 (1- (%line-length lines new-y))))
              (new-x (clamp (+ current-x dx) 0 max-x)))
         (log-info "cursor-inspector: Move cursor by (~D,~D): (~D,~D) -> (~D,~D)"
                   dx dy current-x current-y new-x new-y)
         (make-update-result
           :patches `(((:cursor-x) ,new-x)
                     ((:cursor-y) ,new-y)))))

     ;; Helper: Refresh tmux capture
     (refresh-capture ()
       (log-info "cursor-inspector: Refreshing tmux capture")
       (let ((mode (state-ref app-state :mode :pane)))
         (make-update-result
           :patches `(((:lines) ,(capture-lines :mode mode))
                     ((:last-refresh) ,(get-universal-time)))))))

    ;; Message dispatch using etypecase for type-based routing
    (etypecase message
      ;; Handle key events - object only, no list format support
      (key-event
       (let ((key (key-event-key message)))
         (log-debug "cursor-inspector: key event: ~S" key)
         (cond
           ;; Quit on 'q'
           ((eq key #\q)
            (quit-result))

           ;; Refresh on 'r' or 'R'
           ((member key '(#\r #\R))
            (refresh-capture))

           ;; Movement: h/H (left), l/L (right), k/K (up), j/J (down)
           ((member key '(#\h #\H))
            (move-cursor -1 0))
           ((member key '(#\l #\L))
            (move-cursor 1 0))
           ((member key '(#\k #\K))
            (move-cursor 0 -1))
           ((member key '(#\j #\J))
            (move-cursor 0 1))

           ;; Unhandled key - no-op
           (t
            (log-debug "cursor-inspector: Unhandled key: ~S" key)
            (make-update-result)))))

      ;; Unhandled message type - no-op
      (t
       (log-debug "cursor-inspector: Unhandled message type: ~S" (type-of message))
       (make-update-result)))))

;;;===============================================================
;;; View Function
;;;===============================================================

(defun format-line-with-cursor (line cursor-x cursor-y row)
  "Format a line with cursor indicator at the cursor row."
  (if (/= row cursor-y)
      line
      (let* ((len (length line))
             (pos (min cursor-x (max 0 (1- (max len 1)))))
             (left (subseq line 0 (min pos len)))
             (right (if (< pos len) (subseq line pos) ""))
             (cursor-char (if (< pos len) (aref line pos) #\Space)))
        (format nil "~A[~C]~A" left cursor-char right))))

(defun render-snapshot-lines (lines cursor-x cursor-y)
  "Render snapshot display with cursor overlay."
  (loop for row from 0 below (min 20 (length lines))
        collect (let ((line (format-line-with-cursor
                           (%line-at lines row) cursor-x cursor-y row)))
                 `(:text :style (:width :fill)
                         :content ,(format nil "~3,'0d: ~A" row line)))))

(defun describe-cell (lines cursor-x cursor-y)
  "Create DSL nodes describing the cell at the cursor position."
  (let* ((line (%line-at lines cursor-y))
         (len (length line))
         (char (if (and (< len 1) (>= cursor-x len))
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

(defun cursor-inspector-view (app-state)
  "Render the cursor inspector application."
  (let* ((tmux? (state-ref app-state :tmux-enabled nil))
         (cursor-x (state-ref app-state :cursor-x 0))
         (cursor-y (state-ref app-state :cursor-y 0))
         (lines (state-ref app-state :lines #())))
    (if (not tmux?)
        ;; Error: tmux not available
        `(:container
           :id :root
           :style (:border t :padding 1 :width 60 :height 6)
           :children
           ((:text :content "tmux is not available.")
            (:text :content "Start the app inside tmux to enable inspection.")))
        ;; Main UI: snapshot panel + info panel
        `(:container
           :id :root
           :style (:padding 1 :direction :row :gap 2)
           :children
           (;; Snapshot panel
            (:container
             :id :snapshot-panel
             :style (:border t :padding 1 :width 80 :height 22
                            :flex-direction :column :overflow :hidden)
             :children
             ,(render-snapshot-lines lines cursor-x cursor-y))

            ;; Info panel
            (:container
             :id :info-panel
             :style (:border t :padding 1 :width 40 :height 22
                            :flex-direction :column :gap 1)
             :children
             (,@(describe-cell lines cursor-x cursor-y)
               (:text :content ,(format nil "Snapshot lines: ~D" (length lines)))
               (:text :content "Controls: h/j/k/l move, r refresh, q quit"))))))))

;;;===============================================================
;;; Application Definition
;;;===============================================================

(defapplication cursor-inspector-app
  :root-viewport-id :cursor-inspector-root
  :root-component-dsl '(:root-viewport :id :cursor-inspector-root)
  :initial-state-fn #'initial-inspector-state
  :update-fn #'cursor-inspector-update
  :view-fn #'cursor-inspector-view)

;;;===============================================================
;;; Entry Point
;;;===============================================================

(defun run-cursor-inspector (&key (prefill-from-tmux t) (tmux-mode :pane) (backend-type :terminal))
  "Launch the cursor inspector through its generated runner."
  (log-info "Starting cursor-inspector with tmux-mode: ~S, backend: ~S" tmux-mode backend-type)
  (run-cursor-inspector-app
   :platform backend-type
   :platform-options (list :prefill-from-tmux prefill-from-tmux :tmux-prefill-mode tmux-mode)))
