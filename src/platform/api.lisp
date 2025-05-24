;;;===============================================================
;;; File: src/platform/api.lisp
;;; Platform Abstraction API
;;;
;;; This file defines the generic functions that any platform backend
;;; must implement to integrate with elmtui. These functions model
;;; the abstract behavior required for rendering, input, and display
;;; management, independent of any specific terminal library.
;;;===============================================================

(uiop:define-package :elmtui.platform.api
  (:use :cl)
  (:export
   :lockable
   :lock-of
   :with-lock
   :acquire-lock
   :release-lock
   ;; Backend Lifecycle
   :initialize-backend
   :shutdown-backend
   :backend-name
   :backend-version

   ;; Display & Screen Management
   :get-screen-dimensions
   :clear-screen
   :flush-output
   :set-cursor-visibility
   :set-cursor-position
   :get-cursor-position
   :hide-cursor
   :show-cursor

   ;; Drawing Primitives
   :draw-text-at
   :draw-char-at
   :fill-rectangle
   :draw-box-outline
   :draw-styled-box ; New generic for detailed border drawing
   :set-cell-style
   :clear-area

   ;; Color and Style Management
   :make-color
   :make-style
   :apply-style
   :default-foreground-color
   :default-background-color
   :supports-truecolor-p
   :max-colors

   ;; Terminal Instance
   :term-w
   :term-h
   :term-stream
   :term-style
   ;; (setf term-w) and (setf term-h) are made available by exporting :term-w and :term-h
   ;; and defining the (setf ...) generic functions. No need for explicit (setf ...) in :export.

   ;; Input Handling
   :poll-input-event
   :peek-input-event
   :enable-mouse-support
   :disable-mouse-support
   :set-input-mode ; e.g., :raw, :cooked

   ;; Capability Querying
   :query-feature
   :supports-unicode-p
   :supports-mouse-p

   ;; terminal stats


   ;; Raw Access (Escape Hatch)
   :get-native-handle))

(in-package :elmtui.platform.api)

(defclass lockable ()
  ((lock :initarg :lock
         :initform (bt:make-recursive-lock)
         :accessor lock-of)
   (lock-owner :initarg :lock-owner
               :initform nil
               :accessor lock-owner)
   (lock-owner-count :initarg :lock-owner-count
                     :initform 0
                     :accessor lock-owner-count)))

(defmethod acquire-lock ((l lockable))
  "Acquire the terminal lock. If the lock is already held by the current thread,
increment the lock count. Otherwise, acquire the lock and set the lock owner to
the current thread."
  (with-slots (lock lock-owner lock-owner-count)
      l
    (bt:with-recursive-lock-held (lock)
      (if (eq lock-owner t)
          (incf lock-owner-count)
          (setf lock-owner t
                lock-owner-count 1)))))

(defmethod release-lock ((l lockable))
  "Release the terminal lock. If the lock count is greater than 1, decrement the
lock count. Otherwise, release the lock and set the lock owner to nil."
  (with-slots (lock lock-owner lock-owner-count)
      l
    (bt:with-recursive-lock-held (lock)
      (when (eq lock-owner t)
        (if (> lock-owner-count 1)
            (decf lock-owner-count)
            (setf lock-owner nil
                  lock-owner-count 0))))))

(defmacro with-lock ((lockable) &body body)
  "Execute BODY with LOCKABLE locked."
  `(progn
     (acquire-lock ,lockable)
     (unwind-protect (progn ,@body) (release-lock ,lockable))))
(defgeneric term-w (term))
(defgeneric term-h (term))
(defgeneric (setf term-w) (new-value term))
(defgeneric (setf term-h) (new-value term))
(defgeneric term-stream (term))
(defgeneric term-style (term))
;;;---------------------------------------------------------------
;;; Backend Lifecycle
;;;---------------------------------------------------------------

(defgeneric initialize-backend (backend-type &key &allow-other-keys)
  (:documentation "Initializes and configures the specified platform backend.
This function should perform any necessary setup, such as opening a connection
to the terminal, setting up initial modes, or allocating resources.
It should return an opaque backend instance handle that will be passed to
other platform API functions.
BACKEND-TYPE: A symbol or keyword identifying the backend to initialize (e.g., :ncurses, :cl-charms).
ALLOW-OTHER-KEYS: Backend-specific initialization options can be passed.
Returns the backend instance or signals an error on failure."))

(defgeneric shutdown-backend (backend-instance)
  (:documentation "Shuts down the platform backend and releases all associated resources.
This function should perform cleanup tasks like closing terminal connections,
restoring terminal modes, and freeing memory.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND."))

(defgeneric backend-name (backend-instance)
  (:documentation "Returns a string identifying the name of the backend (e.g., \"NCurses\").
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND."))

(defgeneric backend-version (backend-instance)
  (:documentation "Returns a string identifying the version of the backend library.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND."))

;;;---------------------------------------------------------------
;;; Display & Screen Management
;;;---------------------------------------------------------------

(defgeneric get-screen-dimensions (backend-instance)
  (:documentation "Returns the current dimensions of the terminal screen.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
Returns (VALUES WIDTH HEIGHT) in character cells."))

(defgeneric clear-screen (backend-instance)
  (:documentation "Clears the entire terminal screen.
The cursor position may be affected (typically moved to 0,0).
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND."))

(defgeneric flush-output (backend-instance)
  (:documentation "Forces any buffered output to be displayed on the terminal.
Some backends buffer drawing commands for efficiency; this ensures they are
rendered immediately.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND."))

(defgeneric set-cursor-visibility (backend-instance visible-p)
  (:documentation "Sets the visibility of the terminal cursor.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
VISIBLE-P: A boolean; T to show the cursor, NIL to hide it."))

(defgeneric set-cursor-position (backend-instance row col)
  (:documentation "Moves the terminal cursor to the specified row and column.
Coordinates are 0-indexed (top-left is 0,0).
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
ROW: The target row.
COL: The target column."))

(defgeneric get-cursor-position (backend-instance)
  (:documentation "Gets the current position of the terminal cursor.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
Returns (VALUES ROW COL)."))

(defgeneric hide-cursor (backend-instance)
  (:documentation "Convenience function to hide the terminal cursor. Equivalent to (set-cursor-visibility backend-instance nil).
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND."))

(defgeneric show-cursor (backend-instance)
  (:documentation "Convenience function to show the terminal cursor. Equivalent to (set-cursor-visibility backend-instance t).
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND."))

;;;---------------------------------------------------------------
;;; Drawing Primitives
;;;---------------------------------------------------------------

(defgeneric draw-text-at (backend-instance row col text &key style)
  (:documentation "Draws a string of text at the specified row and column.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
ROW: The starting row for the text.
COL: The starting column for the text.
TEXT: The string to draw.
STYLE: An optional backend-specific style object (e.g., color, attributes) created by MAKE-STYLE.
If NIL, backend default style is used."))

(defgeneric draw-char-at (backend-instance row col char &key style)
  (:documentation "Draws a single character at the specified row and column.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
ROW: The row for the character.
COL: The column for the character.
CHAR: The character to draw.
STYLE: An optional backend-specific style object. If NIL, backend default style is used."))

(defgeneric fill-rectangle (backend-instance row col height width &key char style)
  (:documentation "Fills a rectangular area of the screen with a specified character and style.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
ROW: The top row of the rectangle.
COL: The left column of the rectangle.
HEIGHT: The height of the rectangle in character cells.
WIDTH: The width of the rectangle in character cells.
CHAR: The character to fill with. Defaults to a space if not provided by the backend.
STYLE: An optional backend-specific style object. If NIL, backend default style is used."))

(defgeneric draw-box-outline (backend-instance row col height width &key style corners sides)
  (:documentation "Draws the outline of a box using line-drawing characters.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
ROW: The top row of the box.
COL: The left column of the box.
HEIGHT: The height of the box.
WIDTH: The width of the box.
STYLE: An optional backend-specific style object for the lines.
CORNERS: A list of four characters for top-left, top-right, bottom-left, bottom-right corners.
         Defaults to backend-specific line drawing characters.
SIDES: A list of two characters for horizontal and vertical lines.
       Defaults to backend-specific line drawing characters."))

(defgeneric draw-styled-box (backend-instance row col height width &key border-style border-color box-char-set style)
  (:documentation "Draws a box with potentially different styles for each side/corner.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
ROW: The top row of the box.
COL: The left column of the box.
HEIGHT: The height of the box.
WIDTH: The width of the box.
BORDER-STYLE: A keyword or list describing the line style (e.g., :single, :double, or a list for individual sides).
BORDER-COLOR: A color spec or list of color specs for the border lines.
BOX-CHAR-SET: (Optional) A specific set of characters to use for corners and lines,
              allowing for styles like :ascii or custom characters. If nil, backend chooses based on BORDER-STYLE.
STYLE: An optional backend-specific style object (primarily for foreground color of the border).
       If BORDER-COLOR is provided, it should take precedence for the border lines themselves."))

(defgeneric set-cell-style (backend-instance row col &key style)
  (:documentation "Applies a style to the character cell at the given coordinates without changing the character itself.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
ROW: The row of the cell.
COL: The column of the cell.
STYLE: The backend-specific style object to apply."))

(defgeneric clear-area (backend-instance row col height width &key style)
  (:documentation "Clears a rectangular area of the screen, typically filling it with spaces using a given style.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
ROW: The top row of the area.
COL: The left column of the area.
HEIGHT: The height of the area.
WIDTH: The width of the area.
STYLE: An optional backend-specific style object (often just background color). If NIL, uses default background."))

;;;---------------------------------------------------------------
;;; Color and Style Management
;;;---------------------------------------------------------------

(defgeneric make-color (backend-instance r-or-name &optional g b)
  (:documentation "Creates a backend-specific representation of a color.
Supports named colors (e.g., :RED, :BLUE), or RGB values if the backend supports truecolor.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
R-OR-NAME: A keyword for a named color (e.g., :BLACK, :WHITE, :RED, :GREEN, :YELLOW, :BLUE, :MAGENTA, :CYAN)
             or the red component (0-255) if G and B are also provided.
G: The green component (0-255), if using RGB.
B: The blue component (0-255), if using RGB.
Returns a backend-specific color object or representation."))

(defgeneric make-style (backend-instance &key foreground-color background-color attributes)
  (:documentation "Creates a backend-specific style object from color and text attributes.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
FOREGROUND-COLOR: A color object created by MAKE-COLOR for the text.
BACKGROUND-COLOR: A color object created by MAKE-COLOR for the background.
ATTRIBUTES: A list of keywords representing text attributes (e.g., :BOLD, :ITALIC, :UNDERLINE, :REVERSE).
            Supported attributes are backend-dependent.
Returns a backend-specific style object."))

(defgeneric apply-style (backend-instance style)
  (:documentation "Sets the current drawing style for subsequent drawing operations.
This is an alternative to passing :STYLE to each drawing function if multiple
operations share the same style. Not all backends may support a global current style.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
STYLE: The backend-specific style object created by MAKE-STYLE."))

(defgeneric default-foreground-color (backend-instance)
  (:documentation "Returns the backend's default foreground color.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
Returns a backend-specific color object."))

(defgeneric default-background-color (backend-instance)
  (:documentation "Returns the backend's default background color.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
Returns a backend-specific color object."))

(defgeneric supports-truecolor-p (backend-instance)
  (:documentation "Returns T if the backend supports 24-bit truecolor (RGB), NIL otherwise.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND."))

(defgeneric max-colors (backend-instance)
  (:documentation "Returns the maximum number of distinct colors supported by the backend.
For truecolor backends, this might return a very large number (e.g., 2^24) or a special value.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND."))

;;;---------------------------------------------------------------
;;; Input Handling
;;;---------------------------------------------------------------

(defgeneric poll-input-event (backend-instance &key timeout)
  (:documentation "Polls for the next input event from the terminal.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
TIMEOUT: An optional non-negative real number in seconds.
         If 0, returns immediately (non-blocking).
         If NIL or not provided, blocks indefinitely until an event occurs.
         If > 0, waits for up to TIMEOUT seconds.
Returns an event object (structure/plist) representing the input, or NIL if no event
is available within the timeout. Event objects should be standardized as much as
possible (e.g., (:type :key :key :f1 :modifiers (:control)), (:type :mouse ...))."))

(defgeneric peek-input-event (backend-instance)
  (:documentation "Checks if an input event is available without consuming it.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
Returns the event object if available, or NIL otherwise. Subsequent calls to
POLL-INPUT-EVENT or PEEK-INPUT-EVENT will return the same event if it was not consumed."))

(defgeneric enable-mouse-support (backend-instance &key motion-events-p)
  (:documentation "Enables mouse event reporting for the terminal, if supported.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
MOTION-EVENTS-P: If T, attempts to enable mouse motion events as well.
Returns T if mouse support was successfully enabled, NIL otherwise."))

(defgeneric disable-mouse-support (backend-instance)
  (:documentation "Disables mouse event reporting for the terminal.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND."))

(defgeneric set-input-mode (backend-instance mode)
  (:documentation "Sets the terminal input mode (e.g., raw, cooked, cbreak).
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
MODE: A keyword representing the desired mode (e.g., :RAW, :COOKED, :CBREAK).
      Supported modes are backend-dependent.
Returns T if the mode was set successfully, NIL otherwise."))

;;;---------------------------------------------------------------
;;; Capability Querying
;;;---------------------------------------------------------------

(defgeneric query-feature (backend-instance feature-keyword)
  (:documentation "Queries the backend for support of a specific feature.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
FEATURE-KEYWORD: A keyword identifying the feature (e.g., :UNICODE, :TRUECOLOR, :MOUSE-MOTION, :BLINK-TEXT).
Returns T if the feature is supported, NIL otherwise. This is more general than
specific functions like SUPPORTS-TRUECOLOR-P."))

(defgeneric supports-unicode-p (backend-instance)
  (:documentation "Returns T if the backend and terminal are configured to support Unicode characters correctly.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND."))

(defgeneric supports-mouse-p (backend-instance)
  (:documentation "Returns T if the backend can provide mouse input events.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND."))

;;;---------------------------------------------------------------
;;; Raw Access (Escape Hatch)
;;;---------------------------------------------------------------

(defgeneric get-native-handle (backend-instance)
  (:documentation "Returns the underlying native handle or object used by the backend (e.g., ncurses WINDOW*).
This provides an escape hatch for backend-specific operations not covered by the API.
Use with caution, as it breaks platform independence.
BACKEND-INSTANCE: The opaque handle returned by INITIALIZE-BACKEND.
Returns a native handle, or NIL if not applicable or not exposed."))

;; (defgeneric terminal-instance-width (backend-instance)
;;   (:documentation "Returns the width of the terminal instance in character cells."))

;; (defgeneric terminal-instance-height (backend-instance)
;;   (:documentation "Returns the height of the terminal instance in character cells."))

;; (defgeneric terminal-instance-stream (backend-instance)
;;   (:documentation "Returns the stream associated with the terminal instance."))

;; (defgeneric terminal-instance-current-style (backend-instance)
;;   (:documentation "Returns the current style applied to the terminal instance."))

;;;--------------------------------------------------------------- ;;; Recovery and Reset ;;;---------------------------------------------------------------
