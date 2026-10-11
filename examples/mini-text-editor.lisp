;;;; Mini text editor -- self-contained ElmTUI TEA application.
;;;; Run with ELMTUI_EDITOR_FILE=/tmp/notes.txt ./scripts/examples.sh run mini-text-editor
(uiop:define-package :elmtui.examples.mini-text-editor
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:state-ref #:make-update-result)
  (:import-from :elmtui.core.async #:cmd-async)
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-key #:key-event-char
                #:key-event-modifiers)
  (:export #:run-mini-text-editor #:editor-update #:editor-view
           #:split-editor-lines #:join-editor-lines))
(in-package :elmtui.examples.mini-text-editor)

(defvar *editor-path* nil)
(defparameter +visible-editor-lines+ 12)

(elmtui.keymaps:define-keymap *mini-text-editor-keymap*
  ("C-q" :type :message :target '(:editor-request-quit)
          :description "Request quit with dirty-buffer guard"))

(defun split-editor-lines (text)
  "Preserve blank lines and a trailing newline as an empty final line."
  (coerce (loop with start = 0
                for end = (position #\Newline text :start start)
                collect (subseq text start end)
                while end do (setf start (1+ end)))
          'vector))

(defun join-editor-lines (lines)
  (format nil "~{~A~^~%~}" (coerce lines 'list)))

(defun %initial-state ()
  (let* ((path *editor-path*)
         (content (if (and path (probe-file path))
                      (uiop:read-file-string path :external-format :utf-8)
                      ""))
         (lines (split-editor-lines content)))
    (list :path path :lines lines :row 0 :col 0 :goal 0 :top 0
          :focus-manager '(:current-focus-id :mini-text-editor)
          :component-keymaps (list (cons :mini-text-editor *mini-text-editor-keymap*))
          :version 0 :saved-version 0 :dirty nil :saving nil
          :modal nil :dialog-input "" :quit-after-save nil
          :quit-armed nil :should-quit nil
          :status (if path "Ready | Ctrl+S save" "Scratch buffer | set ELMTUI_EDITOR_FILE to save"))))

(defun %line (lines row)
  (aref lines row))

(defun %clamp-col (lines row col)
  (min (max 0 col) (length (%line lines row))))

(defun %visible-top (top row)
  (cond ((< row top) row)
        ((>= row (+ top +visible-editor-lines+))
         (- row (1- +visible-editor-lines+)))
        (t top)))

(defun %cursor-result (state row col &key (goal col))
  (let* ((lines (state-ref state :lines))
         (r (min (max 0 row) (1- (length lines))))
         (c (%clamp-col lines r col)))
    (make-update-result
     :patches `(((:row) ,r) ((:col) ,c) ((:goal) ,goal)
                ((:top) ,(%visible-top (state-ref state :top 0) r))
                ((:quit-armed) nil)))))

(defun %edit-result (state lines row col)
  (make-update-result
   :patches `(((:lines) ,lines)
              ((:row) ,row) ((:col) ,col) ((:goal) ,col)
              ((:top) ,(%visible-top (state-ref state :top 0) row))
              ((:version) ,(1+ (state-ref state :version 0)))
              ((:dirty) t) ((:quit-armed) nil)
              ((:status) "Modified | Ctrl+S save"))))

(defun %insert-char (state char)
  (let* ((lines (copy-seq (state-ref state :lines)))
         (row (state-ref state :row 0))
         (col (state-ref state :col 0))
         (line (%line lines row)))
    (setf (aref lines row)
          (concatenate 'string (subseq line 0 col) (string char)
                       (subseq line col)))
    (%edit-result state lines row (1+ col))))

(defun %insert-newline (state)
  (let* ((lines (state-ref state :lines))
         (row (state-ref state :row 0))
         (col (state-ref state :col 0))
         (line (%line lines row))
         (new (concatenate 'vector
                           (subseq lines 0 row)
                           (vector (subseq line 0 col) (subseq line col))
                           (subseq lines (1+ row)))))
    (%edit-result state new (1+ row) 0)))

(defun %backspace (state)
  (let* ((lines (state-ref state :lines))
         (row (state-ref state :row 0))
         (col (state-ref state :col 0))
         (line (%line lines row)))
    (cond ((plusp col)
           (let ((new (copy-seq lines)))
             (setf (aref new row)
                   (concatenate 'string (subseq line 0 (1- col))
                                (subseq line col)))
             (%edit-result state new row (1- col))))
          ((plusp row)
           (let* ((previous (%line lines (1- row)))
                  (new (concatenate 'vector
                                    (subseq lines 0 (1- row))
                                    (vector (concatenate 'string previous line))
                                    (subseq lines (1+ row)))))
             (%edit-result state new (1- row) (length previous))))
          (t (make-update-result)))))

(defun %delete-forward (state)
  (let* ((lines (state-ref state :lines))
         (row (state-ref state :row 0))
         (col (state-ref state :col 0))
         (line (%line lines row)))
    (cond ((< col (length line))
           (let ((new (copy-seq lines)))
             (setf (aref new row)
                   (concatenate 'string (subseq line 0 col)
                                (subseq line (1+ col))))
             (%edit-result state new row col)))
          ((< row (1- (length lines)))
           (let ((new (concatenate 'vector
                                   (subseq lines 0 row)
                                   (vector (concatenate 'string line (%line lines (1+ row))))
                                   (subseq lines (+ row 2)))))
             (%edit-result state new row col)))
          (t (make-update-result)))))

(defun %move-vertical (state delta)
  (let* ((lines (state-ref state :lines))
         (row (min (max 0 (+ (state-ref state :row 0) delta))
                   (1- (length lines))))
         (goal (state-ref state :goal (state-ref state :col 0))))
    (%cursor-result state row (%clamp-col lines row goal) :goal goal)))

(defun %write-file (path lines)
  (with-open-file (stream path :direction :output
                          :if-exists :supersede :if-does-not-exist :create
                          :external-format :utf-8)
    (write-string (join-editor-lines lines) stream)
    (finish-output stream))
  path)

(defun %save-command (path lines version)
  ;; Snapshot the buffer; a later edit must not be marked clean by this save.
  (cmd-async (lambda (progress)
               (declare (ignore progress))
               (%write-file path lines))
             :on-complete (lambda (saved-path)
                            (list :editor-saved saved-path version))
             :on-error (lambda (condition)
                         (list :editor-save-failed (princ-to-string condition)))))

(defun %request-quit (state)
  (if (state-ref state :dirty nil)
      (make-update-result
       :patches `(((:modal)
                   ,(elmtui.ui.widgets.modal-dialog:open-modal-dialog
                     :title "Unsaved changes"
                     :message "Save, discard or cancel?"
                     :choices '((#\s . :save) (#\d . :discard) (#\c . :cancel))))
                  ((:status) "Unsaved changes: choose Save, Discard or Cancel")))
      (make-update-result :patches '(((:should-quit) t)))))

(defun %event-parts (message)
  ;; Existing application runners may deliver the canonical :KEYEVENT plist
  ;; instead of a raw KEY-EVENT struct. Support both, like input-selector.
  (cond ((typep message 'key-event)
         (values (key-event-key message)
                 (key-event-char message)
                 (key-event-modifiers message)))
        ((and (consp message) (member (first message) '(:keyevent :key-event)))
         (values (getf (rest message) :key)
                 (getf (rest message) :char)
                 (getf (rest message) :modifiers)))
        (t (values nil nil nil))))

(defun %control-key-p (key char mods letter code)
  (or (eql char (code-char code))
      (and (or (member :control mods) (member :ctrl mods))
           (or (eql key letter)
               (and (characterp char) (char-equal char (char-downcase (char (symbol-name letter) 0))))))))

(defun %show-save-dialog (state &key (quit-after nil))
  (declare (ignore state))
  (make-update-result
   :patches `(((:modal)
               ,(elmtui.ui.widgets.modal-dialog:open-modal-dialog
                 :kind :prompt :title "Save As"
                 :message "Enter a filename"))
              ((:quit-after-save) ,quit-after)
              ((:status) "Save As: enter a filename"))))

(defun %start-save (state path &key (quit-after nil))
  (make-update-result
   :patches `(((:modal) nil) ((:saving) t)
              ((:quit-after-save) ,quit-after)
              ((:status) "Saving..."))
   :commands (list (%save-command path
                                  (copy-seq (state-ref state :lines))
                                  (state-ref state :version 0)))))

(defun %cancel-dialog ()
  (make-update-result
   :patches '(((:modal) nil) ((:quit-after-save) nil)
              ((:status) "Dialog cancelled"))))

(defun %overwrite-dialog (state path)
  (declare (ignore state))
  (make-update-result
   :patches `(((:dialog-input) ,path)
              ((:modal)
               ,(elmtui.ui.widgets.modal-dialog:open-modal-dialog
                 :title "Overwrite?"
                 :message (format nil "Replace existing file ~A?" path)
                 :choices '((#\y . :overwrite) (#\n . :retry))))
              ((:status) "Existing file: confirm overwrite"))))

(defun %modal-update (message state)
  "Capture dialog input before the editor may process any key."
  (multiple-value-bind (key char modifiers) (%event-parts message)
    (let ((dialog (state-ref state :modal)))
      (when (and (consp message) (eq (first message) :app-quit-requested))
        (return-from %modal-update (%cancel-dialog)))
      (multiple-value-bind (next result)
          (elmtui.ui.widgets.modal-dialog:modal-handle-key
           dialog key char modifiers)
        (if (null result)
            (make-update-result :patches `(((:modal) ,next)))
            (case (getf result :action)
              (:cancel (%cancel-dialog))
              (:discard
               (make-update-result
                :patches '(((:modal) nil) ((:should-quit) t))))
              (:save
               (if (state-ref state :path)
                   (%start-save state (state-ref state :path) :quit-after t)
                   (%show-save-dialog state :quit-after t)))
              (:accept
               (let ((path (getf result :value)))
                 (cond
                   ((uiop:directory-exists-p path)
                    (make-update-result
                     :patches '(((:status) "Filename is a directory"))))
                   ((probe-file path)
                    (%overwrite-dialog state path))
                   (t
                    (%start-save state path
                                 :quit-after (state-ref state :quit-after-save nil))))))
              (:overwrite
               (%start-save state (state-ref state :dialog-input)
                            :quit-after (state-ref state :quit-after-save nil)))
              (:retry
               (let ((reopen (%show-save-dialog state
                                                :quit-after (state-ref state :quit-after-save nil))))
                 reopen))
              (otherwise (%cancel-dialog))))))))

(defun %save-result (message state)
  (let* ((path (second message))
         (version (third message))
         (current (state-ref state :version 0))
         (quit-after (state-ref state :quit-after-save nil))
         (clean (= version current)))
    (make-update-result
     :patches `(((:path) ,path)
                ((:saving) nil) ((:quit-after-save) nil)
                ((:saved-version) ,version)
                ((:dirty) ,(not clean))
                ((:should-quit) ,(and quit-after clean))
                ((:status) ,(if clean "Saved"
                                "Saved previous version; buffer modified"))))))

(defun %editor-update-base (message state)
  (let ((row (state-ref state :row 0))
        (col (state-ref state :col 0)))
    (cond
      ((and (consp message) (eq (first message) :editor-saved))
       (let ((version (third message)))
         (make-update-result
          :patches `(((:saving) nil)
                     ((:saved-version) ,version)
                     ((:dirty) ,(/= version (state-ref state :version 0)))
                     ((:status) ,(if (= version (state-ref state :version 0))
                                     "Saved" "Saved previous version; buffer modified"))))))
      ((and (consp message) (eq (first message) :editor-save-failed))
       (make-update-result
        :patches `(((:saving) nil) ((:quit-after-save) nil)
                   ((:status) ,(format nil "Save failed: ~A" (second message))))))
      ((and (consp message) (eq (first message) :app-quit-requested))
       (%request-quit state))
      (t
       (multiple-value-bind (key char mods) (%event-parts message)
         (cond
           ((null key) (make-update-result))
           ((%control-key-p key char mods :q 17) (%request-quit state))
           ((or (eql key :escape) (eql key :esc))
            (%request-quit state))
           ((%control-key-p key char mods :s 19)
            (cond ((state-ref state :saving nil)
                   (make-update-result))
                  ((null (state-ref state :path))
                   (make-update-result :patches
                                       '(((:status) "No path: set ELMTUI_EDITOR_FILE or pass :path"))))
                  (t
                   (make-update-result
                    :patches '(((:saving) t) ((:status) "Saving..."))
                    :commands (list (%save-command
                                     (state-ref state :path)
                                     (copy-seq (state-ref state :lines))
                                     (state-ref state :version 0)))))))
           ((member key '(:left :arrow-left) :test #'eq)
            (if (plusp col)
                (%cursor-result state row (1- col))
                (if (plusp row)
                    (%cursor-result state (1- row)
                                    (length (%line (state-ref state :lines) (1- row))))
                    (make-update-result))))
           ((member key '(:right :arrow-right) :test #'eq)
            (if (< col (length (%line (state-ref state :lines) row)))
                (%cursor-result state row (1+ col))
                (if (< row (1- (length (state-ref state :lines))))
                    (%cursor-result state (1+ row) 0)
                    (make-update-result))))
           ((member key '(:up :arrow-up) :test #'eq) (%move-vertical state -1))
           ((member key '(:down :arrow-down) :test #'eq) (%move-vertical state 1))
           ((eq key :home) (%cursor-result state row 0))
           ((eq key :end)
            (%cursor-result state row (length (%line (state-ref state :lines) row))))
           ((member key '(:page-up :pageup) :test #'eq)
            (%move-vertical state (- +visible-editor-lines+)))
           ((member key '(:page-down :pagedown) :test #'eq)
            (%move-vertical state +visible-editor-lines+))
           ((member key '(:enter :return) :test #'eq) (%insert-newline state))
           ((eq key :backspace) (%backspace state))
           ((eq key :delete) (%delete-forward state))
           ((eq key :tab)
            (%insert-char state #\Space))
           ((and (characterp char) (graphic-char-p char)
                 (not (member :control mods)))
            (%insert-char state char))
           (t (make-update-result))))))))

(defun editor-update (message state)
  "Application-level dialog arbitration, then ordinary editing."
  (cond
    ((and (consp message) (eq (first message) :editor-saved))
     (%save-result message state))
    ((and (consp message) (eq (first message) :editor-save-failed))
     (%editor-update-base message state))
    ((state-ref state :modal)
     (%modal-update message state))
    ((and (consp message) (eq (first message) :editor-request-quit))
     (%request-quit state))
    ((and (consp message) (eq (first message) :app-quit-requested))
     (%request-quit state))
    (t
     (multiple-value-bind (key char mods) (%event-parts message)
       (cond
         ((and key (%control-key-p key char mods :q 17))
          (%request-quit state))
         ((and key (%control-key-p key char mods :s 19)
               (not (state-ref state :saving nil))
               (null (state-ref state :path)))
          (%show-save-dialog state))
         (t (%editor-update-base message state)))))))

(defun %row-display (text cursor-col active)
  (let* ((offset (if (and active (> cursor-col 55)) (- cursor-col 55) 0))
         (end (min (length text) (+ offset 62)))
         (start (subseq text offset end)))
    (if active
        (let ((cursor (- cursor-col offset)))
          (concatenate 'string
                       (subseq start 0 (min cursor (length start)))
                       "|"
                       (subseq start (min cursor (length start)))
                       (if (< end (length text)) "..." "")))
        (concatenate 'string start (if (< end (length text)) "..." "")))))

(defun %editor-title (path dirty)
  "Keep the title inside the editor border, even for long file paths."
  (let* ((prefix "Mini Text Editor | ")
         (mark (if dirty " *" ""))
         (name (or path "[scratch]"))
         (limit (- 72 (length prefix) (length mark)))
         (display (if (> (length name) limit)
                      (concatenate 'string "..."
                                   (subseq name (- (length name) (- limit 3))))
                      name)))
    (concatenate 'string prefix display mark)))

(defun editor-view (state)
  (let* ((lines (state-ref state :lines))
         (row (state-ref state :row 0))
         (col (state-ref state :col 0))
         (top (state-ref state :top 0))
         (path (state-ref state :path))
         (dirty (state-ref state :dirty nil)))
    `(:container
       :id :editor-root
       :style (:display :flex :flex-direction :column :width 78 :height 19
               :border t :border-style :single :border-width 1)
       :children
       ((:text :id :editor-header
          :content ,(%editor-title path dirty))
        (:text :id :editor-help
          :content "Arrows/Home/End/PgUp/PgDn move | Enter new line | Ctrl+S save | Ctrl+Q quit")
        ,@(loop for n below +visible-editor-lines+
                for i = (+ n top)
                unless (and (state-ref state :modal)
                            (< 4 n 9))
                  append (if (and (= n 4) (state-ref state :modal))
                             (elmtui.ui.widgets.modal-dialog:modal-dialog-view
                              (state-ref state :modal) :width 66)
                             (list `(:text
                                      :id ,(intern (format nil "EDITOR-ROW-~D" n) :keyword)
                                      :content ,(if (< i (length lines))
                                                    (format nil "~3D ~A ~A"
                                                            (1+ i) (if (= i row) ">" " ")
                                                            (%row-display (%line lines i)
                                                                          col (= i row)))
                                                    "~")))))
        (:text :id :editor-position
          :content ,(format nil "Ln ~D, Col ~D | ~D lines | ~A"
                            (1+ row) (1+ col) (length lines)
                            (or (state-ref state :status) "")))))))

(defapplication mini-text-editor-app
  :root-viewport-id :mini-editor-viewport
  :root-component-dsl '(:root-viewport :id :mini-editor-viewport
                        :anchor :below-cursor :width 78 :height 19
                        :blank-on-exit t :child-dsl-spec (:view nil))
  :initial-state-fn #'%initial-state
  :update-fn #'editor-update
  :view-fn #'editor-view)

(defun run-mini-text-editor (&key (backend-type :terminal) path)
  "Edit PATH (or ELMTUI_EDITOR_FILE); with neither, open a scratch buffer."
  (let ((*editor-path* (or path (uiop:getenv "ELMTUI_EDITOR_FILE"))))
    (run-mini-text-editor-app :platform backend-type)))

(defun main ()
  (run-mini-text-editor))
