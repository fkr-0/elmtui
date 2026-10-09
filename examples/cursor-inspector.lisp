;;; Unified tmux cursor and history inspector.
(uiop:define-package :elmtui-examples.cursor-inspector
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:state-ref #:make-update-result)
  (:import-from :elmtui.core.event-types #:key-event #:key-event-key)
  (:import-from :elmtui.core.async #:cmd-async)
  (:import-from :elmtui.platform.tmux
                #:tmux-available-p #:capture-lines #:parse-ansi-string)
  (:export #:run-cursor-inspector #:initial-inspector-state
           #:cursor-inspector-update #:cursor-inspector-view
           #:%display-width #:%clamp-position #:%inspected-cell
           #:%capture-safe-p))

(in-package :elmtui-examples.cursor-inspector)

(defvar *inspector-launch-mode* :pane)

(defvar *inspector-launch-title* "CURSOR INSPECTOR")

(defun %capture (mode)
  (if (tmux-available-p)
      (handler-case
          (capture-lines :mode mode)
        (error () #()))
      #()))

(defun initial-inspector-state ()
  "Capture both interpretations before rendering any inspector UI."
  (let* ((available (tmux-available-p))
         (pane (%capture :pane))
         (scrollback (%capture :screen))
         (mode (if (eq *inspector-launch-mode* :screen) :screen :pane)))
    (list :tmux-enabled available
          :pane-lines pane :screen-lines scrollback
          :mode mode :lines (if (eq mode :screen) scrollback pane)
          :title *inspector-launch-title*
          :cursor-x 0 :cursor-y 0
          :status (if available "Snapshot captured before UI launch"
                      "No tmux session; inspect a local demonstration instead")
          :should-quit nil)))

(defun %raw-line (lines y)
  (if (and (vectorp lines) (<= 0 y) (< y (length lines)))
      (aref lines y)
      ""))

(defun %plain-line (raw)
  (handler-case
      (format nil "~{~A~}" (mapcar #'car (parse-ansi-string raw)))
    (error () (remove-if (lambda (c) (and (< (char-code c) 32)
                                         (not (char= c #\Tab))))
                         raw))))

(defun %zero-width-p (code)
  (or (= code 8205) (= code 8204)
      (<= 768 code 879) (<= 6832 code 6911)
      (<= 7616 code 7679) (<= 8400 code 8447)
      (<= 65024 code 65039) (<= 917760 code 917999)))

(defun %codepoint-width (char)
  "Conservative cell width. Zero-width marks do not advance columns."
  (let ((code (char-code char)))
    (cond ((or (%zero-width-p code) (< code 32)) 0)
          ((or (<= 4352 code 4447) (<= 9001 code 9002)
               (<= 11904 code 42191) (<= 44032 code 55203)
               (<= 63744 code 64255) (<= 65040 code 65055)
               (<= 65281 code 65376) (<= 65504 code 65510)
               (<= 127744 code 129791)) 2)
          (t 1))))

(defun %display-width (line)
  (loop for c across line sum (%codepoint-width c)))

(defun %inspected-cell (line column)
  "Return grapheme-like cluster, start column, and terminal-cell width.
A combining mark joins the prior base; a wide cell owns both columns."
  (let ((x 0) (text "") (start 0) (width 0) (clusters '()))
    (loop for c across line
          for w = (%codepoint-width c)
          do (if (and (zerop w) (plusp (length text)))
                 (setf text (concatenate 'string text (string c)))
                 (progn
                   (when (plusp (length text))
                     (push (list text start width) clusters))
                   (setf start x text (string c) width (max 1 w))
                   (incf x (max 1 w)))))
    (when (plusp (length text))
      (push (list text start width) clusters))
    (or (find-if (lambda (entry)
                   (<= (second entry) column
                       (1- (+ (second entry) (third entry)))))
                 clusters)
        (if clusters (car (last clusters)) (list " " 0 1)))))

(defun %clamp-position (lines x y)
  (let* ((row (max 0 (min y (max 0 (1- (length lines))))))
         (text (%plain-line (%raw-line lines row)))
         (width (%display-width text))
         (col (max 0 (min x (max 0 (1- width))))))
    (values (second (%inspected-cell text col)) row)))

(defun %cursor-move (state dx dy)
  (let* ((lines (state-ref state :lines #()))
         (x (state-ref state :cursor-x 0))
         (y (state-ref state :cursor-y 0))
         (text (%plain-line (%raw-line lines y)))
         (cell (%inspected-cell text x))
         (target-x (cond ((plusp dx) (+ (second cell) (third cell)))
                         ((minusp dx) (1- (second cell)))
                         (t x))))
    (multiple-value-bind (new-x new-y)
        (%clamp-position lines target-x (+ y dy))
      (if (and (= new-x x) (= new-y y))
          (make-update-result)
          (make-update-result
           :patches `(((:cursor-x) ,new-x) ((:cursor-y) ,new-y)))))))

(defun %capture-safe-p (lines)
  "A pane showing our rendered frame is not a usable underlay snapshot."
  (not (loop for raw across lines
             for plain = (%plain-line raw)
             thereis (or (search "CURSOR INSPECTOR" plain)
                         (search "tmux-hover-demo [TMUX]" plain)
                         (search "PANE / SCREEN" plain)))))

(defun %refresh-command (mode)
  (cmd-async
   (lambda (progress)
     (declare (ignore progress))
     (handler-case
         (if (tmux-available-p)
             (list :inspector-capture mode (capture-lines :mode mode))
             (list :inspector-capture-error "tmux unavailable"))
       (error (condition)
         (list :inspector-capture-error (princ-to-string condition)))))
   :on-complete #'identity))

(defun %switch-mode (state mode)
  (if (eq (state-ref state :mode :pane) mode)
      (make-update-result)
      (let ((lines (state-ref state
                              (if (eq mode :pane) :pane-lines :screen-lines)
                              #())))
        (multiple-value-bind (x y)
            (%clamp-position lines
                             (state-ref state :cursor-x 0)
                             (state-ref state :cursor-y 0))
          (make-update-result
           :patches `(((:mode) ,mode) ((:lines) ,lines)
                       ((:cursor-x) ,x) ((:cursor-y) ,y)
                       ((:status) "Switched cached underlay mode")))))))

(defun cursor-inspector-update (message state)
  (cond
    ((typep message 'key-event)
     (let ((key (key-event-key message)))
       (cond
         ((member key '(:q :escape :esc :ctrl-c :control-c #\q #\Q #\Escape)
                  :test #'eql)
          (make-update-result :patches '(((:should-quit) t))))
         ((member key '(:up :arrow-up :k #\k #\K) :test #'eql)
          (%cursor-move state 0 -1))
         ((member key '(:down :arrow-down :j #\j #\J) :test #'eql)
          (%cursor-move state 0 1))
         ((member key '(:left :arrow-left :h #\h #\H) :test #'eql)
          (%cursor-move state -1 0))
         ((member key '(:right :arrow-right :l #\l #\L) :test #'eql)
          (%cursor-move state 1 0))
         ((member key '(:page-up :pageup) :test #'eql)
          (%cursor-move state 0 -8))
         ((member key '(:page-down :pagedown) :test #'eql)
          (%cursor-move state 0 8))
         ((member key '(:home :g #\g) :test #'eql)
          (%cursor-move state (- (state-ref state :cursor-x 0)) 0))
         ((member key '(:end :shift-g #\G) :test #'eql)
          (%cursor-move state 0 999999))
         ((member key '(:m #\m #\M #\Tab) :test #'eql)
          (%switch-mode state (if (eq (state-ref state :mode :pane) :pane)
                                  :screen :pane)))
         ((member key '(:p #\p #\P) :test #'eql)
          (%switch-mode state :pane))
         ((member key '(:s #\s #\S) :test #'eql)
          (%switch-mode state :screen))
         ((member key '(:r #\r #\R) :test #'eql)
          (make-update-result :patches '(((:status) "Refresh requested"))
                              :commands (list (%refresh-command (state-ref state :mode :pane)))))
         (t (make-update-result)))))
    ((and (consp message) (eq (first message) :inspector-capture))
     (let* ((mode (second message))
            (lines (third message))
            (safe (and (vectorp lines) (%capture-safe-p lines))))
       (if (not safe)
           (make-update-result
            :patches '(((:status) "tmux capture refreshed safely: overlay excluded, cached underlay intact")))
           (multiple-value-bind (x y)
               (%clamp-position lines
                                (state-ref state :cursor-x 0)
                                (state-ref state :cursor-y 0))
             (make-update-result
              :patches `(((,(if (eq mode :pane) :pane-lines :screen-lines)) ,lines)
                          ((:lines) ,lines) ((:cursor-x) ,x) ((:cursor-y) ,y)
                          ((:status) "tmux capture refreshed")))))))
    ((and (consp message) (eq (first message) :inspector-capture-error))
     (make-update-result
      :patches `(((:status) ,(format nil "Refresh failed: ~A" (second message))))))
    ((and (consp message) (eq (first message) :app-quit-requested))
     (make-update-result :patches '(((:should-quit) t))))
    (t (make-update-result))))

(defun %slice-columns (line from max-width)
  "Clip by terminal cell columns without cutting a wide glyph."
  (with-output-to-string (out)
    (let ((x 0) (written 0))
      (loop for ch across line
            for width = (%codepoint-width ch)
            do (cond ((zerop width)
                      (when (plusp written) (write-char ch out)))
                     ((and (>= x from) (<= (+ written width) max-width))
                      (write-char ch out)
                      (incf written width)))
            do (incf x width)))))

(defun %snapshot-row (lines row x selected)
  (let* ((line (%plain-line (%raw-line lines row)))
         (cell (%inspected-cell line x))
         (col (second cell))
         (window-start (max 0 (- col 24)))
         (prefix (%slice-columns line window-start (max 0 (- col window-start))))
         (suffix (%slice-columns line (+ col (third cell)) 39))
         (preview (if selected
                      (format nil "~A[~A]~A" prefix (first cell) suffix)
                      (%slice-columns line 0 66))))
    (format nil "~:[ ~;>~] ~5,'0D │ ~A" selected (1+ row) preview)))

(defun %style-at (raw column)
  (handler-case
      (loop with x = 0
            for (fragment . style) in (parse-ansi-string raw)
            for next = (+ x (%display-width fragment))
            when (and (<= x column) (< column next))
              return style
            do (setf x next))
    (error () nil)))

(defun cursor-inspector-view (state)
  (let* ((lines (state-ref state :lines #()))
         (row (state-ref state :cursor-y 0))
         (col (state-ref state :cursor-x 0))
         (raw (%raw-line lines row))
         (plain (%plain-line raw))
         (cell (%inspected-cell plain col))
         (glyph (first cell))
         (mode (state-ref state :mode :pane))
         (title (state-ref state :title "CURSOR INSPECTOR"))
         (tmux? (state-ref state :tmux-enabled nil))
         (top (max 0 (min (- row 3) (max 0 (- (length lines) 7)))))
         (style (%style-at raw col)))
    `(:container :id :inspector-frame
       :style (:display :flex :flex-direction :column :width 78 :height 15
               :padding 1)
       :children
       ((:text :content ,(format nil "~A ~A" title (if tmux? "[TMUX]" "[NO-TMUX]"))
               :style (:fg-color :cyan :bold t))
        (:text :content ,(format nil "PANE / SCREEN  │  ~A  │  ~D rows  │  viewport ~D-~D"
                                (if (eq mode :pane) "PANE" "SCROLLBACK")
                                (length lines) (1+ top)
                                (min (length lines) (+ top 7))))
        (:text :content ,(state-ref state :status "Ready")
               :style (:fg-color :yellow))
        ,@(loop for i from top below (+ top 7)
                collect `(:text :content ,(%snapshot-row lines i col (= i row))
                         :style (:fg-color ,(if (= i row) :green :white))))
        (:text :content ,(format nil "Cursor: (~D, ~D)  Cell: ~S  U+~4,'0X  Width: ~D"
                                col row glyph (char-code (char glyph 0))
                                (third cell)))
        (:text :content ,(format nil "Line: ~D columns  Style: ~S  Clipped: ~A"
                                (%display-width plain) style
                                (if (> (%display-width plain) 66) "yes" "no")))
        (:text :content "MOVE  arrows/hjkl PgUp/PgDn  │  p pane / s scrollback / m toggle")
        (:text :content "r safe refresh  │  q/Esc quit  │  cached underlay never overwritten by UI")
        (:text :content "INSPECT / terminal-cell snapshot • screen coordinates 0-based")))))

(defapplication cursor-inspector-app
  :root-viewport-id :root
  :root-component-dsl
  '(:root-viewport :id :root
    :anchor :below-cursor
    :width 80 :height 15 :blank-on-exit nil
    :child-dsl-spec (:view nil))
  :initial-state-fn #'initial-inspector-state
  :update-fn #'cursor-inspector-update
  :view-fn #'cursor-inspector-view)

(defun run-cursor-inspector (&key (prefill-from-tmux t)
                                 (tmux-mode :pane) (backend-type :terminal)
                                 (title "CURSOR INSPECTOR"))
  "Cursor inspector; both entry points share this maintained implementation."
  (let ((*inspector-launch-mode* tmux-mode)
        (*inspector-launch-title* title))
    (run-cursor-inspector-app
     :platform backend-type
     :platform-options (list :prefill-from-tmux prefill-from-tmux
                             :tmux-prefill-mode tmux-mode
                             :use-alternate-screen t))))
