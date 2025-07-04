(uiop:define-package :elmtui.platform.backend.common.virtual-buffer
  (:use :cl :alexandria)
  (:import-from :elmtui.core.loop #:as-plist) ; Keep for existing uses if any, or review if shadowed by ansi-styling's as-plist
  (:import-from :elmtui.view.geo #:=?)
  (:import-from :bordeaux-threads #:make-recursive-lock #:with-recursive-lock-held)
  (:import-from :elmtui.platform.backend.common.ansi-styling
                #:style-to-terminal-style
                #:terminal-style-fg-color-val
                #:terminal-style-bg-color-val
                #:copy-terminal-style
                #:copy-term-color
                #:terminal-color-simple
                #:terminal-style
                #:terminal-style-fg-color
                #:terminal-style-bg-color

                #:as-plist ; This might be specific to ansi-styling, ensure no conflict if elmtui.core.loop also exports it.
                #:as-style #:make-termcolor #:copy-term-style #:make-terminal-style) ; Added copy-term-style, make-terminal-style if needed by new fns
  (:export
   #:make-buffer-cell
   #:is-term-style
   ;; Conditions
   #:buffer-error
   #:invalid-buffer-coordinates-error
   #:invalid-buffer-coordinates-error-buffer
   #:invalid-buffer-coordinates-error-row
   #:invalid-buffer-coordinates-error-col
   ;; Structs
   #:buffer-cell
   #:buffer-cell-char
   #:buffer-cell-style
   #:buffer-char
   #:buffer-style
   #:virtual-terminal-buffer
   #:virtual-terminal-buffer-width
   #:virtual-terminal-buffer-height
   #:virtual-terminal-buffer-cells
   #:virtual-terminal-buffer-lock
   ;; Constructors and Accessors
   #:make-virtual-buffer
   #:new-buffer
   #:buffer-width
   #:buffer-height
   #:buffer-cells ; Raw access, use with caution
   #:buffer-lock
   ;; Macros
   #:with-virtual-buffer-lock
   #:deep-copy-style
   ;; Cell functions
   #:default-buffer-cell
   #:buffer-cell-equal-p
   #:buffer-cell-at
   #:set-buffer-cell-at
   ;; Buffer manipulation
   #:fill-buffer-region
   #:clear-buffer
   #:resize-buffer
   #:copy-virtual-buffer ; This is for cloning the buffer
   #:copy-buffer-contents ; Added for blitting content between buffers
   #:write-string-to-buffer ; Added new function
   ;; Debugging
   #:print-buffer-to-string
   ;; Restarts
   #:use-value
   #:clip-coordinates
   #:clear-buffer
   ;; Accessors for terminal style colors
   ;; #:terminal-style-fg-color-val
   ;; #:terminal-style-bg-color-val
   #:terminal-style-fg-color
   #:terminal-style-bg-color))

(in-package :elmtui.platform.backend.common.virtual-buffer)

;; Add accessor functions for terminal style colors
;; (defun terminal-style-fg-color-val (style)
;;   "Get the simple color value from a terminal style's foreground color."
;;   (when (and style (terminal-style-fg-color style))
;;     (terminal-color-simple (terminal-style-fg-color style))))

;; (defun terminal-style-bg-color-val (style)
;;   "Get the simple color value from a terminal style's background color."
;;   (when (and style (terminal-style-bg-color style))
;;     (terminal-color-simple (terminal-style-bg-color style))))

(defgeneric deep-copy-style (style)
  (:documentation "Creates a deep copy of a style plist, including any nested lists like RGB values."))
;;;----------------------------------------------------------------------------------;;;
;;; Conditions                                                                       ;;;
;;;----------------------------------------------------------------------------------;;;

(define-condition buffer-error (error) ())

(define-condition invalid-buffer-coordinates-error (buffer-error)
  ((buffer :initarg :buffer :reader invalid-buffer-coordinates-error-buffer)
   (row    :initarg :row    :reader invalid-buffer-coordinates-error-row)
   (col    :initarg :col    :reader invalid-buffer-coordinates-error-col))
  (:report (lambda (condition stream)
             (format stream "Invalid coordinates (row ~A, col ~A) for buffer of size ~Ax~A."
                     (invalid-buffer-coordinates-error-row condition)
                     (invalid-buffer-coordinates-error-col condition)
                     (buffer-height (invalid-buffer-coordinates-error-buffer condition))
                     (buffer-width (invalid-buffer-coordinates-error-buffer condition))))))

;;;----------------------------------------------------------------------------------;;;
;;; Data Structures                                                                  ;;;
;;;----------------------------------------------------------------------------------;;;

(defstruct (buffer-cell (:constructor %make-buffer-cell))
  "Represents a single cell in the virtual terminal buffer.
that is: at this point already a character with a style."
  (char #\Space :type character)
  (style nil :type (or null terminal-style)))

(defmethod make-buffer-cell (&key (char #\Space) (style nil))
  "Creates a new BUFFER-CELL instance with the specified character and style.
   The style can be a plist, a terminal-style object, or nil."
  (let ((processed-style (cond
                           ((null style) nil)
                           ((typep style 'terminal-style) style)
                           ((listp style) style) ; Keep as plist for now
                           (t (error "Unsupported style type: ~A" (type-of style))))))
    (%make-buffer-cell :char char
                       :style (if (null processed-style) nil 
                                  (if (typep processed-style 'terminal-style)
                                      processed-style
                                      (deep-copy-style processed-style))))))

(defun default-buffer-cell (&optional (style nil))
  "Returns a new buffer-cell with default character and specified style.
   If style is nil, no style is applied."
  (make-buffer-cell :char #\Space :style style))

(defstruct (virtual-terminal-buffer (:constructor %make-virtual-terminal-buffer))
  "Represents a 2D grid of styled characters for the terminal screen."
  (width 0 :type fixnum :read-only t)
  (height 0 :type fixnum :read-only t)
  (cells nil :type (simple-array buffer-cell (* *)))
  (default-style nil :type (or null terminal-style) :read-only t) ; Buffer-wide default style
  (lock (make-recursive-lock "virtual-buffer-lock") :read-only t))

;;;----------------------------------------------------------------------------------;;;
;;; Macros                                                                           ;;;
;;;----------------------------------------------------------------------------------;;;

(defmacro with-virtual-buffer-lock ((buffer) &body body)
  "Acquires the lock for BUFFER and executes BODY."
  `(with-recursive-lock-held ((virtual-terminal-buffer-lock ,buffer))
     ,@body))

(defmethod buffer-char ((bfr virtual-terminal-buffer) row col)
  "Returns the character at the given ROW and COL in the BUFFER.
   Uses `buffer-cell-at` which handles bounds checking, locking, and returns a copy."
  (check-type bfr virtual-terminal-buffer) ; Keep basic checks for clarity
  (check-type row (integer 0 *))
  (check-type col (integer 0 *))
  (let ((cell (buffer-cell-at bfr row col)))
    (when cell (buffer-cell-char cell))))

(defmethod buffer-style ((bfr virtual-terminal-buffer) row col)
  "Returns the style at the given ROW and COL in the BUFFER.
   Uses `buffer-cell-at` which handles bounds checking, locking, and returns a copy of the style."
  (check-type bfr virtual-terminal-buffer)
  (check-type row (integer 0 *))
  (check-type col (integer 0 *))
  (let ((cell (buffer-cell-at bfr row col)))
    (when cell (buffer-cell-style cell))))

(defmethod (setf buffer-char) (value (bfr virtual-terminal-buffer) row col)
  "Sets the character at the given ROW and COL of the BUFFER to VALUE."
  (check-type bfr virtual-terminal-buffer)
  (check-type row (integer 0 *))
  (check-type col (integer 0 *))
  (setf (buffer-cell-char (aref (virtual-terminal-buffer-cells bfr) row col)) value))

(defmethod (setf buffer-style) ((value terminal-style) (bfr virtual-terminal-buffer) row col)
  "Sets the style at the given ROW and COL of the BUFFER to VALUE."
  (check-type bfr virtual-terminal-buffer)
  (check-type row (integer 0 *))
  (check-type col (integer 0 *))
  ;; Store the style struct or plist directly without deep-copy
  (setf (buffer-cell-style (aref (virtual-terminal-buffer-cells bfr) row col)) value))

(defmethod (setf buffer-style) ((value null) (bfr virtual-terminal-buffer) row col)
  "Sets the style at the given ROW and COL of the BUFFER to NIL."
  (check-type bfr virtual-terminal-buffer)
  (check-type row (integer 0 *))
  (check-type col (integer 0 *))
  ;; Set style to nil directly
  (setf (buffer-cell-style (aref (virtual-terminal-buffer-cells bfr) row col)) nil))

(defmethod (setf buffer-style) ((value list) (bfr virtual-terminal-buffer) row col)
  "Sets the style at the given ROW and COL of the BUFFER to a deep copy of VALUE."
  (check-type bfr virtual-terminal-buffer)
  (check-type row (integer 0 *))
  (check-type col (integer 0 *))
  ;; Create a deep copy of the style plist
  (setf (buffer-cell-style (aref (virtual-terminal-buffer-cells bfr) row col)) (elmtui.platform.backend.common.ansi-styling:style-to-terminal-style value)))
;;;----------------------------------------------------------------------------------;;;
;;; Style Copying Utilities                                                          ;;;
;;;----------------------------------------------------------------------------------;;;
(defmethod deep-copy-style ((style terminal-style))
  "Creates a deep copy of a style plist, including any nested lists like RGB values.
   Returns a new plist with the same keys but new list instances for any list values."
  (let ((ts (copy-terminal-style style)))
    (setf
     (elmtui.platform.backend.common.ansi-styling:terminal-style-fg-color ts)
     (copy-term-color (elmtui.platform.backend.common.ansi-styling:terminal-style-fg-color style)))
    (setf (elmtui.platform.backend.common.ansi-styling:terminal-style-bg-color ts)
          (copy-term-color (elmtui.platform.backend.common.ansi-styling:terminal-style-fg-color style)))
    ts))
(defmethod deep-copy-style ((style list))
  "Creates a deep copy of a style plist, including any nested lists like RGB values.
   Returns a new plist with the same keys but new list instances for any list values."
  (loop for (key value) on style by #'cddr
        ;; Copy any nested lists like RGB values
        if (and (listp value) (every #'numberp value))
          nconc (list key (copy-list value))
        else
          nconc (list key value)))

(defmethod deep-copy-style ((style null))
  "Returns an empty style plist if STYLE is NIL."
  nil)



;;;----------------------------------------------------------------------------------;;;
;;; API Functions                                                                    ;;;
;;;----------------------------------------------------------------------------------;;;

(defun make-virtual-buffer (width height &key (initial-char #\Space) (initial-style nil))
  "Creates a new VIRTUAL-TERMINAL-BUFFER of specified WIDTH and HEIGHT.
   Initializes cells with initial-char and initial-style.
   The buffer's default-style is also set based on a processed version of initial-style."
  (check-type width (integer 0 *))
  (check-type height (integer 0 *))
  (let* ((processed-style (cond
                            ((null initial-style) nil)
                            ((typep initial-style 'terminal-style) initial-style)
                            ((listp initial-style) initial-style)
                            (t (error "Unsupported style type: ~A" (type-of initial-style)))))
         (cells (make-array (list height width) :element-type 'buffer-cell
                                                :initial-element (default-buffer-cell))))

    ;; Initialize each cell individually 
    (dotimes (r height)
      (dotimes (c width)
        (setf (aref cells r c) (make-buffer-cell :char initial-char :style processed-style))))
    
    (%make-virtual-terminal-buffer :width width
                                   :height height
                                   :cells cells)))

(defun buffer-width (buffer)
  "Returns the width of the BUFFER."
  (check-type buffer virtual-terminal-buffer)
  (virtual-terminal-buffer-width buffer))

(defun buffer-height (buffer)
  "Returns the height of the BUFFER."
  (check-type buffer virtual-terminal-buffer)
  (virtual-terminal-buffer-height buffer))

(defun buffer-cells (buffer)
  "Returns the raw 2D array of BUFFER-CELL objects.
   Use with caution; prefer cell-level APIs for modification to ensure thread-safety."
  (check-type buffer virtual-terminal-buffer)
  (virtual-terminal-buffer-cells buffer))

(defun buffer-lock (buffer)
  "Returns the recursive lock associated with the BUFFER."
  (check-type buffer virtual-terminal-buffer)
  (virtual-terminal-buffer-lock buffer))

(defgeneric is-term-style (s)
  (:method (s) nil) ; Default method: not a terminal-style
  (:documentation "Checks if the given style S is a terminal style."))

(defmethod is-term-style ((s terminal-style))
  "A terminal-style struct is indeed a terminal style."
  t)

(defun buffer-cell-equal-p (cell1 cell2)
  "Compares two BUFFER-CELL instances for equality (char and style)."
  (check-type cell1 buffer-cell)
  (check-type cell2 buffer-cell)
  (and (char= (buffer-cell-char cell1) (buffer-cell-char cell2))
       (let ((style1 (buffer-cell-style cell1))
             (style2 (buffer-cell-style cell2)))
         (cond
           ((and (null style1) (null style2)) t) ; Both nil, considered equal
           ((or (null style1) (null style2)) nil) ; One nil, other not, considered different
           ;; Both are terminal-style structs, use the specialized =? method
           ((and (is-term-style style1)
                 (is-term-style style2))
            (elmtui.view.geo:=? style1 style2))
           ;; Fallback for plist comparison if necessary, though ideally styles are always terminal-style structs
           ((and (listp style1) ;; (listp style2) UNREACHABLE CODE
                 )
            ;; UNREACHABLE CODE
            ;; (and (= (length style1) (length style2))
            ;;      (loop for (key value) on style1 by #'cddr
            ;;            always (let ((other-value (getf style2 key :not-found)))
            ;;                     (if (eq other-value :not-found)
            ;;                         nil
            ;;                         (elmtui.view.geo:=? value other-value)))))
            )
           (t nil))))) ; Different types or one is not a style representation

(defun %check-bounds (buffer row col)
  (unless (and (<= 0 row (1- (buffer-height buffer)))
               (<= 0 col (1- (buffer-width buffer))))
    (cerror "Ignore and proceed with potentially invalid coordinates." ; A generic continue for internal use if needed
            'invalid-buffer-coordinates-error :buffer buffer :row row :col col)))

(defun buffer-cell-at (buffer row col)
  "Retrieves a *copy* of the cell at (ROW, COL).
Signals INVALID-BUFFER-COORDINATES-ERROR if out of bounds."
  (check-type buffer virtual-terminal-buffer)
  (check-type row (integer 0 *))
  (check-type col (integer 0 *))
  (with-virtual-buffer-lock (buffer)
    (restart-case
        (progn
          (%check-bounds buffer row col)
          (let ((original-cell (aref (virtual-terminal-buffer-cells buffer) row col)))
            (make-buffer-cell
             :char (buffer-cell-char original-cell)
             ;; Make a deep copy of the style
             :style (deep-copy-style (buffer-cell-style original-cell)))))
      (use-value (value)
        :report "Use a provided buffer-cell instance instead."
        :interactive (lambda () (list (read *query-io* :prompt "Enter a buffer-cell form to use: ")))
        (check-type value buffer-cell)
        value)
      (clip-coordinates () ; Basic clipping: return cell at nearest valid coordinate
        :report "Clip coordinates to the nearest valid boundary and return that cell."
        (let ((clipped-row (clamp row 0 (1- (buffer-height buffer))))
              (clipped-col (clamp col 0 (1- (buffer-width buffer)))))
          (if (and (= clipped-row row) (= clipped-col col)) ; Should not happen if %check-bounds failed
              (default-buffer-cell) ; Fallback, or re-signal
              (buffer-cell-at buffer clipped-row clipped-col)))))))

(defun set-buffer-cell-at (buffer row col char style)
  "Modifies the cell at (ROW, COL) with CHAR and STYLE.
Signals INVALID-BUFFER-COORDINATES-ERROR if out of bounds.
Returns the modified BUFFER."
  (check-type buffer virtual-terminal-buffer)
  (check-type row (integer 0 *))
  (check-type col (integer 0 *))
  (check-type char character)
  ;; Handle different style types properly
  (let ((processed-style (cond
                           ((null style) nil)
                           ((typep style 'terminal-style) style)
                           ((listp style) (as-plist style))
                           (t (error "Unsupported style type: ~A" (type-of style))))))
    (with-virtual-buffer-lock (buffer)
      (restart-case
          (progn
            (%check-bounds buffer row col)
            (setf (aref (virtual-terminal-buffer-cells buffer) row col)
                  (make-buffer-cell :char char :style processed-style))
            buffer)
        (use-value (&optional new-char new-style) ; Allow ignoring the operation by not providing values
          :report "Ignore the set operation or provide new char/style to use (or use defaults)."
          :interactive (lambda ()
                         (format *query-io* "~&Set operation for invalid coordinates (~A, ~A).~%" row col)
                         (list (ignore-errors (read-char *query-io*))
                               (ignore-errors (read *query-io* :prompt "Enter style list (or NIL to skip style): "))))
          (when new-char (setf char new-char))
          (when new-style (setf processed-style new-style))
          buffer) ; Return buffer, operation might have been skipped or values changed for a valid coord.
        (clip-coordinates ()
          :report "Clip coordinates to the nearest valid boundary and set the cell there."
          (let ((clipped-row (clamp row 0 (1- (buffer-height buffer))))
                (clipped-col (clamp col 0 (1- (buffer-width buffer)))))
            (unless (and (= clipped-row row) (= clipped-col col)) ; Only if clipping actually changed coords
              (set-buffer-cell-at buffer clipped-row clipped-col char processed-style))
            buffer)))))
  buffer)

(defun fill-buffer-region (buffer row col width height char style)
  "Fills a rectangular region starting at (ROW, COL) with dimensions WIDTH x HEIGHT
with the specified CHAR and STYLE. Handles clipping to buffer boundaries.
The STYLE argument is passed to `set-buffer-cell-at` for each cell, which
handles conversion (e.g. plist to terminal-style) and copying.
Returns the modified BUFFER."
  (check-type buffer virtual-terminal-buffer)
  (check-type row integer)
  (check-type col integer)
  (check-type width (integer 0 *))
  (check-type height (integer 0 *))
  (check-type char character)
  ;; `style` can be nil, a plist, or a terminal-style object.
  ;; `set-buffer-cell-at` will handle its processing.
  (with-virtual-buffer-lock (buffer)
    (let* ((buf-width (buffer-width buffer))
           (buf-height (buffer-height buffer))
           ;; Clip fill region to buffer boundaries
           (fill-start-row (max 0 row))
           (fill-start-col (max 0 col))
           (fill-end-row (min buf-height (+ row height)))
           (fill-end-col (min buf-width (+ col width))))
      (loop for r from fill-start-row below fill-end-row
            do (loop for c from fill-start-col below fill-end-col
                     do (set-buffer-cell-at buffer r c char style)))))
  buffer)

(defun new-buffer (width height &key (default-char #\Space) (default-style nil))
  "Creates a new VIRTUAL-TERMINAL-BUFFER of specified WIDTH and HEIGHT."
  (check-type width (integer 0 *))
  (check-type height (integer 0 *))
  (check-type default-char character)
  (check-type default-style list)
  (let ((buffer (make-virtual-buffer width height)))
    (clear-buffer buffer :char default-char )
    buffer))

(defun clear-buffer (buffer &key (char #\Space) (style nil))
  "Clears the entire buffer by filling it with CHAR and STYLE.
   Returns the modified BUFFER."
  (check-type buffer virtual-terminal-buffer)
  (check-type char character)
  (with-virtual-buffer-lock (buffer)
    (fill-buffer-region buffer 0 0 (buffer-width buffer) (buffer-height buffer) char style))
  buffer)

(defun resize-buffer (buffer new-width new-height &key (default-char #\Space) (default-style nil))
  "Creates a *new* VIRTUAL-TERMINAL-BUFFER of NEW-WIDTH and NEW-HEIGHT.
Copies content from the old BUFFER that fits into the new dimensions.
Fills any new areas (due to expansion) with DEFAULT-CHAR and DEFAULT-STYLE.
Returns the new buffer."
  (check-type buffer virtual-terminal-buffer)
  (check-type new-width (integer 0 *))
  (check-type new-height (integer 0 *))
  (check-type default-char character)
  (check-type default-style list)

  (let ((new-buffer (make-virtual-buffer new-width new-height)))
    ;; Clear the new buffer first to ensure all cells are initialized, especially if new_dims are smaller.
    (clear-buffer new-buffer :char default-char)

    (with-virtual-buffer-lock (buffer) ; Lock old buffer for reading
      (with-virtual-buffer-lock (new-buffer) ; Lock new buffer for writing
        (let ((old-cells (virtual-terminal-buffer-cells buffer))
              (new-cells (virtual-terminal-buffer-cells new-buffer))
              (rows-to-copy (min (buffer-height buffer) new-height))
              (cols-to-copy (min (buffer-width buffer) new-width)))
          (loop for r from 0 below rows-to-copy
                do (loop for c from 0 below cols-to-copy
                         do (let ((old-cell (aref old-cells r c))
                                  (new-cell (aref new-cells r c)))
                              (setf (buffer-cell-char new-cell) (buffer-cell-char old-cell)
                                    (buffer-cell-style new-cell) (copy-list (buffer-cell-style old-cell)))))))))
    new-buffer))

(defun copy-virtual-buffer (buffer)
  "Creates a deep copy of the BUFFER, including a new `cells` array and new `buffer-cell` objects."
  (check-type buffer virtual-terminal-buffer)
  (with-virtual-buffer-lock (buffer)
    (let* ((width (buffer-width buffer))
           (height (buffer-height buffer))
           (new-buffer (%make-virtual-terminal-buffer :width width :height height
                                                      :cells (make-array (list height width) :element-type 'buffer-cell
                                                                                             :initial-element (default-buffer-cell))))
           (old-cells (virtual-terminal-buffer-cells buffer))
           (new-cells (virtual-terminal-buffer-cells new-buffer)))
      (loop for r from 0 below height
            do (loop for c from 0 below width
                     do (let ((old-cell (aref old-cells r c)))
                          (setf (aref new-cells r c)
                                (make-buffer-cell
                                 :char (buffer-cell-char old-cell)
                                 :style (deep-copy-style (buffer-cell-style old-cell)))))))
      new-buffer)))

(defun print-buffer-to-string (buffer &key show-styles-p)
  "Utility for debugging. Renders the buffer content to a string,
optionally including style information."
  (check-type buffer virtual-terminal-buffer)
  (with-output-to-string (s)
    (with-virtual-buffer-lock (buffer)
      (let ((cells (virtual-terminal-buffer-cells buffer))
            (height (buffer-height buffer))
            (width (buffer-width buffer)))
        (loop for r from 0 below height
              do (loop for c from 0 below width
                       do (let ((cell (aref cells r c)))
                            (write-char (buffer-cell-char cell) s)
                            (when show-styles-p
                              (format s "~A" (buffer-cell-style cell)))))
                 (unless (= r (1- height)) (write-char #\Newline s)))))))

;;;----------------------------------------------------------------------------------;;;
;;; New/Adapted Functions                                                            ;;;
;;;----------------------------------------------------------------------------------;;;

(defun write-string-to-buffer (buffer start-row start-col string style
                               &key (max-width nil) (max-height 1) (wrap nil))
  "Writes STRING to the buffer starting at START-ROW, START-COL with STYLE.
  Optional MAX-WIDTH, MAX-HEIGHT for clipping/wrapping.
  If WRAP is true, text wraps within MAX-WIDTH.
  If STYLE is nil, the buffer's `default-style` is used if set, otherwise nil style.
  Returns the modified BUFFER."
  (check-type buffer virtual-terminal-buffer)
  (check-type start-row integer)
  (check-type start-col integer)
  (check-type string string)
  ;; `style` can be nil, a plist, or a terminal-style object.
  (with-virtual-buffer-lock (buffer)
    (let* ((current-row start-row)
           (current-col start-col)
           (buf-width (buffer-width buffer))
           (buf-height (buffer-height buffer))
           (effective-max-width (or max-width (- buf-width start-col)))
           (effective-max-height (or max-height (- buf-height start-row)))
           (lines-written 0)
           ;; Determine the style to use. If input `style` is nil,
           ;; use the buffer's default-style if available, otherwise nil.
           (actual-style (or style (virtual-terminal-buffer-default-style buffer))))

      (when (or (< effective-max-width 0) (< effective-max-height 0))
        (log:warn "VBUFFER: Calculated effective max-width (~A) or max-height (~A) is negative in write-string-to-buffer. String not written."
                  effective-max-width effective-max-height)
        (return-from write-string-to-buffer buffer))

      (loop for char across string
            do
               (when (>= lines-written effective-max-height) (return))

               ;; Check bounds for current_row, current_col before setting
               (when (and (>= current-row 0) (< current-row buf-height)
                          (>= current-col 0) (< current-col buf-width))
                 (set-buffer-cell-at buffer current-row current-col char actual-style))

               (incf current-col)

               (when (>= (- current-col start-col) effective-max-width)
                 (if wrap
                     (progn
                       (incf current-row)
                       (setf current-col start-col)
                       (incf lines-written)
                       ;; If wrapped to a new line, check if we exceeded max_height immediately
                       (when (>= lines-written effective-max-height) (return)))
                     (return)))))) ; Stop if no wrap and max-width reached on current line
  buffer)

(defun copy-buffer-contents (source-buffer target-buffer)
  "Copies the overlapping contents of SOURCE-BUFFER to TARGET-BUFFER.
  Assumes top-left alignment (0,0) for the copy in both buffers.
  Styles are deep-copied via `buffer-cell-at` and `set-buffer-cell-at`.
  Returns the modified TARGET-BUFFER."
  (check-type source-buffer virtual-terminal-buffer)
  (check-type target-buffer virtual-terminal-buffer)
  (with-virtual-buffer-lock (source-buffer)
    (with-virtual-buffer-lock (target-buffer)
      (let ((rows (min (buffer-height source-buffer) (buffer-height target-buffer)))
            (cols (min (buffer-width source-buffer) (buffer-width target-buffer))))
        (loop for r from 0 below rows
              do (loop for c from 0 below cols
                       do (let ((source-cell (buffer-cell-at source-buffer r c))) ; Gets a copy from source
                            (when source-cell ; buffer-cell-at handles its own errors/restarts
                              (set-buffer-cell-at target-buffer r c
                                                  (buffer-cell-char source-cell)
                                                  (buffer-cell-style source-cell))))))))))
