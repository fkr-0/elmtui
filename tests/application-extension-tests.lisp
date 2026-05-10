(uiop:define-package :elmtui.tests.application-extension
  (:use :cl :fiveam)
  (:import-from :uiop
                #:getenv)
  (:import-from :elmtui.app.extension
                #:parse-cli-options
                #:normalize-simple-args-specs
                #:merge-cli-option-specs)
  (:import-from :elmtui.app
                #:defapplication)
  (:import-from :elmtui.core.globals
                #:*applications*)
  (:import-from :elmtui.app.api
                #:app-config-cli-options
                #:app-config-binary-options
                #:app-config-configure-fn)
  (:import-from :elmtui.state
                #:get-path))

(in-package :elmtui.tests.application-extension)

(def-suite application-extension-tests
  :in elmtui.tests:elmtui-test)
(in-suite application-extension-tests)

(test parse-cli-options-coerces-types-and-overrides-defaults
  (let* ((specs '((:name :fps :long "--fps" :type integer :default 30)
                  (:name :backend :long "--backend" :type keyword :default :tty)
                  (:name :debug :long "--debug" :type boolean :default nil)))
         (parsed (parse-cli-options specs '("--fps" "55" "--debug"))))
    (is (= 55 (getf parsed :fps)))
    (is (eq :tty (getf parsed :backend)))
    (is-true (getf parsed :debug))))

(test parse-cli-options-boolean-explicit-value-form
  (let* ((specs '((:name :debug :long "--debug" :type boolean :default t)))
         (parsed (parse-cli-options specs '("--debug" "false"))))
    (is-false (getf parsed :debug))))

(test parse-cli-options-precedence-cli-over-env-over-default
  (let* ((specs '((:name :fps :long "--fps" :type integer :default 30 :env "ELMTUI_TEST_FPS")))
         (old (getenv "ELMTUI_TEST_FPS")))
    (unwind-protect
         (progn
           #+sbcl (sb-posix:setenv "ELMTUI_TEST_FPS" "77" 1)
           (is (= 77 (getf (parse-cli-options specs nil) :fps)))
           (is (= 120 (getf (parse-cli-options specs '("--fps" "120")) :fps))))
      (if old
          #+sbcl (sb-posix:setenv "ELMTUI_TEST_FPS" old 1)
          #+sbcl (ignore-errors (sb-posix:unsetenv "ELMTUI_TEST_FPS"))
          #-sbcl nil))))

(test normalize-simple-args-specs-produces-validated-cli-specs
  (let* ((args '((:name :fps :long "--fps" :type integer :default 60 :doc "FPS")
                 (:name :debug :long "--debug" :short "-d" :type boolean :default nil)))
         (specs (normalize-simple-args-specs args)))
    (is (= 2 (length specs)))
    (is (eq :fps (getf (first specs) :name)))
    (is (string= "--fps" (getf (first specs) :long)))
    (is (eq 'integer (getf (first specs) :type)))
    (is (= 60 (getf (first specs) :default)))
    (is-false (getf (first specs) :platform-option))))

(test merge-cli-option-specs-signals-on-duplicate-identifiers
  (signals error
    (merge-cli-option-specs
     '((:name :fps :long "--fps" :type integer))
     '((:name :fps2 :long "--fps" :type integer)))))

(defapplication extension-test-app
  :root-component-dsl '(:layout :id :main)
  :root-viewport-id :ext-root
  :binary t
  :cli-options '((:name :fps :long "--fps" :type integer :default 60))
  :configure-fn identity)

(test defapplication-registers-extension-config
  (let ((cfg (gethash 'extension-test-app *applications*)))
    (is (equal '((:name :fps :long "--fps" :type integer :default 60))
               (app-config-cli-options cfg)))
    (is (getf (app-config-binary-options cfg) :enabled))
    (is (eq 'identity (app-config-configure-fn cfg)))))

(defapplication extension-test-app-args
  :root-component-dsl '(:layout :id :main)
  :root-viewport-id :ext-root-args
  :args '((:name :fps :long "--fps" :type integer :default 60 :doc "Frame rate")
          (:name :debug :long "--debug" :type boolean :default nil)))

(test defapplication-registers-args-specs-as-cli-options
  (let* ((cfg (gethash 'extension-test-app-args *applications*))
         (specs (app-config-cli-options cfg))
         (fps-spec (first specs))
         (dbg-spec (second specs)))
    (is (= 2 (length specs)))
    (is (eq :fps (getf fps-spec :name)))
    (is (string= "--fps" (getf fps-spec :long)))
    (is (eq 'integer (getf fps-spec :type)))
    (is-false (getf fps-spec :platform-option))
    (is (eq :debug (getf dbg-spec :name)))
    (is (string= "--debug" (getf dbg-spec :long)))))

(test init-receives-cli-args-and-exposes-them-under-cli-state
  (multiple-value-bind (state commands)
      (initialize-app-state-extension-test-app-args :cli-args '(:fps 144 :debug t))
    (declare (ignore commands))
    (is (= 144 (get-path '(:cli :fps) state)))
    (is-true (get-path '(:cli :debug) state))))
