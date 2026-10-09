(defpackage #:elmtui.workbench.editor.tests
 (:use #:cl #:fiveam)
 (:import-from #:elmtui.workbench.editor
 #:make-editor-state #:editor-text #:editor-insert-text
 #:editor-handle-key #:editor-state-cursor #:editor-state-columns
 #:editor-balanced-p #:editor-cursor-screen-position
 #:editor-history-add #:editor-search-history #:editor-undo
 #:editor-redo #:editor-match-bracket #:editor-indent-line
 #:editor-resize #:editor-backspace #:editor-delete-forward
 #:editor-move-cursor)
 (:export #:editor-tests))

(in-package #:elmtui.workbench.editor.tests)

(def-suite editor-tests :description "Standalone Lisp workbench editor tests")

(in-suite editor-tests)

(test basic-editing
 (let ((state (make-editor-state :text "(+ 1 2)")))
 (is (string= "(+ 1 2)" (editor-text state)))
 (is (editor-balanced-p state))
 (editor-insert-text state " ")
 (is (string= "(+ 1 2) " (editor-text state)))
 (editor-handle-key state :backspace)
 (is (string= "(+ 1 2)" (editor-text state)))))

(test incomplete-and-reader-safety
 (let ((state (make-editor-state :text "(list 1)")))
   (is (editor-balanced-p state))
   (editor-insert-text state (string (code-char 40)))
   (is (not (editor-balanced-p state)))
   (editor-handle-key state :backspace)
   (is (editor-balanced-p state))
   (is (not (editor-balanced-p (make-editor-state :text "#.(+ 1 2)"))))
   (is (not (editor-balanced-p (make-editor-state :text ""))))))

(test history-boundaries-and-search
 (let ((state (make-editor-state :text "draft")))
   (editor-history-add state "alpha")
   (editor-history-add state "beta")
   (editor-handle-key state :up)
   (is (string= "beta" (editor-text state)))
   (editor-handle-key state :up)
   (is (string= "alpha" (editor-text state)))
   (editor-handle-key state :up)
   (is (string= "alpha" (editor-text state)))
   (editor-handle-key state :down)
   (is (string= "beta" (editor-text state)))
   (editor-handle-key state :down)
   (is (string= "draft" (editor-text state)))
   (is (= 1 (editor-search-history state "alp")))))

(test unicode-grapheme-and-cell-position
 (let ((state (make-editor-state :text "á中" :columns 10)))
   (multiple-value-bind (x y) (editor-cursor-screen-position state)
     (is (= 3 x)) (is (= 0 y)))
   (editor-backspace state)
   (is (string= "á" (editor-text state)))
   (multiple-value-bind (x y) (editor-cursor-screen-position state)
     (is (= 1 x)) (is (= 0 y)))
   (editor-backspace state)
   (is (string= "" (editor-text state)))
   (editor-resize state 2)
   (is (= 2 (editor-state-columns state)))))

(test multiline-indent-and-bracket-navigation
 (let ((state (make-editor-state :text "(list 1)" :cursor 7)))
   (editor-handle-key state :shift-enter)
   (is (string= (format nil "(list 1~%)") (editor-text state)))
   (is (editor-balanced-p state))
   (is (= 8 (editor-match-bracket state 0)))
   (is (= 0 (editor-match-bracket state 8)))
   (editor-move-cursor state :up)
   (is (= 0 (editor-state-cursor state)))
   (editor-move-cursor state :down)
   (is (= 8 (editor-state-cursor state)))))

(test incomplete-enter-indents-and-complete-enter-submits
 (let ((state (make-editor-state :text "(progn)" :cursor 6)))
   (editor-handle-key state :delete)
   (is (not (editor-balanced-p state)))
   (editor-handle-key state :enter)
   (is (string= (format nil "~a~%  " (subseq "(progn)" 0 6))
                (editor-text state)))
   (editor-insert-text state
     (concatenate 'string "42" (string (code-char 41))))
   (is (editor-balanced-p state))
   (is (eq :submit (nth-value 1 (editor-handle-key state :enter))))
   (is (string= (editor-text state)
                (first (elmtui.workbench.editor::editor-state-history state))))))

(test kill-yank-undo-redo-and-exit
 (let ((state (make-editor-state :text (format nil "abc~%def") :cursor 1)))
   (editor-handle-key state :kill-line)
   (is (string= (format nil "a~%def") (editor-text state)))
   (editor-handle-key state :yank)
   (is (string= (format nil "abc~%def") (editor-text state)))
   (editor-undo state)
   (is (string= (format nil "a~%def") (editor-text state)))
   (editor-undo state)
   (is (string= (format nil "abc~%def") (editor-text state)))
   (editor-redo state)
   (is (string= (format nil "a~%def") (editor-text state)))
   (is (eq :exit (nth-value 1
       (editor-handle-key (make-editor-state) :ctrl-d))))))

(test display-wrap-and-resize
 (let ((state (make-editor-state :text "a中b" :columns 3)))
   (multiple-value-bind (x y) (editor-cursor-screen-position state)
     (is (= 1 x)) (is (= 1 y)))
   (editor-resize state 6)
   (multiple-value-bind (x y) (editor-cursor-screen-position state
                                     :origin-x 2 :origin-y 4)
     (is (= 6 x)) (is (= 4 y)))
   (is (= 3 (editor-state-cursor state)))))

(test sustained-key-reduction-remains-responsive
 (let ((state (make-editor-state)))
   (loop repeat 400 do (editor-handle-key state #\x))
   (is (= 400 (length (editor-text state))))
   (loop repeat 400 do (editor-handle-key state :backspace))
   (is (string= "" (editor-text state)))
   (is (= 0 (editor-state-cursor state)))
   (is (eq :history-search
           (nth-value 1 (editor-handle-key state :ctrl-r))))
   (is (null (nth-value 1 (editor-handle-key state :ctrl-enter))))))

(test literal-eof-keyword-is-a-form (is (editor-balanced-p (make-editor-state :text ":eof"))) (is (editor-balanced-p (make-editor-state :text ":eof (+ 1 2)"))) (is (editor-balanced-p (make-editor-state :text "  :eof  "))) (is (not (editor-balanced-p (make-editor-state :text " :eof (")))) (is (not (editor-balanced-p (make-editor-state :text "#.(+ 1 2)")))))
