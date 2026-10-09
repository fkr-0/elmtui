(defpackage :elmtui.workbench.app
  (:use :cl)
  (:import-from :elmtui.state.api :make-update-result :state-ref)
  (:export :run-workbench :workbench-update :workbench-view
           :*completion-keybinding-profile*
           :*completion-keybinding-overrides*
           :*completion-theme*
           :*inspector-theme*))
(in-package :elmtui.workbench.app)

(defparameter *completion-keybinding-profile* :default
  "Completion keybinding profile used for newly-created workbench sessions.")

(defparameter *completion-keybinding-overrides* nil
  "Alist of completion key overrides applied to newly-created workbench sessions.")

(defparameter *completion-theme*
  (elmtui.workbench.completion:make-completion-theme)
  "Completion theme used for newly-created workbench sessions.")

(defparameter *inspector-theme*
  (elmtui.workbench.inspector:make-inspector-theme)
  "Inspector theme used for newly-created workbench sessions.")

(defstruct (workbench (:constructor %make-workbench))
  editor repl inspector
  (width 80)
  (height 24)
  transcript
  (history nil)
  (next-request 0)
  active-request
  completion
  (selected 0)
  (generation 0)
  docs
  (dwell (elmtui.workbench.completion:make-documentation-dwell-state))
  completion-keys
  completion-theme
  (docs-enabled t)
  (show-inspector t)
  (focus :editor)
  (inspector-section :packages)
  inspector-snapshot
  (inspector-selected 0)
  (inspector-query "")
  (inspector-query-mode nil)
  inspector-package
  inspector-theme
  (scroll 0)
  (status "Ready"))

(defun %workbench-initial ()
  (let ((wb (%make-workbench
             :editor (elmtui.workbench.editor:make-editor-state :columns 77)
             :repl (elmtui.workbench.eval:make-repl-session)
             :inspector (elmtui.workbench.inspector:make-inspector-session)
             :completion-keys
             (elmtui.workbench.completion:make-completion-keybinding-config
              :profile *completion-keybinding-profile*
              :overrides *completion-keybinding-overrides*)
             :completion-theme *completion-theme*
             :inspector-theme *inspector-theme*)))
    (setf (workbench-inspector-snapshot wb)
          (elmtui.workbench.inspector:snapshot-image
           (workbench-inspector wb) 0 :section :packages))
    (list :workbench wb :revision 0 :should-quit nil)))

(defun %append-line (wb line)
  (when (plusp (length line))
    (push (subseq line 0 (min 512 (length line))) (workbench-transcript wb)))
  (when (> (length (workbench-transcript wb)) 500)
    (setf (workbench-transcript wb)
          (subseq (workbench-transcript wb) 0 500))))

(defun %append-output (wb string)
  (loop with start = 0
        for end = (position #\Newline string :start start)
        do (%append-line wb (subseq string start (or end (length string))))
        while end do (setf start (1+ end))))

(defun %clear-completion (wb)
  (setf (workbench-completion wb) nil
        (workbench-selected wb) 0
        (workbench-docs wb) nil)
  (elmtui.workbench.completion:cancel-documentation-dwell
   (workbench-dwell wb)))

(defun %candidates (wb)
  (and (workbench-completion wb)
       (elmtui.workbench.completion:completion-result-candidates
        (workbench-completion wb))))

(defun %selected-candidate (wb)
  (nth (workbench-selected wb) (%candidates wb)))

(defun %schedule-docs (wb)
  (setf (workbench-docs wb) nil)
  (elmtui.workbench.completion:cancel-documentation-dwell
   (workbench-dwell wb))
  (when (and (workbench-docs-enabled wb) (%selected-candidate wb))
    (elmtui.workbench.completion:schedule-documentation-dwell
     (workbench-dwell wb) (%selected-candidate wb)
     (workbench-generation wb) :delay-ms 450)))

(defun %complete (wb)
  (incf (workbench-generation wb))
  (let* ((ed (workbench-editor wb))
         (result (elmtui.workbench.completion:complete-at
                  (workbench-repl wb)
                  (elmtui.workbench.editor:editor-text ed)
                  (elmtui.workbench.editor:editor-state-cursor ed)
                  (workbench-generation wb))))
    (%clear-completion wb)
    (when (and (elmtui.workbench.completion:completion-current-p
                result (workbench-generation wb))
               (elmtui.workbench.completion:completion-result-candidates result))
      (setf (workbench-completion wb) result)
      (%schedule-docs wb))
    (setf (workbench-status wb)
          (format nil "~D completion candidates" (length (%candidates wb))))))

(defun %accept (wb)
  (let ((candidate (%selected-candidate wb))
        (result (workbench-completion wb))
        (ed (workbench-editor wb)))
    (when candidate
      (let ((end (elmtui.workbench.completion:completion-result-end result))
            (start (elmtui.workbench.completion:completion-result-start result)))
        (loop while (< (elmtui.workbench.editor:editor-state-cursor ed) end)
              do (elmtui.workbench.editor:editor-move-cursor ed :right))
        (loop while (> (elmtui.workbench.editor:editor-state-cursor ed) start)
              do (elmtui.workbench.editor:editor-backspace ed))
        (elmtui.workbench.editor:editor-insert-text
         ed (elmtui.workbench.completion:completion-candidate-insertion candidate)))
      (%clear-completion wb)
      (incf (workbench-generation wb))
      t)))

(defparameter +inspector-sections+
  '(:packages :symbols :watches :asdf-systems :threads :diagnostics))

(defun %current-inspector-package (wb)
  (or (workbench-inspector-package wb)
      (package-name
       (elmtui.workbench.eval:repl-session-package
        (workbench-repl wb)))))

(defun %refresh-inspector (wb &optional (section (workbench-inspector-section wb)))
  (unless (eq section (workbench-inspector-section wb))
    (setf (workbench-inspector-selected wb) 0))
  (setf (workbench-inspector-section wb) section
        (workbench-inspector-snapshot wb)
        (elmtui.workbench.inspector:snapshot-image
         (workbench-inspector wb)
         (workbench-generation wb)
         :section section
         :package (%current-inspector-package wb)
         :query (workbench-inspector-query wb)
         :refresh t))
  (workbench-inspector-snapshot wb))

(defun %inspector-entries (wb)
  (getf (workbench-inspector-snapshot wb) :entries))

(defun %selected-inspector-entry (wb)
  (nth (workbench-inspector-selected wb) (%inspector-entries wb)))

(defun %move-inspector-selection (wb delta)
  (let ((entries (%inspector-entries wb)))
    (when entries
      (setf (workbench-inspector-selected wb)
            (mod (+ (workbench-inspector-selected wb) delta)
                 (length entries)))
      t)))

(defun %cycle-inspector-section (wb delta)
  (let* ((current (position (workbench-inspector-section wb)
                            +inspector-sections+))
         (next (mod (+ (or current 0) delta)
                    (length +inspector-sections+))))
    (%refresh-inspector wb (nth next +inspector-sections+))
    (setf (workbench-status wb)
          (format nil "Inspector: ~A" (workbench-inspector-section wb)))
    t))

(defun %toggle-selected-watch (wb)
  (let* ((entry (%selected-inspector-entry wb))
         (symbol (and entry (getf entry :symbol))))
    (if (not (symbolp symbol))
        (setf (workbench-status wb) "Selected inspector row is not watchable")
        (if (member symbol
                    (elmtui.workbench.inspector:watched-variables
                     (workbench-inspector wb))
                    :test #'eq)
            (progn
              (elmtui.workbench.inspector:unwatch-variable
               (workbench-inspector wb) symbol)
              (setf (workbench-status wb)
                    (format nil "Unwatched ~A" symbol)))
            (progn
              (elmtui.workbench.inspector:watch-variable
               (workbench-inspector wb) symbol)
              (setf (workbench-status wb)
                    (format nil "Watching ~A" symbol)))))
    (%refresh-inspector wb)
    t))

(defun %watch-snapshot-signature (snapshot)
  (mapcar
   (lambda (entry)
     (list (getf entry :id)
           (getf entry :boundp)
           (getf entry :changed)
           (getf entry :preview)
           (getf entry :style-role)))
   (getf snapshot :entries)))

(defun %refresh-live-watches (wb)
  (when (and (workbench-show-inspector wb)
             (eq (workbench-inspector-section wb) :watches))
    (let* ((old (workbench-inspector-snapshot wb))
           (fresh
             (elmtui.workbench.inspector:snapshot-image
              (workbench-inspector wb)
              (workbench-generation wb)
              :section :watches
              :query (workbench-inspector-query wb))))
      (unless (equal (%watch-snapshot-signature old)
                     (%watch-snapshot-signature fresh))
        (setf (workbench-inspector-snapshot wb) fresh)
        (let ((count (length (getf fresh :entries))))
          (when (or (zerop count)
                    (>= (workbench-inspector-selected wb) count))
            (setf (workbench-inspector-selected wb) 0)))
        t))))

(defun %submit (wb)
  (let ((source (elmtui.workbench.editor:editor-text (workbench-editor wb))))
    (when (plusp (length (string-trim '(#\Space #\Tab #\Newline) source)))
      (let ((id (incf (workbench-next-request wb))))
        (%append-output wb (format nil "~A> ~A"
                                   (package-name
                                    (elmtui.workbench.eval:repl-session-package
                                     (workbench-repl wb))) source))
        (elmtui.workbench.eval:request-evaluation (workbench-repl wb) source id)
        (push source (workbench-history wb))
        (setf (workbench-editor wb)
              (elmtui.workbench.editor:make-editor-state
               :columns (max 1 (- (workbench-width wb) 4))
               :history (workbench-history wb))
              (workbench-active-request wb) id
              (workbench-scroll wb) 0
              (workbench-status wb) "Evaluating...")
        (%clear-completion wb)
        t))))

(defun %eval-events (wb)
  (let ((changed nil))
    (dolist (event (elmtui.workbench.eval:poll-evaluation (workbench-repl wb)))
      (setf changed t)
      (case (getf event :type)
        ((:stdout :stderr :value)
         (%append-output wb (or (getf event :text) "")))
        (:condition
         (let ((text (or (getf event :text) "Evaluation error")))
           (%append-output wb (concatenate 'string "ERROR: " text))
           (elmtui.workbench.inspector:record-diagnostic
            (workbench-inspector wb)
            (or (getf event :condition-type) "ERROR") text
            :request-id (getf event :request-id))))
        (:aborted
         (setf (workbench-status wb) "Cancelled"))
        (:finished
         (setf (workbench-active-request wb) nil
               (workbench-status wb)
               (format nil "Evaluation ~A" (getf event :status)))
         (%refresh-inspector wb))))
    (when (elmtui.workbench.completion:consume-documentation-dwell
           (workbench-dwell wb)
           (workbench-generation wb)
           (%selected-candidate wb))
      (let* ((candidate (%selected-candidate wb))
             (signature
               (elmtui.workbench.completion:signature-for candidate))
             (documentation
               (elmtui.workbench.completion:documentation-for
                candidate :max-length 400)))
        (setf (workbench-docs wb)
              (list :signature signature
                    :documentation
                    (or documentation "No documentation available"))))
      (setf changed t))
    (when (%refresh-live-watches wb)
      (setf changed t))
    changed))

(defun %key-parts (message)
  (cond
    ((typep message 'elmtui.core.event-types:key-event)
     (values (elmtui.core.event-types:key-event-key message)
             (elmtui.core.event-types:key-event-char message)
             (elmtui.core.event-types:key-event-modifiers message)))
    ((and (consp message) (member (car message) '(:keyevent :key-event)))
     (values (getf (cdr message) :key)
             (getf (cdr message) :char)
             (getf (cdr message) :modifiers)))
    (t (values nil nil nil))))

(defun %control-p (modifiers)
  (or (member :control modifiers) (member :ctrl modifiers)))

(defun %alt-p (modifiers)
  (or (member :alt modifiers) (member :meta modifiers)))

(defun %shift-p (modifiers)
  (member :shift modifiers))

(defun %event-character (key character)
  (or character
      (and (characterp key) key)
      (and (symbolp key)
           (let ((name (symbol-name key)))
             (cond
               ((= (length name) 1) (char name 0))
               ((member key '(:space :spacebar) :test #'eq) #\Space)
               ((eq key :slash) #\/)
               (t nil))))))

(defun %completion-key-string (key character modifiers)
  (let* ((ctrl (%control-p modifiers))
         (alt (%alt-p modifiers))
         (shift (%shift-p modifiers))
         (char (%event-character key character)))
    (cond
      ((or (and ctrl (char= (or char #\Null) #\Space))
           (eql character (code-char 0)))
       "Ctrl+Space")
      ((and ctrl (member key '(:enter :return) :test #'eq))
       "Ctrl+Enter")
      ((and ctrl char (graphic-char-p char))
       (format nil "C-~C" (char-upcase char)))
      ((and alt char (graphic-char-p char))
       (format nil "M-~C" (char-upcase char)))
      ((and shift (eq key :tab)) "BackTab")
      ((member key '(:arrow-up :up) :test #'eq) "Up")
      ((member key '(:arrow-down :down) :test #'eq) "Down")
      ((member key '(:arrow-left :left) :test #'eq) "Left")
      ((member key '(:arrow-right :right) :test #'eq) "Right")
      ((member key '(:return :enter) :test #'eq) "Enter")
      ((member key '(:pageup :page-up) :test #'eq) "PageUp")
      ((member key '(:pagedown :page-down) :test #'eq) "PageDown")
      ((eq key :escape) "Escape")
      ((eq key :tab) "Tab")
      ((eq key :f2) "F2")
      ((eq key :f3) "F3")
      ((eq key :f4) "F4")
      ((and char (graphic-char-p char)) (string char))
      (t nil))))

(defun %key-name (key character modifiers)
  (let ((ctrl (%control-p modifiers))
        (shift (%shift-p modifiers)))
    (cond
      ((and ctrl (member key '(:enter :return) :test #'eq)) :ctrl-enter)
      ((or (eql character (code-char 3))
           (and ctrl (member key '(:c #\c #\C) :test #'eql))) :ctrl-c)
      ((or (eql character (code-char 4))
           (and ctrl (member key '(:d #\d #\D) :test #'eql))) :ctrl-d)
      ((and ctrl (member key '(:r #\r #\R) :test #'eql)) :ctrl-r)
      ((and shift (eq key :tab)) :backtab)
      ((member key '(:arrow-up :up) :test #'eq) :up)
      ((member key '(:arrow-down :down) :test #'eq) :down)
      ((member key '(:arrow-left :left) :test #'eq) :left)
      ((member key '(:arrow-right :right) :test #'eq) :right)
      ((member key '(:return :enter) :test #'eq) :enter)
      ((member key '(:pageup :page-up) :test #'eq) :page-up)
      ((member key '(:pagedown :page-down) :test #'eq) :page-down)
      ((member key '(:f2 :f3 :f4 :escape :tab :backspace :delete :home :end)
               :test #'eq) key)
      ((and character (graphic-char-p character) (not ctrl)) character)
      ((and (characterp key) (graphic-char-p key) (not ctrl)) key)
      (t nil))))

(defun %move-completion-selection (wb delta)
  (let ((candidates (%candidates wb)))
    (when candidates
      (setf (workbench-selected wb)
            (mod (+ (workbench-selected wb) delta)
                 (length candidates)))
      (%schedule-docs wb)
      t)))

(defun %handle-completion-command (wb command)
  (case command
    (:open
     (when (eq (workbench-focus wb) :editor)
       (%complete wb)
       t))
    (:accept
     (and (%candidates wb) (%accept wb)))
    (:next
     (%move-completion-selection wb 1))
    (:previous
     (%move-completion-selection wb -1))
    (:dismiss
     (when (workbench-completion wb)
       (%clear-completion wb)
       t))
    (:toggle-docs
     (setf (workbench-docs-enabled wb)
           (not (workbench-docs-enabled wb)))
     (if (workbench-docs-enabled wb)
         (%schedule-docs wb)
         (progn
           (setf (workbench-docs wb) nil)
           (elmtui.workbench.completion:cancel-documentation-dwell
            (workbench-dwell wb))))
     (setf (workbench-status wb)
           (if (workbench-docs-enabled wb)
               "Completion docs enabled"
               "Completion docs disabled"))
     t)
    (:page-next
     (%move-completion-selection wb 5))
    (:page-previous
     (%move-completion-selection wb -5))
    (otherwise nil)))

(defun %handle-inspector-key (wb key)
  (cond
    ((workbench-inspector-query-mode wb)
     (cond
       ((eq key :escape)
        (setf (workbench-inspector-query-mode wb) nil
              (workbench-inspector-query wb) "")
        (%refresh-inspector wb)
        (setf (workbench-status wb) "Inspector filter cleared")
        t)
       ((eq key :enter)
        (setf (workbench-inspector-query-mode wb) nil
              (workbench-status wb)
              (format nil "Filter: ~A" (workbench-inspector-query wb)))
        t)
       ((eq key :backspace)
        (let ((query (workbench-inspector-query wb)))
          (when (plusp (length query))
            (setf (workbench-inspector-query wb)
                  (subseq query 0 (1- (length query)))))
          (%refresh-inspector wb)
          (setf (workbench-status wb)
                (format nil "Filter: ~A" (workbench-inspector-query wb))))
        t)
       ((characterp key)
        (setf (workbench-inspector-query wb)
              (concatenate 'string
                           (workbench-inspector-query wb)
                           (string key)))
        (%refresh-inspector wb)
        (setf (workbench-status wb)
              (format nil "Filter: ~A" (workbench-inspector-query wb)))
        t)
       (t nil)))
    ((char= (if (characterp key) key #\Null) #\/)
     (setf (workbench-inspector-query-mode wb) t
           (workbench-inspector-query wb) ""
           (workbench-status wb) "Filter: ")
     (%refresh-inspector wb)
     t)
    ((char= (if (characterp key) key #\Null) #\W)
     (%refresh-inspector wb :watches)
     (setf (workbench-status wb) "Inspector: watches")
     t)
    ((char= (if (characterp key) key #\Null) #\w)
     (%toggle-selected-watch wb))
    ((eq key :tab)
     (%cycle-inspector-section wb 1))
    ((eq key :backtab)
     (%cycle-inspector-section wb -1))
    ((eq key :down)
     (%move-inspector-selection wb 1))
    ((eq key :up)
     (%move-inspector-selection wb -1))
    ((eq key :enter)
     (let ((entry (%selected-inspector-entry wb)))
       (when (and (eq (workbench-inspector-section wb) :packages)
                  entry
                  (stringp (getf entry :name)))
         (setf (workbench-inspector-package wb) (getf entry :name))
         (%refresh-inspector wb :symbols)
         (setf (workbench-status wb)
               (format nil "Symbols: ~A" (workbench-inspector-package wb)))
         t)))
    ((eq key :escape)
     (setf (workbench-focus wb) :editor)
     t)
    (t nil)))

(defun %handle-key (wb key)
  (cond
    ((and (eq (workbench-focus wb) :inspector)
          (%handle-inspector-key wb key))
     t)
    ((eq key :f2)
     (%clear-completion wb)
     (setf (workbench-focus wb)
           (if (eq (workbench-focus wb) :editor) :inspector :editor))
     (when (eq (workbench-focus wb) :inspector)
       (%refresh-inspector wb))
     t)
    ((eq key :f4)
     (%clear-completion wb)
     (setf (workbench-focus wb) :inspector
           (workbench-show-inspector wb) t)
     (%refresh-inspector wb :diagnostics)
     t)
    ((eq key :page-up)
     (incf (workbench-scroll wb) 5)
     t)
    ((eq key :page-down)
     (setf (workbench-scroll wb)
           (max 0 (- (workbench-scroll wb) 5)))
     t)
    ((eq key :ctrl-c)
     (when (workbench-active-request wb)
       (elmtui.workbench.eval:cancel-evaluation
        (workbench-repl wb) (workbench-active-request wb)))
     (setf (workbench-status wb)
           "Cancellation requested (cooperative)")
     t)
    ((eq key :escape)
     (setf (workbench-focus wb) :editor)
     t)
    ((eq (workbench-focus wb) :inspector)
     t)
    (t
     (multiple-value-bind (editor action)
         (elmtui.workbench.editor:editor-handle-key
          (workbench-editor wb) key)
       (declare (ignore editor))
       (let ((result
               (case action
                 (:submit (%submit wb))
                 (:exit
                  (elmtui.workbench.eval:close-repl-session
                   (workbench-repl wb))
                  (setf (workbench-status wb) "Exit requested")
                  :quit)
                 (:history-search
                  (setf (workbench-status wb)
                        "Use Up/Down to search history"))
                 (otherwise nil))))
         (when (workbench-completion wb)
           (%clear-completion wb))
         (incf (workbench-generation wb))
         (if (eq result :quit) :quit t))))))

(defun workbench-update (message app-state)
  (let ((wb (state-ref app-state :workbench)))
    (cond
      ((and (consp message)
            (member (car message) '(:terminal-resized :terminalresized)))
       (setf (workbench-width wb) (max 24 (getf (cdr message) :width 80))
             (workbench-height wb) (max 8 (getf (cdr message) :height 24)))
       (elmtui.workbench.editor:editor-resize
        (workbench-editor wb)
        (max 1
             (- (if (and (>= (workbench-width wb) 120)
                         (workbench-show-inspector wb))
                    (floor (* (workbench-width wb) 68) 100)
                    (workbench-width wb))
                4)))
       (make-update-result
        :patches
        (list (list '(:revision)
                    (1+ (state-ref app-state :revision 0))))))
      ((and (consp message) (eq (car message) :wb-tick))
       (make-update-result
        :patches
        (when (%eval-events wb)
          (list (list '(:revision)
                      (1+ (state-ref app-state :revision 0)))))
        :handled t))
      ((or (typep message 'elmtui.core.event-types:key-event)
           (and (consp message)
                (member (car message) '(:keyevent :key-event))))
       (multiple-value-bind (key char modifiers)
           (%key-parts message)
         (let* ((normalized (%key-name key char modifiers))
                (binding-key (%completion-key-string key char modifiers))
                (completion-command
                  (and binding-key
                       (elmtui.workbench.completion:completion-command-for-key
                        (workbench-completion-keys wb)
                        binding-key)))
                (completion-action
                  (and completion-command
                       (%handle-completion-command wb completion-command)))
                (action
                  (or completion-action
                      (and normalized (%handle-key wb normalized)))))
           (make-update-result
            :patches
            (append
             (when action
               (list (list '(:revision)
                           (1+ (state-ref app-state :revision 0)))))
             (when (eq action :quit)
               (list (list '(:should-quit) t))))
            :handled t))))
      ((and (consp message) (eq (car message) :app-quit-requested))
       (elmtui.workbench.eval:close-repl-session (workbench-repl wb))
       (make-update-result :patches '(((:should-quit) t)) :handled t))
      (t
       (make-update-result)))))

(defun workbench-view (app-state)
  (let ((wb (state-ref app-state :workbench)))
    (multiple-value-bind (rows style-map)
        (elmtui.workbench.view:frame-lines
         :width (workbench-width wb)
         :height (workbench-height wb)
         :source (elmtui.workbench.editor:editor-text
                  (workbench-editor wb))
         :cursor (elmtui.workbench.editor:editor-state-cursor
                  (workbench-editor wb))
         :transcript (workbench-transcript wb)
         :completion (workbench-completion wb)
         :selected (workbench-selected wb)
         :docs (workbench-docs wb)
         :completion-theme (workbench-completion-theme wb)
         :inspector (workbench-inspector-snapshot wb)
         :inspector-section (workbench-inspector-section wb)
         :inspector-selected (workbench-inspector-selected wb)
         :inspector-query (workbench-inspector-query wb)
         :inspector-query-mode (workbench-inspector-query-mode wb)
         :inspector-theme (workbench-inspector-theme wb)
         :show-inspector (workbench-show-inspector wb)
         :focus (workbench-focus wb)
         :status (workbench-status wb)
         :package
         (package-name
          (elmtui.workbench.eval:repl-session-package
           (workbench-repl wb)))
         :scroll (workbench-scroll wb))
      (elmtui.workbench.view:frame-dsl
       rows
       (workbench-width wb)
       (workbench-height wb)
       :style-map style-map))))

(defun workbench-subscriptions (state)
  (declare (ignore state))
  '((:timer :interval 0.075 :message (:wb-tick))))

(elmtui.app:defapplication workbench
  :root-viewport-id :workbench-root
  :root-component-dsl
  '(:root-viewport :id :workbench-root :anchor :top-left
    :child-dsl-spec (:view nil) :overflow-policy :scroll
    :blank-on-exit t)
  :initial-state-fn #'%workbench-initial
  :view-fn #'workbench-view
  :update-fn #'workbench-update
  :subscriptions-fn workbench-subscriptions)

