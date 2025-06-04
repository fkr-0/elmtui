(uiop:define-package :elmtui.platform.backend.common.virtual-buffer
  (:use :cl :alexandria)
  (:import-from :elmtui.core.loop #:as-plist)
  (:import-from :elmtui.view.geo #:=?)
  (:import-from :bordeaux-threads #:make-recursive-lock #:with-recursive-lock-held)
  (:export
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
   #:copy-virtual-buffer
   ;; Debugging
   #:print-buffer-to-string
   ;; Restarts
   #:use-value
   #:clip-coordinates))

(in-package :elmtui.platform.backend.common.virtual-buffer)

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
  "Represents a single cell in the virtual terminal buffer."
  (char #\Space :type character)
  (style nil :type list))

(defun default-buffer-cell ()
  "Returns a new buffer-cell with default character and style."
  (%make-buffer-cell))

(defstruct (virtual-terminal-buffer (:constructor %make-virtual-terminal-buffer))
  "Represents a 2D grid of styled characters for the terminal screen."
  (width 0 :type fixnum :read-only t)
  (height 0 :type fixnum :read-only t)
  (cells nil :type (simple-array buffer-cell (* *)))
  (lock (make-recursive-lock "virtual-buffer-lock") :read-only t))

;;;----------------------------------------------------------------------------------;;;
;;; Macros                                                                           ;;;
;;;----------------------------------------------------------------------------------;;;

(defmacro with-virtual-buffer-lock ((buffer) &body body)
  "Acquires the lock for BUFFER and executes BODY."
  `(with-recursive-lock-held ((virtual-terminal-buffer-lock ,buffer))
     ,@body))

;;;----------------------------------------------------------------------------------;;;
;;; Style Copying Utilities                                                          ;;;
;;;----------------------------------------------------------------------------------;;;

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

(defun make-virtual-buffer (width height)
  "Creates a new VIRTUAL-TERMINAL-BUFFER of specified WIDTH and HEIGHT.
Initializes cells with (default-buffer-cell)."
  (check-type width (integer 0 *))
  (check-type height (integer 0 *))
  (let ((cells (make-array (list height width)
                           :initial-element (%make-buffer-cell)
                           :element-type 'buffer-cell)))
    ;; Initialize each cell individually to avoid sharing the same buffer-cell instance
    (dotimes (r height)
      (dotimes (c width)
        (setf (aref cells r c) (%make-buffer-cell :char #\Space :style nil))))
    (%make-virtual-terminal-buffer :width width :height height :cells cells)))

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
  (:method (s) nil)
  (:documentation "Checks if the given style S is a terminal style."))
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
           ((and (listp style1) (listp style2))
            (and (= (length style1) (length style2))
                 (loop for (key value) on style1 by #'cddr
                       always (let ((other-value (getf style2 key :not-found)))
                                (if (eq other-value :not-found)
                                    nil
                                    (elmtui.view.geo:=? value other-value))))))
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
            (%make-buffer-cell
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
  (let ((style (as-plist style)))
    (check-type style list)
    (with-virtual-buffer-lock (buffer)
      (restart-case
          (progn
            (%check-bounds buffer row col)
            (let ((cell (aref (virtual-terminal-buffer-cells buffer) row col)))
              (setf (aref (virtual-terminal-buffer-cells buffer) row col)
                    (%make-buffer-cell :char char :style (deep-copy-style style)))
              ;; (buffer-cell-char cell) char
              ;;      ;; Create a deep copy of the style to prevent shared references
              ;;      (buffer-cell-style cell) (deep-copy-style style)))
              buffer))
        (use-value (&optional new-char new-style) ; Allow ignoring the operation by not providing values
          :report "Ignore the set operation or provide new char/style to use (or use defaults)."
          :interactive (lambda ()
                         (format *query-io* "~&Set operation for invalid coordinates (~A, ~A).~%" row col)
                         (list (ignore-errors (read-char *query-io*))
                               (ignore-errors (read *query-io* :prompt "Enter style list (or NIL to skip style): "))))
          (when new-char (setf char new-char))
          (when new-style (setf style new-style))
          ;; If new-char/new-style are nil, this effectively becomes a skip if we don't proceed.
          ;; For now, we just use the (potentially modified) char/style and let it error again if still invalid.
          ;; A more robust `use-value` might allow specifying new coords or truly skipping.
          ;; This restart is more for "ignore the error and don't set" or "try setting with this value if coords were okay".
          ;; The primary use of `use-value` for `set-buffer-cell-at` is to effectively skip the operation.
          buffer) ; Return buffer, operation might have been skipped or values changed for a valid coord.
        (clip-coordinates ()
          :report "Clip coordinates to the nearest valid boundary and set the cell there."
          (let ((clipped-row (clamp row 0 (1- (buffer-height buffer))))
                (clipped-col (clamp col 0 (1- (buffer-width buffer)))))
            (unless (and (= clipped-row row) (= clipped-col col)) ; Only if clipping actually changed coords
              (set-buffer-cell-at buffer clipped-row clipped-col char (copy-list style)))
            buffer)))))
  buffer)

(defun fill-buffer-region (buffer row col width height char style)
  "Fills a rectangular region starting at (ROW, COL) with dimensions WIDTH x HEIGHT
with the specified CHAR and STYLE. Handles clipping to buffer boundaries.
Returns the modified BUFFER."
  (check-type buffer virtual-terminal-buffer)
  (check-type row integer)
  (check-type col integer)
  (check-type width (integer 0 *))
  (check-type height (integer 0 *))
  (check-type char character)
  (check-type style list)
  (with-virtual-buffer-lock (buffer)
    (let* ((buf-width (buffer-width buffer))
           (buf-height (buffer-height buffer))
           (start-row (max 0 row))
           (start-col (max 0 col))
           (end-row (min buf-height (+ row height)))
           (end-col (min buf-width (+ col width))))
      ;; Create a deep copy of the style once, outside the loops
      (let ((copied-style (deep-copy-style style)))
        (loop for r from start-row below end-row
              do (loop for c from start-col below end-col
                       do (let ((cell (aref (virtual-terminal-buffer-cells buffer) r c)))
                            (setf (buffer-cell-char cell) char
                                  ;; Create a fresh copy of the already deep-copied style for each cell
                                  (buffer-cell-style cell) (copy-list copied-style))))))))
  buffer)

(defun new-buffer (width height &key (default-char #\Space) (default-style nil))
  "Creates a new VIRTUAL-TERMINAL-BUFFER of specified WIDTH and HEIGHT."
  (check-type width (integer 0 *))
  (check-type height (integer 0 *))
  (check-type default-char character)
  (check-type default-style list)
  (let ((buffer (make-virtual-buffer width height)))
    (clear-buffer buffer :default-char default-char :default-style default-style)
    buffer))

(defun clear-buffer (buffer &key (default-char #\Space) (default-style nil))
  "Fills the entire BUFFER with the specified DEFAULT-CHAR and DEFAULT-STYLE.
Returns the modified BUFFER."
  (check-type buffer virtual-terminal-buffer)
  (check-type default-char character)
  (check-type default-style list)
  (fill-buffer-region buffer 0 0
                      (buffer-width buffer)
                      (buffer-height buffer)
                      default-char default-style)
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
    (clear-buffer new-buffer :default-char default-char :default-style default-style)

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
                                (%make-buffer-cell
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
