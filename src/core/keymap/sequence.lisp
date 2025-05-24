;;;===============================================================
;;; File: src/core/keymap/sequence.lisp
;;; Key Sequence Support - Multi-key sequence handling and detection
;;;===============================================================
(uiop:define-package :elmtui.core.keymap.sequence
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.core.keymap
   :normalized-key
                :normalized-key=
   :make-normalized-key
                :normalized-key->string)
  (:import-from :elmtui.core.event-async
   :schedule-timer
                :cancel-timer)
  (:export
   ;; Key sequence structures
   #:key-sequence
   #:make-key-sequence
   #:key-sequence-keys
   #:key-sequence-complete-p
   #:key-sequence-partial-p
   #:collect-key-sequences-from-keymap

   ;; Key sequence state management
   #:sequence-state
   #:make-sequence-state
   #:sequence-state-current
   #:sequence-state-timeout
   #:reset-sequence-state
   #:update-sequence-state

   ;; Key sequence utilities
   #:sequence=
   #:sequence-matches-prefix-p
   #:sequence->string
   #:parse-key-sequence-string

   ;; Key sequence lookup
   #:keymap-lookup-sequence))

(in-package :elmtui.core.keymap.sequence)

;;;-----------------------------------------------------------------------------
;;; Key Sequence Structure
;;;-----------------------------------------------------------------------------

(defstruct key-sequence
  "Represents a sequence of normalized keys."
  (keys nil :type list :read-only t))  ; List of normalized-key structs

(defun sequence= (seq1 seq2)
  "Compare two key sequences for equality."
  (and (= (length (key-sequence-keys seq1))
          (length (key-sequence-keys seq2)))
       (every #'normalized-key=
              (key-sequence-keys seq1)
              (key-sequence-keys seq2))))

(defun sequence-matches-prefix-p (prefix full-sequence)
  "Check if the prefix sequence matches the beginning of the full sequence."
  (let ((prefix-keys (key-sequence-keys prefix))
        (full-keys (key-sequence-keys full-sequence)))
    (and (<= (length prefix-keys) (length full-keys))
         (every #'normalized-key=
                prefix-keys
                (subseq full-keys 0 (length prefix-keys))))))

(defun sequence->string (sequence)
  "Convert a key sequence to string representation."
  (format nil "~{~A~^ ~}"
          (mapcar #'normalized-key->string (key-sequence-keys sequence))))

(defun parse-key-sequence-string (key-string)
  "Parse a string like 'C-x C-s' into a key-sequence.
   Keys are separated by spaces."
  (let ((parts (uiop:split-string key-string :separator '(#\Space))))
    (make-key-sequence
     :keys (mapcar #'elmtui.core.keymap::parse-key-string parts))))

;;;-----------------------------------------------------------------------------
;;; Key Sequence State Management
;;;-----------------------------------------------------------------------------

(defvar *default-sequence-timeout* 1000
  "Default timeout for key sequences in milliseconds.")

(defstruct sequence-state
  "State for tracking partial key sequences."
  (current nil :type (or null key-sequence))   ; Current partial sequence
  (timer-id nil)                               ; ID of the timeout timer
  (timeout *default-sequence-timeout*))        ; Timeout in milliseconds

(defun reset-sequence-state (state)
  "Reset the sequence state, cancelling any timers."
  (when (sequence-state-timer-id state)
    (cancel-timer (sequence-state-timer-id state))
    (setf (sequence-state-timer-id state) nil))
  (setf (sequence-state-current state) nil))

(defun update-sequence-state (state key &key timeout-fn)
  "Update sequence state with a new key press, return updated sequence.
   If timeout-fn is provided, it will be called when the sequence times out."
  ;; Cancel existing timer if any
  (when (sequence-state-timer-id state)
    (cancel-timer (sequence-state-timer-id state))
    (setf (sequence-state-timer-id state) nil))

  ;; Update current sequence
  (let* ((current-keys (if (sequence-state-current state)
                           (key-sequence-keys (sequence-state-current state))
                           nil))
         (new-keys (append current-keys (list key)))
         (new-sequence (make-key-sequence :keys new-keys)))

    (setf (sequence-state-current state) new-sequence)

    ;; Set timeout
    (when timeout-fn
      (setf (sequence-state-timer-id state)
            (sb-ext:schedule-timer
             (lambda ()
               (let ((final-sequence (sequence-state-current state)))
                 (reset-sequence-state state)
                 (funcall timeout-fn final-sequence)))
             (sequence-state-timeout state))))

    ;; Return the new sequence
    new-sequence))

;;;-----------------------------------------------------------------------------
;;; Key Sequence Predicates
;;;-----------------------------------------------------------------------------

(defun key-sequence-complete-p (sequence available-sequences)
  "Check if the sequence exactly matches one of the available sequences."
  (some (lambda (avail-seq) (sequence= sequence avail-seq))
        available-sequences))

(defun key-sequence-partial-p (sequence available-sequences)
  "Check if the sequence is a prefix of any available sequence."
  (some (lambda (avail-seq)
          (and (not (sequence= sequence avail-seq))  ; Not an exact match
               (sequence-matches-prefix-p sequence avail-seq)))
        available-sequences))

;;;-----------------------------------------------------------------------------
;;; Key Sequence Lookup
;;;-----------------------------------------------------------------------------

(defun collect-key-sequences-from-keymap (keymap)
  "Collect all key sequences defined in a keymap.
   Returns a list of key-sequence structs."
  (let ((result '()))
    (maphash
     (lambda (key binding)
       (declare (ignore binding))
       (cond
         ;; Single normalized key
         ((elmtui.core.keymap::normalized-key-p key)
          (push (make-key-sequence :keys (list key)) result))

         ;; Already a list of keys (multi-key sequence)
         ((listp key)
          (push (make-key-sequence :keys key) result))

         ;; Already a key-sequence struct
         ((key-sequence-p key)
          (push key result))))
     (elmtui.core.keymap::keymap-bindings keymap))
    result))

(defun keymap-lookup-sequence (keymap sequence)
  "Look up a key sequence in a keymap. Returns the binding or NIL if not found."
  (when (and keymap sequence)
    (let ((keys (key-sequence-keys sequence)))
      (cond
        ;; Single-key sequence
        ((= 1 (length keys))
         (elmtui.core.keymap:lookup-keymap keymap (first keys)))

        ;; Multi-key sequence
        (t
         (elmtui.core.keymap:lookup-keymap keymap keys))))))
