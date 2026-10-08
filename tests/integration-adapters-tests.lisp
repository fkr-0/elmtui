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
                #:key-event-char
                #:key-event-key
                #:make-key-event)
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

(test cl-inputs-key-token-with-missing-code-produces-event-with-nil-code
  (let* ((token (make-token :key '(:mods (:alt) :char #\x :type :key-down)))
         (evt (cl-inputs-token->event token)))
    (is-true (key-event-p evt))
    (is (char= #\x (key-event-char evt)))))

(test input-reader-mapping-preserves-raw-key-events
  (let* ((evt (make-key-event :key :tab :char #\Tab :modifiers '(:shift)
                              :type :key-down :code 9))
         (mapped (elmtui.platform.input::%map-reader-event evt)))
    (is-true (key-event-p mapped))
    (is (eq :tab (key-event-key mapped))))
  t)

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

(test style-manager-falls-back-to-default-sheet-when-current-is-not-cl-styles
  (let ((computed (compute-active-stylesheet '(:current-stylesheet :not-a-sheet))))
    (is (null (stylesheet-variables computed)))))

(test style-manager-ignores-non-stylesheet-list-without-signaling
  (let ((ok t)
        (computed nil))
    (handler-case
        (setf computed (compute-active-stylesheet '(:current-stylesheet (:bogus :sheet))))
      (error ()
        (setf ok nil)))
    (is-true ok)
    (is (null (stylesheet-variables computed)))))

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

(test reactive-view-register-cleanup-repeated-does-not-leak-observers
  (let ((state (make-state :initial '(:count 0) :backend :plist)))
    (dotimes (_ 3)
      (let ((view (create-reactive-view :integration-view-loop state
                                        (lambda (_state _dispatch)
                                          (declare (ignore _state _dispatch))
                                          nil))))
        (register-view-dependency view :count)
        (cleanup-reactive-view view)))
    (is-false (application-state-observers state))))

(test core-loop-blocking-mailbox-delivers-event-and-stops-on-close
  "The runtime receives directly from its mailbox without periodic polling."
  (let* ((channel (make-message-channel :capacity 1))
         (elmtui.core.loop::*default-event-channel* channel)
         (elmtui.core.loop::*active-event-channels* (list channel))
         (elmtui.core.loop::*consumer-deferred-in* nil)
         (elmtui.core.loop::*consumer-deferred-out* nil))
    (unwind-protect
         (progn
           (multiple-value-bind (event origin)
               (elmtui.core.loop::%poll-runtime-event :timeout 0)
             (is-false event)
             (is-false origin))
           (is-true (cl-events.channel:chan-put
                     (elmtui.core.event-channels:channel-of channel) :key))
           (multiple-value-bind (event origin)
               (elmtui.core.loop::%poll-runtime-event)
             (is (eq :key event))
             (is (eq channel origin)))
           (cl-events.channel:chan-close
            (elmtui.core.event-channels:channel-of channel))
           (multiple-value-bind (event origin)
               (elmtui.core.loop::%poll-runtime-event)
             (is (eq :shutdown-loop event))
             (is (eq channel origin))))
      (cl-events.channel:chan-close
       (elmtui.core.event-channels:channel-of channel)))))

(test core-loop-bootstrap-selects-primary-channel-via-cl-events-policy
  (let ((select-called nil)
        (orig-select (symbol-function 'cl-events.loop:select-primary-channel))
        (orig-standard (symbol-function 'elmtui.core.event-channels:standard-event-channels)))
    (unwind-protect
         (progn
           (setf (symbol-function 'cl-events.loop:select-primary-channel)
                 (lambda (channels desired-name name-fn &key test)
                   (declare (ignore desired-name name-fn test))
                   (setf select-called t)
                   (first channels)))
           (setf (symbol-function 'elmtui.core.event-channels:standard-event-channels)
                 (lambda ()
                   (let ((ch (make-message-channel)))
                     (list (cons :message ch)))))
           (multiple-value-bind (primary active)
               (elmtui.core.loop::%bootstrap-single-mailbox-channels)
             (is-true select-called)
             (is-true primary)
             (is (= 1 (length active)))))
      (setf (symbol-function 'cl-events.loop:select-primary-channel) orig-select
            (symbol-function 'elmtui.core.event-channels:standard-event-channels) orig-standard))))

(test core-loop-consumer-error-policy-stop-sets-shutdown
  (let ((elmtui.core.loop::*shutdown-requested-flag* (elmtui.core.loop::make-shutdown-flag))
        (elmtui.core.loop::*consumer-error-policy* :stop))
    (is (eq :stop
            (elmtui.core.loop::%handle-consumer-poll-error
             (make-condition 'simple-error
                             :format-control "x"
                             :format-arguments nil))))
    (is-true elmtui.core.loop::*shutdown-requested*)))

(test core-loop-consumer-error-policy-restart-does-not-force-shutdown
  (let ((elmtui.core.loop::*shutdown-requested-flag* (elmtui.core.loop::make-shutdown-flag))
        (elmtui.core.loop::*consumer-error-policy* :restart))
    (is (eq :restart
            (elmtui.core.loop::%handle-consumer-poll-error
             (make-condition 'simple-error
                             :format-control "x"
                             :format-arguments nil))))
    (is-false elmtui.core.loop::*shutdown-requested*)))

(test core-loop-event-consumer-delegates-lifecycle-shell
  (let ((called nil)
        (callbacks-shape nil)
        (orig-shell (symbol-function 'cl-events.loop:run-consumer-loop-shell))
        (elmtui.core.loop::*shutdown-requested-flag* (elmtui.core.loop::make-shutdown-flag))
        (elmtui.core.loop::*active-event-channels* nil))
    (unwind-protect
         (progn
           (setf (symbol-function 'cl-events.loop:run-consumer-loop-shell)
                 (lambda (&key stop-p channels-fn on-idle step-fn on-restart)
                   (setf called t
                         callbacks-shape
                         (list (functionp stop-p)
                               (functionp channels-fn)
                               (functionp on-idle)
                               (functionp step-fn)
                               (functionp on-restart)))
                   :ok))
           (elmtui.core.loop::event-consumer-loop)
           (is-true called)
           (is (equal '(t t t t t) callbacks-shape)))
      (setf (symbol-function 'cl-events.loop:run-consumer-loop-shell) orig-shell))))

(test reactive-view-dependency-delivers-debounced-render
  "A state observer must enqueue a real render, not an uninterpreted async command."
  (let* ((state (make-state :initial '(:count 0) :backend :plist))
         (result-channel (cl-events.channel:make-channel))
         (view (create-reactive-view
                :integration-view-delivery
                state
                (lambda (current-state _dispatch)
                  (declare (ignore _dispatch))
                  (list :count (state-ref current-state :count)))))
         (elmtui.view.reactive::*view-invalidation-debounce* 5))
    (unwind-protect
         (progn
           (register-view-dependency view :count)
           (setf (view-invalidated-p view) nil)
           (elmtui.view.reactive::start-reactive-rendering
            view
            (lambda (message)
              (cl-events.channel:-> result-channel message)))
           (setf (state-ref state :count) 3)
           (is-true
            (cl-events.loop:poll-until
             (lambda ()
               (plusp (cl-events.channel:channel-length result-channel)))
             :timeout 0.5
             :interval 0.005))
           (let ((message (cl-events.channel:<- result-channel)))
             (is (eq :view-updated (first message)))
             (is (eq :integration-view-delivery (second message)))
             (is (equal '(:count 3) (third message))))
           (is-false (view-invalidated-p view)))
      ;; CLEANUP-REACTIVE-VIEW sends :SHUTDOWN to the managed worker; callers
      ;; intentionally receive a worker ID rather than a Bordeaux thread object.
      (cleanup-reactive-view view))))

(test core-loop-shutdown-does-not-block-on-full-mailbox
  "Closing a full channel wakes waiters without inserting a shutdown event."
  (let* ((channel (make-message-channel :capacity 1))
         (raw (elmtui.core.event-channels:channel-of channel))
         (elmtui.core.loop::*active-event-channels* (list channel))
         (elmtui.core.loop::*default-event-channel* channel)
         (elmtui.core.loop::*consumer-thread* nil)
         (elmtui.core.loop::*shutdown-requested-flag*
           (elmtui.core.loop::make-shutdown-flag)))
    (is-true (cl-events.channel:chan-put raw :pending))
    (is-true (elmtui.core.loop:elm-stop-loop))
    (is-true elmtui.core.loop::*shutdown-requested*)
    (is (eq :closing (cl-events.channel:channel-state raw)))
    (multiple-value-bind (ok status)
        (cl-events.channel:chan-put raw :too-late :timeout 0)
      (is-false ok)
      (is (eq :closing status)))
    (multiple-value-bind (item status)
        (cl-events.channel:chan-take raw :timeout 0)
      (is (eq :pending item))
      (is (eq :ok status)))
    (is (eq :closed (cl-events.channel:channel-state raw)))))
