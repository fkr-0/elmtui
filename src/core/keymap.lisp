;;;===============================================================
;;; File: src/core/keymap.lisp
;;; Keymap Definition and Handling
;;;===============================================================
(uiop:define-package :elmtui.core.keymap
  (:use :cl :alexandria :log4cl)
  (:export #:keymap #:make-keymap #:define-keymap
           #:normalized-key #:make-normalized-key
           #:key-event->normalized-key
           #:parse-key-string
           #:lookup-keymap))
(in-package :elmtui.core.keymap)

;;;-----------------------------------------------------------------------------
;;; Normalized Key Representation
;;;-----------------------------------------------------------------------------

;; Represents a key press, including modifiers.
;; :key can be a character or a keyword symbol for special keys (e.g., :f1, :enter, :backspace, :up).
;; :modifiers is a list of keywords (:ctrl, :alt, :shift, :meta). Order doesn't matter.
(defstruct normalized-key
  (key nil :type (or character keyword))
  (modifiers nil :type list))

(defun normalize-modifiers (mods)
  "Sorts and removes duplicates from a list of modifier keywords."
  (sort (remove-duplicates (mapcar #'alexandria:make-keyword mods)) #'string<))

(defmethod make-load-form ((key normalized-key) &optional environment)
  (declare (ignore environment))
  `(make-normalized-key :key ',(normalized-key-key key)
                        :modifiers ',(normalized-key-modifiers key)))

;; We need a stable equality test for use in hash tables etc.
(defmethod print-object ((key normalized-key) stream)
  (print-unreadable-object (key stream :type t :identity nil)
    (format stream "~{~S~^+~}~S"
            (normalized-key-modifiers key)
            (normalized-key-key key))))

(defun normalized-key= (key1 key2)
  (and (eql (normalized-key-key key1) (normalized-key-key key2))
       (equal (normalized-key-modifiers key1) (normalized-key-modifiers key2)))) ; Assumes modifiers are normalized (sorted)

;;;-----------------------------------------------------------------------------
;;; Key Event -> Normalized Key
;;;-----------------------------------------------------------------------------

(defun key-event->normalized-key (key-event)
  "Converts a raw key event (e.g., from platform layer) to a normalized-key struct.
   Assumes key-event is a list like '(:key <char-or-kw> :modifiers (:ctrl...))'."
  ;; TODO: This needs actual implementation based on the platform input format.
  ;; Placeholder implementation:
  (let ((key (getf key-event :key))
        (mods (getf key-event :modifiers)))
    (when key
      (make-normalized-key :key key :modifiers (normalize-modifiers mods)))))

;;;-----------------------------------------------------------------------------
;;; Key String Parsing -> Normalized Key
;;;-----------------------------------------------------------------------------

(defun parse-key-string (key-string)
  "Parses a string like \"C-S-x\", \"Ctrl+Alt+Delete\", \"F1\", \"Enter\", \"a\"
   into a normalized-key struct. Case-insensitive for modifiers and special keys."
  ;; TODO: Implement robust parsing logic.
  ;; - Handle prefixes like C-, M-, S-, Ctrl+, Alt+, Shift+, Meta+
  ;; - Handle special key names (Enter, Tab, Esc, F1-F12, Up, Down, Left, Right, etc.) -> keywords
  ;; - Handle single characters -> character object
  ;; Placeholder:
  (cond
    ((string-equal key-string "C-c") (make-normalized-key :key #\c :modifiers '(:ctrl)))
    ((string-equal key-string "Enter") (make-normalized-key :key :enter :modifiers nil))
    ((= (length key-string) 1) (make-normalized-key :key (char key-string 0) :modifiers nil))
    (t (warn "parse-key-string: Cannot parse ~S yet." key-string) nil)))

;;;-----------------------------------------------------------------------------
;;; Keymap Structure and Lookup
;;;-----------------------------------------------------------------------------

;; A keymap is a hash table mapping normalized-key structs to actions (e.g., messages).
(defstruct keymap
  (bindings (make-hash-table :test #'normalized-key=) :type hash-table))

(defun lookup-keymap (keymap normalized-key)
  "Looks up the action associated with normalized-key in the keymap."
  (gethash normalized-key (keymap-bindings keymap)))

(defmacro define-keymap (name &body bindings)
  "Defines a keymap variable with the given name and bindings.
   Each binding is a (key-spec action) pair.
   key-spec can be a string (parsed by parse-key-string) or a normalized-key keyword."
  `(defparameter ,name
     (let ((km (make-keymap)))
       (loop for (key-spec action) in ',bindings
             do (let ((norm-key (etypecase key-spec
                                  (string (parse-key-string key-spec))
                                  (keyword (make-normalized-key :key key-spec :modifiers nil))
                                  (normalized-key key-spec))))
                  (when norm-key
                    (setf (gethash norm-key (keymap-bindings km)) action))))
       km)))

;; Example:
;; (define-keymap *my-global-keymap*
;;   ("C-x C-c" '(:quit-app))
;;   ("C-s"     '(:save-file))
;;   (:f1       '(:show-help)))
;;
;; (lookup-keymap *my-global-keymap* (parse-key-string "C-s")) => (:save-file)
