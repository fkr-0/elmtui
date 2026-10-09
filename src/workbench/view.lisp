(defpackage :elmtui.workbench.view
  (:use :cl)
  (:export :frame-lines :frame-dsl))
(in-package :elmtui.workbench.view)

(defun %fit (value width)
  (let ((str (princ-to-string (or value ""))))
    (subseq str 0 (min (length str) (max 0 width)))))

(defun %paint (screen row column value
                        &optional width style-map style)
  "Paint a bounded fragment and optionally record a semantic style span."
  (when (and (<= 0 row) (< row (length screen)))
    (let* ((line (aref screen row))
           (start (max 0 column))
           (value (princ-to-string value))
           (skip (max 0 (- start column)))
           (size (max 0 (min (- (length line) start)
                              (- (length value) skip)
                              (or width (length value))))))
      (when (plusp size)
        (replace line value
                 :start1 start
                 :start2 skip
                 :end2 (+ skip size))
        (when (and style-map style)
          (push (list start (+ start size) (copy-list style))
                (aref style-map row))))))
  screen)

(defun %split-lines (source)
  (loop with start = 0
        for end = (position #\Newline source :start start)
        collect (subseq source start (or end (length source)))
        while end do (setf start (1+ end))))

(defun %candidate-line (candidate active)
  (format nil "~A ~A  ~A" (if active ">" " ")
          (elmtui.workbench.completion:completion-candidate-display candidate)
          (elmtui.workbench.completion:completion-candidate-annotation candidate)))

(defun %single-line (value)
  (let ((text (princ-to-string (or value ""))))
    (map 'string
         (lambda (character)
           (if (member character '(#\Newline #\Return #\Tab)
                       :test #'char=)
               #\Space
               character))
         text)))

(defun %inspector-row (entry &optional active)
  (let ((name (or (getf entry :name)
                  (getf entry :summary)
                  (getf entry :preview)
                  "?")))
    (format nil "~A~A ~A~A"
            (if active ">" " ")
            (if (getf entry :changed) "!" " ")
            name
            (if (getf entry :boundp)
                (format nil " = ~A" (or (getf entry :preview) "?"))
                ""))))

(defun %inspector-entry-style (theme entry active)
  (if active
      (elmtui.workbench.inspector:inspector-style theme :selected)
      (elmtui.workbench.inspector:inspector-style
       theme
       (or (getf entry :style-role) :normal))))

(defun %paint-inspector-rows
    (screen style-map entries start-row column end-row width selected theme)
  (loop for entry in entries
        for index from 0
        for row from start-row below end-row
        do (%paint screen row column
                   (%fit (%inspector-row entry (= index selected)) width)
                   width
                   style-map
                   (%inspector-entry-style
                    theme entry (= index selected)))))

(defun %row-segments (row spans default-style)
  (let* ((length (length row))
         (styles (make-array length :initial-element default-style)))
    (dolist (span (reverse spans))
      (destructuring-bind (start end style) span
        (loop for index from (max 0 start)
              below (min length end)
              do (setf (aref styles index) style))))
    (loop with start = 0
          while (< start length)
          for style = (aref styles start)
          for end = (loop for index from (1+ start) below length
                          while (equal (aref styles index) style)
                          finally (return index))
          collect (list :content (subseq row start end)
                        :style style)
          do (setf start end))))

(defun frame-lines
    (&key (width 80) (height 24) (source "") (cursor 0)
       transcript completion (selected 0) docs
       inspector (inspector-section :packages) (inspector-selected 0)
       (inspector-query "") inspector-query-mode
       (show-inspector t) (focus :editor) (status "Ready")
       (package "CL-USER") (scroll 0)
       (completion-theme (elmtui.workbench.completion:make-completion-theme))
       (inspector-theme (elmtui.workbench.inspector:make-inspector-theme)))
  "Produce screen rows plus semantic style spans without writing a terminal."
  (let* ((w (max 24 (min 240 width)))
         (h (max 8 (min 100 height)))
         (wide (>= w 120))
         (narrow-inspector
           (and (not wide) show-inspector (eq focus :inspector)))
         (main-w
           (if (and wide show-inspector)
               (floor (* w 68) 100)
               w))
         (screen (make-array h))
         (style-map (make-array h :initial-element nil))
         (logical-lines (%split-lines source))
         (editor-height (min 6 (max 2 (length logical-lines))))
         (editor-y (- h 3 editor-height))
         (visible
           (last logical-lines (min editor-height (length logical-lines))))
         (offset (- (length logical-lines) (length visible)))
         (cursor-line
           (count #\Newline source :end (min cursor (length source))))
         (cursor-start
           (or (position #\Newline source
                         :end (min cursor (length source))
                         :from-end t)
               -1))
         (cursor-x
           (+ 3 (min (- main-w 5)
                     (- cursor (1+ cursor-start)))))
         (cursor-y
           (+ editor-y (max 0 (- cursor-line offset))))
         (header-style '(:fg-color :cyan :bold t))
         (footer-style '(:fg-color :gray))
         (status-style '(:fg-color :yellow))
         (separator-style '(:fg-color :gray)))
    (dotimes (index h)
      (setf (aref screen index)
            (make-string w :initial-element #\Space)))
    (%paint screen 0 0
             (format nil " Lisp Workbench  [~A]  ~A"
                     package
                     (if wide "REPL  |  IMAGE" "REPL / IMAGE"))
             nil style-map header-style)
    (%paint screen (1- h) 0
             (if (eq focus :inspector)
                 " F2 Editor  Up/Down Select  Tab Section  w Watch  W Watches  / Filter  Esc Editor"
                 " Ctrl+Enter Eval  Ctrl+Space Complete  F2 Inspector  F3 Docs  F4 Diagnostics  Ctrl+D Exit")
             nil style-map footer-style)
    (%paint screen (- h 2) 0
             (format nil " ~A  |  ~D x ~D  |  ~A"
                     status w h focus)
             nil style-map status-style)
    (if narrow-inspector
        (progn
          (%paint screen 2 2
                   (format nil "IMAGE / ~A~A"
                           inspector-section
                           (if (plusp (length inspector-query))
                               (format nil " / ~A~A"
                                       inspector-query
                                       (if inspector-query-mode "_" ""))
                               (if inspector-query-mode " / _" "")))
                   nil
                   style-map
                   (elmtui.workbench.inspector:inspector-style
                    inspector-theme :section-title))
          (%paint-inspector-rows
           screen style-map (getf inspector :entries)
           4 2 (- h 3) (- w 4)
           inspector-selected inspector-theme))
        (progn
          (let* ((available (max 0 (- editor-y 2)))
                 (ordered (reverse transcript))
                 (end (max 0 (- (length ordered) (max 0 scroll))))
                 (start (max 0 (- end available))))
            (%paint screen 1 1
                     (format nil "Transcript (~D)" (length transcript))
                     nil style-map '(:fg-color :gray :bold t))
            (loop for item in (subseq ordered start end)
                  for row from 2
                  do (%paint screen row 2
                             (%fit item (- main-w 4))
                             (- main-w 4)
                             style-map
                             '(:fg-color :white))))
          (%paint screen (1- editor-y) 0
                   (make-string (max 0 (1- main-w))
                                :initial-element #\-)
                   nil style-map separator-style)
          (loop for line in visible
                for row from editor-y
                for first = (= row editor-y)
                do (%paint screen row 0
                           (if first " > " "   ")
                           nil style-map
                           (if first
                               '(:fg-color :cyan :bold t)
                               '(:fg-color :gray)))
                   (%paint screen row 3
                           (%fit line (- main-w 4))
                           (- main-w 4)
                           style-map
                           '(:fg-color :white)))
          (%paint screen
                   (min (- h 4) cursor-y)
                   (max 3 (min (- main-w 2) cursor-x))
                   "|"
                   1 style-map '(:fg-color :cyan :bold t))))
    (when (and wide show-inspector)
      (loop for row from 1 below (- h 2)
            do (%paint screen row main-w "|"
                       1 style-map separator-style))
      (%paint screen 1 (+ main-w 2)
               (format nil "IMAGE / ~A~A"
                       inspector-section
                       (if (plusp (length inspector-query))
                           (format nil " / ~A~A"
                                   inspector-query
                                   (if inspector-query-mode "_" ""))
                           (if inspector-query-mode " / _" "")))
               nil
               style-map
               (elmtui.workbench.inspector:inspector-style
                inspector-theme :section-title))
      (%paint-inspector-rows
       screen style-map (getf inspector :entries)
       3 (+ main-w 2) (- h 3) (- w main-w 3)
       inspector-selected inspector-theme))
    (when (and completion
               (not narrow-inspector)
               (elmtui.workbench.completion:completion-result-candidates
                completion))
      (let* ((presented
               (elmtui.workbench.completion:completion-present-candidates
                completion
                :selected-index selected
                :theme completion-theme))
             (limit (min 5 (length presented)))
             (signature
               (and (listp docs) (getf docs :signature)))
             (documentation
               (cond
                 ((and (listp docs) (getf docs :documentation))
                  (getf docs :documentation))
                 ((stringp docs) docs)
                 (t nil)))
             (doc-rows (+ (if signature 1 0)
                          (if documentation 1 0)))
             (rows (+ 1 limit doc-rows))
             (y (if (>= cursor-y (+ rows 1))
                    (- cursor-y rows)
                    (min (- h rows 3) (1+ cursor-y))))
             (x (max 1 (min (- main-w 48)
                            (max 1 cursor-x)))))
        (setf y (max 1 y)
              x (max 1 x))
        (%paint screen y x "[ COMPLETION ]"
                 nil style-map '(:fg-color :cyan :bold t))
        (loop for row-data in presented
              for index from 0 below limit
              for row = (+ y index 1)
              do (let* ((active (getf row-data :selected-p))
                        (base-style (getf row-data :style))
                        (marker (if active "> " "  "))
                        (display (or (getf row-data :display) ""))
                        (package-name (or (getf row-data :package) ""))
                        (annotation (or (getf row-data :annotation) "")))
                   (%paint screen row x
                            (format nil "~A~A" marker display)
                            23 style-map base-style)
                   (%paint screen row (+ x 23)
                            (%fit package-name 12)
                            12 style-map
                            (elmtui.workbench.completion:completion-style
                             completion-theme :package))
                   (%paint screen row (+ x 35)
                            (%fit annotation 11)
                            11 style-map
                            (elmtui.workbench.completion:completion-style
                             completion-theme :annotation))))
        (let ((doc-row (+ y limit 1)))
          (when signature
            (%paint screen doc-row x
                     (%fit (format nil "SIG: ~A"
                                   (%single-line signature))
                           46)
                     46 style-map
                     (elmtui.workbench.completion:completion-style
                      completion-theme :signature))
            (incf doc-row))
          (when documentation
            (%paint screen doc-row x
                     (%fit (format nil "DOC: ~A"
                                   (%single-line documentation))
                           46)
                     46 style-map
                     (elmtui.workbench.completion:completion-style
                      completion-theme :documentation))))))
    (values (coerce screen 'list) style-map)))

(defun frame-dsl (rows width height &key style-map)
  "Convert frame rows into stable text nodes. Preserve row-level styling.
Multiple inline style segments cannot yet be composed reliably by the nested
flex renderer: emitting a single text node per row keeps prompts, transcript,
completion, inspector and status rows visible."
  (list :container
        :id :workbench-frame
        :style (list :display :flex
                     :flex-direction :column
                     :width (max 24 width)
                     :height (max 8 height))
        :children
        (loop for row in rows
              for row-index from 0
              for default-style = (if (zerop row-index)
                                      '(:fg-color :cyan :bold t)
                                      '(:fg-color :white))
              for spans = (and style-map
                               (< row-index (length style-map))
                               (aref style-map row-index))
              for segments = (%row-segments row spans default-style)
              for active-style = (loop for span in spans
                                       for style = (third span)
                                       when (and (listp style)
                                                 (getf style :bg-color))
                                         return style)
              collect (list :text
                            :id (intern (format nil "WB-ROW-~D" row-index)
                                        :keyword)
                            :content row
                            :style (or active-style
                                       (getf (first segments) :style)
                                       default-style)))))
