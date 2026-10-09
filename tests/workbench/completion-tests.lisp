(defpackage :elmtui.workbench.completion.tests
  (:use :cl :fiveam)
  (:import-from :elmtui.workbench.completion
    #:complete-at #:completion-result-start #:completion-result-end
    #:completion-result-prefix #:completion-result-context
    #:completion-result-candidates #:completion-current-p
    #:completion-candidate-id #:completion-candidate-display
    #:completion-candidate-insertion #:completion-candidate-symbol
    #:completion-candidate-package #:documentation-for #:signature-for
    #:make-documentation-dwell-state #:schedule-documentation-dwell
    #:cancel-documentation-dwell #:documentation-dwell-due-p
    #:consume-documentation-dwell))
(in-package :elmtui.workbench.completion.tests)
(def-suite completion-suite)
(in-suite completion-suite)

(test unqualified-symbol-completion
  (let* ((result (complete-at (find-package "CL-USER") "(mapc" 5 11))
         (candidates (completion-result-candidates result)))
    (is (eql 11 (elmtui.workbench.completion:completion-result-generation result)))
    (is (= 1 (completion-result-start result)))
    (is (= 5 (completion-result-end result)))
    (is (string= "mapc" (completion-result-prefix result)))
    (is (member "MAPCAR" candidates :test #'string=
                :key #'completion-candidate-display))))

(test qualified-public-symbols
  (let* ((result (complete-at nil "(cl:mapc" 8 12))
         (hits (completion-result-candidates result)))
    (is (= 4 (completion-result-start result)))
    (is (= 8 (completion-result-end result)))
    (is (member "MAPCAR" hits :key #'completion-candidate-display :test #'string=))
    (is (every (lambda (candidate)
                 (eq (find-package "COMMON-LISP") (completion-candidate-package candidate)))
               hits))))

(test package-private-and-stale-generation
  (let ((double (complete-at nil "(cl::mapc" 9 14))
        (unknown (complete-at nil "(no-such-package:map" 20 15)))
    (is (= 5 (completion-result-start double)))
    (is (member "MAPCAR" (completion-result-candidates double)
                :key #'completion-candidate-display :test #'string=))
    (is (null (completion-result-candidates unknown)))
    (is (completion-current-p double 14))
    (is (not (completion-current-p double 15)))))

(test keyword-symbol-completion
  (let ((symbol (intern "WB03-COMPLETION-KEY" "KEYWORD")))
    (unwind-protect
         (let* ((result (complete-at nil ":wb03-" 6 16))
                (candidate (find symbol (completion-result-candidates result)
                                 :key #'completion-candidate-symbol)))
           (is (= 1 (completion-result-start result)))
           (is (string= "WB03-COMPLETION-KEY"
                        (completion-candidate-insertion candidate))))
      (unintern symbol "KEYWORD"))))

(test quoted-strings-and-comments-suppress
  (dolist (source (list "(format nil \"map"
                         "(+ 1 ; map"
                         "#| map"
                         "#| outer #| inner |# map"
                         "|escaped"))
    (let ((result (complete-at nil source (length source) 17)))
      (is (null (completion-result-candidates result)))
      (is (not (eq :code (completion-result-context result)))))))

(test incomplete-input-and-replacement-span
  (let ((open (complete-at nil "(defun demo (x) (mapc" 20 19))
        (middle (complete-at nil "(mapcXX 42)" 5 20)))
    (is (eq :code (completion-result-context open)))
    (is (member "MAPCAR" (completion-result-candidates open)
                :test #'string= :key #'completion-candidate-display))
    (is (= 1 (completion-result-start middle)))
    (is (= 7 (completion-result-end middle)))))

(test passive-reader-never-executes-dispatch
  (let ((executed nil))
    (declare (ignorable executed))
    (let* ((source "(#.(setf elmtui.workbench.completion.tests::*reader-sentinel* t) mapc")
           (result (complete-at nil source (length source) 21)))
      (is (eq :code (completion-result-context result)))
      (is (member "MAPCAR" (completion-result-candidates result)
                  :key #'completion-candidate-display :test #'string=)))))


(test unicode-symbol-insertion
  (let* ((package (make-package "WB03-UNICODE" :use '(:cl)))
         (symbol (intern "λQUARK" package)))
    (unwind-protect
         (let* ((result (complete-at package "(λ" 2 22))
                (candidate (find symbol (completion-result-candidates result)
                                 :key #'completion-candidate-symbol)))
           (is (= 1 (completion-result-start result)))
           (is (string= "|λQUARK|" (completion-candidate-insertion candidate)))
           (is (eq package (completion-candidate-package candidate))))
      (delete-package package))))

(test bounded-documentation
  (let ((symbol (intern "WB03-LONG-DOC" *package*)))
    (unwind-protect
         (progn
           (setf (documentation symbol 'function)
                 (make-string 8000 :initial-element (code-char 88)))
           (is (= 48 (length (documentation-for symbol :max-length 48))))
           (is (string= "XXXXX" (documentation-for symbol :max-length 5)))
           (is (string= "" (documentation-for symbol :max-length 0))))
      (setf (documentation symbol 'function) nil)
      (unintern symbol *package*))))

(test dwell-selection-cancellation
  (let ((state (make-documentation-dwell-state)))
    (schedule-documentation-dwell state "A" 31 :now 100 :delay-ms 450)
    (is (not (documentation-dwell-due-p state 31 "A" :now 101)))
    (is (not (documentation-dwell-due-p state 30 "A" :now 1000000)))
    (is (not (documentation-dwell-due-p state 31 "B" :now 1000000)))
    (is (equal '(:wb-doc-dwell :generation 31 :candidate-id "A")
               (consume-documentation-dwell state 31 "A" :now 1000000)))
    (is (null (consume-documentation-dwell state 31 "A" :now 1000000)))
    (schedule-documentation-dwell state "B" 32 :now 100 :delay-ms 0)
    (cancel-documentation-dwell state)
    (is (not (documentation-dwell-due-p state 32 "B" :now 1000000)))))

(test selected-function-signature
  (let ((signature (signature-for 'cl:mapcar)))
    (is (stringp signature))
    (is (search "MAPCAR" signature))
    (is (search "FUNCTION" signature))))

(test passive-reader-does-not-intern
  (let* ((package (find-package "ELMTUI.WORKBENCH.COMPLETION.TESTS"))
         (name "WB03-DISPATCH-SENTINEL")
         (source "(#.(intern \"WB03-DISPATCH-SENTINEL\" \"ELMTUI.WORKBENCH.COMPLETION.TESTS\") mapc"))
    (is (null (nth-value 1 (find-symbol name package))))
    (complete-at nil source (length source) 27)
    (is (null (nth-value 1 (find-symbol name package))))))

(test visibility-respects-package-separator
  (let* ((package (make-package "WB03-VISIBILITY" :use nil))
         (private (intern "INTERNAL-ONLY" package))
         (public (intern "PUBLIC-NAME" package)))
    (unwind-protect
         (progn
           (export public package)
           (let* ((single "(wb03-visibility:in")
                  (double "(wb03-visibility::in")
                  (single-result (complete-at nil single (length single) 28))
                  (double-result (complete-at nil double (length double) 29)))
             (is (null (find private (completion-result-candidates single-result)
                             :key #'completion-candidate-symbol)))
             (is (find private (completion-result-candidates double-result)
                       :key #'completion-candidate-symbol))))
      (delete-package package))))

(test zero-arity-signature
  (setf (fdefinition 'wb03-noargs) (lambda () :ready))
  (unwind-protect
       (is (string= "(WB03-NOARGS)" (signature-for 'wb03-noargs)))
    (fmakunbound 'wb03-noargs)))

(test exact-prefix-ranks-first
  (let* ((package (make-package "WB03-RANKING" :use nil))
         (exact (intern "FOO" package))
         (longer (intern "FOOBAR" package)))
    (declare (ignore longer))
    (unwind-protect
         (let ((candidates (completion-result-candidates
                            (complete-at package "foo" 3 33))))
           (is (eq exact (completion-candidate-symbol (first candidates)))))
      (delete-package package))))

(test comment-termination-restores-code
  (let* ((source (format nil "; ignored~%(mapc"))
         (result (complete-at nil source (length source) 34))
         (candidate (find "MAPCAR" (completion-result-candidates result)
                          :test #'string= :key #'completion-candidate-display)))
    (is (eq :code (completion-result-context result)))
    (is (string= "MAPCAR" (completion-candidate-insertion candidate)))))

(test configurable-completion-keybindings
  (let ((default
          (elmtui.workbench.completion:make-completion-keybinding-config))
        (emacs
          (elmtui.workbench.completion:make-completion-keybinding-config
           :profile :emacs)))
    (is (eq :open
            (elmtui.workbench.completion:completion-command-for-key
             default "ctrl+space")))
    (is (eq :accept
            (elmtui.workbench.completion:completion-command-for-key
             default "TAB")))
    (is (eq :next
            (elmtui.workbench.completion:completion-command-for-key
             emacs "c-n")))
    (is (eq :dismiss
            (elmtui.workbench.completion:completion-command-for-key
             emacs "C-G")))
    (elmtui.workbench.completion:set-completion-keybinding
     default "Enter" nil)
    (is (null
         (elmtui.workbench.completion:completion-command-for-key
          default "enter")))
    (elmtui.workbench.completion:set-completion-keybinding
     default "C-J" :accept)
    (is (eq :accept
            (elmtui.workbench.completion:completion-command-for-key
             default "c-j")))
    (signals error
      (elmtui.workbench.completion:set-completion-keybinding
       default "X" :not-an-action))))

(test completion-keybinding-constructor-overrides-profile
  (let ((config
          (elmtui.workbench.completion:make-completion-keybinding-config
           :profile :default
           :overrides '(("Tab" . :next) ("F3")))))
    (is (member :default
                (elmtui.workbench.completion:completion-keybinding-profile-names)))
    (is (member :emacs
                (elmtui.workbench.completion:completion-keybinding-profile-names)))
    (is (eq :next
            (elmtui.workbench.completion:completion-command-for-key
             config "tab")))
    (is (null
         (elmtui.workbench.completion:completion-command-for-key
          config "f3")))))

(test completion-presentation-carries-style-roles
  (let ((package (make-package "WB03-PRESENTATION" :use nil)))
    (unwind-protect
         (progn
           (intern "FOO" package)
           (intern "FOOBAR" package)
           (let* ((result
                    (elmtui.workbench.completion:complete-at
                     package "foo" 3 91))
                  (theme
                    (elmtui.workbench.completion:make-completion-theme))
                  (rows
                    (elmtui.workbench.completion:completion-present-candidates
                     result :selected-index 1 :theme theme))
                  (first (first rows))
                  (second (second rows)))
             (is (= 2 (length rows)))
             (is (eq :normal (getf first :style-role)))
             (is (eq :selected (getf second :style-role)))
             (is (eq :cyan (getf (getf second :style) :bg-color)))
             (is (eq :black (getf (getf second :style) :fg-color)))
             (is (string= "WB03-PRESENTATION" (getf second :package)))))
      (delete-package package))))
