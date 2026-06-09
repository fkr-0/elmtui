(uiop:define-package :elmtui.tests.runtime-e2e
  (:use :cl :fiveam)
  (:import-from :asdf
                #:load-system)
  (:import-from :cl-inputs.tokens
                #:make-token
                #:+k-key+)
  (:import-from :elmtui.core.event-types
                #:make-key-event)
  (:import-from :elmtui.core.event-channels
                #:make-message-channel)
  (:import-from :elmtui.platform.driver
                #:make-driver-context
                #:driver-context-stop-flag))

(in-package :elmtui.tests.runtime-e2e)

(def-suite runtime-e2e-tests
  :in elmtui.tests:elmtui-test
  :description "Deterministic runtime integration tests (input->route->update->effects->render).")

(in-suite runtime-e2e-tests)

(test runtime-e2e-token-route-update-effects-render
  (let ((orig-next (symbol-function 'cl-inputs.loop:next-token))
        (orig-render (symbol-function 'elmtui.platform.driver::execute-render-command))
        (orig-make-ctx (symbol-function 'elmtui.platform.driver::make-context-from-spec))
        (orig-pipeline (symbol-function 'elmtui.platform.driver::full-view-pipeline))
        (orig-processor elmtui.core.globals:*app-message-processor*)
        (orig-backend elmtui.platform.driver::*backend*)
        (orig-model elmtui.platform.driver::*current-app-model*)
        (orig-app-state elmtui.core.globals:*app-state*)
        (orig-shutdown elmtui.core.loop::*shutdown-requested*))
    (let ((update-msg nil)
          (update-calls 0)
          (render-cmds nil)
          (non-render-cmds nil)
          (pipeline-calls 0)
          (poll-calls 0))
      (unwind-protect
           (progn
             (setf elmtui.core.loop::*shutdown-requested* nil)
             (setf elmtui.platform.driver::*backend* :test-backend)
             (setf (symbol-function 'cl-inputs.loop:next-token)
                   (lambda (_source &key timeout)
                     (declare (ignore _source timeout))
                     (incf poll-calls)
                     (when (= poll-calls 1)
                       (make-token +k-key+ '(:code #\a :mods ()) 0))))
             (setf (symbol-function 'elmtui.platform.driver::execute-render-command)
                   (lambda (cmd _backend)
                     (declare (ignore _backend))
                     (push cmd render-cmds)
                     t))
             (setf (symbol-function 'elmtui.platform.driver::make-context-from-spec)
                   (lambda (_app-spec state backend)
                     (elmtui.contracts:make-app-context
                       :state state
                       :backend backend
                       :front-buffer nil)))
             (setf (symbol-function 'elmtui.platform.driver::full-view-pipeline)
                   (lambda (ctx)
                     (incf pipeline-calls)
                     ctx))
             (elmtui.platform.driver::initialize-app-model
              (list :name 'runtime-e2e-app
                    :init-fn (lambda () (values '(:count 0) nil))
                    :update-fn (lambda (msg model)
                                 (setf update-msg msg)
                                 (incf update-calls)
                                 (values
                                  (list :count (1+ (getf model :count 0)))
                                  (list
                                   '(:render :set-cursor 2 3)
                                   '(:dispatch (:worker-done)))))
                    :view-fn (lambda (_model) (declare (ignore _model)) nil)
                    :subscriptions-fn (lambda (_model) (declare (ignore _model)) nil)
                    :command-processor-fn
                    (lambda (cmd _queue _model _app-config)
                      (declare (ignore _queue _model _app-config))
                      (push cmd non-render-cmds))
                    :message-queue nil
                    :root-viewport-id :root-viewport))
             (let* ((channel (make-message-channel))
                    (ctx (make-driver-context
                          :backend nil
                          :device nil
                          :input-source :dummy-source
                          :publish-fn nil)))
               (setf (elmtui.platform.driver::driver-context-publish-fn ctx)
                     (lambda (evt)
                       (elmtui.core.loop::process-channel-event evt channel)
                       (setf (driver-context-stop-flag ctx) t)))
               (elmtui.platform.driver::driver-context-input-loop ctx))
             (is (= 1 update-calls))
             (is (consp update-msg))
             (is (eq :KEYEVENT (car update-msg)))
             (is (= 1 pipeline-calls))
             (is (equal '(:render :set-cursor 2 3) (first render-cmds)))
             (is (equal '(:dispatch (:worker-done)) (first non-render-cmds)))
             (is (= 1 (getf elmtui.platform.driver::*current-app-model* :count))))
        (setf (symbol-function 'cl-inputs.loop:next-token) orig-next
              (symbol-function 'elmtui.platform.driver::execute-render-command) orig-render
              (symbol-function 'elmtui.platform.driver::make-context-from-spec) orig-make-ctx
              (symbol-function 'elmtui.platform.driver::full-view-pipeline) orig-pipeline
              elmtui.core.globals:*app-message-processor* orig-processor
              elmtui.platform.driver::*backend* orig-backend
              elmtui.platform.driver::*current-app-model* orig-model
              elmtui.core.globals:*app-state* orig-app-state
              elmtui.core.loop::*shutdown-requested* orig-shutdown)))))

(test runtime-e2e-shutdown-clears-subscriptions-and-skips-render
  (let ((orig-render (symbol-function 'elmtui.platform.driver::execute-render-command))
        (orig-make-ctx (symbol-function 'elmtui.platform.driver::make-context-from-spec))
        (orig-pipeline (symbol-function 'elmtui.platform.driver::full-view-pipeline))
        (orig-cancel (symbol-function 'elmtui.core.async:cancel-cmd))
        (orig-processor elmtui.core.globals:*app-message-processor*)
        (orig-backend elmtui.platform.driver::*backend*)
        (orig-model elmtui.platform.driver::*current-app-model*)
        (orig-app-state elmtui.core.globals:*app-state*)
        (orig-shutdown elmtui.core.loop::*shutdown-requested*))
    (let ((pipeline-calls 0)
          (cancel-calls 0)
          (seen-msgs nil))
      (unwind-protect
           (progn
             (setf elmtui.core.loop::*shutdown-requested* nil)
             (setf elmtui.platform.driver::*backend* :test-backend)
             (setf (symbol-function 'elmtui.platform.driver::execute-render-command)
                   (lambda (_cmd _backend)
                     (declare (ignore _cmd _backend))
                     t))
             (setf (symbol-function 'elmtui.platform.driver::make-context-from-spec)
                   (lambda (_app-spec state backend)
                     (elmtui.contracts:make-app-context
                       :state state
                       :backend backend
                       :front-buffer nil)))
             (setf (symbol-function 'elmtui.platform.driver::full-view-pipeline)
                   (lambda (ctx)
                     (incf pipeline-calls)
                     ctx))
             (setf (symbol-function 'elmtui.core.async:cancel-cmd)
                   (lambda (_cmd)
                     (incf cancel-calls)
                     t))
             (elmtui.platform.driver::initialize-app-model
              (list :name 'runtime-shutdown-e2e-app
                    :init-fn (lambda () (values '(:count 0) nil))
                    :update-fn (lambda (_msg _model)
                                 (push _msg seen-msgs)
                                 (values '(:should-quit t) nil))
                    :view-fn (lambda (_model) (declare (ignore _model)) nil)
                    :subscriptions-fn (lambda (_model) (declare (ignore _model)) nil)
                    :command-processor-fn nil
                    :message-queue nil
                    :root-viewport-id :root-viewport))
             ;; Seed one active recurring subscription handle to verify teardown.
             (clrhash elmtui.platform.driver::*active-app-subscriptions*)
             (setf (gethash :dummy elmtui.platform.driver::*active-app-subscriptions*)
                   (list :cmd '(:recurring-task :id :dummy)))
             (funcall elmtui.core.globals:*app-message-processor* '(:tick))
             (is-true elmtui.core.loop::*shutdown-requested*)
             (is (member '(:appshutdown) seen-msgs :test #'equal))
             (is (= 0 (hash-table-count elmtui.platform.driver::*active-app-subscriptions*)))
             (is (= 1 cancel-calls))
             (is (= 0 pipeline-calls)))
        (setf (symbol-function 'elmtui.platform.driver::execute-render-command) orig-render
              (symbol-function 'elmtui.platform.driver::make-context-from-spec) orig-make-ctx
              (symbol-function 'elmtui.platform.driver::full-view-pipeline) orig-pipeline
              (symbol-function 'elmtui.core.async:cancel-cmd) orig-cancel
              elmtui.core.globals:*app-message-processor* orig-processor
              elmtui.platform.driver::*backend* orig-backend
              elmtui.platform.driver::*current-app-model* orig-model
              elmtui.core.globals:*app-state* orig-app-state
              elmtui.core.loop::*shutdown-requested* orig-shutdown
              elmtui.platform.driver::*last-ctx* nil
              elmtui.platform.driver::*previous-frame-buffer* nil)))))

(test runtime-e2e-tmux-idle-key-exit-emits-no-scroll-render-commands
  (let ((orig-render (symbol-function 'elmtui.platform.driver::execute-render-command))
        (orig-make-ctx (symbol-function 'elmtui.platform.driver::make-context-from-spec))
        (orig-pipeline (symbol-function 'elmtui.platform.driver::full-view-pipeline))
        (orig-processor elmtui.core.globals:*app-message-processor*)
        (orig-backend elmtui.platform.driver::*backend*)
        (orig-model elmtui.platform.driver::*current-app-model*)
        (orig-app-state elmtui.core.globals:*app-state*)
        (orig-shutdown elmtui.core.loop::*shutdown-requested*))
    (let ((pipeline-calls 0)
          (render-cmds nil))
      (unwind-protect
           (progn
             (setf elmtui.core.loop::*shutdown-requested* nil)
             (setf elmtui.platform.driver::*backend* :test-backend)
             (setf (symbol-function 'elmtui.platform.driver::execute-render-command)
                   (lambda (cmd _backend)
                     (declare (ignore _backend))
                     (push cmd render-cmds)
                     t))
             (setf (symbol-function 'elmtui.platform.driver::make-context-from-spec)
                   (lambda (_app-spec state backend)
                     (elmtui.contracts:make-app-context
                      :state state
                      :backend backend
                      :front-buffer nil)))
             (setf (symbol-function 'elmtui.platform.driver::full-view-pipeline)
                   (lambda (ctx)
                     (incf pipeline-calls)
                     ctx))
             (load-system :elmtui-examples)
             (let* ((pkg (find-package :elmtui.examples.tmux-idle))
                    (init-fn (symbol-function (find-symbol "INITIALIZE-APP-STATE-TMUX-IDLE-APP" pkg)))
                    (update-fn (symbol-function (find-symbol "PROCESS-MESSAGE-TMUX-IDLE-APP" pkg)))
                    (view-fn (symbol-function (find-symbol "WRAPPED-VIEW-TMUX-IDLE-APP" pkg)))
                    (subs-fn (symbol-function (find-symbol "IDLE-SUBSCRIPTIONS" pkg))))
               (elmtui.platform.driver::initialize-app-model
                (list :name 'runtime-tmux-idle-key-exit
                      :init-fn init-fn
                      :update-fn update-fn
                      :view-fn view-fn
                      :subscriptions-fn subs-fn
                      :command-processor-fn nil
                      :message-queue nil
                      :root-viewport-id :tmux-idle-root))
               (let ((channel (make-message-channel)))
                 (elmtui.core.loop::process-channel-event
                  (make-key-event :key :q :char #\q :code 113)
                  channel)))
             (is-true elmtui.core.loop::*shutdown-requested*)
             (is (= 0 pipeline-calls))
             (is-false
              (find-if (lambda (cmd)
                         (and (consp cmd)
                              (eq (first cmd) :render)
                              (member (second cmd) '(:scroll :scroll-up :scroll-down))))
                       render-cmds)))
        (setf (symbol-function 'elmtui.platform.driver::execute-render-command) orig-render
              (symbol-function 'elmtui.platform.driver::make-context-from-spec) orig-make-ctx
              (symbol-function 'elmtui.platform.driver::full-view-pipeline) orig-pipeline
              elmtui.core.globals:*app-message-processor* orig-processor
              elmtui.platform.driver::*backend* orig-backend
              elmtui.platform.driver::*current-app-model* orig-model
              elmtui.core.globals:*app-state* orig-app-state
              elmtui.core.loop::*shutdown-requested* orig-shutdown
              elmtui.platform.driver::*last-ctx* nil
              elmtui.platform.driver::*previous-frame-buffer* nil)))))
