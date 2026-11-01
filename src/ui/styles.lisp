;;;; src/ui/styles.lisp — Named style-class registry for the ElmTUI DSL.
;;;;
;;;; Provides DEFSTYLE for declaring named style plists and RESOLVE-STYLE-CLASSES
;;;; / MERGE-STYLES for composing them at DSL resolution time.  The :CLASS
;;;; property on DSL nodes is wired into the rendering pipeline via
;;;; RESOLVE-NODE-STYLES.

(uiop:define-package :elmtui.ui.styles
  (:use :cl)
  (:export
   ;; Registry
   #:*style-registry*
   #:defstyle
   #:resolve-style-class
   #:resolve-style-classes
   ;; Merge
   #:merge-styles
   ;; DSL integration
   #:resolve-node-styles
   ;; Theme
   #:apply-theme
   #:clear-style-registry))

(in-package :elmtui.ui.styles)

;;;--------------------------------------------------------------
;;; Style registry
;;;--------------------------------------------------------------

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defvar *style-registry* (make-hash-table :test 'eq)
    "Global registry mapping keyword names to style property lists.
Styles are typically registered at load time via DEFSTYLE."))

(defmacro defstyle (name style-plist)
  "Register a named style class.  NAME must be a keyword; STYLE-PLIST is a
property list of style properties.

Example:
  (defstyle :flex-column (:display :flex :flex-direction :column))"
  (check-type name keyword)
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     (setf (gethash ,name *style-registry*) ',style-plist)))

(defun resolve-style-class (name)
  "Look up a named style class.  Signals an error if NAME is not registered."
  (or (gethash name *style-registry*)
      (error "Unknown style class ~S" name)))

(defun resolve-style-classes (class-spec)
  "Resolve a class specification to a merged style plist.

CLASS-SPEC is either a keyword (single class) or a list of keywords.
When multiple classes are given, later classes override earlier ones on
property conflict."
  (let ((classes (if (listp class-spec) class-spec (list class-spec))))
    (let ((merged '()))
      (dolist (cls classes)
        (let ((style (resolve-style-class cls)))
          (loop for (k v) on style by #'cddr
                do (setf (getf merged k) v))))
      merged)))

;;;--------------------------------------------------------------
;;; Merge helpers
;;;--------------------------------------------------------------

(defun merge-styles (class-style inline-style)
  "Merge class-resolved styles with inline styles.  Inline wins on conflict.

Both arguments are property lists.  Returns a fresh property list."
  (let ((merged (copy-list class-style)))
    (loop for (k v) on inline-style by #'cddr
          do (setf (getf merged k) v))
    merged))

;;;--------------------------------------------------------------
;;; DSL node integration
;;;--------------------------------------------------------------

(defun resolve-node-styles (props)
  "Given a DSL node's property list PROPS, resolve any :CLASS specification
and merge it with the explicit :STYLE.  Returns a new property list where
:STYLE contains the merged result and :CLASS has been consumed.

If PROPS has no :CLASS key the property list is returned unchanged."
  (let ((class-spec (getf props :class)))
    (if class-spec
        (let* ((class-style (resolve-style-classes class-spec))
               (inline-style (getf props :style))
               (merged (if inline-style
                           (merge-styles class-style inline-style)
                           class-style))
               (new-props (copy-list props)))
          ;; Replace :style with the merged result
          (setf (getf new-props :style) merged)
          ;; Remove :class — it has been consumed
          (remf new-props :class)
          new-props)
        props)))

;;;--------------------------------------------------------------
;;; Theme support
;;;--------------------------------------------------------------

(defun apply-theme (theme-styles)
  "Register a batch of named styles from a theme plist.

THEME-STYLES is a plist of (NAME STYLE-PLIST ...) pairs.  Each NAME is
registered as a style class, overwriting any previous definition with that
name.

Example:
  (apply-theme '(:title  (:bold t :fg :cyan)
                 :muted  (:dim t :fg :white)))"
  (loop for (name style) on theme-styles by #'cddr
        do (check-type name keyword)
           (setf (gethash name *style-registry*) style)))

(defun clear-style-registry ()
  "Remove all entries from the style registry.  Intended for testing."
  (clrhash *style-registry*))

;;;--------------------------------------------------------------
;;; Built-in presets
;;;--------------------------------------------------------------

(defstyle :flex-row (:display :flex :flex-direction :row))
(defstyle :flex-column (:display :flex :flex-direction :column))
(defstyle :bold (:bold t))
(defstyle :dim (:dim t))
(defstyle :centered (:justify-content :center :align-items :center))
(defstyle :padded (:padding-x 1 :padding-y 1))
(defstyle :bordered (:border :single))
(defstyle :bordered-rounded (:border :rounded))
