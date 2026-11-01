(defpackage #:elmtui.workbench.e3.tests
  (:use #:cl #:fiveam))
(in-package #:elmtui.workbench.e3.tests)

(def-suite e3-release-suite :description "E3 Workbench release UI and state regressions")
(in-suite e3-release-suite)

(defun dsl-texts (tree)
  (if (and (consp tree) (keywordp (first tree)))
      (if (eq (first tree) :text)
          (list (getf (rest tree) :content))
          (mapcan #'dsl-texts (getf (rest tree) :children)))
      nil))

(test selected-inspector-row-is-visible-in-short-viewport
  (let* ((snapshot (list :entries (loop for i below 30
                                        collect (list :name (format nil "ROW~2,'0D" i)))))
         (pane (elmtui.workbench.view::%inspector-pane
                40 4 snapshot :packages 18 "" nil
                (elmtui.workbench.inspector:make-inspector-theme)))
         (texts (dsl-texts pane)))
    (is (= 4 (length texts)))
    (is (some (lambda (x) (search "ROW18" x)) texts))
    (is (not (some (lambda (x) (search "ROW00" x)) texts)))
    (is (some (lambda (x) (search "> " x)) texts))))

(test completion-presentation-follows-selected-row
  (let* ((result (elmtui.workbench.completion:complete-at
                  (find-package :cl-user) "(c" 2 1))
         (candidates (elmtui.workbench.completion:completion-result-candidates result)))
    (is (>= (length candidates) 8))
    (when (>= (length candidates) 8)
      (let* ((name (elmtui.workbench.completion:completion-candidate-display
                    (nth 7 candidates)))
             (pane (elmtui.workbench.view::%completion-pane
                    40 result 7 nil
                    (elmtui.workbench.completion:make-completion-theme)))
             (texts (dsl-texts pane)))
        (is (some (lambda (x) (search (concatenate 'string "> " name) x))
                  texts))))))

(test short-completion-viewport-always-paints-selected-item
  (let* ((result (elmtui.workbench.completion:complete-at
                  (find-package :cl-user) "(c" 2 1))
         (candidates (elmtui.workbench.completion:completion-result-candidates result))
         (selected (1- (length candidates)))
         (name (elmtui.workbench.completion:completion-candidate-display
                (nth selected candidates))))
    (is (> (length candidates) 8))
    (dolist (geometry '((40 12) (24 8)))
      (destructuring-bind (width height) geometry
        (let* ((tree (elmtui.workbench.view:frame-view
                       :width width :height height :source "(c"
                       :completion result :selected selected))
               (texts (dsl-texts tree))
               (marker (concatenate 'string "> " name)))
          (is (some (lambda (item) (search marker item)) texts))
          (when (= height 8)
            (is (not (member "[ COMPLETION ]" texts :test #'string=)))))))))

(test inspector-navigation-crosses-snapshot-pages
  (let* ((wb (getf (elmtui.workbench.app::%workbench-initial) :workbench))
         (entries (elmtui.workbench.app::%inspector-entries wb)))
    (is (getf (elmtui.workbench.app::workbench-inspector-snapshot wb) :has-more))
    (when (getf (elmtui.workbench.app::workbench-inspector-snapshot wb) :has-more)
      (loop repeat (length entries)
            do (elmtui.workbench.app::%move-inspector-selection wb 1))
      (is (= 1 (elmtui.workbench.app::workbench-inspector-page wb)))
      (is (= 0 (elmtui.workbench.app::workbench-inspector-selected wb)))
      (is (plusp (length (elmtui.workbench.app::%inspector-entries wb))))
      (elmtui.workbench.app::%move-inspector-selection wb -1)
      (is (= 0 (elmtui.workbench.app::workbench-inspector-page wb)))
      (is (= (1- (length entries))
             (elmtui.workbench.app::workbench-inspector-selected wb)))
      (elmtui.workbench.app::%handle-inspector-key wb #\/)
      (is (= 0 (elmtui.workbench.app::workbench-inspector-page wb)))
      (is (= 0 (elmtui.workbench.app::workbench-inspector-selected wb))))))

(test tiny-resize-preserves-editor-and-reported-geometry
  (let* ((state (elmtui.workbench.app::%workbench-initial))
         (wb (getf state :workbench))
         (ed (elmtui.workbench.app::workbench-editor wb)))
    (elmtui.workbench.editor:editor-insert-text ed "🇩🇪a")
    (elmtui.workbench.app:workbench-update
     '(:terminal-resized :width 12 :height 5) state)
    (is (= 12 (elmtui.workbench.app::workbench-width wb)))
    (is (= 5 (elmtui.workbench.app::workbench-height wb)))
    (is (= 8 (elmtui.workbench.editor:editor-state-columns ed)))
    (elmtui.workbench.app:workbench-update
     '(:terminal-resized :width 1 :height 1) state)
    (is (= 1 (elmtui.workbench.app::workbench-width wb)))
    (is (= 1 (elmtui.workbench.app::workbench-height wb)))
    (is (= 1 (elmtui.workbench.editor:editor-state-columns ed)))
    (is (string= "🇩🇪a" (elmtui.workbench.editor:editor-text ed)))
    (is (consp (elmtui.workbench.app:workbench-view state)))))

(test transcript-scroll-does-not-disappear-beyond-history
  (let ((wb (getf (elmtui.workbench.app::%workbench-initial) :workbench)))
    (setf (elmtui.workbench.app::workbench-transcript wb) '("three" "two" "one"))
    (loop repeat 10 do (elmtui.workbench.app::%handle-key wb :page-up))
    (is (= 2 (elmtui.workbench.app::workbench-scroll wb)))
    (elmtui.workbench.app::%handle-key wb :page-down)
    (is (= 0 (elmtui.workbench.app::workbench-scroll wb)))))

(test slynk-capability-is-explicitly-not-implemented
  (let ((report (elmtui.workbench.slynk:slynk-capability-report :request-id :e3)))
    (is (eq :disabled (getf report :transport)))
    (is (eq :not-implemented (getf report :remote-inspection)))
    (is (eq :e3 (getf report :request-id)))))
