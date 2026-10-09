(uiop:define-package :elmtui.tests.tmux-examples-smoke
  (:use :cl :fiveam)
  (:import-from :asdf #:load-system)
  (:import-from :elmtui.core.globals #:*applications*)
  (:import-from :elmtui.core.event-types #:make-key-event)
  (:import-from :elmtui.state.api #:update-result)
  (:import-from :elmtui.app.api #:app-config-root-component-dsl)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:make-virtual-buffer
                #:set-buffer-cell-at
                #:buffer-cell-at
                #:buffer-cell-char
                #:buffer-cell-style)
  (:import-from :elmtui.platform.backend.common.ansi-styling
                #:style-to-terminal-style)
  (:import-from :elmtui.view.geo #:=?)
  (:export #:tmux-examples-smoke-tests))

(in-package :elmtui.tests.tmux-examples-smoke)

(def-suite tmux-examples-smoke-tests
  :in elmtui.tests:elmtui-test
  :description "Smoke tests for tmux example entrypoints and update/view paths")

(in-suite tmux-examples-smoke-tests)

(defun %fn (pkg name)
  (symbol-function (find-symbol name (find-package pkg))))

(test tmux-examples-load-and-export-entrypoints
  (load-system :elmtui-examples)
  (is (fboundp (find-symbol "RUN-TMUX-HOVER-DEMO" (find-package :elmtui-examples.tmux-hover-demo))))
  (is (fboundp (find-symbol "RUN-TMUX-IDLE" (find-package :elmtui.examples.tmux-idle)))))

(test tmux-hover-delegated-inspector-update-and-view-smoke
  "The hover compatibility runner uses the maintained cursor-inspector model."
  (load-system :elmtui-examples)
  (let* ((init-fn (%fn :elmtui-examples.cursor-inspector "INITIAL-INSPECTOR-STATE"))
         (update-fn (%fn :elmtui-examples.cursor-inspector "CURSOR-INSPECTOR-UPDATE"))
         (view-fn (%fn :elmtui-examples.cursor-inspector "CURSOR-INSPECTOR-VIEW"))
         (state (funcall init-fn))
         (result (funcall update-fn (make-key-event :key #\l) state))
         (view (funcall view-fn state)))
    (is (listp state))
    (is (typep result 'update-result))
    (is (listp view))))

(test tmux-idle-update-and-view-smoke
  (load-system :elmtui-examples)
  (let* ((init-fn (%fn :elmtui.examples.tmux-idle "%INITIAL-IDLE-STATE"))
         (update-fn (%fn :elmtui.examples.tmux-idle "IDLE-UPDATE"))
         (view-fn (%fn :elmtui.examples.tmux-idle "IDLE-VIEW"))
         (state (funcall init-fn))
         (tick-result (funcall update-fn '(:tick) state))
         (keyevent-result (funcall update-fn '(:keyevent :key #\q) state))
         (key-event-result (funcall update-fn '(:key-event :key #\q) state))
         (quit-result (funcall update-fn (make-key-event :key #\q) state))
         (view (funcall view-fn state)))
    (is (listp state))
    (is (typep tick-result 'update-result))
    (is (typep keyevent-result 'update-result))
    (is (typep key-event-result 'update-result))
    (is (typep quit-result 'update-result))
    (is (listp view))))

(test tmux-idle-defines-timer-subscription
  (load-system :elmtui-examples)
  (let* ((subs (%fn :elmtui.examples.tmux-idle "IDLE-SUBSCRIPTIONS"))
         (cold '(:should-quit nil))
         (ready '(:should-quit nil
                  :components (:tmux-idle-root (:first-ready-done t))))
         (done '(:should-quit t
                 :components (:tmux-idle-root (:first-ready-done t)))))
    (is (equal '(:timer (:interval 0.4 :message (:tick)))
               (funcall subs cold)))
    (is (equal '(:timer (:interval 0.4 :message (:tick)))
               (funcall subs ready)))
    (is (null (funcall subs done)))))

(test tmux-idle-keypress-quits-immediately-without-exit-frame
  (load-system :elmtui-examples)
  (let* ((init-fn (%fn :elmtui.examples.tmux-idle "%INITIAL-IDLE-STATE"))
         (update-fn (%fn :elmtui.examples.tmux-idle "IDLE-UPDATE"))
         (state (funcall init-fn))
         (key-result (funcall update-fn '(:keyevent :key #\q) state))
         (patches (elmtui.state.api:ur-patches key-result)))
    (is (typep key-result 'update-result))
    (is (find '((:should-quit) t) patches :test #'equal))
    (is-false (find '((:status-label) "Exiting...") patches :test #'equal))
    (is-false (find '((:exiting) t) patches :test #'equal))))

(test tmux-idle-root-viewport-stays-inline
  (load-system :elmtui-examples)
  (let* ((pkg (find-package :elmtui.examples.tmux-idle))
         (app-sym (find-symbol "TMUX-IDLE-APP" pkg))
         (cfg (gethash app-sym *applications*))
         (dsl (app-config-root-component-dsl cfg))
         (props (rest dsl)))
    (is (eq (first dsl) :root-viewport))
    (is (eql (getf props :anchor) :below-cursor))
    (is (eql (getf props :overflow-policy) :truncate))
    (is (= (getf props :height) 8))
    (is (eql (getf props :blank-on-exit) nil))))

(test tmux-idle-fallback-slice-has-mutable-points
  (load-system :elmtui-examples)
  (let* ((idle-pkg (find-package :elmtui.examples.tmux-idle))
         (slice-fn (symbol-function (find-symbol "%SLICE-WITH-FALLBACK-MUTABLE-POINTS" idle-pkg)))
         (full (make-virtual-buffer 80 20)))
    ;; Put visible content only in the top-left area.
    (set-buffer-cell-at full 0 0 #\X nil)
    (multiple-value-bind (base points)
        (funcall slice-fn full 0 12 80 8)
      (declare (ignore base))
      (is (plusp (length points)))
      (let* ((pt (aref points 0))
             (ch (getf pt :char)))
        (is (characterp ch))
        (is (not (char= ch #\Space)))))))

(test tmux-idle-mutation-preserves-cell-style
  (load-system :elmtui-examples)
  (let* ((base (make-virtual-buffer 4 1))
         (style (style-to-terminal-style '(:fg-color :red :bg-color :black)))
         (points (vector (list :x 1 :y 0 :char #\B)))
         (idle-pkg (find-package :elmtui.examples.tmux-idle))
         (mutate-fn (symbol-function (find-symbol "%APPLY-ACTIVE-MUTATIONS" idle-pkg))))
    (set-buffer-cell-at base 0 0 #\A style)
    (set-buffer-cell-at base 0 1 #\B style)
    (set-buffer-cell-at base 0 2 #\C style)
    (set-buffer-cell-at base 0 3 #\D style)
    (let* ((frame (elmtui.platform.backend.common.virtual-buffer:copy-virtual-buffer base))
           (before (buffer-cell-at frame 0 1)))
      (funcall mutate-fn frame points '(0) 7)
      (let ((after (buffer-cell-at frame 0 1)))
        (is (not (char= (buffer-cell-char before) (buffer-cell-char after))))
        (is (=? (buffer-cell-style before) (buffer-cell-style after)))))))

(test tmux-runner-wrappers-preserve-legacy-api-and-delegate-inspector
  (load-system :elmtui-examples)
  (let* ((idle-pkg (find-package :elmtui.examples.tmux-idle))
         (hover-pkg (find-package :elmtui-examples.tmux-hover-demo))
         (inspector-pkg (find-package :elmtui-examples.cursor-inspector))
         (idle-wrapper (%fn :elmtui.examples.tmux-idle "RUN-TMUX-IDLE"))
         (hover-wrapper (%fn :elmtui-examples.tmux-hover-demo "RUN-TMUX-HOVER-DEMO"))
         (idle-runner-sym (find-symbol "RUN-TMUX-IDLE-APP" idle-pkg))
         (hover-inspector-runner-sym (find-symbol "RUN-TMUX-HOVER-INSPECTOR" hover-pkg))
         (inspector-runner-sym (find-symbol "RUN-CURSOR-INSPECTOR" inspector-pkg))
         (idle-orig (and idle-runner-sym (symbol-function idle-runner-sym)))
         (inspector-orig (and inspector-runner-sym (symbol-function inspector-runner-sym)))
         (idle-captured nil)
         (inspector-captured nil))
    (is (fboundp idle-runner-sym))
    (is (fboundp hover-inspector-runner-sym))
    (is (fboundp inspector-runner-sym))
    (unwind-protect
         (progn
           (setf (symbol-function idle-runner-sym)
                 (lambda (&rest args)
                   (setf idle-captured args) :idle-ok))
           (setf (symbol-function inspector-runner-sym)
                 (lambda (&rest args)
                   (setf inspector-captured args) :inspector-ok))
           (is (eq :idle-ok (funcall idle-wrapper :backend-type :terminal :mode :pane)))
           (is (eq :inspector-ok (funcall hover-wrapper :backend-type :terminal :mode :screen)))
           (is (equal idle-captured
                      '(:platform :terminal
                        :platform-options (:prefill-from-tmux t :tmux-prefill-mode :pane))))
           (is (equal inspector-captured
                      '(:backend-type :terminal :tmux-mode :screen :title "tmux-hover-demo"))))
      (when idle-orig
        (setf (symbol-function idle-runner-sym) idle-orig))
      (when inspector-orig
        (setf (symbol-function inspector-runner-sym) inspector-orig)))))
