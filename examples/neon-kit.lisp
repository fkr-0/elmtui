;;;; Shared, renderer-native visual vocabulary for the NILMSP-inspired demos.
(uiop:define-package :elmtui.examples.neon-kit
  (:use :cl)
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-key #:key-event-char
                #:key-event-modifiers)
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

(defun %palette (role)
  (case role
    (:title (values '(97 233 250) '(18 34 57) t))
    (:accent (values '(248 199 115) '(10 17 31) t))
    (:signal (values '(103 245 206) '(10 17 31) t))
    (:muted (values '(125 143 169) '(10 17 31) nil))
    (:border (values '(140 114 231) '(10 17 31) nil))
    (:danger (values '(254 124 149) '(10 17 31) t))
    (:footer (values '(190 171 250) '(18 25 45) nil))
    (otherwise (values '(216 225 242) '(10 17 31) nil))))

(defun screen (id lines &key (width 74) (height 24))
  "Render stable, individually styled rows through ElmTUI's diff presenter.
No raw ANSI and no terminal output occurs here."
  `(:container :id ,id
     :style (:display :flex :flex-direction :column
             :width ,width :height ,height :gap 0 :padding 0)
     :children
     ,(loop for (content . role) in lines
            for i from 0
            collect (multiple-value-bind (fg bg strong) (%palette role)
                      `(:text :id ,(intern (format nil "NEON-ROW-~D" i) :keyword)
                         :content ,(clip content width)
                         :style (:width ,width :height 1 :fg-color ,fg
                                 :bg-color ,bg :bold ,strong))))))
