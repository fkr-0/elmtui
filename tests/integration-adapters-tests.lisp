(uiop:define-package :elmtui.tests.integration-adapters
  (:use :cl :fiveam)
  (:import-from :cl-events.types
                #:make-message)
  (:import-from :elmtui.core.conditions
                #:message-validation-error)
  (:import-from :elmtui.core.events
                #:validate-message)
  (:import-from :elmtui.state.msg
                #:defmsg
                #:make-setvalue-adaptertestmsg)
  (:import-from :cl-inputs.tokens
                #:make-token)
  (:import-from :elmtui.platform.input
                #:cl-inputs-token->event)
  (:import-from :elmtui.core.event-types
                #:key-event-p
                #:key-event-char)
  (:import-from :elmtui.core.event-channels
                #:make-message-channel)
  (:import-from :cl-styles.sheet
                #:make-stylesheet
                #:stylesheet-variables)
  (:import-from :elmtui.style.manager
                #:compute-active-stylesheet)
  (:import-from :cl-state.core
                #:make-state
                #:state-ref
                #:application-state-observers)
  (:import-from :elmtui.view.reactive
                #:create-reactive-view
                #:register-view-dependency
                #:cleanup-reactive-view
                #:view-invalidated-p))

(in-package :elmtui.tests.integration-adapters)

(def-suite integration-adapters-tests
  :in elmtui.tests:elmtui-test)
(in-suite integration-adapters-tests)

(defmsg AdapterTestMsg (:docstring "Schema validation bridge tests")
  Ping
  (SetValue :value integer))

(test cl-events-message-validates-via-defmsg-schema
  (let ((msg (make-message :type 'AdapterTestMsg
                           :data (make-setvalue-adaptertestmsg :value 7))))
    (is-true (validate-message msg))))

(test cl-events-message-schema-failure-signals-condition
  (let ((msg (make-message :type 'AdapterTestMsg
                           :data '(:setvalue :value "bad"))))
    (signals message-validation-error
      (validate-message msg))))

(test cl-inputs-token-adapter-produces-key-event
  (let* ((token (make-token :key '(:code 97 :mods (:ctrl) :char #\a :type :key-down)))
         (evt (cl-inputs-token->event token)))
    (is-true (key-event-p evt))
    (is (char= #\a (key-event-char evt)))))

(test cl-inputs-unsupported-token-kind-returns-nil
  (let* ((token (make-token :paste '(:text "hello")))
         (evt (cl-inputs-token->event token)))
    (is-false evt)))

(test style-manager-overlays-style-variables
  (let* ((sheet (make-stylesheet :rules nil
                                 :variables '(("--accent" . :blue))
                                 :namespace nil))
         (computed (compute-active-stylesheet `(:current-stylesheet ,sheet
                                                :style-variables (("--accent" . :orange)
                                                                  ("--gap" . 1))))))
    (is (equal '(("--accent" . :orange)
                 ("--gap" . 1))
               (stylesheet-variables computed)))))

(test message-schema-registry-shared-between-state-and-core-globals
  (is (eq elmtui.state.msg::*message-schemas*
          elmtui.core.globals:*message-schemas*)))

(test validate-message-does-not-write-to-standard-output
  (let* ((msg (make-message :type 'AdapterTestMsg
                            :data (make-setvalue-adaptertestmsg :value 3)))
         (result nil)
         (out (with-output-to-string (s)
                (let ((*standard-output* s))
                  (setf result (validate-message msg))))))
    (is-true result)
    (is (string= "" out))))

(test process-channel-event-ignores-malformed-event-shapes
  (let ((channel (make-message-channel))
        (ok t))
    (handler-case
        (elmtui.core.loop::process-channel-event nil channel)
      (error ()
        (setf ok nil)))
    (is-true ok)))

(test reactive-view-registers-and-cleans-observers-with-cl-state
  (let* ((state (make-state :initial '(:count 0) :backend :plist))
         (view (create-reactive-view :integration-view state
                                     (lambda (_state _dispatch)
                                       (declare (ignore _state _dispatch))
                                       nil))))
    (setf (view-invalidated-p view) nil)
    (register-view-dependency view :count)
    (is (= 1 (length (application-state-observers state))))
    (setf (state-ref state :count) 1)
    (is-true (view-invalidated-p view))
    (cleanup-reactive-view view)
    (is-false (application-state-observers state))))

(test reactive-view-cleanup-prevents-future-invalidation
  (let* ((state (make-state :initial '(:count 0) :backend :plist))
         (view (create-reactive-view :integration-view-cleanup state
                                     (lambda (_state _dispatch)
                                       (declare (ignore _state _dispatch))
                                       nil))))
    (register-view-dependency view :count)
    (cleanup-reactive-view view)
    (setf (view-invalidated-p view) nil)
    (setf (state-ref state :count) 2)
    (is-false (view-invalidated-p view))
    (is-false (application-state-observers state))))
