(defpackage #:elmtui.workbench.editor
 (:use #:cl)
 (:export #:editor-state #:make-editor-state #:editor-text #:editor-handle-key
 #:editor-insert-text #:editor-balanced-p #:editor-cursor-screen-position
 #:editor-state-cursor #:editor-state-columns #:editor-state-last-action
 #:editor-history-add #:editor-search-history #:editor-undo #:editor-redo
 #:editor-match-bracket #:editor-indent-line #:editor-resize
 #:editor-backspace #:editor-delete-forward #:editor-move-cursor))

(in-package #:elmtui.workbench.editor)

(defstruct (editor-state (:constructor %make-editor-state))
 (buffer "" :type string) (cursor 0 :type integer) (columns 80 :type (integer 1 *))
 (history nil :type list) (history-index nil) (history-draft "" :type string)
 (undo-stack nil :type list) (redo-stack nil :type list)
 (kill-ring "" :type string) (preferred-column nil) (last-action nil))

(defun make-editor-state (&key (text "") cursor (columns 80) history)
 "Create an editor with character offsets and display-cell geometry."
 (check-type text string)
 (check-type columns (integer 1 *))
 (%make-editor-state :buffer (copy-seq text)
 :cursor (if cursor (max 0 (min cursor (length text))) (length text))
 :columns columns :history (copy-list history)))

(defun editor-text (state)
 "Return a copy of the editable source."
 (copy-seq (editor-state-buffer state)))

(defun %save-edit (state)
 (push (cons (editor-text state) (editor-state-cursor state)) (editor-state-undo-stack state))
 (when (> (length (editor-state-undo-stack state)) 128)
 (setf (editor-state-undo-stack state) (subseq (editor-state-undo-stack state) 0 128)))
 (setf (editor-state-redo-stack state) nil))

(defun %replace-region (state start end replacement)
 (check-type replacement string)
 (let ((old (editor-state-buffer state)))
 (unless (and (= (- end start) (length replacement))
 (string= old replacement :start1 start :end1 end))
 (%save-edit state)
 (setf (editor-state-buffer state)
 (concatenate 'string (subseq old 0 start) replacement (subseq old end))
 (editor-state-cursor state) (+ start (length replacement))
 (editor-state-preferred-column state) nil)))
 state)

(defun editor-insert-text (state text)
 "Insert source at the character cursor."
 (%replace-region state (editor-state-cursor state) (editor-state-cursor state) text))

(defun editor-undo (state)
 (when (editor-state-undo-stack state)
 (push (cons (editor-text state) (editor-state-cursor state)) (editor-state-redo-stack state))
 (let ((snapshot (pop (editor-state-undo-stack state))))
 (setf (editor-state-buffer state) (car snapshot)
 (editor-state-cursor state) (cdr snapshot)
 (editor-state-preferred-column state) nil)))
 state)

(defun editor-redo (state)
 (when (editor-state-redo-stack state)
 (push (cons (editor-text state) (editor-state-cursor state)) (editor-state-undo-stack state))
 (let ((snapshot (pop (editor-state-redo-stack state))))
 (setf (editor-state-buffer state) (car snapshot)
 (editor-state-cursor state) (cdr snapshot)
 (editor-state-preferred-column state) nil)))
 state)

(defun %combining-p (char)
 (let ((n (char-code char)))
 (or (<= #x300 n #x36f) (<= #x1ab0 n #x1aff)
 (<= #x1dc0 n #x1dff) (<= #x20d0 n #x20ff)
 (<= #xfe00 n #xfe0f) (<= #xfe20 n #xfe2f)
 (<= #xe0100 n #xe01ef) (= n #x200d) (= n #x20e3)
 (<= #x1f3fb n #x1f3ff))))

(defun %next-grapheme (text index)
 (let ((end (length text)) (i (1+ index)))
 (loop while (< i end)
 for current = (char text i)
 for before = (char text (1- i))
 while (and (not (char= current #\Newline))
 (or (%combining-p current) (= (char-code before) #x200d)))
 do (incf i))
 i))

(defun %previous-grapheme (text index)
 "Find the previous grapheme boundary by scanning backward at bounded local cost."
 (if (zerop index)
 0
 (let ((i (1- index)))
 (loop while (and (> i 0)
 (or (%combining-p (char text i))
 (= (char-code (char text (1- i))) #x200d)))
 do (decf i))
 i)))

(defun editor-backspace (state)
 "Delete one grapheme cluster to the left."
 (let ((cursor (editor-state-cursor state)))
 (when (> cursor 0)
 (%replace-region state (%previous-grapheme (editor-state-buffer state) cursor) cursor "")))
 state)

(defun editor-delete-forward (state)
 "Delete one grapheme cluster to the right."
 (let* ((cursor (editor-state-cursor state)) (text (editor-state-buffer state)))
 (when (< cursor (length text))
 (%replace-region state cursor (%next-grapheme text cursor) "")))
 state)

(defun %line-start (text cursor)
 (let ((before (position #\Newline text :end cursor :from-end t)))
 (if before (1+ before) 0)))

(defun %line-end (text cursor)
 (or (position #\Newline text :start cursor) (length text)))

(defun editor-history-add (state &optional (source (editor-text state)))
 "Add a nonempty submitted form to history, newest first."
 (when (and (plusp (length (string-trim '(#\Space #\Tab #\Newline) source)))
 (not (string= source (or (first (editor-state-history state)) ""))))
 (push (copy-seq source) (editor-state-history state)))
 (setf (editor-state-history-index state) nil (editor-state-history-draft state) "")
 state)

(defun %history-load (state index)
 (let ((entries (editor-state-history state)))
 (when (and (<= 0 index) (< index (length entries)))
 (when (null (editor-state-history-index state))
 (setf (editor-state-history-draft state) (editor-text state)))
 (setf (editor-state-history-index state) index
 (editor-state-buffer state) (copy-seq (nth index entries))
 (editor-state-cursor state) (length (nth index entries))
 (editor-state-preferred-column state) nil)))
 state)

(defun %history-step (state amount)
 (let ((index (editor-state-history-index state)))
 (cond ((and (null index) (plusp amount)) (%history-load state 0))
 ((and index (>= (+ index amount) 0)
 (< (+ index amount) (length (editor-state-history state))))
 (%history-load state (+ index amount)))
 ((and index (< (+ index amount) 0))
 (setf (editor-state-buffer state) (editor-state-history-draft state)
 (editor-state-cursor state) (length (editor-state-history-draft state))
 (editor-state-history-index state) nil))))
 state)

(defun editor-search-history (state needle &key (start 0))
 "Load the next earlier matching history entry."
 (check-type needle string)
 (let ((index (position-if (lambda (entry) (search needle entry :test #'char-equal))
 (editor-state-history state) :start start)))
 (when index (%history-load state index))
 index))

(defun %wide-p (char)
 (let ((n (char-code char)))
 (or (<= #x1100 n #x115f) (<= #x2329 n #x232a)
 (<= #x2e80 n #xa4cf) (<= #xac00 n #xd7a3) (<= #xf900 n #xfaff)
 (<= #xfe10 n #xfe19) (<= #xfe30 n #xfe6f)
 (<= #xff00 n #xff60) (<= #xffe0 n #xffe6)
 (<= #x1f000 n #x1ffff) (<= #x20000 n #x3fffd))))

(defun %cluster-cells (text start end column)
 (if (char= (char text start) #\Tab)
 (- 8 (mod column 8))
 (let ((width 0))
 (loop for i from start below end
 for character = (char text i) do
 (unless (%combining-p character)
 (setf width (max width (if (%wide-p character) 2 1)))))
 (max 1 width))))

(defun editor-resize (state columns)
 "Change terminal-cell width without moving the logical cursor."
 (check-type columns (integer 1 *))
 (setf (editor-state-columns state) columns
 (editor-state-preferred-column state) nil)
 state)

(defun editor-cursor-screen-position (state &key (origin-x 0) (origin-y 0))
 "Return X and Y as zero-based screen-cell coordinates."
 (let ((text (editor-state-buffer state)) (width (editor-state-columns state))
 (x 0) (y 0) (i 0) (limit (editor-state-cursor state)))
 (loop while (< i limit) do
 (if (char= (char text i) #\Newline)
 (setf x 0 y (1+ y) i (1+ i))
 (let* ((next (%next-grapheme text i))
 (cells (%cluster-cells text i next x)))
 (when (and (> x 0) (> (+ x cells) width))
 (setf x 0 y (1+ y))
 (setf cells (%cluster-cells text i next x)))
 (incf x (min cells width))
 (when (>= x width) (setf x 0 y (1+ y)))
 (setf i next))))
 (values (+ origin-x x) (+ origin-y y))))

(defun %line-column (text cursor)
 (let ((i (%line-start text cursor)) (x 0))
 (loop while (< i cursor) do
 (let* ((next (%next-grapheme text i))
 (cells (%cluster-cells text i next x)))
 (incf x cells)
 (setf i next)))
 x))

(defun %column-index (text start end desired)
 (let ((i start) (column 0))
 (loop while (< i end) do
 (let* ((next (%next-grapheme text i))
 (cells (%cluster-cells text i next column)))
 (when (> (+ column cells) desired) (return))
 (incf column cells)
 (setf i next)))
 i))

(defun %scan-brackets (text &optional (stop (length text)))
 "Return matching parenthesis indices and depth, skipping lexical comments and strings."
 (let ((pairs (make-hash-table :test #'eql))
       (stack nil) (line-comment nil) (block-depth 0)
       (in-string nil) (in-bars nil) (escaped nil)
       (i 0) (limit (min stop (length text))))
   (loop while (< i limit) do
     (let* ((ch (char text i))
            (next (and (< (1+ i) limit) (char text (1+ i)))))
       (cond
         (line-comment
           (when (char= ch #\Newline) (setf line-comment nil)))
         ((plusp block-depth)
           (cond ((and next (char= ch (code-char 35)) (char= next (code-char 124)))
                  (incf block-depth) (incf i))
                 ((and next (char= ch (code-char 124)) (char= next (code-char 35)))
                  (decf block-depth) (incf i))))
         (escaped (setf escaped nil))
         (in-string
           (cond ((char= ch (code-char 92)) (setf escaped t))
                 ((char= ch (code-char 34)) (setf in-string nil))))
         (in-bars
           (cond ((char= ch (code-char 92)) (setf escaped t))
                 ((char= ch (code-char 124)) (setf in-bars nil))))
         ((char= ch (code-char 59)) (setf line-comment t))
         ((and next (char= ch (code-char 35)) (char= next (code-char 124)))
           (setf block-depth 1) (incf i))
         ((and next (char= ch (code-char 35)) (char= next (code-char 92)))
           (incf i 2)
           (when (and (< i limit) (alpha-char-p (char text i)))
             (loop while (and (< (1+ i) limit)
                              (alphanumericp (char text (1+ i))))
                   do (incf i))))
         ((char= ch (code-char 34)) (setf in-string t))
         ((char= ch (code-char 124)) (setf in-bars t))
         ((char= ch (code-char 92)) (setf escaped t))
         ((char= ch (code-char 40)) (push i stack))
         ((char= ch (code-char 41))
           (when stack
             (let ((opening (pop stack)))
               (setf (gethash opening pairs) i
                     (gethash i pairs) opening)))))
       (incf i)))
   (values pairs (length stack))))

(defun editor-match-bracket (state &optional (position (editor-state-cursor state)))
 "Find partner of parenthesis under cursor or immediately to its left."
 (let ((pairs (nth-value 0 (%scan-brackets (editor-state-buffer state)))))
   (or (gethash position pairs)
       (and (> position 0) (gethash (1- position) pairs)))))

(defun editor-indent-line (state &optional (step 2))
 "Indent a logical line to two spaces per unmatched opening parenthesis."
 (let* ((text (editor-state-buffer state))
        (start (%line-start text (editor-state-cursor state)))
        (end (%line-end text start))
        (body (or (position-if-not
                   (lambda (ch) (or (char= ch #\Space) (char= ch #\Tab)))
                   text :start start :end end)
                  end))
        (depth (nth-value 1 (%scan-brackets text start)))
        (closing (and (< body end) (char= (char text body) (code-char 41))))
        (spaces (make-string
                 (min 80 (* step (max 0 (- depth (if closing 1 0)))))
                 :initial-element #\Space))
        (old (editor-state-cursor state)))
   (%replace-region state start body spaces)
   (when (>= old body)
     (setf (editor-state-cursor state)
           (+ old (- (length spaces) (- body start)))))
   state))

(defun editor-balanced-p (state) "Check that input has at least one complete reader form with read-eval disabled." (let ((source (editor-state-buffer state)) (seen nil) (offset 0) (*read-eval* nil) (*readtable* (copy-readtable nil)) (eof (gensym "EDITOR-EOF-"))) (when (> (length source) 100000) (return-from editor-balanced-p nil)) (handler-case (loop while (< offset (length source)) do (multiple-value-bind (form end) (read-from-string source nil eof :start offset) (when (eq form eof) (return)) (unless (> end offset) (return-from editor-balanced-p nil)) (setf seen t offset end))) (error () (return-from editor-balanced-p nil))) seen))

(defun editor-move-cursor (state direction)
 "Move by grapheme, line or buffer, with boundary history navigation."
 (let* ((text (editor-state-buffer state))
        (cursor (editor-state-cursor state))
        (start (%line-start text cursor))
        (end (%line-end text cursor))
        (target cursor))
   (case direction
     (:left (when (> cursor 0) (setf target (%previous-grapheme text cursor))))
     (:right (when (< cursor (length text)) (setf target (%next-grapheme text cursor))))
     (:home (setf target start))
     (:end (setf target end))
     (:buffer-start (setf target 0))
     (:buffer-end (setf target (length text)))
     ((:up :down)
      (let* ((desired (or (editor-state-preferred-column state)
                          (%line-column text cursor)))
             (above (and (> start 0) (%line-start text (1- start))))
             (below (and (< end (length text)) (1+ end))))
        (setf (editor-state-preferred-column state) desired)
        (cond
          ((and (eq direction :up) above)
           (setf target (%column-index text above (1- start) desired)))
          ((and (eq direction :down) below)
           (setf target (%column-index text below (%line-end text below) desired)))
          ((eq direction :up)
           (%history-step state 1)
           (return-from editor-move-cursor state))
          ((eq direction :down)
           (%history-step state -1)
           (return-from editor-move-cursor state))))))
   (unless (member direction '(:up :down))
     (setf (editor-state-preferred-column state) nil))
   (setf (editor-state-cursor state) target))
 state)

(defun %kill-line (state)
 "Store text to logical line end in the single-entry kill ring."
 (let* ((text (editor-state-buffer state))
        (cursor (editor-state-cursor state))
        (end (%line-end text cursor))
        (finish (if (and (= cursor end) (< end (length text)))
                    (1+ end) end)))
   (setf (editor-state-kill-ring state) (subseq text cursor finish))
   (when (> finish cursor) (%replace-region state cursor finish "")))
 state)

(defun editor-handle-key (state key)
 "Mutate editor from keyword command, character or pasted text; return state and action."
 (setf (editor-state-last-action state) nil)
 (cond
   ((and (characterp key) (char= key #\Newline))
    (return-from editor-handle-key (editor-handle-key state :enter)))
   ((characterp key) (editor-insert-text state (string key)))
   ((stringp key) (editor-insert-text state key))
   ((and (consp key) (eq (first key) :search-history))
    (editor-search-history state (second key)))
   (t
    (case key
      ((:left :right :up :down :home :end :buffer-start :buffer-end)
       (editor-move-cursor state key))
      (:backspace (editor-backspace state))
      (:delete (editor-delete-forward state))
      (:undo (editor-undo state))
      (:redo (editor-redo state))
      (:history-previous (%history-step state 1))
      (:history-next (%history-step state -1))
      (:kill-line (%kill-line state))
      (:yank (editor-insert-text state (editor-state-kill-ring state)))
      (:tab (editor-insert-text state "  "))
      (:indent (editor-indent-line state))
      ((:newline :shift-enter)
       (editor-insert-text state (string #\Newline))
       (editor-indent-line state))
      (:enter
       (if (editor-balanced-p state)
           (progn (editor-history-add state)
                  (setf (editor-state-last-action state) :submit))
           (progn (editor-insert-text state (string #\Newline))
                  (editor-indent-line state))))
      (:ctrl-enter
       (when (plusp (length
                     (string-trim '(#\Space #\Tab #\Newline) (editor-text state))))
         (editor-history-add state)
         (setf (editor-state-last-action state) :submit)))
      (:ctrl-r (setf (editor-state-last-action state) :history-search))
      (:escape (setf (editor-state-last-action state) :escape))
      (:ctrl-c (setf (editor-state-last-action state) :interrupt))
      (:ctrl-d
       (if (zerop (length (editor-state-buffer state)))
           (setf (editor-state-last-action state) :exit)
           (editor-delete-forward state))))))
 (values state (editor-state-last-action state)))
