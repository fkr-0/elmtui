(uiop:define-package :cl-styles.styled-strings
  (:nicknames :styles.ss) (:use :common-lisp)
  (:import-from :str :upcase :split :join :trim :fit :concat
    :numericp)
  (:export :styled-string :parse-string :parse-style-string
    :make-styled-string))

(in-package :cl-styles.styled-strings)

;; ====================
;; = Styled strings   =
;; ====================
;;
;; Styled strings are strings that have a style associated with them.
;; The style is a list of styles that are applied to the string in the
;; rendering process.
;; It is possible to style a string using tags enclosed in curly braces.
;; Parsing this string using the parse-string function will return a list
;; of styled strings. For example:
;; (parse-string "{bold}Hello {/bold}world!")
;; will return a list of two styled strings:
;; 1. "Hello " with the style ("bold")
;; The lisp representation of this styled-string is:
;; (make-instance 'styled-string :content "Hello " :style '("bold")) =>
;; <String[("bold")]: "Hello ">
;; 2. "world!" with the style ()
;; The lisp representation of this styled-string is:
;; (make-instance 'styled-string :content "world!" :style '()) =>
;; <String[(NIL)]: "world!">
;; (parse-style-string "{text-bold: t}")
;; (parse-style-string "{text-bold: 1}")
;; (parse-style-string "{text-bold}")
;; (parse-style-string "{padding-top:   1}")
;; (parse-style-string "{box:ascii}")
;; (setf zz (make-styled-string "a" "text-bold"))
;; (make-styled-string "a" '(:box :ascii) '(:padding-top 1))
;; (make-styled-string "a" "text-bold" "text-italic"  "box:ascii" "padding-top: 1"
;; "text-underline"  "padding-bottom: 1" "padding-left: 1" "padding-right: 1" "margin-top: 1" "margin-bottom: 1" "margin-left: 1" "margin-right: 1" "border-top: 1" "border-bottom: 1" "border-left: 1" "border-right: 1" "border-color: red" "border-style: solid" "border-width: 1" "border-radius: 1" "text-align: center" "text-justify: left" "text-wrap: word" "text-overflow: clip" "text-transform: uppercase" "text-transform: lowercase" "text-transform: capitalize" "text-indent: 1"
;; (setf zz (parse-string "Hello iii\\{ iii \\}iiiiiiii<world!"))
;; (format t "~a" (parse-string "Hello iii\\{ iii \\}iiiiiiii<world!"))
;; (make-instance 'box :value :ascii)
;; (format t "~a" (parse-string "{text-bold}{text-italic}Hello {/text-bold}{/text-italic}iii\\{ iii \\}iiiiiiii<world!\\{ab\\}fff\\{/ab\\}"))
;; (format t "~a" (parse-string "iii\\{ iii \\}iiiiiiii<world!\\{ab\\}fff\\{/ab\\}"))

(defclass styled-string ()
  ((content :initarg :content
     :accessor content
     :documentation "The content of the string.")
    (style :initarg :style
      :accessor style
      :documentation "The style of the string.")))

(defun find-next-skip-escaped (str char &optional (start 0))
  "Find the next occurence of char in str, skipping escaped chars.
   Returns the position of the char or nil if not found.
   If start is specified, the search starts at that position.
   Args:
     str: The string to search in.
     char: The char to search for.
     start: The position to start searching from.
    Returns:
     The position of the char or nil if not found.
    Example:
     (find-next-skip-escaped \"Hello \\{world!\" #\\{) => 6"
  (let ((pos (position char str :start start)))
    (loop while (and pos (< 0 pos) (char= #\\ (char str (1- pos))))
      do (setf pos (position char str :start (+ 2 pos))))
    pos))

(defun process-style (style styles)
  "Add or remove a style from the list of styles.
   If the style starts with a slash, it is removed from the list.
   Otherwise it is added to the list.
   Args:
     style: The style to add or remove.
     styles: The list of styles to add or remove the style from.
    Returns:
     The new list of styles.
    Example:
     (process-style \"bold\" '(\"italic\" \"underline\")) => (\"italic\" \"underline\" \"bold\")"
  (if (char= #\/ (char style 0))
    (remove (subseq style 1) styles :test #'string=)
    (cons style styles)))

(defun parse-string (str)
  "Parse a string STR and return a list of styled strings class
    instances.
   Args:
     STR: The string to parse.
    Returns:
     A list of instances of STYLED-STRING.
    Example:
     (parse-string \"Hello {bold}world!\")
       => ((\"Hello \") (\"world!  (\"bold\")))"
  (let ((start 0) (end 0) (style "") (cnt "") (styles 'nil) (chunks 'nil))
    (loop (when (null end)
            (return))
      (setf start (find-next-skip-escaped str #\{ end))
      (when (null start)
        (when (and (= 0 (length chunks)) (< (1+ end) (length str)))
          (push (list (subseq str end) styles) chunks))
        (return))
      (setf end (find-next-skip-escaped str #\} (1+ start)))
      (setf style (subseq str (1+ start) end))
      (setf cnt
        (or (find-next-skip-escaped str #\{ (1+ end)) (length str)))
      (setf cnt (subseq str (1+ end) cnt))
      (setf styles (process-style style styles))
      ;; (format t "~a~&" cnt)
      (when (< 0 (length cnt))
        (push (list cnt styles) chunks)))
    (mapcar
      #'(lambda (chunk)
          (apply #'make-styled-string
            (append (list (first chunk)) (second chunk))))
      (reverse chunks))))

(defun parse-style-string (style-string)
  "Parse a style string and return a list of style and value.
   Args:
     style-string: The style string to parse.
    Returns:
     A list of style and value.
    Example:
     (parse-style-string \"bold: 1\")
       => (\"BOLD\" 1)"
  (let* ((trimmed (string-trim '(#\{ #\}) style-string))
          (spl (split #\: trimmed))
          (attr-i (intern (upcase (first spl))))
          (attr-s (intern (upcase (first spl)) :keyword))
          (val (or (second spl) t)))
    (when (and (stringp val) (numericp (trim val)))
      (setf val (parse-integer (trim val))))
    (handler-case (make-instance attr-i :value val)
      (error ()
        (progn
          (make-instance attr-i :value (intern (upcase val) :keyword))
          (setf val (intern (upcase val) :keyword)))))
    (list attr-s val)))

(defun make-styled-string (str &rest styles)
  (let ((s nil))
    (loop for each in styles
      do (progn
           (push
             (typecase each
               (string (parse-style-string each))
               (symbol
                 (if (null each)
                   nil
                   (list each t)))
               (list each)
               (t (error "Style ~a is not known." each)))
             s)))
    (make-instance 'styled-string :content str :style (remove nil s))))

(defmethod print-object ((s styled-string) stream)
  (format stream "<String[~a]: \"~a\">" (style s) (content s)))
