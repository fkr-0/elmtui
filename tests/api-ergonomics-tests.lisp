;;;; API Ergonomics Tests
;;;; Tests for convenience constructors, default quit handling, and viewport defaults.

(uiop:define-package :elmtui.tests.api-ergonomics
  (:use :cl :fiveam)
  (:import-from :elmtui.state.api
                #:make-update-result #:update-result
                #:ur-patches #:ur-commands
                #:patch #:patch* #:quit-result)
  (:import-from :elmtui.core.event-types
                #:make-key-event #:key-event-p
                #:key-event-parts)
  (:export #:api-ergonomics-tests))

(in-package :elmtui.tests.api-ergonomics)

(def-suite api-ergonomics-tests
  :in elmtui.tests:elmtui-test
  :description "Tests for API ergonomics: patch, patch*, quit-result, key-event-parts, cmd-async export")

(in-suite api-ergonomics-tests)

;;; ===================================================================
;;; Unit tests for PATCH
;;; ===================================================================

(test patch-zero-keys
  "PATCH with no arguments returns an empty update-result."
  (let ((ur (patch)))
    (is (typep ur 'update-result))
    (is (null (ur-patches ur)))
    (is (null (ur-commands ur)))))

(test patch-one-key
  "PATCH with one key-value pair."
  (let ((ur (patch :count 42)))
    (is (typep ur 'update-result))
    (is (equal '(((:count) 42)) (ur-patches ur)))
    (is (null (ur-commands ur)))))

(test patch-two-keys
  "PATCH with two key-value pairs."
  (let ((ur (patch :count 42 :name "hello")))
    (is (typep ur 'update-result))
    (is (equal '(((:count) 42) ((:name) "hello")) (ur-patches ur)))
    (is (null (ur-commands ur)))))

(test patch-three-keys
  "PATCH with three key-value pairs."
  (let ((ur (patch :a 1 :b 2 :c 3)))
    (is (typep ur 'update-result))
    (is (= 3 (length (ur-patches ur))))
    (is (equal '(((:a) 1) ((:b) 2) ((:c) 3)) (ur-patches ur)))))

;;; ===================================================================
;;; Unit tests for PATCH*
;;; ===================================================================

(test patch*-with-keys-and-commands
  "PATCH* with key-value pairs and commands."
  (let ((ur (patch* '(:x 10 :y 20) :commands '((:print "moved")))))
    (is (typep ur 'update-result))
    (is (equal '(((:x) 10) ((:y) 20)) (ur-patches ur)))
    (is (equal '((:print "moved")) (ur-commands ur)))))

(test patch*-with-keys-only
  "PATCH* with key-value pairs and no commands."
  (let ((ur (patch* '(:x 10))))
    (is (typep ur 'update-result))
    (is (equal '(((:x) 10)) (ur-patches ur)))
    (is (null (ur-commands ur)))))

(test patch*-empty
  "PATCH* with empty plist."
  (let ((ur (patch* '())))
    (is (typep ur 'update-result))
    (is (null (ur-patches ur)))))

;;; ===================================================================
;;; Unit tests for QUIT-RESULT
;;; ===================================================================

(test quit-result-patches
  "QUIT-RESULT returns the correct :should-quit patch."
  (let ((ur (quit-result)))
    (is (typep ur 'update-result))
    (is (equal '(((:should-quit) t)) (ur-patches ur)))
    (is (null (ur-commands ur)))))

;;; ===================================================================
;;; Unit tests for KEY-EVENT-PARTS
;;; ===================================================================

(test key-event-parts-struct
  "KEY-EVENT-PARTS extracts from a key-event struct."
  (let ((event (make-key-event :type :key-down :key :enter :char #\Return
                               :modifiers '(:ctrl))))
    (multiple-value-bind (key char mods) (key-event-parts event)
      (is (eq :enter key))
      (is (eql #\Return char))
      (is (equal '(:ctrl) mods)))))

(test key-event-parts-legacy-plist
  "KEY-EVENT-PARTS extracts from a legacy (:keyevent ...) plist."
  (let ((msg '(:keyevent :key :space :char #\Space :modifiers nil)))
    (multiple-value-bind (key char mods) (key-event-parts msg)
      (is (eq :space key))
      (is (eql #\Space char))
      (is (null mods)))))

(test key-event-parts-non-key-message
  "KEY-EVENT-PARTS returns nil nil nil for non-key messages."
  (multiple-value-bind (key char mods) (key-event-parts '(:app-quit-requested))
    (is (null key))
    (is (null char))
    (is (null mods)))
  (multiple-value-bind (key char mods) (key-event-parts "hello")
    (is (null key))
    (is (null char))
    (is (null mods)))
  (multiple-value-bind (key char mods) (key-event-parts 42)
    (is (null key))
    (is (null char))
    (is (null mods))))

;;; ===================================================================
;;; CMD-ASYNC facade export test
;;; ===================================================================

(test cmd-async-exported-from-facade
  "CMD-ASYNC is accessible from the ELMTUI facade package."
  (is (not (null (find-symbol "CMD-ASYNC" :elmtui))))
  (is (fboundp (find-symbol "CMD-ASYNC" :elmtui))))

;;; ===================================================================
;;; Facade export completeness
;;; ===================================================================

(test new-symbols-exported-from-facade
  "All new convenience symbols are exported from the ELMTUI facade."
  (dolist (name '("PATCH" "PATCH*" "QUIT-RESULT" "KEY-EVENT-PARTS" "CMD-ASYNC"))
    (let ((sym (find-symbol name :elmtui)))
      (is (not (null sym))
          "~A should be found in ELMTUI" name)
      (when sym
        (is (eq :external (nth-value 1 (find-symbol name :elmtui)))
            "~A should be external in ELMTUI" name)))))

;;; ===================================================================
;;; Integration tests for default quit handling
;;; ===================================================================

(test defapplication-default-quit-handling
  "DEFAPPLICATION with default :handle-quit t intercepts :app-quit-requested."
  ;; The defapplication macro generates a PROCESS-MESSAGE function that,
  ;; when :handle-quit is true, returns quit patches for :app-quit-requested
  ;; without calling the user's update function.
  (let ((user-called nil))
    ;; Define a test update that records whether it was called
    (defun %test-quit-update (msg state)
      (declare (ignore msg state))
      (setf user-called t)
      (make-update-result))
    (defun %test-quit-view (state)
      (declare (ignore state))
      '(:text :content "test"))
    ;; Expand defapplication and check the generated PROCESS-MESSAGE
    ;; handles quit automatically by checking for the quit-requested-p clause
    ;; in the macro expansion.
    (let* ((expansion (macroexpand-1
                        '(elmtui.app:defapplication %test-quit-app
                           :root-viewport-id :test-root
                           :root-component-dsl '(:root-viewport :id :test-root
                                                  :child-dsl-spec (:view nil))
                           :update-fn '%test-quit-update
                           :view-fn '%test-quit-view
                           :handle-quit t)))
           (expansion-string (prin1-to-string expansion)))
      ;; The expansion should contain quit-requested-p for auto handling
      (is (search "QUIT-REQUESTED-P" expansion-string)
          "Expansion with :handle-quit t should contain QUIT-REQUESTED-P check"))))

(test defapplication-no-quit-handling
  "DEFAPPLICATION with :handle-quit nil omits the quit interception clause."
  (let* ((expansion (macroexpand-1
                      '(elmtui.app:defapplication %test-no-quit-app
                         :root-viewport-id :test-root
                         :root-component-dsl '(:root-viewport :id :test-root
                                                :child-dsl-spec (:view nil))
                         :update-fn '%test-no-quit-update
                         :view-fn '%test-no-quit-view
                         :handle-quit nil)))
         (expansion-string (prin1-to-string expansion)))
    ;; The expansion should NOT contain the automatic quit handling clause
    ;; (the QUIT-REQUESTED-P check should not appear in the process-message cond)
    ;; We check the process function body does not have the quit clause
    (is (not (search "QUIT-RESULT" expansion-string))
        "Expansion with :handle-quit nil should not contain QUIT-RESULT call")))

;;; ===================================================================
;;; Integration tests for root-viewport defaults
;;; ===================================================================

(test defapplication-viewport-defaults-no-dsl
  "DEFAPPLICATION generates viewport DSL when :root-component-dsl is omitted."
  (let* ((expansion (macroexpand-1
                      '(elmtui.app:defapplication %test-vp-defaults-app
                         :root-viewport-id :test-vp
                         :anchor :below-cursor
                         :height 10
                         :update-fn '%test-vp-update
                         :view-fn '%test-vp-view)))
         (expansion-string (prin1-to-string expansion)))
    ;; The generated DSL should contain the root viewport with anchor and height
    (is (search "ROOT-VIEWPORT" expansion-string)
        "Generated DSL should include :ROOT-VIEWPORT")
    (is (search "BELOW-CURSOR" expansion-string)
        "Generated DSL should include the anchor value")
    (is (search ":HEIGHT 10" expansion-string)
        "Generated DSL should include :HEIGHT")))

(test defapplication-explicit-dsl-wins
  "DEFAPPLICATION uses explicit :root-component-dsl when provided, ignoring :anchor/:height."
  (let* ((expansion (macroexpand-1
                      '(elmtui.app:defapplication %test-explicit-dsl-app
                         :root-viewport-id :test-vp
                         :root-component-dsl '(:root-viewport :id :test-vp
                                                :anchor :top-left
                                                :child-dsl-spec (:view nil))
                         :anchor :below-cursor
                         :height 99
                         :update-fn '%test-explicit-dsl-update
                         :view-fn '%test-explicit-dsl-view)))
         (expansion-string (prin1-to-string expansion)))
    ;; Explicit DSL should win: should see TOP-LEFT (from DSL), not BELOW-CURSOR
    (is (search "TOP-LEFT" expansion-string)
        "Explicit DSL should preserve its own :anchor")))
