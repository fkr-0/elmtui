(uiop:define-package :elmtui.platform.backend.common.ansi-styling
  (:use :cl :log4cl)
  (:import-from :elmtui.platform.api :with-lock :lockable)
  (:import-from :elmtui.utils :hex-str-to-rgb)
  (:import-from :elmtui.view.geo :=?)
  (:export
   #:fuzz-color
   #:terminal-style-bg-color
   #:make-terminal-color
   #:terminal-style
   #:make-terminal-style
   #:terminal-color
   #:make-termcolor
   #:no-color-p
   #:terminal-style-bold
   #:terminal-style-italic
   #:terminal-style-underline
   #:terminal-style-faint
   #:terminal-style-blink
   #:terminal-style-inverse
   #:terminal-style-strike
   #:terminal-style-invisible
   #:deep-copy-style
   #:copy-term-color

   #:terminal-color-simple
   #:terminal-color-kv
   #:terminal-color-bg
   #:style-to-terminal-style
   #:terminal-style-kv
   #:terminal-style-bg-color
   #:terminal-style-fg-color
   #:terminal-style-bg-color-val
   #:terminal-style-fg-color-val
   #:update-style!
   #:exec-sequence
   #:copy-term-color
   #:copy-term-style
   #:ansi-seqs
   #:as-plist
   #:terminal-color
   ))
(in-package :elmtui.platform.backend.common.ansi-styling)

(defgeneric as-plist (style)
  (:documentation "Convert STYLE to plist representation for terminal rendering."))

(defstruct terminal-color red green blue simple bg color-256)
(defstruct terminal-style
  fg-color
  bg-color
  bold
  italic
  underline
  faint
  blink
  inverse
  strike
  invisible)
(defun fuzz-color (in &optional (bg nil))
  (unless (null in)
    (etypecase in
      (terminal-color in)
      (list (if (or (and (listp in) (= (length in) 3))
                    (and (listp in) (= (length in) 1)))
                (or
                 (and (= (length in) 3) (make-terminal-color :red (first in) :green (second in) :blue (third in) :bg bg))
                 (if (integerp (car in))(make-terminal-color :color-256 (first in) :bg bg)
                     (and (symbolp (first in))(make-terminal-color :simple (first in) :bg bg))))

                ))
      (integer (make-terminal-color :color-256 in :bg bg))
      (keyword (make-terminal-color :simple in :bg bg))
      (string (let ((rgb (hex-str-to-rgb in)))
                (and rgb (make-terminal-color :bg bg
                                              :red (first rgb)
                                              :green (second rgb)
                                              :blue (third rgb))))))))
(defun style-to-terminal-style (style-plist)
  "Converts a style plist to a terminal-style instance, ensuring a valid
   terminal-style object is always returned.
   Args:
   - STYLE-PLIST: A property list containing style attributes.
   Returns:
   - A terminal-style instance with the specified attributes."
  (let ((ts (make-terminal-style)))
    (when (and style-plist (listp style-plist))
      (let ((bg-color-val (or (getf style-plist :bg)
                              (getf style-plist :bg-color)
                              (getf style-plist :background-color))))
        (when bg-color-val
          (let ((bg (fuzz-color bg-color-val t)))
            (when bg
              (setf (terminal-style-bg-color ts) bg)))))
      (let ((fg-color-val (or (getf style-plist :fg)
                              (getf style-plist :fg-color)
                              (getf style-plist :color)
                              (getf style-plist :foreground-color))))
        (when fg-color-val
          (let ((fg (fuzz-color fg-color-val)))
            (when fg
              (setf (terminal-style-fg-color ts) fg)))))
      (let ((attrs (getf style-plist :attributes)))
        (when (listp attrs)
          (when (member :bold attrs) (setf (terminal-style-bold ts) t))
          (when (member :italic attrs) (setf (terminal-style-italic ts) t))
          (when (member :underline attrs) (setf (terminal-style-underline ts) t))
          (when (member :inverse attrs) (setf (terminal-style-inverse ts) t))
          (when (member :faint attrs) (setf (terminal-style-faint ts) t))
          (when (member :blink attrs) (setf (terminal-style-blink ts) t))
          (when (member :strike attrs) (setf (terminal-style-strike ts) t))
          (when (member :invisible attrs) (setf (terminal-style-invisible ts) t)))))
    ts))
;; (defgeneric mcopy-terminal-style (style)
;;   (:method ((style terminal-style))
;;     "Creates a deep copy of a terminal-style instance."
;;     (make-terminal-style
;;      :fg-color (copy-term-color (terminal-style-fg-color style))
;;      :bg-color (copy-term-color (terminal-style-bg-color style))
;;      :bold (terminal-style-bold style)
;;      :italic (terminal-style-italic style)
;;      :underline (terminal-style-underline style)
;;      :faint (terminal-style-faint style)
;;      :blink (terminal-style-blink style)
;;      :inverse (terminal-style-inverse style)
;;      :strike (terminal-style-strike style)
;;      :invisible (terminal-style-invisible style))))


;; (defun terminal-style-fg-color-val (style)
;;   "Get the simple color value from a terminal style's foreground color."
;;   (when (and style (terminal-style-fg-color style))
;;     (termcolor-simple (terminal-style-fg-color style))))

;; (defun terminal-style-bg-color-val (style)
;;   "Get the simple color value from a terminal style's background color."
;;   (when (and style (terminal-style-bg-color style))
;;     (termcolor-simple (terminal-style-bg-color style))))
(defmethod deep-copy-style ((style elmtui.platform.backend.common.ansi-styling:terminal-style))
  "Creates a deep copy of a terminal-style instance."
  (copy-term-style style))
;; (defgeneric from-styles (styles)
;;   "Derives a Terminal-Style from regular styles object")

(defmethod make-termcolor
    (&key (r nil) (g nil) (b nil) (simple nil) (bg nil)
       (color-256 nil))
  (make-terminal-color :red r
                       :green g
                       :blue b
                       :simple simple
                       :color-256 color-256
                       :bg bg))

(defmethod no-color-p ((c terminal-color))
  (and (not (terminal-color-red c))
       (not (terminal-color-green c))
       (not (terminal-color-blue c))
       (not (terminal-color-simple c))
       (not (terminal-color-color-256 c))))

(defun stringify-sgr (parts)
  "Turn a list of strings/numbers into a full ESC[…m sequence."
  ;; (log-info "PARTS: ~A" parts)
  (format nil "~C[~{~A~}m" (code-char 27) parts))
;; == uncharming-tui/lowterm/terminal-style/color.lisp ==
;; -------- Colour code tables & helpers --------

(defparameter *basic-colors*
  ;; keyword → index 0-7
  '((:black   . 0) (:red      . 1) (:green  . 2) (:yellow . 3)
    (:blue    . 4) (:magenta  . 5) (:cyan   . 6) (:white  . 7)
    (:bright-black . 60) (:bright-red . 61) (:bright-green . 62)
    (:bright-yellow . 63) (:bright-blue . 64) (:bright-magenta . 65)
    (:bright-cyan . 66) (:bright-white . 67)))


(defun %simple-sgr-code (keyword &key bg );bright)
  "Return the numeric SGR code (30–37 / 90–97 / 40–47 / 100–107)
   for a *basic* colour keyword."
  (let ((idx (cdr (assoc keyword *basic-colors*))))
    (unless idx (error "Unknown simple colour ~A" keyword))
    (+ (if bg 40 30)
       idx
       ;; (if bright 60 0)
       )))

;; (defun stringify-sgr (parts)
;;   "Turn a list of strings/numbers into a full ESC[…m sequence."
;;   (format nil "[~{~A~}m" parts))
;; == end/color.lisp ==

;; == uncharming-tui/lowterm/terminal-style/to-ansi.lisp ==
(defmethod to-ansi-seq ((col t)  &key bg)
  (cond
    ;; ---------- reset -------------

    ;; ---------- true colour -------
    ((and (listp col)
          (integerp (first col))
          (integerp (second col))
          (integerp (third col)))
     (stringify-sgr
      (list (if bg 48 38)
            #\; #\2 #\;                    ; “;2;”
            (first   col) #\;
            (second col) #\;
            (third  col))))
    ;; ---------- 256-colour --------
    ((integerp col)
     (stringify-sgr
      (list (if  bg  48 38)
            #\; #\5 #\;                    ; “;5;”
            col)))
    ;; ---------- simple keyword ----
    ((keywordp col)
     (stringify-sgr
      (list (%simple-sgr-code col
                              :bg bg))))
    (t (error "Unsupported colour spec ~S" col))))
(defmethod to-ansi-seq ((col terminal-color) &key bg)
  (cond
    ;; ---------- reset -------------
    ((no-color-p col)
     (stringify-sgr (list (if bg 49 39))))
    ;; ---------- true colour -------
    ((and (integerp (terminal-color-red col))
          (integerp (terminal-color-green col))
          (integerp (terminal-color-blue col)))
     (stringify-sgr
      (list (if (or bg (terminal-color-bg col)) 48 38)
            #\; #\2 #\;                    ; “;2;”
            (terminal-color-red   col) #\;
            (terminal-color-green col) #\;
            (terminal-color-blue  col))))
    ;; ---------- 256-colour --------
    ((integerp (terminal-color-color-256 col))
     (stringify-sgr
      (list (if (or bg (terminal-color-bg col)) 48 38)
            #\; #\5 #\;                    ; “;5;”
            (terminal-color-color-256 col))))
    ;; ---------- simple keyword ----
    ((keywordp (terminal-color-simple col))
     (stringify-sgr
      (list (%simple-sgr-code (terminal-color-simple col)
                              :bg (or bg (terminal-color-bg col))))))
    (t (error "Unsupported colour spec ~S" col))))

(defmethod to-ansi-seq ((col null) &key (bg nil))
  "Converts a color to an ANSI sequence. Base case:
in case col is nil, return the default ANSI sequence for
bg or fg, that causes the terminal to use the default color.
   Args:
   - COL: The color to convert.
   - BG: If true, use the background color.
   Returns:
   - An ANSI sequence string.

   Example:
   (to-ansi-seq nil :bg t) => \"[49m\""
  (stringify-sgr (list (if bg 49 39))))

;; == end/to-ansi.lisp ==

;; == uncharming-tui/lowterm/terminal-style/attributes.lisp ==
(defparameter *attr-code*
  '((:bold         1 22)
    (:italic       3 23)
    (:underline    4 24)
    (:faint        2 22)
    (:blink        5 25)
    (:inverse      7 27)
    (:strike       9 29)
    (:invisible    8 28)))

(defun attr-code (key onp)
  (let ((entry (assoc key *attr-code*)))
    (unless entry (error "Unknown attribute ~A" key))
    (if onp (second entry) (third entry))))
(defmethod style-of ((s terminal-style) &rest attrs)
  "Return the value of STYLE attributes from terminal-style S.
If a single attribute is requested, return its value (t or nil).
If multiple attributes are requested, return a list of values in order."
  (let ((values
          (loop for k in attrs collect
                               (case k
                                 (:fg-color (terminal-style-fg-color s))
                                 (:bg-color (terminal-style-bg-color s))
                                 (:bold (terminal-style-bold s))
                                 (:italic (terminal-style-italic s))
                                 (:underline (terminal-style-underline s))
                                 (:faint (terminal-style-faint s))
                                 (:blink (terminal-style-blink s))
                                 (:inverse (terminal-style-inverse s))
                                 (:strike (terminal-style-strike s))
                                 (:invisible (terminal-style-invisible s))
                                 (t nil)))))
    (if (= (length values) 1)
        (first values)
        values)))

(defmethod ansi-seqs ((s terminal-style) &rest attrs)
  (loop for k in attrs collect
                       (case k
                         (:fg-color (to-ansi-seq (terminal-style-fg-color s)))
                         (:bg-color (to-ansi-seq (terminal-style-bg-color s) :bg t))
                         (otherwise
                          (stringify-sgr
                           (list (attr-code k (style-of s k))))))))

(defmethod ansi-seqs ((s null) &rest attrs)
  "Should accept a list of attributes and return the ANSI escape
   sequences for them. The list should contain the attributes in
   the form of keyword value pairs. The non-color attrs may be set as
   '(:fg-color :blue :bold t) or '(:fg-color :blue :attrs '(:bold :underline))
   Args:
   - S: The list of attributes to convert.
   - ATTRS: The attributes to convert.
   Returns:
   - A list of ANSI escape sequences."
  (declare (ignore attrs))
  nil)
(defmethod ansi-seqs ((s list) &rest attrs)
  "Should accept a list of attributes and return the ANSI escape
   sequences for them. The list should contain the attributes in
   the form of keyword value pairs. The non-color attrs may be set as
   '(:fg-color :blue :bold t) or '(:fg-color :blue :attrs '(:bold :underline))
   Args:
   - S: The list of attributes to convert.
   - ATTRS: The attributes to convert.
   Returns:
   - A list of ANSI escape sequences."
  (log-info "ansi-seqs: ~A attrs: ~A" s attrs)
  (mapcar
   (lambda
       (kv)
     (let ((k (car kv)))
       (case k
         (:fg-color (to-ansi-seq (second kv)))
         (:bg-color (to-ansi-seq (second kv) :bg t))
         (otherwise (stringify-sgr (list (attr-code k (second kv))))))))
   s))
;; == end/attributes.lisp ==

(defun is-csi-final-byte? (char)
  (and (>= (char-code char) (char-code #\@))
       (<= (char-code char) (char-code #\~))))


(defmethod terminal-style-kv ((s terminal-style) k v)
  (case k
    (:fg (setf (terminal-style-fg-color s) v))
    (:bg (setf (terminal-style-bg-color s) v))
    (:bold (setf (terminal-style-bold s) v))
    (:italic (setf (terminal-style-italic s) v))
    (:underline (setf (terminal-style-underline s) v))
    (:faint (setf (terminal-style-faint s) v))
    (:blink (setf (terminal-style-blink s) v))
    (:inverse (setf (terminal-style-inverse s) v))
    (:strike (setf (terminal-style-strike s) v))
    (:invisible (setf (terminal-style-invisible s) v))
    (otherwise (error "Invalid key ~A" k))))

(defmethod =? ((c1 t) (c2 t)) (equalp c1 c2))

(defmethod =? ((c1 null) (c2 null)) t)

(defmethod =? ((c1 integer) (c2 integer)) (= c1 c2))

;; (defmethod =? ((c1 t) (c2 null))
;;   nil)
;; (defmethod =? ((c1 null) (c2 t))
;;   nil)

(defmethod =? ((c1 terminal-color) (c2 terminal-color))
  (and (eq (terminal-color-bg c1) (terminal-color-bg c2)) ; BG flag must match
       (cond
         ;; Both have RGB values
         ((and (terminal-color-red c1) (terminal-color-green c1) (terminal-color-blue c1)
               (terminal-color-red c2) (terminal-color-green c2) (terminal-color-blue c2))
          (and (integerp (terminal-color-red c1)) (integerp (terminal-color-red c2))
               (= (terminal-color-red c1) (terminal-color-red c2))
               (integerp (terminal-color-green c1)) (integerp (terminal-color-green c2))
               (= (terminal-color-green c1) (terminal-color-green c2))
               (integerp (terminal-color-blue c1)) (integerp (terminal-color-blue c2))
               (= (terminal-color-blue c1) (terminal-color-blue c2))))
         ;; Both have simple keyword values
         ((and (terminal-color-simple c1) (terminal-color-simple c2))
          (and (keywordp (terminal-color-simple c1)) (keywordp (terminal-color-simple c2))
               (eq (terminal-color-simple c1) (terminal-color-simple c2))))
         ;; Both have 256-color values
         ((and (terminal-color-color-256 c1) (terminal-color-color-256 c2))
          (and (integerp (terminal-color-color-256 c1)) (integerp (terminal-color-color-256 c2))
               (= (terminal-color-color-256 c1) (terminal-color-color-256 c2))))
         ;; Both are "no color" (all specific color fields are nil)
         ((and (no-color-p c1) (no-color-p c2))
          t)
         ;; Otherwise, they are different (e.g., one RGB, one simple, or one has color and other doesn't)
         (t nil))))

(defmethod =? ((style-1 terminal-style) (style-2 terminal-style))
  (and (=? (terminal-style-fg-color style-1) (terminal-style-fg-color style-2))
       (=? (terminal-style-bg-color style-1) (terminal-style-bg-color style-2))
       (=? (terminal-style-bold style-1) (terminal-style-bold style-2))
       (=? (terminal-style-italic style-1) (terminal-style-italic style-2))
       (=? (terminal-style-underline style-1)
           (terminal-style-underline style-2))
       (=? (terminal-style-faint style-1) (terminal-style-faint style-2))
       (=? (terminal-style-blink style-1) (terminal-style-blink style-2))
       (=? (terminal-style-inverse style-1) (terminal-style-inverse style-2))
       (=? (terminal-style-strike style-1) (terminal-style-strike style-2))))

(defmethod terminal-style-bg-color-val ((style terminal-style))
  (when (terminal-style-bg-color style)
    (let ((bg-color (terminal-style-bg-color style)))
      (cond
        ((and (integerp (terminal-color-red bg-color))
              (integerp (terminal-color-green bg-color))
              (integerp (terminal-color-blue bg-color)))
         (list (terminal-color-red bg-color) (terminal-color-green bg-color)
               (terminal-color-blue bg-color)))
        ((and (integerp (terminal-color-color-256 bg-color)))
         (terminal-color-color-256 bg-color))
        ((keywordp (terminal-color-simple bg-color))
         (terminal-color-simple bg-color))
        (t nil)))))

(defmethod terminal-style-fg-color-val ((style terminal-style))
  (when (terminal-style-fg-color style)
    (let ((fg-color (terminal-style-fg-color style)))
      (cond
        ((and (integerp (terminal-color-red fg-color))
              (integerp (terminal-color-green fg-color))
              (integerp (terminal-color-blue fg-color)))
         (list (terminal-color-red fg-color) (terminal-color-green fg-color)
               (terminal-color-blue fg-color)))
        ((and (integerp (terminal-color-color-256 fg-color)))
         (terminal-color-color-256 fg-color))
        ((keywordp (terminal-color-simple fg-color))
         (terminal-color-simple fg-color))
        (t nil)))))

(defmethod update-style! ((style null) (update-style terminal-style))
  "Update the style STYLE with the values from UPDATE-STYLE. Returns a list of changes made.
   The changes are represented as a list of key-value pairs.
   Args:
   - STYLE: The style to update.
   - UPDATE-STYLE: The style to update with.
   Returns:
   - A list of changes made."
  (let ((style (make-terminal-style)))
    (update-style! style update-style)))
;;; Handle cases where style is provided as a plist (list)
(defmethod update-style! ((style list) (update-style terminal-style))
  "Ignore update requests when STYLE is a raw plist; no in-place update."
  (declare (ignore style update-style))
  nil)
(defmethod update-style! ((style list) (update-style null))
  "Ignore reset requests when STYLE is a raw plist; no-op."
  (declare (ignore style))
  nil)
(defmethod update-style! ((style terminal-style) (update-style null))
  "Update the style STYLE with the values from UPDATE-STYLE. Returns a list of changes made.
   The changes are represented as a list of key-value pairs.
   Args:
   - STYLE: The style to update.
   - UPDATE-STYLE: The style to update with.
   Returns:
   - A list of changes made."
  (let ((u-style (make-terminal-style)))
    (update-style! style u-style)))

(defmethod update-style! ((style terminal-style) (update-style terminal-style))
  "Update the style STYLE with the values from UPDATE-STYLE. Returns a list of changes made.
   The changes are represented as a list of key-value pairs.
   Args:
   - STYLE: The style to update.
   - UPDATE-STYLE: The style to update with.
   Returns:
   - A list of changes made.

  Example:
  (update-style! style update-style)
    ==> ((:fg-color 122) (:bold nil))"
  (let ((fg-color (terminal-style-fg-color update-style))
        (bg-color (terminal-style-bg-color update-style))
        (fg-color-val (terminal-style-fg-color-val update-style))
        (bg-color-val (terminal-style-bg-color-val update-style))
        (bold (terminal-style-bold update-style))
        (italic (terminal-style-italic update-style))
        (underline (terminal-style-underline update-style))
        (faint (terminal-style-faint update-style))
        (blink (terminal-style-blink update-style))
        (inverse (terminal-style-inverse update-style))
        (strike (terminal-style-strike update-style))
        (delta nil))
    (when (and ;;fg-color-val
           (not (=? fg-color (terminal-style-fg-color style))))
      (setf (terminal-style-fg-color style) (copy-term-color fg-color))
      (push (list :fg-color fg-color-val) delta))
    (when (and ;;bg-color-val
           (not (=? bg-color (terminal-style-bg-color style))))
      (setf (terminal-style-bg-color style) (copy-term-color bg-color))
      (push (list :bg-color bg-color-val) delta))
    (when (not (=? bold (terminal-style-bold style)))
      (setf (terminal-style-bold style) bold)
      (push (list :bold bold) delta))
    (when (not (=? italic (terminal-style-italic style)))
      (setf (terminal-style-italic style) italic)
      (push (list :italic italic) delta))
    (when (not (=? underline (terminal-style-underline style)))
      (setf (terminal-style-underline style) underline)
      (push (list :underline underline) delta))
    (when (not (=? faint (terminal-style-faint style)))
      (setf (terminal-style-faint style) faint)
      (push (list :faint faint) delta))
    (when (not (=? blink (terminal-style-blink style)))
      (setf (terminal-style-blink style) blink)
      (push (list :blink blink) delta))
    (when (not (=? inverse (terminal-style-inverse style)))
      (setf (terminal-style-inverse style) inverse)
      (push (list :inverse inverse) delta))
    (when (not (=? strike (terminal-style-strike style)))
      (setf (terminal-style-strike style) strike)
      (push (list :strike strike) delta))
    delta))

;; (let ((red-fg  (make-terminal-style :fg-color (make-termcolor :simple :red)))
;;       (red-bg  (make-terminal-style :bg-color (make-termcolor :simple :red :bg t)))
;;       (rgb     (make-terminal-style :fg-color (make-termcolor :r 100 :g 150 :b 200)))
;;       (bold    (make-terminal-style :bold t)))
;;   (list
;;    (ansi-seqs red-fg  :fg-color)     ; ⇒ ("[31m")
;;    (ansi-seqs red-bg  :bg-color)     ; ⇒ ("[41m")
;;    (ansi-seqs rgb     :fg-color)     ; ⇒ ("[38;2;100;150;200m")
;;    (ansi-seqs bold    :bold)         ; ⇒ ("[1m")
;;    (ansi-seqs bold    :bold :underline) ; underline currently off ⇒ turns it *off*
;;    ))


(defmethod exec-sequence (lockable fd (seq string) &rest args)
  "Print the escape sequence SEQ to the terminal TERM.
TERM is locked while the sequence is printed. The FD is receiving
the escape sequence as byte stream."
  (declare (ignore args))
  (with-lock (lockable)
    (loop for ch across seq
          do  (write-byte (char-code ch) fd)
                                        ;(write-char ch fd)
          )
    (finish-output fd)))
(defun copy-term-color (color)
  "Creates a deep copy of a terminal-color instance."
  (when color
    (make-terminal-color
     :red (terminal-color-red color)
     :green (terminal-color-green color)
     :blue (terminal-color-blue color)
     :simple (terminal-color-simple color)
     :bg (terminal-color-bg color)
     :color-256 (terminal-color-color-256 color))))
(defun copy-term-style (style)
  "Creates a deep copy of a terminal-style instance.
   Returns NIL if style is NIL, otherwise always returns a terminal-style."
  (if (null style)
      nil
      (make-terminal-style
       :fg-color (copy-term-color (terminal-style-fg-color style))
       :bg-color (copy-term-color (terminal-style-bg-color style))
       :bold (terminal-style-bold style)
       :italic (terminal-style-italic style)
       :underline (terminal-style-underline style)
       :faint (terminal-style-faint style)
       :blink (terminal-style-blink style)
       :inverse (terminal-style-inverse style)
       :strike (terminal-style-strike style)
       :invisible (terminal-style-invisible style))))

;; (defun copy-terminal-style (style)
;;   "Alias for copy-term-style to maintain backward compatibility."
;;   (copy-term-style style))
;; (dotimes (i (length output))
;;     (as-utf-8-bytes (char output i) (lambda (x) (write-byte x (fd term)))))

(defmethod as-plist ((col null))
  "Convert a null color to a plist."
  nil)
(defmethod as-plist ((col terminal-color))
  "Convert a terminal-color object to a plist."
  (list :red (terminal-color-red col)
        :green (terminal-color-green col)
        :blue (terminal-color-blue col)
        :simple (terminal-color-simple col)
        :bg (terminal-color-bg col)
        :color-256 (terminal-color-color-256 col)))
(defmethod as-plist ((style-val terminal-style))
  (list :fg-color (slot-value style-val 'fg-color)
        :bg-color (slot-value style-val 'bg-color)
        :bold (slot-value style-val 'bold)
        :italic (slot-value style-val 'italic)
        :underline (slot-value style-val 'underline)
        :faint (slot-value style-val 'faint)
        :blink (slot-value style-val 'blink)
        :inverse (slot-value style-val 'inverse)
        :strike (slot-value style-val 'strike)
        :invisible (slot-value style-val 'invisible)))

(defmethod is-term-style ((style1 terminal-style))
  "Check if STYLE1 is a terminal-style object and matches STYLE-VAL.
   Returns a list of attributes that differ, or NIL if they match."
  t)

(defun termcolor-simple (color)
  "Returns the simple color keyword from a terminal-color instance."
  (when color
    (terminal-color-simple color)))
