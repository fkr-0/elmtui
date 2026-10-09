(defpackage :elmtui.workbench.completion
  (:use :cl)
  (:export #:completion-candidate #:completion-candidate-id
           #:completion-candidate-display #:completion-candidate-insertion
           #:completion-candidate-annotation #:completion-candidate-symbol
           #:completion-candidate-package #:completion-candidate-score
           #:completion-result #:completion-result-generation
           #:completion-result-start #:completion-result-end
           #:completion-result-prefix #:completion-result-context
           #:completion-result-candidates #:completion-current-p
           #:complete-at #:documentation-for #:signature-for
           #:documentation-dwell-state #:make-documentation-dwell-state
           #:documentation-dwell-state-generation
           #:documentation-dwell-state-candidate-id
           #:schedule-documentation-dwell #:cancel-documentation-dwell
           #:documentation-dwell-due-p #:consume-documentation-dwell
           #:completion-keybinding-config #:make-completion-keybinding-config
           #:completion-keybinding-config-bindings
           #:completion-keybinding-profile-names
           #:completion-command-for-key #:set-completion-keybinding
           #:completion-theme #:make-completion-theme
           #:completion-theme-popup #:completion-theme-selected
           #:completion-theme-normal #:completion-theme-annotation
           #:completion-theme-package #:completion-theme-signature
           #:completion-theme-documentation
           #:completion-style #:completion-present-candidates))
(in-package :elmtui.workbench.completion)

(defstruct completion-candidate id display insertion annotation symbol package score)
(defstruct completion-result generation start end prefix context candidates)
(defstruct documentation-dwell-state generation candidate-id due-at)

(defun completion-current-p (result generation)
  (and (completion-result-p result)
       (eql generation (completion-result-generation result))))

(defun %session-package (session)
  (or (typecase session
        (package session)
        (string (find-package session))
        (symbol (find-package session)))
      (when session
        (let* ((namespace (find-package "ELMTUI.WORKBENCH.EVAL"))
               (reader (and namespace (find-symbol "REPL-SESSION-PACKAGE" namespace))))
          (when (and reader (fboundp reader))
            (ignore-errors
              (let ((value (funcall (symbol-function reader) session)))
                (typecase value
                  (package value)
                  (string (find-package value))
                  (symbol (find-package value))))))))
      *package*))

(defun %token-char-p (character)
  (and character
       (not (member (char-code character)
                    '(40 41 34 39 96 44 59 124 32 9 10 13 12)))))

(defun %lexical-context (source cursor)
  (let ((mode :code) (block-depth 0) (index 0))
    (loop while (< index cursor)
          for character = (char source index)
          for next = (and (< (1+ index) cursor) (char source (1+ index)))
          do (cond
               ((eq mode :line-comment)
                (when (char= character #\Newline) (setf mode :code)))
               ((eq mode :string)
                (cond ((char= character (code-char 92)) (incf index))
                      ((char= character (code-char 34)) (setf mode :code))))
               ((eq mode :bar-symbol)
                (cond ((char= character (code-char 92)) (incf index))
                      ((char= character (code-char 124)) (setf mode :code))))
               ((plusp block-depth)
                (cond ((and next (char= character (code-char 35)) (char= next (code-char 124)))
                       (incf block-depth) (incf index))
                      ((and next (char= character (code-char 124)) (char= next (code-char 35)))
                       (decf block-depth) (incf index))))
               ((and next (char= character (code-char 35)) (char= next (code-char 124)))
                (setf block-depth 1) (incf index))
               ((and next (char= character (code-char 35)) (char= next (code-char 92)))
                (incf index)
                (when (< (1+ index) cursor)
                  (incf index)
                  (when (alpha-char-p (char source index))
                    (loop while (and (< (1+ index) cursor)
                                     (alpha-char-p (char source (1+ index))))
                          do (incf index)))))
               ((char= character (code-char 59)) (setf mode :line-comment))
               ((char= character (code-char 34)) (setf mode :string))
               ((char= character (code-char 124)) (setf mode :bar-symbol)))
          (incf index))
    (cond ((plusp block-depth) :comment)
          ((eq mode :line-comment) :comment)
          ((eq mode :string) :string)
          ((eq mode :bar-symbol) :escaped-symbol)
          (t :code))))

(defun %span-start (source cursor)
  (loop for index downfrom (1- cursor) to 0
        while (%token-char-p (char source index))
        finally (return (1+ index))))

(defun %span-end (source cursor)
  (loop for index from cursor below (length source)
        while (%token-char-p (char source index))
        finally (return index)))

(defun %match-score (name prefix)
  (let ((position (search (string-upcase prefix) (string-upcase name))))
    (when position
      (if (zerop position)
          (- 10000 (length name))
          (- 1000 (* 10 position) (length name))))))

(defun %annotation (symbol)
  (cond ((macro-function symbol) "macro")
        ((special-operator-p symbol) "special")
        ((fboundp symbol) "function")
        ((boundp symbol) "variable")
        ((find-class symbol nil) "class")
        (t "symbol")))

(defun %escaped-name (name)
  (if (and (plusp (length name))
           (string= name (string-upcase name))
           (not (digit-char-p (char name 0)))
           (not (string= name "."))
           (every #'%token-char-p name))
      name
      (with-output-to-string (stream)
        (write-char (code-char 124) stream)
        (loop for character across name
              do (when (member (char-code character) '(92 124))
                   (write-char (code-char 92) stream))
                 (write-char character stream))
        (write-char (code-char 124) stream))))

(defun %candidate (symbol score)
  (let* ((home (symbol-package symbol))
         (name (symbol-name symbol))
         (package-name (if home (package-name home) "")))
    (make-completion-candidate
     :id (format nil "~A::~A" package-name name)
     :display name :insertion (%escaped-name name)
     :annotation (%annotation symbol)
     :symbol symbol :package home :score score)))

(defun %candidate-less-p (left right)
  (if (= (completion-candidate-score left) (completion-candidate-score right))
      (string-lessp (completion-candidate-display left)
                    (completion-candidate-display right))
      (> (completion-candidate-score left) (completion-candidate-score right))))

(defun complete-at (session source cursor generation &key (limit 40))
  (check-type source string)
  (check-type cursor (integer 0 *))
  (unless (<= cursor (length source))
    (error "Completion cursor beyond source"))
  (let* ((*read-eval* nil)
         (context (%lexical-context source cursor))
         (token-start (%span-start source cursor))
         (token-before (subseq source token-start cursor))
         (separator (position (code-char 58) token-before :from-end t))
         (double-colon (and separator (plusp separator)
                            (char= (char token-before (1- separator)) (code-char 58))))
         (package-text (and separator (subseq token-before 0
                                               (if double-colon (1- separator) separator))))
         (start (if separator (+ token-start separator 1) token-start))
         (prefix (subseq source start cursor))
         (end (%span-end source cursor))
         (package (cond ((null separator) (%session-package session))
                        ((zerop (length package-text)) (find-package "KEYWORD"))
                        (t (find-package (string-upcase package-text)))))
         (external-only (and separator (not double-colon)))
         (seen (make-hash-table :test #'eq))
         (candidates nil))
    (when (and (eq context :code) package)
      (flet ((consider (symbol)
               (unless (gethash symbol seen)
                 (setf (gethash symbol seen) t)
                 (let ((score (%match-score (symbol-name symbol) prefix)))
                   (when score
                     (push (%candidate symbol score) candidates))))))
        (if external-only
            (do-external-symbols (symbol package) (consider symbol))
            (do-symbols (symbol package) (consider symbol)))))
    (make-completion-result
     :generation generation :start start :end end :prefix prefix :context context
     :candidates (subseq (sort candidates #'%candidate-less-p)
                         0 (min (length candidates) (max 0 (min limit 200)))))))

(defparameter +completion-actions+
  '(:open :accept :next :previous :dismiss :toggle-docs :page-next :page-previous))

(defparameter +completion-keybinding-profiles+
  '((:default
     ("Ctrl+Space" . :open)
     ("C-SPC" . :open)
     ("Tab" . :accept)
     ("Enter" . :accept)
     ("Down" . :next)
     ("Up" . :previous)
     ("Escape" . :dismiss)
     ("F3" . :toggle-docs)
     ("PageDown" . :page-next)
     ("PageUp" . :page-previous))
    (:emacs
     ("Ctrl+Space" . :open)
     ("C-SPC" . :open)
     ("M-/" . :open)
     ("Tab" . :accept)
     ("Enter" . :accept)
     ("Down" . :next)
     ("Up" . :previous)
     ("C-N" . :next)
     ("C-P" . :previous)
     ("Escape" . :dismiss)
     ("C-G" . :dismiss)
     ("F3" . :toggle-docs)
     ("PageDown" . :page-next)
     ("PageUp" . :page-previous))))

(defstruct (completion-keybinding-config
             (:constructor %make-completion-keybinding-config))
  (bindings nil :type list))

(defun completion-keybinding-profile-names ()
  (mapcar #'car +completion-keybinding-profiles+))

(defun %canonical-key-name (key)
  (check-type key string)
  (string-upcase key))

(defun %valid-completion-action-p (action)
  (member action +completion-actions+ :test #'eq))

(defun set-completion-keybinding (config key action)
  (check-type config completion-keybinding-config)
  (let ((canonical (%canonical-key-name key)))
    (setf (completion-keybinding-config-bindings config)
          (remove canonical
                  (completion-keybinding-config-bindings config)
                  :key #'car
                  :test #'string=))
    (when action
      (unless (%valid-completion-action-p action)
        (error "Unknown completion action ~S" action))
      (push (cons canonical action)
            (completion-keybinding-config-bindings config))))
  config)

(defun make-completion-keybinding-config (&key (profile :default) overrides)
  (let ((profile-bindings (cdr (assoc profile +completion-keybinding-profiles+))))
    (unless profile-bindings
      (error "Unknown completion keybinding profile ~S" profile))
    (let ((config (%make-completion-keybinding-config)))
      (dolist (binding profile-bindings)
        (set-completion-keybinding config (car binding) (cdr binding)))
      (dolist (binding overrides)
        (set-completion-keybinding config (car binding) (cdr binding)))
      config)))

(defun completion-command-for-key (config key)
  (check-type config completion-keybinding-config)
  (cdr (assoc (%canonical-key-name key)
              (completion-keybinding-config-bindings config)
              :test #'string=)))

(defstruct (completion-theme (:constructor %make-completion-theme))
  popup selected normal annotation package signature documentation)

(defun make-completion-theme
    (&key
       (popup '(:border-style :solid :border-width 1 :fg-color :cyan))
       (selected '(:fg-color :black :bg-color :cyan :bold t))
       (normal '(:fg-color :white))
       (annotation '(:fg-color :gray))
       (package '(:fg-color :blue))
       (signature '(:fg-color :yellow :bold t))
       (documentation '(:fg-color :white)))
  (%make-completion-theme
   :popup (copy-list popup)
   :selected (copy-list selected)
   :normal (copy-list normal)
   :annotation (copy-list annotation)
   :package (copy-list package)
   :signature (copy-list signature)
   :documentation (copy-list documentation)))

(defun completion-style (theme role)
  (check-type theme completion-theme)
  (copy-list
   (ecase role
     (:popup (completion-theme-popup theme))
     (:selected (completion-theme-selected theme))
     (:normal (completion-theme-normal theme))
     (:annotation (completion-theme-annotation theme))
     (:package (completion-theme-package theme))
     (:signature (completion-theme-signature theme))
     (:documentation (completion-theme-documentation theme)))))

(defun completion-present-candidates
    (result &key (selected-index 0) (theme (make-completion-theme)))
  (check-type result completion-result)
  (loop for candidate in (completion-result-candidates result)
        for index from 0
        for selected-p = (= index selected-index)
        collect
        (list :id (completion-candidate-id candidate)
              :display (completion-candidate-display candidate)
              :insertion (completion-candidate-insertion candidate)
              :annotation (completion-candidate-annotation candidate)
              :package (let ((package (completion-candidate-package candidate)))
                         (and package (package-name package)))
              :selected-p selected-p
              :style-role (if selected-p :selected :normal)
              :style (completion-style theme
                                       (if selected-p :selected :normal)))))
