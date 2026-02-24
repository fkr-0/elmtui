(uiop:define-package :elmtui.tests.application-extension
  (:use :cl :fiveam)
  (:import-from :elmtui.app.extension
                #:parse-cli-options)
  (:import-from :elmtui.app
                #:defapplication)
  (:import-from :elmtui.core.globals
                #:*applications*)
  (:import-from :elmtui.app.api
                #:app-config-cli-options
                #:app-config-binary-options
                #:app-config-configure-fn))

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
