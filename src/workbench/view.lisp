(defpackage :elmtui.workbench.view
  (:use :cl)
  (:export :frame-view :frame-lines :frame-dsl))
(in-package :elmtui.workbench.view)

(defun %single-line (value)
  (map 'string (lambda (ch) (if (find ch '(#\Newline #\Return)) #\Space ch))
       (princ-to-string (or value ""))))

(defun %split-lines (source)
  (loop with start = 0
        for end = (position #\Newline source :start start)
        collect (subseq source start (or end (length source)))
        while end do (setf start (1+ end))))

(defun %text (id content width &optional (style '(:fg-color :white)))
  (list :text :id (if (listp id) (format nil "~{~A~^-~}" id) id)
        :content (elmtui.view.layout.size-utils:terminal-string-slice (%single-line content) 0)
        :style (append (copy-list style)
                       (list :width (max 0 width) :height 1 :flex-shrink 0))))

(defun %box (id direction width height children &rest style)
  (list :container :id (if (listp id) (format nil "~{~A~^-~}" id) id)
        :style (append (list :display :flex :flex-direction direction
                            :width (max 0 width) :height (max 0 height)
                            :padding 0 :gap 0 :flex-shrink 0 :overflow :hidden)
                       style)
        :children children))

(defun %inspector-row (entry active)
  (format nil "~A~A ~A~A" (if active ">" " ")
          (if (getf entry :changed) "!" " ")
          (or (getf entry :name) (getf entry :summary) (getf entry :preview) "?")
          (if (getf entry :boundp)
              (format nil " = ~A" (or (getf entry :preview) "?")) "")))

(defun %inspector-pane (width height snapshot section selected query query-mode theme)
  (let* ((entries (getf snapshot :entries))
         (visible (max 0 (1- height)))
         (start (max 0 (- selected (max 0 (1- visible))))))
    (%box :workbench-inspector :column width height
        (cons (%text :inspector-title
                     (format nil "IMAGE / ~A~A" section
                             (if (or query-mode (plusp (length query)))
                                 (format nil " / ~A~A" query (if query-mode "_" "")) ""))
                     width (elmtui.workbench.inspector:inspector-style theme :section-title))
              (loop for entry in (nthcdr start entries)
                    for i from start below (+ start visible)
                    collect (%text (list :inspector-entry i)
                                   (%inspector-row entry (= i selected)) width
                                   (elmtui.workbench.inspector:inspector-style
                                    theme (if (= i selected) :selected
                                              (or (getf entry :style-role) :normal)))))))))

(defun %completion-pane (width completion selected docs theme &optional available-height)
  (let* ((candidates (and completion
                          (elmtui.workbench.completion:completion-present-candidates
                           completion :selected-index selected :theme theme)))
         (signature (and (listp docs) (getf docs :signature)))
         (documentation (if (stringp docs) docs
                            (and (listp docs) (getf docs :documentation))))
         (height (max 0 (or available-height
                            (+ 6 (if signature 1 0) (if documentation 1 0))))))
    (when (and candidates (plusp height))
      ;; The selected candidate must stay inside the *actual* terminal viewport.
      ;; With only one free row, prioritize it over the optional title.
      (let* ((show-title (> height 1))
             (capacity (min 5 (- height (if show-title 1 0))))
             (start (max 0 (min selected (- (length candidates) capacity))))
             (rows
               (append
                (when show-title
                  (list (%text :completion-title "[ COMPLETION ]" width
                               '(:fg-color :cyan :bold t))))
                (loop for item in (nthcdr start candidates)
                      for i from start below (+ start capacity)
                      collect
                      (%box (list :completion-row i) :row width 1
                            (list (%text (list :completion-label i)
                                         (format nil "~A~A"
                                                 (if (getf item :selected-p) "> " "  ")
                                                 (or (getf item :display) ""))
                                         (min 23 width) (getf item :style))
                                  (%text (list :completion-package i)
                                         (getf item :package) (min 12 (max 0 (- width 23)))
                                         (elmtui.workbench.completion:completion-style theme :package))
                                  (%text (list :completion-annotation i)
                                         (getf item :annotation) (max 0 (- width 35))
                                         (elmtui.workbench.completion:completion-style theme :annotation)))))))
             (remaining (- height (length rows))))
        (when (and signature (plusp remaining))
          (setf rows (append rows
                             (list (%text :completion-signature
                                          (format nil "SIG: ~A" (%single-line signature))
                                          width (elmtui.workbench.completion:completion-style theme :signature))))
                remaining (1- remaining)))
        (when (and documentation (plusp remaining))
          (setf rows (append rows
                             (list (%text :completion-documentation
                                          (format nil "DOC: ~A" (%single-line documentation))
                                          width (elmtui.workbench.completion:completion-style theme :documentation))))))
        (values (%box :workbench-completion :column width (length rows) rows)
                (length rows))))))

(defun %editor-pane (width height source cursor focused)
  (let* ((lines (%split-lines source))
         (cursor (max 0 (min cursor (length source))))
         (cursor-line (count #\Newline source :end cursor))
         (line-start (1+ (or (position #\Newline source :end cursor :from-end t) -1)))
         ;; Keep the cursor's logical line in the visible window.
         (start (max 0 (- cursor-line (1- height))))
         (end (min (length lines) (+ start height))))
    (%box :workbench-editor :column width height
          (loop for line in (subseq lines start end)
                for line-number from start
                for active = (and focused (= line-number cursor-line))
                for before = (if active (subseq line 0 (- cursor line-start)) line)
                for cells = (elmtui.view.layout.size-utils:terminal-string-width before)
                for room = (max 0 (- width 3 (if active 1 0)))
                for offset = (if active (max 0 (- cells room)) 0)
                for prefix = (elmtui.view.layout.size-utils:terminal-string-slice before offset (+ offset room))
                for prefix-width = (elmtui.view.layout.size-utils:terminal-string-width prefix)
                collect
                (%box (list :editor-line line-number) :row width 1
                      (append
                       (list (%text (list :editor-prompt line-number)
                                    (if (= line-number start) " > " "   ") (min 3 width)
                                    '(:fg-color :cyan :bold t))
                             (%text (list :editor-before line-number) prefix prefix-width))
                       (when active
                         (list (%text :editor-cursor "|" 1 '(:fg-color :cyan :bold t))
                               (%text :editor-after
                                      (elmtui.view.layout.size-utils:terminal-string-slice line cells)
                                      (max 0 (- width 4 prefix-width)))))))))))

(defun frame-view
    (&key (width 80) (height 24) (source "") (cursor 0)
       transcript completion (selected 0) docs inspector
       (inspector-section :packages) (inspector-selected 0)
       (inspector-query "") inspector-query-mode (show-inspector t)
       (focus :editor) (status "Ready") (package "CL-USER") (scroll 0)
       (completion-theme (elmtui.workbench.completion:make-completion-theme))
       (inspector-theme (elmtui.workbench.inspector:make-inspector-theme)))
  "Return semantic ElmTUI panes. Layout, clipping and painting belong to ElmTUI."
  (let* ((w (max 1 width)) (h (max 1 height))
         (body-height (max 0 (- h 3)))
         (wide (and (>= w 120) show-inspector))
         (inspector-only (and show-inspector (not wide) (eq focus :inspector)))
         (main-width (if wide (floor (* w 68) 100) w))
         (editor-height (min (max 1 body-height) 6 (max 2 (length (%split-lines source))))))
    (multiple-value-bind (completion-pane completion-height)
        (%completion-pane main-width completion selected docs completion-theme
                          (max 0 (- body-height editor-height 2)))
      (let* ((transcript-height (max 0 (- body-height editor-height (or completion-height 0) 2)))
             (ordered (reverse transcript))
             (end (max 0 (- (length ordered) (max 0 scroll)))))
        (%box :workbench-frame :column w h
              (list
               (%text :workbench-header
                      (format nil " Lisp Workbench  [~A]  ~A" package
                              (if (eq focus :editor) "REPL" "IMAGE"))
                      w '(:fg-color :cyan :bold t))
               (%box :workbench-body :row w body-height
                     (if inspector-only
                         (list (%inspector-pane w body-height inspector inspector-section inspector-selected
                                                inspector-query inspector-query-mode inspector-theme))
                         (append
                          (list
                           (%box :workbench-main :column main-width body-height
                                 (append
                                  (list (%text :transcript-title (format nil " Transcript (~D)" (length transcript))
                                               main-width '(:fg-color :gray :bold t))
                                        (%box :workbench-transcript :column main-width transcript-height
                                              (loop for item in (subseq ordered (max 0 (- end transcript-height)) end)
                                                    for i from 0 collect
                                                    (%text (list :transcript-line i) (format nil "  ~A" item) main-width))))
                                  (when (and completion-pane (plusp completion-height)) (list completion-pane))
                                  (list (%text :editor-separator (make-string main-width :initial-element #\-)
                                               main-width '(:fg-color :gray))
                                        (%editor-pane main-width editor-height source cursor (eq focus :editor))))))
                          (when wide
                            (list (%text :inspector-divider "|" 1 '(:fg-color :gray))
                                  (%inspector-pane (max 0 (- w main-width 1)) body-height inspector
                                                   inspector-section inspector-selected inspector-query
                                                   inspector-query-mode inspector-theme))))))
               (%text :workbench-status (format nil " ~A  |  ~D x ~D  |  ~A" status w h focus)
                      w '(:fg-color :yellow))
               (%text :workbench-help
                      (if (eq focus :inspector)
                          " F2 Editor  Up/Down Select  Tab Section  w Watch  W Watches  / Filter  Esc Editor"
                          " Ctrl+Enter Eval  Ctrl+Space Complete  F2 Inspector  F3 Docs  F4 Diagnostics  Ctrl+D Exit")
                      w '(:fg-color :gray))))))))

(defun %row-segments (row spans default)
  (let ((offset 0) (column 0) (segments nil))
    (dolist (grapheme (elmtui.view.layout.size-utils:terminal-graphemes row))
      (let* ((original (car grapheme))
             (tabp (string= original (string #\Tab)))
             (cells (if tabp (- 8 (mod column 8)) (cdr grapheme)))
             (cluster (if tabp (make-string cells :initial-element #\Space) original))
             (style default))
        (dolist (span (reverse spans))
          (when (and (< (first span) (+ offset (length original)))
                     (> (second span) offset))
            (setf style (third span))))
        (if (and segments (equal style (getf (first segments) :style)))
            (setf (getf (first segments) :content)
                  (concatenate 'string (getf (first segments) :content) cluster)
                  (getf (first segments) :width) (+ cells (getf (first segments) :width)))
            (push (list :content cluster :style style :width cells) segments))
        (incf column cells)
        (incf offset (length original))))
    (nreverse segments)))

(defun frame-dsl (rows width height &key style-map)
  "Compatibility adapter for styled rows; all geometry uses ElmTUI display cells.
STYLE-MAP spans use string indices, and style changes inside a grapheme apply to
its whole cluster. The application uses FRAME-VIEW directly."
  (%box :workbench-frame :column width height
        (loop for row in rows for i from 0
              for default = (if (zerop i) '(:fg-color :cyan :bold t) '(:fg-color :white))
              for spans = (and style-map (< i (length style-map)) (aref style-map i))
              collect
              (if (null spans)
                  (%text (list :wb-row i) row
                         (elmtui.view.layout.size-utils:terminal-string-width row) default)
                  (%box (list :wb-row i) :row
                        (elmtui.view.layout.size-utils:terminal-string-width row) 1
                        (loop for segment in (%row-segments row spans default)
                              for j from 0 collect
                              (%text (list :wb-segment i j) (getf segment :content)
                                     (getf segment :width) (getf segment :style))))))))

(defun frame-lines (&rest options &key (width 80) (height 24) &allow-other-keys)
  "Compatibility snapshot of FRAME-VIEW rendered by ElmTUI, without terminal I/O.
Applications should consume FRAME-VIEW; this helper returns text rows only."
  (let* ((rect (elmtui.view.geo:make-rectangle
                :pos (elmtui.view.geo:make-pos :x 0 :y 0)
                :size (elmtui.view.geo:make-size :w width :h height)))
         (tree (elmtui.view.tree-transforms:process-tree
                (elmtui.view.base-elements:dsl->objects (apply #'frame-view options))
                :ctx (elmtui.contracts:make-app-context :viewport-rect rect) :root-rect rect))
         (buffer (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer width height)))
    (elmtui.platform.tree-renderer:render-laid-out-tree-to-buffer (list tree) :buffer buffer)
    (values
     (loop for row below height collect
           (with-output-to-string (out)
             (loop for col below width
                   for cell = (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at buffer row col)
                   for ch = (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell)
                   unless (char= ch #\Null)
                     do (write-string (or (elmtui.platform.backend.common.virtual-buffer:buffer-cell-grapheme cell)
                                          (string ch)) out))))
     nil)))
