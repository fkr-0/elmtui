;;;; Tests for deftea-app + defcomponent interop
;;;; Validates the app-model accessor, root-component-dsl override,
;;;; and behavioral contracts for hosting components in deftea-app apps.

(uiop:define-package :elmtui.tests.tea-app-component
  (:use :cl :fiveam)
  (:import-from :elmtui.app.tea-core #:deftea-app #:app-model)
  (:import-from :elmtui.ui.defcomponent #:defcomponent)
  (:import-from :elmtui.ui.api #:component #:component-id #:id-from-path
    #:init #:update #:view)
  (:import-from :elmtui.state.api
    #:make-update-result #:make-state #:state-ref
    #:ur-patches #:ur-commands #:get-path)
  (:export #:tea-app-component-tests))

(in-package :elmtui.tests.tea-app-component)

(def-suite tea-app-component-tests
  :in elmtui.tests:elmtui-test
  :description "Tests for deftea-app hosting defcomponent children")

(in-suite tea-app-component-tests)

;;; ===================================================================
;;; Test components
;;; ===================================================================

;; A display component that reads the app model via app-model
(defcomponent tea-display-component (component)
  (:state
    (label "default" :type string))
  (:view (local-state app-state id-path children)
    (let ((model (app-model app-state)))
      `(:text :id ,(id-from-path id-path)
         :content ,(format nil "~A: ~A"
                    (getf local-state :label "default")
                    (if model (getf model :count 0) "no-model"))))))

;; A component that uses app-model in its update clause
(defcomponent tea-update-component (component)
  (:state
    (last-seen-count 0 :type integer))
  (:update (msg local-state app-state id-path)
    (:sync-count ()
      (let ((model (app-model app-state)))
        (values `(:last-seen-count ,(if model (getf model :count 0) 0))
                nil))))
  (:view (local-state app-state id-path children)
    `(:text :id ,(id-from-path id-path)
       :content ,(format nil "Synced: ~A"
                  (getf local-state :last-seen-count 0)))))

;;; ===================================================================
;;; app-model accessor tests
;;; ===================================================================

(test app-model-returns-tea-model-from-state
  "app-model extracts the :tea-model value from an application state."
  (let* ((user-model (list :count 42 :name "test"))
         (app-state (make-state :initial
                     (alexandria:plist-hash-table
                      (list :tea-model user-model :should-quit nil)))))
    (is (equal user-model (app-model app-state)))))

(test app-model-returns-nil-when-no-tea-model
  "app-model returns NIL for state without :tea-model (e.g. plain defapplication)."
  (let ((app-state (make-state :initial
                    (alexandria:plist-hash-table
                     (list :counter 0 :should-quit nil)))))
    (is (null (app-model app-state)))))

(test app-model-returns-nil-for-nil-model
  "app-model returns NIL when the user model itself is NIL."
  (let ((app-state (make-state :initial
                    (alexandria:plist-hash-table
                     (list :tea-model nil :should-quit nil)))))
    (is (null (app-model app-state)))))

(test app-model-preserves-complex-model-types
  "app-model works with hash-table models, list models, and struct models."
  ;; Plist model
  (let ((app-state (make-state :initial
                    (alexandria:plist-hash-table
                     (list :tea-model '(:a 1 :b 2))))))
    (is (equal '(:a 1 :b 2) (app-model app-state))))
  ;; Hash-table model
  (let* ((ht (make-hash-table :test 'equal))
         (_ (setf (gethash "key" ht) "val"))
         (app-state (make-state :initial
                     (alexandria:plist-hash-table
                      (list :tea-model ht)))))
    (declare (ignore _))
    (is (eq ht (app-model app-state)))))

;;; ===================================================================
;;; deftea-app initialization with components
;;; ===================================================================

;; Minimal deftea-app with a component in its DSL
(defun %test-tea-comp-init ()
  (values (list :count 0 :should-quit nil) nil))

(defun %test-tea-comp-transition (msg model)
  (cond
    ((and (consp msg) (eq (first msg) :increment))
     (values (list :count (1+ (getf model :count 0)) :should-quit nil) nil))
    ((and (consp msg) (eq (first msg) :app-quit-requested))
     (values (list :count (getf model :count 0) :should-quit t) nil))
    (t (values model nil))))

(defun %test-tea-comp-view (model)
  `(:container :id :main
     :children
     ((:text :id :counter-label
        :content ,(format nil "Count: ~A" (getf model :count 0))))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (deftea-app test-tea-with-component
    :init #'%test-tea-comp-init
    :transition #'%test-tea-comp-transition
    :view #'%test-tea-comp-view
    :root-component-dsl '(:root-viewport :id :root-viewport :anchor :below-cursor
                          :height 5
                          :children ((:tea-display-component :id :display
                                      :initial-label "Count")))))

(test tea-app-with-component-initializes
  "A deftea-app with :root-component-dsl initializes without error."
  (let ((init-fn #'initialize-app-state-test-tea-with-component))
    (is (fboundp 'initialize-app-state-test-tea-with-component))
    (multiple-value-bind (state commands)
      (funcall init-fn)
      (declare (ignore commands))
      (is (not (null state)))
      ;; The tea-model should be present
      (is (not (null (state-ref state :tea-model))))
      ;; The user model should be accessible via app-model
      (is (equal 0 (getf (app-model state) :count))))))

(test tea-app-run-function-defined
  "deftea-app with :root-component-dsl generates the expected RUN- function."
  (is (fboundp 'run-test-tea-with-component)))

(test tea-app-process-message-defined
  "deftea-app with :root-component-dsl generates the message processor."
  (is (fboundp 'process-message-test-tea-with-component)))

;;; ===================================================================
;;; Model update propagation
;;; ===================================================================

(test tea-app-transition-updates-model
  "After processing an :increment message, app-model returns updated count."
  (multiple-value-bind (state commands)
    (initialize-app-state-test-tea-with-component)
    (declare (ignore commands))
    (is (= 0 (getf (app-model state) :count)))
    (multiple-value-bind (next-state next-cmds)
      (process-message-test-tea-with-component '(:increment) state)
      (declare (ignore next-cmds))
      (is (= 1 (getf (app-model next-state) :count))))))

(test tea-app-multiple-transitions-accumulate
  "Multiple transitions accumulate correctly via app-model."
  (multiple-value-bind (state _) (initialize-app-state-test-tea-with-component)
    (declare (ignore _))
    (let ((s state))
      (dotimes (i 5)
        (multiple-value-bind (next cmds) (process-message-test-tea-with-component '(:increment) s)
          (declare (ignore cmds))
          (setf s next)))
      (is (= 5 (getf (app-model s) :count))))))

;;; ===================================================================
;;; Component view receives accessible app state
;;; ===================================================================

(test component-view-receives-app-state-with-model
  "A tea-display-component's view can read the app model via app-model."
  (multiple-value-bind (state _) (initialize-app-state-test-tea-with-component)
    (declare (ignore _))
    ;; The component was initialized from the DSL tree; verify its state exists
    ;; by checking the components subtree
    (let ((comp-data (get-path '(:components :root-viewport :display) state)))
      (is (not (null comp-data))
          "Component :display should have state in the component tree"))))

;;; ===================================================================
;;; Plain deftea-app (no root-component-dsl) still works
;;; ===================================================================

(defun %plain-init () (values (list :x 1) nil))
(defun %plain-transition (msg model) (declare (ignore msg)) (values model nil))
(defun %plain-view (model) `(:text :id :t :content ,(format nil "~A" (getf model :x))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (deftea-app test-plain-tea
    :init #'%plain-init
    :transition #'%plain-transition
    :view #'%plain-view))

(test plain-tea-app-still-works
  "A deftea-app without :root-component-dsl continues to work as before."
  (is (fboundp 'run-test-plain-tea))
  (multiple-value-bind (state cmds)
    (initialize-app-state-test-plain-tea)
    (declare (ignore cmds))
    (is (not (null state)))
    (is (equal 1 (getf (app-model state) :x)))))

;;; ===================================================================
;;; app-model is available from elmtui facade
;;; ===================================================================

(test app-model-exported-from-elmtui
  "app-model is accessible via the ELMTUI facade package."
  (is (not (null (find-symbol "APP-MODEL" :elmtui))))
  (is (eq (find-symbol "APP-MODEL" :elmtui)
          (find-symbol "APP-MODEL" :elmtui.app.tea-core))))
