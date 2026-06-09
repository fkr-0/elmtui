(uiop:define-package :elmtui.tests.pong-example-smoke
  (:use :cl :fiveam)
  (:import-from :asdf #:load-system)
  (:import-from :elmtui.core.globals #:*applications*)
  (:import-from :elmtui.core.event-types #:make-key-event)
  (:import-from :elmtui.state.api #:update-result #:ur-patches)
  (:import-from :elmtui.app.api #:app-config-root-component-dsl)
  (:export #:pong-example-smoke-tests))

(in-package :elmtui.tests.pong-example-smoke)

(def-suite pong-example-smoke-tests
  :in elmtui.tests:elmtui-test
  :description "Smoke tests for the pong below-cursor example")

(in-suite pong-example-smoke-tests)

(defun %fn (pkg name)
  (symbol-function (find-symbol name (find-package pkg))))

(test pong-example-loads-and-registers-root-viewport
  (load-system :elmtui-examples)
  (let* ((pkg (find-package :elmtui.examples.pong-below-cursor))
         (app-sym (find-symbol "PONG-BELOW-CURSOR-APP" pkg))
         (cfg (gethash app-sym *applications*))
         (dsl (app-config-root-component-dsl cfg))
         (props (rest dsl)))
    (is (fboundp (find-symbol "RUN-PONG-BELOW-CURSOR" pkg)))
    (is (eq (first dsl) :root-viewport))
    (is (eql (getf props :anchor) :below-cursor))
    (is (= (getf props :height) 12))))

(test pong-example-update-view-quit-smoke
  (load-system :elmtui-examples)
  (let* ((init-fn (%fn :elmtui.examples.pong-below-cursor "%INITIAL-STATE"))
         (update-fn (%fn :elmtui.examples.pong-below-cursor "PONG-UPDATE"))
         (view-fn (%fn :elmtui.examples.pong-below-cursor "PONG-VIEW"))
         (state (funcall init-fn))
         (tick-result (funcall update-fn '(:tick) state))
         (quit-result (funcall update-fn (make-key-event :key #\q) state))
         (view (funcall view-fn state))
         (quit-patches (ur-patches quit-result)))
    (is (listp state))
    (is (typep tick-result 'update-result))
    (is (typep quit-result 'update-result))
    (is (listp view))
    (is (find-if (lambda (patch)
                   (and (consp patch)
                        (equal (first patch) '(:should-quit))
                        (eql (second patch) t)))
          quit-patches))))
