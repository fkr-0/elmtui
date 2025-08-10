;;; == exampleproject/src/components/key-tester.lisp ==
(uiop:define-package :example.key-tester
  (:use :cl :alexandria)
  (:import-from :log4cl
    :log-info)
  (:import-from :elmtui.keymaps
    #:key-event->normalized-key
    #:normalized-key->string
    )
  (:export
    #:make-key-tester
    #:key-tester
    #:key-tester-on-key-event
    #:key-tester-render
    #:nk->keyword-list
    #:printable-ascii-char-p))

(in-package :example.key-tester)

;;; --------------------------------------------------------------------------
;;; Model
;;; --------------------------------------------------------------------------

(defstruct key-tester
  "Minimal component model:
   - INPUT: user-entered text
   - ECHO:  last recognized key as keyword notation string (e.g. (:CTRL :A))"
  (id "key-tester-1" :type string)
  (input "" :type string)
  (echo  "" :type string))

;; (defun make-key-tester (&key (id "key-tester-1"))
;;   (make-key-tester :id id))

;;; --------------------------------------------------------------------------
;;; Helpers – key formatting / predicates
;;; --------------------------------------------------------------------------

(defun nk->keyword-list (nk)
  "Return a list of keywords for NK: modifiers first (normalized order), then key.
   - If NK.key is a character, convert to a KEYWORD (:A, :Z, ...).
   - If NK.key is already a keyword (e.g. :ENTER), keep it.
   Example → '(:CTRL :ALT :A)"
  (let* ((mods (slot-value nk 'elmtui.keymaps::modifiers))            ; use exported behavior; nk is a struct
          (key  (slot-value nk 'elmtui.keymaps::key))
          (key-kw (etypecase key
                    (character (intern (string-upcase (string key)) :keyword))
                    (keyword   key))))
    (append (mapcar #'alexandria:make-keyword
              ;; NOTE: MODS are already normalized by elmtui.keymaps.
              (copy-list mods))
      (list key-kw))))

(defun printable-ascii-char-p (ch)
  "True iff CH is a printable ASCII character. Assumes CHAR input."
  (let ((code (char-code ch)))
    (<= 32 code 126)))

;;; --------------------------------------------------------------------------
;;; Update (key handling)
;;; --------------------------------------------------------------------------
;;; Assumptions (you can tweak as needed):
;;; 1) We *append to input* only for printable ASCII *without modifiers*.
;;;    Rationale: avoids inserting control combos like C-a, C-v, etc.
;;; 2) We *always* update ECHO with keyword-notated form of the pressed key.

(defun key-tester-on-key-event (component evt)
  "Handle a raw key event:
   - Update ECHO with keyword notation.
   - If key is printable ASCII and has no modifiers, append to INPUT.
   Returns the updated COMPONENT."
  (log-info "Key-Tester> Key event: ~A" evt)
  (let* ((e (getf (elmtui.tea-state.msg:msg-data evt) :event))
          (chr (getf (elmtui.tea-state.msg:msg-data evt) :char))
          (nk (key-event->normalized-key e))
          (ck (getf (elmtui.tea-state.msg:msg-data evt) :key)))
    (if (null nk)
      component
      (let* ((kw-form (nk->keyword-list nk))
              (echo-str (prin1-to-string kw-form)))
        ;; extract key & modifiers (using the same slots the NK struct uses)
        ;; (mods (slot-value nk 'elmtui.keymaps::modifiers))
        ;;(key  (slot-value nk 'elmtui.keymaps::key)))

        ;; Always refresh echo to the parsed value:
        (setf (key-tester-echo component) echo-str)
        (when (eql ck :backspace)
          ;; Backspace: delete last character in INPUT (if any).
          (setf (key-tester-input component)
            (if (> (length (key-tester-input component)) 0)
              (subseq (key-tester-input component) 0
                (1- (length (key-tester-input component)))))))
        ;; Append printable ASCII only if no modifiers are held:
        (when chr ;; (and (characterp key)
          ;;   (printable-ascii-char-p key)
          ;;   (null mods))
          (setf (key-tester-input component)
            (concatenate 'string (key-tester-input component)
              (format nil "~C" chr))))
        component))))

;;; --------------------------------------------------------------------------
;;; (Very) Simple Renderer for demonstration / console logs
;;; --------------------------------------------------------------------------
;;; In a real ELMTUI UI, you'd return a widget tree – here we format strings.

(defun key-tester-render (component &key (stream *standard-output*))
  "Render a minimal textual view:
     +--------------------------+
     | Input: <accumulated>     |
     | Echo : <last key parsed> |
     +--------------------------+"
  (format stream "~&+--------------------------+~%")
  (format stream   "| Input: ~A~%" (key-tester-input component))
  (format stream   "| Echo : ~A~%" (key-tester-echo  component))
  (format stream   "+--------------------------+~%")
  component)
;;; == end/components/key-tester.lisp ==
