(uiop:define-package :elmtui.tests.errs-regression
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.api #:init #:update)
  (:import-from :elmtui.ui.widgets.drawable-content
                #:make-drawable-content
                #:msg-set-drawable-content)
  (:import-from :elmtui.ui.widgets.viewport-enhanced
                #:make-viewport-enhanced)
  (:import-from :elmtui.state.api
                #:update-result
                #:ur-patches
                #:ur-commands)
  (:import-from :elmtui.core.event-channels
                #:make-ui-channel
                #:handlers)
  (:import-from :elmtui.core.event-async
                #:event-promise)
  (:import-from :elmtui.core.event-types
                #:make-ui-event)
  (:import-from :elmtui.core.topic-registry
                #:subscribe
                #:subscribe-if)
  (:import-from :elmtui.runtime.protocol
                #:dispatch-root-message))

(in-package :elmtui.tests.errs-regression)

(def-suite errs-regression-tests
  :in elmtui.tests:elmtui-test)
(in-suite errs-regression-tests)

(defun %patch-value-for (patches path)
  (second (find path patches :key #'first :test #'equal)))

(test top-level-dev-main-is-silent
  "The exported development entrypoint must not leak placeholder debug text."
  (let ((output (with-output-to-string (*standard-output*)
                  (elmtui:dev-main))))
    (is (string= "" output))))

(test drawable-content-update-accepts-standard-update-argument-order
  (let* ((component (make-drawable-content :id :content))
         (state nil))
    (multiple-value-bind (_ initialized-patches _commands)
        (init component :id-path '(:components :content) :initial-content "old")
      (declare (ignore _ _commands))
      (setf state initialized-patches))
    (let ((result (update component
                          (cons msg-set-drawable-content "new")
                          state
                          :id-path '(:components :content))))
      (is-true (typep result 'update-result))
      (is (equal "new"
                 (%patch-value-for (ur-patches result)
                                   '(:components :content :content)))))))

(test viewport-enhanced-update-accepts-standard-update-argument-order
  (let ((component (make-viewport-enhanced :id :viewport)))
    (multiple-value-bind (_ init-patches _commands)
        (init component :id-path '(:components :viewport)
                        :initial-width 10
                        :initial-height 5)
      (declare (ignore _ _commands))
      (multiple-value-bind (patches commands)
          (update component
                  '(:resize :width 20 :height 7)
                  init-patches
                  :id-path '(:components :viewport))
        (declare (ignore commands))
        (is (equal '(:components :viewport) (first (first patches))))
        (is (= 20 (getf (second (first patches)) :width)))
        (is (= 7 (getf (second (first patches)) :height)))))))

(test event-promise-unregisters-handler-after-resolve
  (let ((channel (make-ui-channel)))
    (event-promise :click :target :button :channel channel)
    (is (= 1 (length (handlers channel))))
    (funcall (first (handlers channel))
             (make-ui-event :type :click :target :button))
    (is (= 0 (length (handlers channel))))))

(test topic-subscribe-rejects-non-functions-early
  (signals type-error
    (subscribe "ui/*" :not-a-function))
  (signals type-error
    (subscribe-if "ui/*" :not-a-function #'identity))
  (signals type-error
    (subscribe-if "ui/*" #'identity :not-a-function)))

(defclass errs-regression-root (elmtui.ui.api:component) ())

(defmethod update ((component errs-regression-root) msg state &key id-path)
  (declare (ignore component msg state id-path))
  (values '(:patches) '(:commands) :extra-value))

(test dispatch-root-message-rejects-three-value-update-results
  (let ((old-get-component-instance
          (symbol-function 'elmtui.app.api:get-component-instance)))
    (unwind-protect
         (progn
           (setf (symbol-function 'elmtui.app.api:get-component-instance)
                 (lambda (id-path state)
                   (declare (ignore id-path state))
                   (make-instance 'errs-regression-root)))
           (multiple-value-bind (patches commands)
               (dispatch-root-message :message nil :root)
             (is (null patches))
             (is (null commands))))
      (setf (symbol-function 'elmtui.app.api:get-component-instance)
            old-get-component-instance))))


(defun %load-example (name)
  (load (merge-pathnames (format nil "examples/~A.lisp" name)
                         (asdf:system-source-directory :elmtui))))

(defun %pkg-fn (package-name symbol-name)
  (symbol-function (find-symbol symbol-name (find-package package-name))))

(test dirli-update-handles-missing-listbox-model
  (%load-example "dirli")
  (let ((update-fn (%pkg-fn "ELMTUI.EXAMPLES.DIRLI" "APP-UPDATE")))
    (is-true (typep (funcall update-fn :item-selected '(:current-path #p"./"))
                    'update-result))
    (is-true (typep (funcall update-fn '(:terminal-resized :width 80 :height 24)
                             '(:terminal-width 80 :terminal-height 24))
                    'update-result))))

(test minimal-update-handles-non-cons-messages
  (%load-example "minimal-app")
  (let ((update-fn (%pkg-fn "ELMTUI.EXAMPLES.MINIMAL" "MINIMAL-UPDATE")))
    (is-true (typep (funcall update-fn
                             (elmtui.core.event-types:make-key-event :key :enter)
                             '(:last-key "before"))
                    'update-result))
    (is-true (typep (funcall update-fn :unknown-message '(:last-key "before"))
                    'update-result))))

(test focus-simple-listbox-dispatch-returns-patch-without-mutating-state
  (%load-example "focus-simple")
  (let* ((pkg (find-package "ELMTUI.EXAMPLES.FOCUS-SIMPLE"))
         (init-fn (symbol-function (find-symbol "%INITIAL-STATE" pkg)))
         (update-fn (symbol-function (find-symbol "APP-UPDATE" pkg)))
         (state (funcall init-fn))
         (components-before (copy-alist (getf state :demo-components)))
         (result (funcall update-fn '(:dispatch-to-component :choices :down) state)))
    (is-true (typep result 'update-result))
    (is (equal components-before (getf state :demo-components))
        "APP-UPDATE must not mutate the original demo-components alist in place.")
    (is (equal '(:demo-components) (first (first (ur-patches result)))))
    (is (assoc :choices (second (first (ur-patches result)))))))

(test input-selector-handles-list-and-typed-key-events-consistently
  (%load-example "input-selector")
  (let* ((pkg (find-package "ELMTUI.EXAMPLES.INPUT-SELECTOR"))
         (init-fn (symbol-function (find-symbol "%INITIAL-STATE" pkg)))
         (update-fn (symbol-function (find-symbol "APP-UPDATE" pkg)))
         (state (funcall init-fn)))
    (let ((list-result (funcall update-fn '(:key-event :arrow-down nil) state))
          (typed-result (funcall update-fn
                                 (elmtui.core.event-types:make-key-event :key :arrow-down)
                                 state)))
      (is (equal (ur-patches list-result)
                 (ur-patches typed-result))))))

(test tmux-idle-subscriptions-stop-after-quit
  (%load-example "tmux-idle-screensaver")
  (let* ((pkg (find-package "ELMTUI.EXAMPLES.TMUX-IDLE"))
         (subs-fn (symbol-function (find-symbol "IDLE-SUBSCRIPTIONS" pkg)))
         (ready '(:should-quit nil
                  :components (:tmux-idle-root (:first-ready-done t))))
         (stopped '(:should-quit t
                    :components (:tmux-idle-root (:first-ready-done t)))))
    (is (equal '(:timer (:interval 0.4 :message (:tick)))
               (funcall subs-fn '(:should-quit nil))))
    (is (null (funcall subs-fn stopped)))
    (is (equal '(:timer (:interval 0.4 :message (:tick)))
               (funcall subs-fn ready)))))

(test tmux-hover-delegated-inspector-reports-capture-errors
  "The hover compatibility runner shares cursor-inspector's error model."
  (%load-example "cursor-inspector")
  (let* ((pkg (find-package "ELMTUI-EXAMPLES.CURSOR-INSPECTOR"))
         (update-fn (symbol-function (find-symbol "CURSOR-INSPECTOR-UPDATE" pkg)))
         (view-fn (symbol-function (find-symbol "CURSOR-INSPECTOR-VIEW" pkg)))
         (result (funcall update-fn '(:inspector-capture-error "boom")
                          '(:lines #("old") :cursor-x 0 :cursor-y 0))))
    (is-true (typep result 'update-result))
    (is (search "boom" (prin1-to-string (ur-patches result)) :test #'char-equal))
    (is (search "boom"
                (prin1-to-string
                 (funcall view-fn '(:lines #() :cursor-x 0 :cursor-y 0
                                    :status "Refresh failed: boom")))
                :test #'char-equal))))

(defun %pkg-sym (package-designator name)
  (or (find-symbol name (find-package package-designator))
      (error "Missing symbol ~A in package ~A" name package-designator)))

(defun %pkg-fn* (package-designator name)
  (symbol-function (%pkg-sym package-designator name)))

(test subpackage-state-path-and-observer-validation
  (asdf:load-system :cl-state)
  (let* ((make-state (%pkg-fn* :cl-state.core "MAKE-STATE"))
         (state-ref (%pkg-sym :cl-state.core "STATE-REF"))
         (add-observer (%pkg-fn* :cl-state.observer "ADD-OBSERVER"))
         (notify-observers (%pkg-fn* :cl-state.observer "NOTIFY-OBSERVERS"))
         (app (funcall make-state :initial '(:a 1)))
         (calls '()))
    (signals error
      (funcall state-ref app '(:a . :b)))
    (signals type-error
      (funcall add-observer app :a :not-callable))
    (funcall add-observer app :a (lambda (_old _new) (declare (ignore _old _new)) (push :first calls)))
    (funcall add-observer app :a (lambda (_old _new) (declare (ignore _old _new)) (push :second calls)))
    (funcall notify-observers app :a 1 2)
    (is (equal '(:second :first) calls))))

(test subpackage-events-validation-and-channel-close
  (asdf:load-system :cl-events)
  (let* ((make-bus (%pkg-fn* :cl-events.bus "MAKE-EVENT-BUS"))
         (subscribe (%pkg-fn* :cl-events.bus "SUBSCRIBE"))
         (make-filtered-channel (%pkg-fn* :cl-events.channel "MAKE-FILTERED-CHANNEL"))
         (channel-add-filter (%pkg-fn* :cl-events.channel "CHANNEL-ADD-FILTER"))
         (chan-close (%pkg-fn* :cl-events.channel "CHAN-CLOSE"))
         (channel (funcall make-filtered-channel)))
    (signals error
      (funcall subscribe (funcall make-bus) nil))
    (signals type-error
      (funcall channel-add-filter channel :not-callable))
    (is-true (funcall chan-close channel))))

(test subpackage-input-decoder-bounds-and-timeout-validation
  (asdf:load-system :cl-inputs)
  (let* ((make-decoder (%pkg-fn* :cl-inputs.decoder "MAKE-DECODER"))
         (decode-chunk (%pkg-fn* :cl-inputs.decoder "DECODE-CHUNK"))
         (buffered-byte-count (%pkg-fn* :cl-inputs.decoder "DECODER-BUFFERED-BYTE-COUNT"))
         (input-token-kind (%pkg-fn* :cl-inputs.tokens "INPUT-TOKEN-KIND"))
         (input-token-data (%pkg-fn* :cl-inputs.tokens "INPUT-TOKEN-DATA"))
         (next-token (%pkg-fn* :cl-inputs.loop "NEXT-TOKEN")))
    (multiple-value-bind (tokens decoder*)
        (funcall decode-chunk (funcall make-decoder)
                 (make-array 1 :element-type '(unsigned-byte 8) :initial-contents '(27)))
      (is (null tokens))
      (is (= 1 (funcall buffered-byte-count decoder*))))
    (multiple-value-bind (tokens _decoder)
        (funcall decode-chunk (funcall make-decoder)
                 (make-array 9 :element-type '(unsigned-byte 8)
                             :initial-contents '(27 91 60 48 59 48 59 48 77)))
      (declare (ignore _decoder))
      (is (= 1 (length tokens)))
      (is (eq :protocol (funcall input-token-kind (first tokens))))
      (is (eq :unknown-sequence
              (getf (funcall input-token-data (first tokens)) :category))))
    (signals error
      (funcall next-token nil :timeout -1))))



(test subpackage-style-validation-and-cache
  (asdf:load-system :cl-styles)
  (let* ((validate-declarations (%pkg-fn* :cl-styles.properties "VALIDATE-DECLARATIONS"))
         (apply-tree (%pkg-fn* :cl-styles.engine "APPLY-STYLESHEET-TO-TREE"))
         (make-stylesheet (%pkg-fn* :cl-styles.sheet "MAKE-STYLESHEET"))
         (sheet (funcall make-stylesheet :rules nil))
         (root (make-instance 'elmtui.view.base-elements:container-element
                              :id :root :style '(:color :blue)))
         (cache (make-hash-table :test 'equal))
         (sentinel (list :cached)))
    (signals error
      (funcall validate-declarations '(:colro :red)))
    (setf (gethash (list :root sheet :patches :sig) cache) sentinel)
    ;; Compatibility cache arguments are accepted, but stale entries are never authoritative.
    (let ((result (funcall apply-tree root sheet
                           :return :objects
                           :cache cache :previous-signature :sig)))
      (is (not (eq sentinel result)))
      (is (eq root (first result)))
      (is (eq :blue
              (getf (cl-styles.protocols:get-computed-style root) :color))))))

(test subpackage-restored-promise-cancellation-is-stable
  (asdf:load-system :cl-events)
  (let* ((make-promise (%pkg-fn* :cl-events.async "MAKE-PROMISE"))
         (cancel (%pkg-fn* :cl-events.async "PROMISE-CANCEL"))
         (cancelled-p (%pkg-fn* :cl-events.async "PROMISE-CANCELLED-P"))
         (resolve (%pkg-fn* :cl-events.async "RESOLVE-PROMISE"))
         (reject (%pkg-fn* :cl-events.async "REJECT-PROMISE"))
         (value (%pkg-fn* :cl-events.async "PROMISE-VALUE"))
         (error-slot (%pkg-fn* :cl-events.async "PROMISE-ERROR"))
         (p (funcall make-promise)))
    (is-true (funcall cancel p))
    (is-true (funcall cancelled-p p))
    (funcall resolve p :late-value)
    (funcall reject p :late-error)
    (is (null (funcall value p)))
    (is (null (funcall error-slot p)))
    (is-true (funcall cancelled-p p))))

(test subpackage-restored-bus-cleans-closed-subscriptions
  (asdf:load-system :cl-events)
  (let* ((make-bus (%pkg-fn* :cl-events.bus "MAKE-EVENT-BUS"))
         (subscribe (%pkg-fn* :cl-events.bus "SUBSCRIBE"))
         (cleanup (%pkg-fn* :cl-events.bus "CLEANUP-CLOSED-SUBSCRIPTIONS"))
         (chan-close (%pkg-fn* :cl-events.channel "CHAN-CLOSE"))
         (bus (funcall make-bus))
         (ch (funcall subscribe bus :topic)))
    (is (= 0 (funcall cleanup bus)))
    (funcall chan-close ch)
    (is (= 1 (funcall cleanup bus)))
    (is (= 0 (funcall cleanup bus)))))

(test subpackage-restored-input-sink-publishes-to-event-bus
  (asdf:load-system :cl-events)
  (asdf:load-system :cl-inputs/events)
  (let* ((make-bus (%pkg-fn* :cl-events.bus "MAKE-EVENT-BUS"))
         (subscribe (%pkg-fn* :cl-events.bus "SUBSCRIBE"))
         (chan-take (%pkg-fn* :cl-events.channel "CHAN-TAKE"))
         (event-bus-sink (%pkg-fn* :cl-inputs.events "EVENT-BUS-SINK"))
         (make-token (%pkg-fn* :cl-inputs.tokens "MAKE-TOKEN"))
         (event-type (%pkg-fn* :cl-events.types "EVENT-TYPE"))
         (event-data (%pkg-fn* :cl-events.types "EVENT-DATA"))
         (bus (funcall make-bus))
         (ch (funcall subscribe bus :input/token))
         (sink (funcall event-bus-sink bus))
         (token (funcall make-token :key :a 0)))
    (funcall sink token)
    (let ((event (funcall chan-take ch)))
      (is (eq :input/token (funcall event-type event)))
      (is (eq token (funcall event-data (funcall event-data event)))))))


(test subpackage-restored-device-defaults-fail-clearly
  (asdf:load-system :cl-inputs)
  (let* ((read-bytes (%pkg-fn* :cl-inputs.device.api "DEVICE-READ-BYTES"))
         (input-stream (%pkg-fn* :cl-inputs.device.api "DEVICE-INPUT-STREAM"))
         (set-modes (%pkg-fn* :cl-inputs.device.api "DEVICE-SET-MODES"))
         (buffer (make-array 1 :element-type '(unsigned-byte 8))))
    (signals error
      (funcall read-bytes :unsupported buffer 0 1))
    (signals error
      (funcall input-stream :unsupported))
    (signals error
      (funcall set-modes :unsupported '(:mouse :sgr)))))

(test directional-grid-focus-uses-row-and-column-coordinates
  "Grid-first directional focus should use grid row/column metadata, not plist/stylable fallbacks."
  (let* ((tree '(:id :root :children
                 ((:id :a :focusable t :grid-row 0 :grid-col 0 :x 0 :y 0 :width 1 :height 1)
                  (:id :b :focusable t :grid-row 0 :grid-col 1 :x 10 :y 0 :width 1 :height 1)
                  (:id :c :focusable t :grid-row 1 :grid-col 0 :x 0 :y 10 :width 1 :height 1)
                  (:id :d :focusable t :grid-row 1 :grid-col 1 :x 10 :y 10 :width 1 :height 1))))
         (fm (elmtui.core.focus:make-focus-manager :initial-focus :a)))
    (setf (elmtui.core.focus:focus-manager-focusable-elements fm)
          (elmtui.core.focus:collect-focusable-ids tree))
    (is (equal '(:a :b :c :d)
               (elmtui.core.focus:focus-manager-focusable-elements fm)))

    (is-true (elmtui.core.focus:navigate-right fm :ui-tree tree))
    (is (eq :b (elmtui.core.focus:get-current-focus fm)))

    (is-true (elmtui.core.focus:navigate-down fm :ui-tree tree))
    (is (eq :d (elmtui.core.focus:get-current-focus fm)))

    (is-true (elmtui.core.focus:navigate-left fm :ui-tree tree))
    (is (eq :c (elmtui.core.focus:get-current-focus fm)))

    (is-true (elmtui.core.focus:navigate-up fm :ui-tree tree))
    (is (eq :a (elmtui.core.focus:get-current-focus fm)))))

(test directional-grid-focus-honors-row-and-column-spans
  "Grid-first directional focus should compare occupied cell extents, not only top-left cells."
  (let* ((tree '(:id :root :children
                 ((:id :wide :focusable t
                   :grid-row 0 :grid-col 0 :grid-col-span 2
                   :x 0 :y 0 :width 20 :height 1)
                  (:id :overlap-right :focusable t
                   :grid-row 0 :grid-col 1
                   :x 10 :y 0 :width 10 :height 1)
                  (:id :right :focusable t
                   :grid-row 0 :grid-col 2
                   :x 20 :y 0 :width 10 :height 1)
                  (:id :tall :focusable t
                   :grid-row 1 :grid-col 0 :grid-row-span 2
                   :x 0 :y 10 :width 10 :height 20)
                  (:id :overlap-down :focusable t
                   :grid-row 2 :grid-col 1
                   :x 10 :y 20 :width 10 :height 10)
                  (:id :down :focusable t
                   :grid-row 3 :grid-col 0
                   :x 0 :y 30 :width 10 :height 10))))
         (fm (elmtui.core.focus:make-focus-manager :initial-focus :wide)))
    (setf (elmtui.core.focus:focus-manager-focusable-elements fm)
          (elmtui.core.focus:collect-focusable-ids tree))

    (is-true (elmtui.core.focus:navigate-right fm :ui-tree tree))
    (is (eq :right (elmtui.core.focus:get-current-focus fm)))

    (elmtui.core.focus:set-focus fm :tall)
    (is-true (elmtui.core.focus:navigate-down fm :ui-tree tree))
    (is (eq :down (elmtui.core.focus:get-current-focus fm)))))

(test minimal-defapplication-wrapped-view-renders-through-buffer-diff
  "The real minimal DEFAPPLICATION lowering must reach layout, virtual buffer, and diff output."
  (%load-example "minimal-app")
  (let* ((package-name "ELMTUI.EXAMPLES.MINIMAL")
         (init-fn (%pkg-fn package-name "INITIALIZE-APP-STATE-MINIMAL"))
         (process-fn (%pkg-fn package-name "PROCESS-MESSAGE-MINIMAL"))
         (view-fn (%pkg-fn package-name "WRAPPED-VIEW-MINIMAL"))
         (state nil))
    (multiple-value-bind (initial-state commands)
        (funcall init-fn)
      (declare (ignore commands))
      (setf state initial-state))
    (multiple-value-bind (next-state commands)
        (funcall process-fn '(:terminalresized :width 80 :height 24) state)
      (declare (ignore commands))
      (setf state next-state))
    (multiple-value-bind (next-state commands)
        (funcall process-fn '(:cursorposition :col 1 :row 1) state)
      (declare (ignore commands))
      (setf state next-state))
    (let* ((viewport
             (elmtui.view.geo:make-rectangle
              :pos (elmtui.view.geo:make-pos :x 0 :y 0)
              :size (elmtui.view.geo:make-size :w 80 :h 24)))
           (front
             (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 80 24))
           (ctx
             (elmtui.contracts:make-app-context
              :state state
              :viewport-rect viewport
              :front-buffer front
              :view-fn view-fn))
           (result (elmtui.pipeline:render-pipeline-0-to-5 ctx))
           (laid (elmtui.contracts:ctx-laid-out-tree result))
           (back (elmtui.contracts:ctx-back-buffer result))
           (row-zero
             (coerce
              (loop for col below 80
                    collect
                    (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char
                     (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at
                      back 0 col)))
              'string))
           (diff (elmtui.render.presentation:compute-frame-operations front back))
           (diff-text
             (with-output-to-string (stream)
               (dolist (operation diff)
                 (when (eq :write-chars (getf operation :type))
                   (write-string (getf operation :chars "") stream))))))
      (is-true laid "The wrapped minimal view must produce a laid-out tree.")
      (is-true (elmtui.contracts:root laid)
               "The laid-out tree must retain the resolved root element.")
      (is (search "Hello slurp" row-zero)
          "The expected text must reach the virtual back buffer.")
      (is (search "Hello slurp" diff-text)
          "The expected text must survive into the terminal diff output."))))

(test primitive-component-collisions-prefer-primitives-at-render-time
  "Primitive tags stay declarative even when compatibility component aliases share their names."
  (dolist (tag '(:text :label :button))
    (is-true (elmtui.view.base-elements:element-class tag)
             "Each collision tag must retain a registered primitive class.")
    (multiple-value-bind (component-class props)
        (elmtui.ui.dsl-resolution:resolve-dsl-type tag)
      (declare (ignore props))
      (is-true component-class
               "The compatibility component resolution remains observable."))
    (let ((resolved
            (elmtui.view.dsl:render-dsl-to-resolved-tree
             (list tag :id :collision-proof :content "visible")
             nil)))
      (is (eq tag (first resolved))
          "Render-time resolution must preserve the primitive tag."))))
