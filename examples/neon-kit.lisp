;;;; Shared, renderer-native visual vocabulary for the NILMSP-inspired demos.
(uiop:define-package :elmtui.examples.neon-kit
  (:use :cl)
  (:import-from :elmtui.keys
                #:key-event #:key-event-key #:key-event-char
                #:key-event-modifiers)
  (:import-from :elmtui.ui.styles #:defstyle)
  (:export #:event-key #:pressed-p #:control-p #:quit-message-p
           #:screen #:line #:clip #:numbered-line))
(in-package :elmtui.examples.neon-kit)

(defun event-key (message)
  "Return KEY, CHAR and MODIFIERS from either supported ElmTUI event shape."
  (cond ((typep message 'key-event)
         (values (key-event-key message) (key-event-char message)
                 (key-event-modifiers message)))
        ((and (consp message) (member (first message) '(:keyevent :key-event)))
         (values (getf (rest message) :key)
                 (getf (rest message) :char)
                 (getf (rest message) :modifiers)))
        (t (values nil nil nil))))

(defun pressed-p (message &key char keys)
  (multiple-value-bind (key actual) (event-key message)
    (or (and char (or (and (characterp actual) (char= actual char))
                      (and (characterp key) (char= key char))))
        (and keys (member key keys :test #'eql)))))

(defun control-p (message letter code)
  (multiple-value-bind (key char mods) (event-key message)
    (or (eql char (code-char code))
        (and (intersection mods '(:control :ctrl))
             (or (and (characterp key) (char-equal key letter))
                 (eql key (intern (string-upcase (string letter)) :keyword))
                 (and (characterp char) (char-equal char letter)))))))

(defun quit-message-p (message)
  (and (consp message) (eq (first message) :app-quit-requested)))

(defun clip (text width)
  (let ((s (or text "")))
    (if (<= (length s) width) s (subseq s 0 width))))

(defun line (text &optional (role :body))
  (cons text role))

(defun numbered-line (index text &key (width 54))
  (format nil " │ ~2,'0D │ ~VA │" (1+ index) width (clip text width)))

;;;--------------------------------------------------------------
;;; Named style classes for the neon screen roles.
;;; Previously every row carried an inline :style plist repeating
;;; the same fg-color / bg-color / bold triple.  With defstyle the
;;; role palette is defined once and referenced by :class.
;;;--------------------------------------------------------------

(defstyle :neon-screen (:display :flex :flex-direction :column :gap 0 :padding 0))

(defstyle :neon-title  (:height 1 :fg-color (97 233 250)  :bg-color (18 34 57) :bold t))
(defstyle :neon-accent (:height 1 :fg-color (248 199 115) :bg-color (10 17 31) :bold t))
(defstyle :neon-signal (:height 1 :fg-color (103 245 206) :bg-color (10 17 31) :bold t))
(defstyle :neon-muted  (:height 1 :fg-color (125 143 169) :bg-color (10 17 31) :bold nil))
(defstyle :neon-border (:height 1 :fg-color (140 114 231) :bg-color (10 17 31) :bold nil))
(defstyle :neon-danger (:height 1 :fg-color (254 124 149) :bg-color (10 17 31) :bold t))
(defstyle :neon-footer (:height 1 :fg-color (190 171 250) :bg-color (18 25 45) :bold nil))
(defstyle :neon-body   (:height 1 :fg-color (216 225 242) :bg-color (10 17 31) :bold nil))

(defun %role-class (role)
  "Map a role keyword to its neon style class."
  (case role
    (:title  :neon-title)
    (:accent :neon-accent)
    (:signal :neon-signal)
    (:muted  :neon-muted)
    (:border :neon-border)
    (:danger :neon-danger)
    (:footer :neon-footer)
    (otherwise :neon-body)))

(defun screen (id lines &key (width 74) (height 24))
  "Render stable, individually styled rows through ElmTUI's diff presenter.
No raw ANSI and no terminal output occurs here.

Each row's colour palette is defined once as a named style class via
DEFSTYLE; the per-row :width override is the only inline property."
  `(:container :id ,id
     :class :neon-screen
     :style (:width ,width :height ,height)
     :children
     ,(loop for (content . role) in lines
            for i from 0
            collect `(:text :id ,(intern (format nil "NEON-ROW-~D" i) :keyword)
                       :content ,(clip content width)
                       :class ,(%role-class role)
                       :style (:width ,width)))))
