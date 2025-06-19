;;;===============================================================
;;; File: src/core/keymap.lisp
;;; Keymap Definition and Handling
;;;===============================================================
(uiop:define-package :elmtui.core.keymap
  (:use :cl :alexandria :log4cl )
  (:import-from :elmtui.state.api #:state-ref) ; For list-widget-keybindings
  (:import-from :str :split)
  (:export #:keymap
           #:nkwrap
           #:make-keymap
           #:define-keymap
           #:keymap-bindings
           #:normalized-key #:make-normalized-key
           #:key-event->normalized-key
           #:parse-key-string
           #:lookup-keymap
           #:normalized-key=
           #:create-keymap-from-definitions ; Exporting for widget use
           #:normalized-key->string         ; For introspection
           #:list-widget-keybindings))    ; For introspection
(in-package :elmtui.core.keymap)

;;;-----------------------------------------------------------------------------
;;; Normalized Key Representation
;;;-----------------------------------------------------------------------------

;; Represents a key press, including modifiers.
;; :key can be a character or a keyword symbol for special keys (e.g., :f1, :enter, :backspace, :up).
;; :modifiers is a list of keywords (:ctrl, :alt, :shift, :meta). Order doesn't matter.
(defstruct normalized-key
  (key :none :type (or character keyword))
  (modifiers nil :type list))

;; (defun normalize-modifiers (mods)
;;   "Sorts and removes duplicates from a list of modifier keywords."
;;   (sort (remove-duplicates (mapcar #'alexandria:make-keyword mods)) #'string<))
(defgeneric normalized-key= (a b)
  (:method ((a t) (b t))
    nil))
(defmethod normalized-key= ((a normalized-key) (b normalized-key))
  "Equality that ignores modifier order and aliases."
  (and (eql (normalized-key-key a) (normalized-key-key b))
       (equal (normalize-modifiers (normalized-key-modifiers a))
              (normalize-modifiers (normalized-key-modifiers b)))))
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

;;; ──────────────────────────────────────────────────────────────────────────
;;;  Key-map utilities – canonicalisation, equality & pretty printing
;;; ──────────────────────────────────────────────────────────────────────────

;;;; Canonical names for every modifier we care about
(defparameter *modifier-canonicalisation*
  '((:control  . :ctrl)
    (:ctrl     . :ctrl)
    (:shift    . :shift)
    (:meta     . :alt)      ;; sbcl/linux “meta” ⇒ treat like Alt
    (:option   . :alt)      ;; macOS alias
    (:alt      . :alt)
    (:command  . :cmd)      ;; macOS alias
    (:cmd      . :cmd)))

(defun canonicalise-modifier (mod)
  "Return the canonical keyword for MOD (eql comparison)."
  (or (cdr (assoc mod *modifier-canonicalisation* :test #'eq)) mod))

;;;; Desired display / precedence order (first element prints first)
(defparameter *modifier-order* '(:alt :ctrl :cmd :shift))

(defun %modifier-rank (mod)
  (or (position (canonicalise-modifier mod) *modifier-order* :test #'eq)
      most-positive-fixnum))

(defun %modifier< (a b)
  (< (%modifier-rank a) (%modifier-rank b)))

(defun normalize-modifiers (mods)
  "Return a *fresh*, sorted list of canonical modifier keywords."
  (let ((canon (remove-duplicates (mapcar #'canonicalise-modifier mods)
                                  :test #'eq)))
    (sort canon #'%modifier<)))

;;;; ------------------------------------------------------------------------
;;;; Normalized-key helpers
;;;; ------------------------------------------------------------------------


;; (defun normalized-key= (key1 key2)
;;   (and (eql (normalized-key-key key1) (normalized-key-key key2))
;;        (equal (normalized-key-modifiers key1) (normalized-key-modifiers key2))))
(defun normalized-key->string (nk)
  "Human-readable form, e.g. \"Alt-Ctrl-Shift-Z\"."
  (with-output-to-string (out)
    (let* ((mods (normalize-modifiers (normalized-key-modifiers nk)))
           (key-str (etypecase (normalized-key-key nk)
                      (character (string (normalized-key-key nk)))
                      (symbol (cond
                                ;; Special case for common key names in tests
                                ((eq (normalized-key-key nk) :esc) "Escape")
                                (t (string-capitalize (symbol-name (normalized-key-key nk)))))))))

      ;; Modifiers first, in the right order
      (loop for i from 0
            for m in mods
            do (progn
                 (when (> i 0)
                   (write-char #\- out))
                 (princ (string-capitalize (symbol-name m)) out)))
      
      ;; If we have modifiers, add a dash before the key
      (when mods
        (write-char #\- out))
      
      ;; Add the key itself
      (princ key-str out))))
;; "Human-readable form, e.g. \"Shift-Ctrl-Alt-Z\"."
;; (string-trim (list #\-)
;;              (with-output-to-string (out)
;;                (let ((mods (normalize-modifiers (normalized-key-modifiers nk)))
;;                      (ky (format nil "-~A"
;;                                  (etypecase (normalized-key-key nk)
;;                                    (character (string (normalized-key-key nk)))
;;                                    (symbol    (string-capitalize (symbol-name (normalized-key-key nk))))))))
;;                  (loop for m in mods
;;                        for i from 0
;;                        do (progn
;;                             (when (> i 0) (write-char #\- out))
;;                             (princ (string-capitalize (symbol-name m)) out)))
;;                  (princ ky out) ; Append the key at the end)
;;                  ))))

;;;; ------------------------------------------------------------------------
;;;; Existing public constructor remains unchanged; key-event helper just
;;;; re-uses NORMALIZE-MODIFIERS, so no code outside this file needs edits.
;;;; ------------------------------------------------------------------------

                                        ; Assumes modifiers are normalized (sorted)

;;;-----------------------------------------------------------------------------
;;; Key Event -> Normalized Key
;;;-----------------------------------------------------------------------------

(defun key-event->normalized-key (key-event)
  "Converts a platform key-event struct to a normalized-key struct."
  (when (and key-event (typep key-event 'elmtui.core.event-types:key-event))
    (let ((platform-key (elmtui.core.event-types:key-event-key key-event))
          (platform-char (elmtui.core.event-types:key-event-char key-event))
          (platform-mods (elmtui.core.event-types:key-event-modifiers key-event)))
      (make-normalized-key
       ;; If char is present and key is a simple symbol (like :a or :A), prefer char for case sensitivity.
       ;; Otherwise, use the key symbol (for :f1, :enter, etc.)
       :key (if (and platform-char
                     (symbolp platform-key)
                     (= (length (symbol-name platform-key)) 1)
                     (alpha-char-p (char (symbol-name platform-key) 0)))
                platform-char
                platform-key)
       :modifiers (normalize-modifiers platform-mods)))))

;;;-----------------------------------------------------------------------------
;;; Key String Parsing -> Normalized Key
;;;-----------------------------------------------------------------------------

(defun parse-key-string (key-string)
  "Parse a key string like 'C-x' or 'Shift-F1' into a normalized key.
   For sequences like 'C-x C-s', returns the first key (caller should use
   parse-key-sequence-string for sequences)."
  ;; Check if this is a multi-key sequence
  (if (find #\Space key-string)
      (progn
        (log-warn "Multi-key sequence detected in parse-key-string: ~S. Use parse-key-sequence-string instead." key-string)
        ;; Just parse the first key for backward compatibility
        (parse-key-string (subseq key-string 0 (position #\Space key-string))))
      ;; Handle single key
      (parse-single-key-string key-string)))

;; TODO for M-m and A-a
(defun parse-single-key-string (key-string)
  "Parse a single key string (no spaces) into a normalized key."
  ;; (let* ((modifiers nil)
  ;;        (key nil)
  ;;        (parts (str:split "-" key-string))
  ;;        (last-part (car (last parts)))
  ;;        (last-part-sym (make-keyword (string-upcase last-part)))
  ;;        (butlast-parts (butlast parts)))

  ;;   (cond
  ;;     ((eql last-part-sym :ESCAPE) (setf key :esc))
  ;;     ((eql last-part-sym :ENTER) (setf key :enter))
  ;;     ((eql last-part-sym :DELETE) (setf key :delete))
  ;;     ((eql last-part-sym :BACKSPACE) (setf key :backspace))
  ;;     ((eql last-part-sym :TAB) (setf key :tab))
  ;;     ((eql last-part-sym :SPACE) (setf key :space))

  ;;     ;; For single character keys, store the character
  ;;     ((and (= (length (symbol-name last-part-sym)) 1)
  ;;           (alpha-char-p (char (symbol-name last-part-sym) 0)))
  ;;      (setf key (char (symbol-name last-part-sym) 0)))

  ;;     ;; Any other key is a keyword
  ;;     (t (setf key last-part-sym)))
  (let* ((modifiers nil)
         (key nil)
         (parts  (str:split "-" key-string))
         (last-part (car (last parts)))
         (last-part-sym (make-keyword (string-upcase last-part)))
         (butlast-parts (butlast parts)))
    (setf key
          (cond
            ;; Special keys
            ((eql last-part-sym :ESCAPE) :esc)
            ((eql last-part-sym :ENTER) :enter)
            ((eql last-part-sym :DELETE) :delete)
            ((eql last-part-sym :BACKSPACE) :backspace)
            ((eql last-part-sym :TAB) :tab)
            ((eql last-part-sym :SPACE) :space)

            ;; Single character keys
            ((and (= (length (symbol-name last-part-sym)) 1)
                  (alpha-char-p (char (symbol-name last-part-sym) 0)))
             (char (symbol-name last-part-sym) 0))

            ;; Any other key is a keyword
            (t last-part-sym)))
    ;; Handle modifiers and key
    (loop for part in butlast-parts
          ;; (loop for part in (str:split "-" key-string) ;:regex t)
          ;; (loop for part in (str:split "[-|+]" key-string) ;:regex t)
          do (let ((part-sym (make-keyword (string-upcase part))))
               (cond
                 ;; Single letter modifiers
                 ((eql part-sym :C) (push :ctrl modifiers))
                 ((eql part-sym :S) (push :shift modifiers))
                 ((eql part-sym :A) (push :alt modifiers))
                 ((eql part-sym :M) (push :alt modifiers))  ;; Meta is Alt

                 ;; Full modifier names
                 ((member part-sym '(:CTRL :CONTROL)) (push :ctrl modifiers))
                 ((eql part-sym :SHIFT) (push :shift modifiers))
                 ((member part-sym '(:ALT :META)) (push :alt modifiers))
                 ((member part-sym '(:CMD :COMMAND)) (push :cmd modifiers))

                 (t (push part-sym modifiers)))))
    ;; Special key mappings

    ;; ;; Normalize the key for the tests
    ;; (when (characterp key)
    ;;   (setf key (char-downcase key)))
    ;;              ;; Modifier
    ;;              ((member part-sym '(:ctrl :control :c :cmd :command :alt :meta :m :shift :s))
    ;;               ;; unless last part and :C or :A
    ;;               (if (and (eql part-sym :C)
    ;;                        (member part-sym (normalize-modifiers modifiers)  :test #'eq))
    ;;                   (setf key part-sym)
    ;;                   ;; Add to modifiers
    ;;                   (push (canonicalise-modifier part-sym) modifiers)))

    ;;              ;; Key
    ;;              (t (setf key part-sym)))))

    ;; Create normalized key
    (make-normalized-key :key key :modifiers (normalize-modifiers modifiers))))
;; (parse-single-key-string "C-c")
                                        ; Example usage
;;;-----------------------------------------------------------------------------
;;; Keymap Structure and Lookup
;;;-----------------------------------------------------------------------------

(defstruct (keymap (:constructor make-keymap))
  "A mapping from keys to actions."
  (bindings (make-hash-table :test 'equal) :type hash-table)
  (name nil :type (or null string symbol))) ; Optional name for introspection)

(defun lookup-keymap (keymap key)
  "Look up a binding for KEY in KEYMAP.
   KEY can be a normalized-key or a key-sequence."
  (when (and keymap key)
    (let ((bindings (keymap-bindings keymap)))
      (cond
        ;; Handle key-sequence objects from elmtui.core.keymap.sequence
        ((and (find-package :elmtui.core.keymap.sequence)
              (fboundp (intern "KEY-SEQUENCE-P" :elmtui.core.keymap.sequence))
              (funcall (intern "KEY-SEQUENCE-P" :elmtui.core.keymap.sequence) key))
         (let ((keys (funcall (intern "KEY-SEQUENCE-KEYS" :elmtui.core.keymap.sequence) key)))
           (if (= 1 (length keys))
               ;; Single-key sequence - lookup directly
               (gethash (car keys) bindings)
               ;; Multi-key sequence - lookup by sequence
               (gethash keys bindings))))

        ;; Handle list of normalized-keys (for multi-key sequences)
        ((and (listp key) (every #'normalized-key-p key))
         (gethash key bindings))

        ;; Handle direct normalized-key
        ((normalized-key-p key)
         (gethash key bindings))

        ;; Invalid key type
        (t
         (log-warn "Invalid key type for lookup-keymap: ~S" key)
         nil)))))

(defun set-keymap-binding (keymap key binding)
  "Set a binding for KEY in KEYMAP. KEY can be a normalized-key or a sequence."
  (when (and keymap key)
    (let ((bindings (keymap-bindings keymap)))
      (cond
        ;; Handle key-sequence objects
        ((and (find-package :elmtui.core.keymap.sequence)
              (fboundp (intern "KEY-SEQUENCE-P" :elmtui.core.keymap.sequence))
              (funcall (intern "KEY-SEQUENCE-P" :elmtui.core.keymap.sequence) key))
         (let ((keys (funcall (intern "KEY-SEQUENCE-KEYS" :elmtui.core.keymap.sequence) key)))
           (if (= 1 (length keys))
               ;; Single-key sequence - store by the key itself
               (setf (gethash (car keys) bindings) binding)
               ;; Multi-key sequence - store by the full list
               (setf (gethash keys bindings) binding))))

        ;; Handle list of normalized-keys (for multi-key sequences)
        ((and (listp key) (every #'normalized-key-p key))
         (setf (gethash key bindings) binding))

        ;; Handle direct normalized-key
        ((normalized-key-p key)
         (setf (gethash key bindings) binding))

        ;; Invalid key type
        (t
         (log-warn "Invalid key type for set-keymap-binding: ~S" key))))))

(defun create-keymap-from-definitions (map-name binding-definitions &optional (source-identifier map-name))
  "Creates and returns a keymap struct from a list of binding definitions.
   MAP-NAME: An optional name for the keymap (for introspection).
   BINDING-DEFINITIONS: A list of (key-spec &key type target description) lists.
   SOURCE-IDENTIFIER: Identifier for the source of these bindings (e.g., widget type or keymap name)."
  (let ((km (make-keymap :name map-name)))
    (dolist (binding-def binding-definitions)
      (destructuring-bind (key-spec &key type target description) binding-def
        (let ((norm-key (etypecase key-spec
                          (string (parse-key-string key-spec))
                          (keyword (make-normalized-key :key key-spec :modifiers nil))
                          (normalized-key key-spec))))
          (unless type (error "Binding type (:action or :message) is required for key ~S in keymap ~S" key-spec map-name))
          (unless target (error "Binding target is required for key ~S in keymap ~S" key-spec map-name))
          (when norm-key
            (setf (gethash norm-key (keymap-bindings km))
                  (list :type type
                        :target target
                        :description description
                        :source source-identifier))))))
    km))

(defmacro define-keymap (name &body binding-definitions)
  "Defines a global keymap variable with the given name and bindings.
   Each binding-definition is a list: (key-string &key type target description).
   Example: (\"C-s\" :type :message :target '(:save-file) :description \"Save file\")"
  `(defparameter
       ,name
     (create-keymap-from-definitions ',name ',binding-definitions)))

;; Example:
;; (define-keymap *my-global-keymap*
;;   ("C-x C-c" :type :action :target 'quit-app :description "Quit application")
;;   ("C-s"     :type :message :target '(:save-file) :description "Save current file")
;;   (:f1       :type :message :target '(:show-help) :description "Show help screen"))
;;
;; (lookup-keymap *my-global-keymap* (parse-key-string "C-s"))
;; => (:TYPE :MESSAGE :TARGET (:SAVE-FILE) :DESCRIPTION "Save current file" :SOURCE *MY-GLOBAL-KEYMAP*)

;;;-----------------------------------------------------------------------------
;;; Normalized Key to String Conversion (for Introspection)
;;;-----------------------------------------------------------------------------

;; (defun normalized-key->string (normalized-key)
;;   "Converts a normalized-key struct to a user-friendly string representation."
;;   (when normalized-key
;;     (let ((key-part (etypecase (normalized-key-key normalized-key)
;;                       (character (string (normalized-key-key normalized-key)))
;;                       (keyword (string-capitalize (normalized-key-key normalized-key)))))
;;           (mod-parts (loop for mod in (normalized-key-modifiers normalized-key)
;;                            collect (string-capitalize mod))))
;;       (if mod-parts
;;           (format nil "~{~A-~}~A" mod-parts key-part)
;;           key-part))))

;;;-----------------------------------------------------------------------------
;;; Introspection API
;;;-----------------------------------------------------------------------------

(defun list-widget-keybindings (app-state widget-id &key (keymap-slot :active-keymap))
  "Lists keybindings for a specific widget.
   APP-STATE: The global application state.
   WIDGET-ID: The ID of the widget.
   KEYMAP-SLOT: The slot in the widget's model where its keymap is stored (e.g., :active-keymap, :focused-keymap).
   Returns a list of plists, each describing a keybinding."
  (let* ((widget-model-path (list :widgets widget-id)) ; Convention
         (widget-model (state-ref app-state widget-model-path)))
    (when widget-model
      (let ((keymap (getf widget-model keymap-slot)))
        (when (and keymap (typep keymap 'keymap))
          (let ((results '()))
            (maphash (lambda (norm-key binding-plist)
                       (push (list :key (normalized-key->string norm-key)
                                   :description (getf binding-plist :description)
                                   :type (getf binding-plist :type)
                                   :target (getf binding-plist :target)
                                   :scope :local ; Assuming these are local to the widget
                                   :source widget-id
                                   :keymap-name (keymap-name keymap)) ; Add name of specific keymap
                             results))
                     (keymap-bindings keymap))
            results))))))

;; TODO: Implement list-global-keybindings and list-active-keybindings as per spec.
