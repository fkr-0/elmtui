;;;; Reusable, pure modal-dialog state machine and bounded TUI presentation.
;;;; Keyboard capture is explicit: call MODAL-HANDLE-KEY before parent update.
(uiop:define-package :elmtui.ui.widgets.modal-dialog
  (:use :cl)
  (:export #:modal-dialog #:modal-dialog-p #:modal-dialog-kind
           #:modal-dialog-input #:modal-dialog-return-focus
           #:open-modal-dialog #:modal-handle-key #:modal-dialog-lines
           #:modal-dialog-view))
(in-package :elmtui.ui.widgets.modal-dialog)

(defstruct (modal-dialog (:constructor %make-modal-dialog))
  (kind :confirm :type keyword)
  (title "" :type string)
  (message "" :type string)
  (input "" :type string)
  (choices nil :type list)
  (return-focus nil))

(defun open-modal-dialog (&key (kind :confirm) (title "Dialog")
                               (message "") (input "") (choices nil)
                               return-focus)
  "Create an independent modal session. CHOICES is ((character . action) ...).
A prompt resolves as :ACCEPT with the typed string. Enter on confirmation
resolves as :CANCEL. The parent must route keys here while modal is active."
  (unless (member kind '(:confirm :prompt))
    (error "Unknown modal kind: ~S" kind))
  (unless (and (stringp title) (stringp message) (stringp input))
    (error "Modal text must be strings"))
  (dolist (choice choices)
    (unless (and (consp choice) (characterp (car choice)) (keywordp (cdr choice)))
      (error "Modal choice must be a (CHAR . KEYWORD) pair: ~S" choice)))
  (%make-modal-dialog :kind kind :title title :message message
                      :input input :choices choices
                      :return-focus return-focus))

(defun %resolved (dialog action &optional value)
  (values nil (list :action action :value value
                    :return-focus (modal-dialog-return-focus dialog))))

(defun modal-handle-key (dialog key char modifiers)
  "Return (values updated-dialog result). RESULT is NIL while editing,
otherwise a plist with :ACTION, :VALUE and :RETURN-FOCUS.
The parent must not dispatch this key to the application if DIALOG exists."
  (check-type dialog modal-dialog)
  (cond
    ((member key '(:escape :esc))
     (%resolved dialog :cancel))
    ((and (eq (modal-dialog-kind dialog) :prompt)
          (member key '(:enter :return)))
     (if (plusp (length (string-trim '(#\Space #\Tab)
                                     (modal-dialog-input dialog))))
         (%resolved dialog :accept (modal-dialog-input dialog))
         (values dialog nil)))
    ((eq (modal-dialog-kind dialog) :confirm)
     (let ((choice (and (characterp char)
                        (assoc char (modal-dialog-choices dialog)
                               :test #'char-equal))))
       (cond (choice (%resolved dialog (cdr choice)))
             ((member key '(:enter :return)) (%resolved dialog :cancel))
             (t (values dialog nil)))))
    ((eq key :backspace)
     (let ((new (copy-modal-dialog dialog)))
       (when (plusp (length (modal-dialog-input dialog)))
         (setf (modal-dialog-input new)
               (subseq (modal-dialog-input dialog) 0
                       (1- (length (modal-dialog-input dialog))))))
       (values new nil)))
    ((and (characterp char) (graphic-char-p char)
          (not (or (member :ctrl modifiers) (member :control modifiers)
                   (member :alt modifiers))))
     (let ((new (copy-modal-dialog dialog)))
       (setf (modal-dialog-input new)
             (concatenate 'string (modal-dialog-input dialog) (string char)))
       (values new nil)))
    (t (values dialog nil))))

(defun %bounded-text (value width)
  "One physical row, safe against text, line breaks and overlong filenames."
  (let ((clean (coerce
                (loop for c across (or value "")
                      collect (if (or (char= c #\Newline) (char= c #\Return)
                                      (char= c #\Tab) (not (graphic-char-p c)))
                                  #\Space c))
                'string)))
    (if (> (length clean) width)
        (concatenate 'string "..." (subseq clean (- (length clean) (- width 3))))
        clean)))

(defun %cell (text width)
  (let* ((short (%bounded-text text width))
         (padding (max 0 (- width (length short)))))
    (concatenate 'string short (make-string padding :initial-element #\Space))))

(defun modal-dialog-lines (dialog &key (width 66))
  "Return five printable, bounded rows. Designed to work even without z-index
or compositor-level overlays; can replace five host content rows."
  (check-type dialog modal-dialog)
  (unless (<= 24 width 1000)
    (error "Modal width must be between 24 and 1000"))
  (let* ((inner (- width 2))
         (title (format nil " ~A " (modal-dialog-title dialog)))
         (detail (if (eq (modal-dialog-kind dialog) :prompt)
                     (format nil " Filename: ~A_" (modal-dialog-input dialog))
                     (modal-dialog-message dialog)))
         (help (if (eq (modal-dialog-kind dialog) :prompt)
                   " Enter: Accept   Esc: Cancel"
                   (format nil " ~{[~C] ~A~^   ~}"
                           (loop for (key . action) in (modal-dialog-choices dialog)
                                 append (list key (string-capitalize (string-downcase action))))))))
    (list (concatenate 'string "╔" (make-string inner :initial-element #\═) "╗")
          (format nil "║~A║" (%cell title inner))
          (format nil "║~A║" (%cell detail inner))
          (format nil "║~A║" (%cell help inner))
          (concatenate 'string "╚" (make-string inner :initial-element #\═) "╝"))))

(defun modal-dialog-view (dialog &key (id-prefix "MODAL") (width 66))
  "Return five :TEXT DSL nodes for rendering in a normal host layout.
Use the parent update to trap events; these nodes intentionally do not
claim a compositor overlay or implicit focus manager integration."
  (loop for line in (modal-dialog-lines dialog :width width)
        for index from 0
        collect (list :text
                      :id (intern (format nil "~A-ROW-~D" id-prefix index)
                                  :keyword)
                      :content line)))
