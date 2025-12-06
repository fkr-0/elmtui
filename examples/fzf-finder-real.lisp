;;; Elmtui FZF-like Fuzzy Finder
;;; Integrates cl-fzy with TUI dropdown interface

(uiop:define-package :elmtui.examples.fzf-finder
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-info)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.tea-state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.app.api #:run-application)
  (:import-from :elmtui.core.event-types #:key-event #:key-event-key)
  (:import-from :cl-inputs #:default-keymap)
  (:export #:run-fzf-finder))

(in-package :elmtui.examples.fzf-finder)

;;;===================================================================
;; External Library Integration (cl-fzy)
;;;===================================================================

;; Assume cl-fzy is loaded and available
;; (ql:quickload :cl-fzy)
;; (use-package :cl-fzy)

;;;===================================================================
;; Finder State Management
;;;===================================================================

(defun make-initial-finder-state (items &key (prompt "Find: "))
  "Create initial state for fuzzy finder."
  `(:items ,items                      ; List of strings to search
     :prompt ,prompt                    ; Input prompt text
     :input-text ""                     ; Current search input
     :matches '()                       ; Current fuzzy matches
     :selected-index 0                  ; Currently selected item
     :visible-start 0                   ; First visible match index
     :visible-count 8                   ; Number of matches to show
     :callback nil                      ; Selected item callback
     :dropdown-visible nil              ; Whether dropdown is visible
     :should-quit nil                   ; Flag to quit application
     :screen-width 80                   ; Terminal width
     :screen-height 24))                ; Terminal height

(defun calculate-matches (items input-text)
  "Calculate fuzzy matches using cl-fzy integration."
  (if (or (null input-text) (string= input-text ""))
    ;; If no input, return all items in order
    (mapcar (lambda (item index)
              (list :item item :index index :score 0.0))
      items
      (iota (length items)))
    ;; Otherwise use fuzzy matching
    ;; This is a simplified version - integrate with actual cl-fzy here
    (let ((input (string-downcase input-text)))
      (sort (mapcar (lambda (item index)
                      (let ((item-lower (string-downcase item)))
                        (list :item item
                          :index index
                          :score (calculate-simple-fuzzy-score input item-lower))))
              items
              (iota (length items)))
        #'> :key (lambda (match) (getf match :score))))))

(defun calculate-simple-fuzzy-score (pattern text)
  "Simple fuzzy scoring (replace with cl-fzy:fuzzy-score)."
  (if (and pattern (> (length pattern) 0))
    (let ((pattern-idx 0)
           (score 0.0)
           (consecutive-matches 0))
      (loop for char across text
        for pattern-char = (when (< pattern-idx (length pattern))
                             (char pattern pattern-idx))
        do (cond
             ;; Exact match
             ((and pattern-char (char= char pattern-char))
               (incf pattern-idx)
               (incf consecutive-matches)
               (incf score (+ 10 (* consecutive-matches 2))))
             ;; No match, look ahead for pattern char
             ((and pattern-char (find char (subseq pattern pattern-idx)))
               (setf consecutive-matches 0) ; Reset consecutive bonus
               (incf score 1))
             (t
               (setf consecutive-matches 0))))
      finally (return (/ score (max 1 (length text))))))
  1.0) ; Perfect score for empty pattern

;;;===================================================================
;; Finder State Updates
;;;===================================================================

(defun update-finder-app (message app-state)
  "Update fuzzy finder state based on messages."
  (let ((current-input (state-ref app-state :input-text ""))
         (current-items (state-ref app-state :items '()))
         (selected-idx (state-ref app-state :selected-index 0))
         (callback (state-ref app-state :callback))))

  (cond
    ;; Input text changed
    ((eq message :input-changed)
      (let* ((new-text (second message))
              (matches (calculate-matches current-items new-text))
              (max-visible (min (state-ref app-state :visible-count 8) (length matches))))
        (make-update-result
          :patches `((:input-text ,new-text)
                      (:matches ,matches)
                      (:selected-index 0)
                      (:visible-start 0)
                      (:visible-count ,max-visible)
                      (:dropdown-visible ,(and (> (length matches) 0) (not (string= new-text ""))))))))

    ;; Listbox selection changed
    ((eq message :listbox-selected)
      (let* ((listbox-id (second message))
              (selected-index (third message)))
        (declare (ignore listbox-id))
        (make-update-result
          :patches `((:selected-index ,selected-index)))))

    ;; Item selected from listbox
    ((eq message :item-selected)
      (let* ((matches (state-ref app-state :matches '()))
              (selected-index (state-ref app-state :selected-index 0)))
        (when (and (< selected-index (length matches)) (>= selected-index 0))
          (let ((selected-item (getf (nth selected-index matches) :item)))
            ;; Call callback if provided
            (when callback (funcall callback selected-item))
            ;; Return quit command
            (make-update-result :patches '((:should-quit t)))))))

    ;; Handle key events
    ((typep message 'key-event)
      (let ((key (key-event-key message)))
        (case key
          ;; Escape or Ctrl-C to quit
          ((:escape #\c) ; Ctrl-C is #\c with control modifier
            (make-update-result :patches '((:should-quit t))))
          ;; Tab to toggle dropdown
          (:tab
            (make-update-result
              :patches `((:dropdown-visible ,(not (state-ref app-state :dropdown-visible nil))))))
          ;; Enter to select
          ((:enter :return)
            (if (state-ref app-state :dropdown-visible nil)
              ;; Select current item
              (let* ((matches (state-ref app-state :matches '()))
                      (selected-index (state-ref app-state :selected-index 0)))
                (when (and (< selected-index (length matches)) (>= selected-index 0))
                  (let ((selected-item (getf (nth selected-index matches) :item)))
                    ;; Call callback if provided
                    (when callback (funcall callback selected-item))
                    ;; Return quit command
                    (make-update-result :patches '((:should-quit t))))))
              ;; Hide dropdown
              (make-update-result
                :patches '((:dropdown-visible nil)))))
          ;; Up/down navigation handled by listbox component
          (t (make-update-result)))))

    ;; Set items
    ((eq message :set-items)
      (let ((new-items (second message)))
        (let ((matches (calculate-matches new-items current-input)))
          (make-update-result
            :patches `((:items ,new-items)
                        (:matches ,matches)
                        (:selected-index 0)
                        (:visible-start 0)
                        (:visible-count ,(min (state-ref app-state :visible-count 8) (length matches))))))))

    ;; Set callback
    ((eq message :set-callback)
      (let ((new-callback (second message)))
        (make-update-result
          :patches `((:callback ,new-callback)))))

    ;; Handle printable characters for input
    ((and (typep message 'key-event)
       (let ((ch (key-event-char message)))
         (and ch (>= (char-code ch) 32))))
      (let* ((current-input (state-ref app-state :input-text ""))
              (ch (key-event-char message))
              (new-input (concatenate 'string current-input (string ch))))
        (update-finder-app `(:input-changed ,new-input) app-state)))

    ;; Handle backspace
    ((and (typep message 'key-event)
       (member (key-event-key message) '(:backspace :delete) :test #'eq))
      (let* ((current-input (state-ref app-state :input-text ""))
              (new-input (if (plusp (length current-input))
                           (subseq current-input 0 (1- (length current-input)))
                           current-input)))
        (update-finder-app `(:input-changed ,new-input) app-state)))

    ;; Handle up/down arrows for navigation
    ((and (typep message 'key-event)
       (member (key-event-key message) '(:up :down) :test #'eq))
      (let* ((matches (state-ref app-state :matches '()))
              (selected-index (state-ref app-state :selected-index 0))
              (available (length matches))
              (delta (if (eq (key-event-key message) :up) -1 1))
              (new-index (mod (+ selected-index delta) (max 1 available))))
        (make-update-result
          :patches `((:selected-index ,new-index)))))

    ;; Screen resize
    ((eq message :screen-resized)
      (destructuring-bind (&key width height) (second message)
        (make-update-result
          :patches `((:screen-width ,width) (:screen-height ,height)))))

    (otherwise (make-update-result))))

;;;===================================================================
;; Finder View
;;;===================================================================

(defun view-finder-app (app-state)
  "Render the fuzzy finder interface."
  (let* ((prompt (state-ref app-state :prompt "Find: "))
          (input-text (state-ref app-state :input-text ""))
          (matches (state-ref app-state :matches '()))
          (selected-idx (state-ref app-state :selected-index 0))
          (dropdown-visible (state-ref app-state :dropdown-visible nil))
          (screen-width (state-ref app-state :screen-width 80))
          (screen-height (state-ref app-state :screen-height 24)))

    `(:root-viewport :id :main-viewport
       :anchor :below-cursor
       :children
       ((:layout :id :input-layout
          :direction :vertical
          :style (:width ,(min screen-width 60) :spacing 1)
          :children
          (;; Search prompt and input area
            (:layout :id :search-row
              :direction :horizontal
              :style (:width :fill)
              :children
              ((:text :id :prompt-text :text ,prompt)
                (:text :id :search-input-text :text ,input-text)))

            ;; Dropdown for matches (visible when we have matches and input)
            ,@(when (and dropdown-visible (> (length matches) 0))
                `((:layout :id :dropdown-layout
                    :direction :vertical
                    :style (:width ,(min screen-width 60) :height ,(min 8 (length matches))
                             :border t :border-style :single)
                    :children
                    ,@(loop for i from 0 below (min 8 (length matches))
                        for match = (nth i matches)
                        for item = (getf match :item)
                        for selected = (= i selected-idx)
                        collect `(:text :id ,(keyword (format nil "match-~d" i))
                                   :text ,(format nil "~a ~a"
                                            (if selected ">" " ")
                                            item)
                                   :style ,(when selected '(:background :blue)))))))

            ;; Help text
            (:text :id :help-text
              :text "[↑↓] Navigate [Enter] Select [Esc] Cancel [Tab] Toggle"
              :style (:foreground :gray))))))))

;;;===================================================================
;; Fuzzy Finder Application
;;;===================================================================

(elmtui.app:defapplication fzf-finder
  :initial-state-plist (make-initial-finder-state '())
  :update-fn #'update-finder-app
  :root-viewport-id :fzf-finder-root
  :root-component-dsl '(:layout :id :fzf-finder-root)
  :view-fn #'view-finder-app
  :subscriptions-fn (lambda (model) nil))

;;;===================================================================
;; Finder API
;;;===================================================================

(defun show-fzf-finder (items &key (prompt "Find: ") (callback nil) (screen-width 80) (screen-height 24))
  "Show fuzzy finder and return selected item or NIL.

   Example:
     (show-fzf-finder '(\"apple\" \"banana\" \"cherry\")
                    :prompt \"> \"
                    :callback (lambda (item) (format t \"Selected: ~A\" item)))"

  (let ((initial-state (make-initial-finder-state items :prompt prompt)))
    ;; Set callback and screen size
    (setf (getf initial-state :callback) callback)
    (setf (getf initial-state :screen-width) screen-width)
    (setf (getf initial-state :screen-height) screen-height)

    ;; Show dropdown immediately if we have items
    (when (> (length items) 0)
      (setf (getf initial-state :dropdown-visible) t))

    ;; Run the finder application
    (run-application 'fzf-finder :initial-state-plist initial-state)))

(defun %run-fzf-finder ()
  "Run a demo fuzzy finder with sample items."
  (let ((sample-items '("apple" "banana" "cherry" "date" "elderberry"
                         "fig" "grape" "honeydew" "kiwi" "lemon"
                         "mango" "nectarine" "orange" "pear" "quince"
                         "raspberry" "strawberry" "tangerine" "ugli fruit"
                         "vanilla" "watermelon" "xigua" "yellow passion fruit"
                         "zucchini" "apricot" "blackberry" "coconut"
                         "dragonfruit" "elderberry" "fig" "grapefruit")))

    (format t "~%Elmtui FZF-like Fuzzy Finder Demo~%~%")
    (format t "Try searching for: 'apple', 'berry', 'grape', etc.~%~%")
    (format t "The finder will drop below your cursor when you type.~%~%")

    (let ((selected (show-fzf-finder sample-items
                      :prompt "> "
                      :callback (lambda (item)
                                  (format t "~%You selected: ~A~%" item))
                      :screen-width 80
                      :screen-height 24)))
      (when selected
        (format t "~%Final selection: ~A~%" selected)))))

;;;===================================================================
;; Integration with stdin/items
;;;===================================================================

(defun run-fzf-on-stdin ()
  "Run fuzzy finder on items from stdin (simplified demo)."
  (let ((stdin-items '("line1" "line2" "line3" "line4" "line5"))) ; Replace with actual stdin read
    (show-fzf-finder stdin-items :prompt "filter> ")))

;;;===================================================================
;; Entry Point
;;;===================================================================

(defun main ()
  "Main entry point for fuzzy finder example."
  (run-fzf-finder))

;; Uncomment to run when loaded:
;; (main)
