(uiop:define-package :elmtui.backend.common.ansi-styling
  (:use :cl :log4cl)
  (:import-from :elmtui.platform.api :with-lock :lockable)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
   :deep-copy-style)
  (:import-from :elmtui.core.loop :as-plist)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:is-term-style)
  (:import-from :elmtui.view.geo :=?)
  (:export
   #:make-terminal-color
   #:terminal-style
   #:make-terminal-style
   #:terminal-color
   #:make-termcolor
   #:no-color-p
   #:terminal-style-kv
   #:terminal-style-bg-color-val
   #:terminal-style-fg-color-val
   #:update-style!
   #:exec-sequence
   #:copy-term-color
   #:copy-term-style
   #:ansi-seqs
   #:as-plist
   ))
(in-package :elmtui.backend.common.ansi-styling)
(defstruct terminal-color red green blue simple bg color-256)
(defun style-to-terminal-style (style-plist)
  (when style-plist
    (let ((ts (make-terminal-style)))
      (let ((bg (getf style-plist :bg)))
        (when bg (if (listp bg) (setf (terminal-style-bg-color ts) (elmtui.backend.common.ansi-styling:make-termcolor :bg t :r (first bg) :g (second bg) :b (third bg)))
                     (if (numberp bg) (setf (terminal-style-bg-color ts) (elmtui.backend.common.ansi-styling:make-termcolor :bg t :color-256 bg))
                         (setf (terminal-style-bg-color ts) (elmtui.backend.common.ansi-styling:make-termcolor :bg t :simple bg))))))
      (let ((fg (getf style-plist :fg)))
        (when fg (if (listp fg) (setf (terminal-style-fg-color ts) (elmtui.backend.common.ansi-styling:make-termcolor :r (first fg) :g (second fg) :b (third fg)))
                     (if (numberp fg) (setf (terminal-style-fg-color ts) (elmtui.backend.common.ansi-styling:make-termcolor :color-256 fg))
                         (setf (terminal-style-fg-color ts) (elmtui.backend.common.ansi-styling:make-termcolor :simple fg))))))
      (let ((attrs (getf style-plist :attrs)))
        (when (member :bold attrs) (setf (terminal-style-bold ts) t))
        (when (member :italic attrs) (setf (terminal-style-italic ts) t))
        (when (member :underline attrs) (setf (terminal-style-underline ts) t))
        (when (member :inverse attrs) (setf (terminal-style-inverse ts) t)))
      ts)))
;; (defgeneric copy-terminal-style (style))

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
(defmethod deep-copy-style ((style elmtui.backend.common.ansi-styling:terminal-style))
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
  (log-info "PARTS: ~A" parts)
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
(defun copy-term-color (tc)
  (if tc
      (let ((term-color (make-terminal-color)))
        (setf (terminal-color-red term-color)
              (terminal-color-red tc))
        (setf (terminal-color-green term-color)
              (terminal-color-green tc))
        (setf (terminal-color-blue term-color)
              (terminal-color-blue tc))
        (setf (terminal-color-simple term-color)
              (terminal-color-simple tc))
        (setf (terminal-color-bg term-color)
              (terminal-color-bg tc))
        (setf (terminal-color-color-256 term-color)
              (terminal-color-color-256 tc))
        term-color)
      (make-terminal-color)))
(defun copy-term-style (ts)
  (if ts
      (let ((term-style (make-terminal-style)))
        (setf (terminal-style-fg-color term-style)
              (copy-term-color (terminal-style-fg-color ts)))
        (setf (terminal-style-bg-color term-style)
              (copy-term-color (terminal-style-bg-color ts)))
        (setf (terminal-style-bold term-style)
              (terminal-style-bold ts))
        (setf (terminal-style-italic term-style)
              (terminal-style-italic ts))
        (setf (terminal-style-underline term-style)
              (terminal-style-underline ts))
        (setf (terminal-style-faint term-style)
              (terminal-style-faint ts))
        (setf (terminal-style-blink term-style)
              (terminal-style-blink ts))
        (setf (terminal-style-inverse term-style)
              (terminal-style-inverse ts))
        term-style)
      (make-terminal-style)))
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
