(uiop:define-package :elmtui.tests.examples-smoke
  (:use :cl :fiveam)
  (:import-from :elmtui.app.api
                #:app-config-p
                #:app-config-root-component-dsl
                #:app-config-view-fn-sym)
  (:export #:examples-smoke-tests))

(in-package :elmtui.tests.examples-smoke)

(def-suite examples-smoke-tests
  :in elmtui.tests:elmtui-test
  :description "Smoke tests for maintained examples and legacy cleanup")

(in-suite examples-smoke-tests)

(defparameter *maintained-examples*
  '(("cursor-inspector" "CURSOR-INSPECTOR-APP")
    ("dirli" "DIRLI-APP")
    ("focus-simple" "FOCUS-SIMPLE-APP")
    ("fzf-finder-real" "FZF-FINDER")
    ("game-of-life" "GAME-OF-LIFE-APP")
    ("glider-real" "GLIDER-ANIMATION-APP")
    ("input-selector" "INPUT-SELECTOR-APP")
    ("keymap-app" "KEYMAP-EXAMPLE-APP")
    ("key-tester" "KEY-TESTER-APP")
    ("minimal-app" "MINIMAL")
    ("mini-text-editor" "MINI-TEXT-EDITOR-APP")
    ("mini-rainbow" "MINI-RAINBOW")
    ("neon-glider" "NEON-GLIDER-APP")
    ("neon-life" "NEON-LIFE-APP")
    ("neon-less" "NEON-LESS-APP")
    ("neon-nano" "NEON-NANO-APP")
    ("neon-pong" "NEON-PONG-APP")
    ("neon-tetris" "NEON-TETRIS-APP")
    ("pong-below-cursor" "PONG-BELOW-CURSOR-APP")
    ("rainbow-app" "RAINBOW-EXAMPLE-APP")
    ("root-viewport-test-app" "ROOT-VIEWPORT-TEST-APP")
    ("scroll-panel-demo" "SCROLL-PANEL-DEMO-APP")
    ("tmux-idle-screensaver" "TMUX-IDLE-APP")
    ("wifi-menu" "WIFI-MENU-APP")
    ("wifi-inline" "WIFI-INLINE-APP")))


(defparameter *dropped-legacy-example-files*
  '("examples/boxes-app.lisp"
    "examples/colorblocks-app.lisp"
    "examples/colortext-app.lisp"
    "examples/comprehensive-widgets-demo.lisp"
    "examples/dirlister_poc/dirlister_poc.asd"
    "examples/dirlister_poc/dirlister_poc.lisp"
    "examples/dsl-integration-demo.lisp"
    "examples/grid-event-form-app.lisp"
    "examples/message-contract-demo.lisp"
    "examples/rainbow-app-canvas.lisp"
    "examples/rainbow-app-contracted.lisp"
    "examples/simple-counter.lisp"
    "examples/standardized-widgets-example.lisp"
    "examples/variant-examples.lisp"))


(defun %assert-example-loads-and-has-entry (name)
  (let* ((file (elmtui.examples.runner::%resolve-example-file name))
         (_ (load file))
         (pkg-designator (elmtui.examples.runner::%read-example-package-designator file))
         (pkg (find-package pkg-designator))
         (entry (elmtui.examples.runner::%resolve-entry-symbol pkg name)))
    (declare (ignore _))
    (is (pathnamep file))
    (is (not (null pkg)))
    (is (and entry (fboundp entry)))))

(test legacy-system-removed
  (signals error
    (asdf:find-system "elmtui-examples/legacy")))

(test legacy-example-files-removed
  (dolist (path *dropped-legacy-example-files*)
    (is (null (probe-file path)))))

(defun %example-package (name)
  (let* ((file (elmtui.examples.runner::%resolve-example-file name))
         (pkg-designator (elmtui.examples.runner::%read-example-package-designator file)))
    (find-package pkg-designator)))

(defun %registered-app-config-for-example (name app-name)
  (%assert-example-loads-and-has-entry name)
  (let* ((pkg (%example-package name))
         (app-symbol (and pkg (intern app-name pkg))))
    (and app-symbol
         (gethash app-symbol elmtui.core.globals:*applications*))))

(defun %registered-app-configs-for-example (name app-name)
  (let ((config (%registered-app-config-for-example name app-name)))
    (if config (list config) nil)))

(defun %keyword-headed-dsl-p (dsl)
  (and (consp dsl)
       (keywordp (first dsl))))

(defun %assert-current-example-dsl-contract (name app-name)
  (let ((configs (%registered-app-configs-for-example name app-name)))
    (is (= 1 (length configs))
        "Example ~A should expose exactly one known defapplication config." name)
    (let* ((config (first configs))
           (root (and config (app-config-root-component-dsl config)))
           (view-fn (and config (app-config-view-fn-sym config))))
      (is (app-config-p config))
      (is (%keyword-headed-dsl-p root)
          "Example ~A root DSL must be a keyword-headed DSL node." name)
      (is (eq :root-viewport (first root))
          "Example ~A must use defapplication's current root viewport wrapping contract." name)
      (is (getf (rest root) :id)
          "Example ~A root DSL must carry an :id." name)
      (is (and view-fn (fboundp view-fn))
          "Example ~A must expose a callable wrapped view function." name))))

(test tmux-hover-wrapper-delegates-to-maintained-inspector
  "Hover is a compatibility runner; cursor-inspector owns the one TEA app."
  (asdf:load-system "elmtui-examples")
  (%assert-example-loads-and-has-entry "tmux-hover-demo")
  (let* ((pkg (%example-package "tmux-hover-demo"))
         (runner (find-symbol "RUN-TMUX-HOVER-INSPECTOR" pkg)))
    (is (and runner (fboundp runner)))))

(test maintained-examples-load
  (asdf:load-system "elmtui")
  (dolist (example *maintained-examples*)
    (destructuring-bind (name app-name) example
      (%assert-current-example-dsl-contract name app-name))))

(defun %latest-app-config-for-example (name app-name)
  (first (%registered-app-configs-for-example name app-name)))

(defun %render-initialized-example (example-name package-name app-name)
  (%assert-example-loads-and-has-entry example-name)
  (let* ((pkg (find-package package-name))
         (app-symbol (intern app-name pkg))
         (init-symbol (intern (format nil "INITIALIZE-APP-STATE-~A" app-name) pkg))
         (config (gethash app-symbol elmtui.core.globals:*applications*))
         (view-fn (and config (app-config-view-fn-sym config))))
    (multiple-value-bind (state commands)
        (funcall init-symbol)
      (declare (ignore commands))
      (funcall view-fn state))))

(test focus-simple-view-renders-from-initialized-app-state
  (asdf:load-system "elmtui")
  (let ((view (%render-initialized-example "focus-simple"
                                           "ELMTUI.EXAMPLES.FOCUS-SIMPLE"
                                           "FOCUS-SIMPLE-APP")))
    (is (eq :root-viewport (first view)))
    (is (search "Cancel" (prin1-to-string view) :test #'char-equal))
    (is (search "OK" (prin1-to-string view) :test #'char-equal))))

(test keymap-app-view-renders-from-initial-state
  (asdf:load-system "elmtui")
  (let ((view (%render-initialized-example "keymap-app"
                                           "ELMTUI.EXAMPLES.KEYMAP-APP"
                                           "KEYMAP-EXAMPLE-APP")))
    (is (eq :root-viewport (first view)))
    (is (search "COUNTER-A" (prin1-to-string view) :test #'char-equal))
    (is (search "10" (prin1-to-string view) :test #'char-equal))))

(test mini-rainbow-view-is-visible-and-sized
  (asdf:load-system "elmtui")
  (%assert-example-loads-and-has-entry "mini-rainbow")
  (let* ((pkg (find-package :elmtui.examples.mini-rainbow))
         (view-fn (symbol-function (find-symbol "VIEW" pkg)))
         (view (funcall view-fn (list :orientation :row)))
         (style (getf (rest view) :style))
         (width (getf style :width))
         (height (getf style :height))
         (rendered (prin1-to-string view)))
    (is (numberp width))
    (is (numberp height))
    (is (> width 0))
    (is (> height 0))
    (is (not (search ":AUTO" rendered :test #'char-equal)))
    (is (search "#" rendered))))

(test wifi-menu-parses-escaped-nmcli-output
  (%assert-example-loads-and-has-entry "wifi-menu")
  (let* ((pkg (find-package :elmtui.examples.wifi-menu))
         (parse (symbol-function (find-symbol "PARSE-NMCLI-WIFI-OUTPUT" pkg)))
         (active-p (symbol-function (find-symbol "WIFI-NETWORK-ACTIVE-P" pkg)))
         (ssid (symbol-function (find-symbol "WIFI-NETWORK-SSID" pkg)))
         (bssid (symbol-function (find-symbol "WIFI-NETWORK-BSSID" pkg)))
         (signal (symbol-function (find-symbol "WIFI-NETWORK-SIGNAL" pkg)))
         (networks (funcall parse
                            (format nil "*:Cafe\\:Lab:AA\\:BB\\:CC\\:DD\\:EE\\:FF:77:WPA2:wlan0~% :Guest:11\\:22\\:33\\:44\\:55\\:66:42:--:wlan0~%"))))
    (is (= 2 (length networks)))
    (is (funcall active-p (first networks)))
    (is (string= "Cafe:Lab" (funcall ssid (first networks))))
    (is (string= "AA:BB:CC:DD:EE:FF" (funcall bssid (first networks))))
    (is (= 77 (funcall signal (first networks))))))

(test wifi-menu-connect-argv-never-contains-password
  (%assert-example-loads-and-has-entry "wifi-menu")
  (let* ((pkg (find-package :elmtui.examples.wifi-menu))
         (make-network (symbol-function (find-symbol "MAKE-WIFI-NETWORK" pkg)))
         (connect-argv (symbol-function (find-symbol "WIFI-CONNECT-ARGV" pkg)))
         (network (funcall make-network :ssid "Lab WiFi" :bssid "AA:BB:CC:DD:EE:FF"
                           :signal 70 :security "WPA2" :device "wlan0"))
         (argv (funcall connect-argv network :ask-for-secrets t)))
    (is (member "--ask" argv :test #'string=))
    (is (member "Lab WiFi" argv :test #'string=))
    (is (member "wlan0" argv :test #'string=))
    (is (null (find "correct horse battery staple" argv :test #'string=)))
    (is (null (find "password" argv :test #'string=)))))

(test maintained-example-wrappers-delegate-to-generated-runners
  (dolist (spec '(("focus-simple" "ELMTUI.EXAMPLES.FOCUS-SIMPLE" "RUN-FOCUS-SIMPLE" "RUN-FOCUS-SIMPLE-APP"
                    (:backend-type :fake) (:platform :fake :platform-options nil :argv nil))
                  ("dirli" "ELMTUI.EXAMPLES.DIRLI" "RUN-DIRLI" "RUN-DIRLI-APP"
                    (:backend-type :fake) (:platform :fake :platform-options nil :argv nil))
                  ("pong-below-cursor" "ELMTUI.EXAMPLES.PONG-BELOW-CURSOR" "RUN-PONG-BELOW-CURSOR" "RUN-PONG-BELOW-CURSOR-APP"
                    (:backend-type :fake) (:platform :fake))
                  ("scroll-panel-demo" "ELMTUI.EXAMPLES.SCROLL-PANEL-DEMO" "RUN-SCROLL-PANEL-DEMO" "RUN-SCROLL-PANEL-DEMO-APP"
                    (:backend-type :fake) (:platform :fake))
                  ("wifi-menu" "ELMTUI.EXAMPLES.WIFI-MENU" "RUN-WIFI-MENU" "RUN-WIFI-MENU-APP"
                    (:backend-type :fake) (:platform :fake :platform-options nil :argv nil))))
    (destructuring-bind (example package-name wrapper-name runner-name call-args expected-args) spec
      (%assert-example-loads-and-has-entry example)
      (let* ((pkg (find-package package-name))
             (wrapper (find-symbol wrapper-name pkg))
             (runner (find-symbol runner-name pkg))
             (original (symbol-function runner))
             (captured :not-called))
        (unwind-protect
             (progn
               (setf (symbol-function runner)
                     (lambda (&rest args) (setf captured args) :delegated))
               (is (eq :delegated (apply wrapper call-args)))
               (is (equal expected-args captured)))
          (setf (symbol-function runner) original))))))

(test fzf-finder-preserves-caller-items-and-prompt
  (%assert-example-loads-and-has-entry "fzf-finder-real")
  (let* ((pkg (find-package :elmtui.examples.fzf-finder))
         (show (find-symbol "SHOW-FZF-FINDER" pkg))
         (runner (find-symbol "RUN-FZF-FINDER" pkg))
         (items-symbol (find-symbol "*FINDER-INITIAL-ITEMS*" pkg))
         (prompt-symbol (find-symbol "*FINDER-INITIAL-PROMPT*" pkg))
         (original (symbol-function runner))
         (captured-items nil)
         (captured-prompt nil))
    (unwind-protect
         (progn
           (setf (symbol-function runner)
                 (lambda (&rest args)
                   (declare (ignore args))
                   (setf captured-items (copy-list (symbol-value items-symbol))
                         captured-prompt (symbol-value prompt-symbol))
                   :delegated))
           (is (eq :delegated (funcall show '("one" "two") :prompt "pick> " :backend-type :fake)))
           (is (equal '("one" "two") captured-items))
           (is (string= "pick> " captured-prompt)))
      (setf (symbol-function runner) original))))

(test maintained-examples-render-real-initial-frames
  "Resolve and paint every maintained example using the application initializer."
  (asdf:load-system :elmtui-examples)
  (dolist (entry *maintained-examples*)
    (destructuring-bind (example-name app-name) entry
      (let* ((config (%registered-app-config-for-example example-name app-name))
             (pkg (%example-package example-name))
             (init (find-symbol (format nil "INITIALIZE-APP-STATE-~A" app-name) pkg))
             (view (and config (app-config-view-fn-sym config)))
             (root (and config (app-config-root-component-dsl config)))
             (root-id (and root (getf (rest root) :id))))
        (is-true init "Initializer exists for ~A" example-name)
        (when (and config init root-id view)
          (multiple-value-bind (state commands) (funcall init)
            (declare (ignore commands))
            (let ((root-entry (elmtui.state.api:state-ref
                                state (list :components root-id))))
              (is-true root-entry "Canonical viewport exists for ~A" example-name))
            (dolist (entry '((:terminal-size (100 35)) (:size-known t)
                              (:pos-known t) (:first-ready-done t)
                              (:cursor-pos (1 1)) (:width 100)
                              (:height 30) (:offset-x 0) (:offset-y 0)))
              (setf (elmtui.state.api:state-ref
                      state (list :components root-id (first entry)))
                    (second entry)))
            (let* ((rect (elmtui.view.geo:make-rectangle
                           :pos (elmtui.view.geo:make-pos :x 0 :y 0)
                           :size (elmtui.view.geo:make-size :w 100 :h 35)))
                   (ctx (elmtui.contracts:make-app-context
                          :state state :view-fn (symbol-function view)
                          :viewport-rect rect))
                   (out (elmtui.pipeline:render-pipeline-0-to-5 ctx)))
              (is-true (elmtui.contracts:ctx-laid-out-tree out)
                       "Layout resolves for ~A" example-name)
              (is-true (elmtui.contracts:ctx-back-buffer out)
                       "Paint buffer exists for ~A" example-name))))))))

(test repaired-examples-have-deterministic-visible-native-views
  "Dirli rows, rainbow bands and key tester content are terminal DSL, not empty boxes."
  (asdf:load-system :elmtui-examples)
  (dolist (entry '(("dirli" "ELMTUI.EXAMPLES.DIRLI" "APP-VIEW" "DIRLI")
                   ("rainbow-app" "ELMTUI.EXAMPLES.RAINBOW-APP" "RAINBOW-CONTENT-VIEW" "CHROMATIC")
                   ("mini-rainbow" "ELMTUI.EXAMPLES.MINI-RAINBOW" "VIEW" "RAINBOW / mini")
                   ("key-tester" "ELMTUI-EXAMPLES.KEY-TESTER" "KEY-TESTER-VIEW" "Key Tester")))
    (destructuring-bind (name package view-name title) entry
      (let* ((config (%registered-app-config-for-example
                      name (second (assoc name *maintained-examples* :test #'string=))))
             (init-symbol (find-symbol
                           (format nil "INITIALIZE-APP-STATE-~A"
                                   (second (assoc name *maintained-examples* :test #'string=)))
                           package))
             (state (funcall (symbol-function init-symbol)))
             (view (symbol-function (find-symbol view-name package)))
             (first-view (funcall view state))
             (second-view (funcall view state)))
        (declare (ignore config))
        (is (equal first-view second-view)
            "Unchanged state must give stable DSL for ~A" name)
        (is (search title (prin1-to-string first-view) :test #'char-equal)
            "~A must expose visible output text" name)))))

(test dirli-key-navigation-does-not-enter-directory-implicitly
  (asdf:load-system :elmtui-examples)
  (let* ((pkg (find-package "ELMTUI.EXAMPLES.DIRLI"))
         (initial (funcall (symbol-function (find-symbol "%DIRLI-INITIAL-STATE" pkg))))
         (update (symbol-function (find-symbol "APP-UPDATE" pkg)))
         (before (elmtui.ui.widgets.listbox:listbox-model-selected-index
                  (getf initial :listbox-model)))
         (result (funcall update
                          (elmtui.core.event-types:make-key-event :key :arrow-down)
                          initial)))
    (is (null (elmtui.state.api:ur-commands result)))
    (is (equal before
               (elmtui.ui.widgets.listbox:listbox-model-selected-index
                (getf initial :listbox-model))))
    (is (assoc '(:listbox-model)
               (elmtui.state.api:ur-patches result) :test #'equal))))

(test key-tester-edits-copy-without-corrupting-previous-model
  (asdf:load-system :elmtui-examples)
  (let* ((pkg (find-package "ELMTUI-EXAMPLES.KEY-TESTER"))
         (initial (funcall (symbol-function (find-symbol "%KEY-TESTER-INITIAL-STATE" pkg))))
         (update (symbol-function (find-symbol "KEY-TESTER-UPDATE" pkg)))
         (typed (funcall update
                         (elmtui.core.event-types:make-key-event :key :a :char #\a)
                         initial))
         (component (second (assoc '(:component)
                                   (elmtui.state.api:ur-patches typed) :test #'equal))))
    (is (equal "" (example.key-tester::key-tester-input
                   (getf initial :component))))
    (is (string= "a" (example.key-tester::key-tester-input component)))
    (let* ((next-state (list :component component))
           (backspace (funcall update
                               (elmtui.core.event-types:make-key-event :key :backspace)
                               next-state))
           (revised (second (assoc '(:component)
                                   (elmtui.state.api:ur-patches backspace)
                                   :test #'equal))))
      (is (string= "" (example.key-tester::key-tester-input revised)))
      (is (string= "a" (example.key-tester::key-tester-input component))))))

(test root-viewport-q-exits-for-character-bearing-events
  "Printable keys carry :CHAR even when KEY is not a character."
  (asdf:load-system :elmtui-examples)
  (let* ((pkg (find-package :elmtui.examples.root-viewport-test-app))
         (update (symbol-function (find-symbol "ROOT-VIEWPORT-TEST-UPDATE" pkg)))
         (result (funcall update
                          (elmtui.core.event-types:make-key-event
                           :key :character :char #\q)
                          '(:offset-x 0 :offset-y 0))))
    (is (equal '(((:should-quit) t))
               (elmtui.state.api:ur-patches result)))))

(defun %buffer-text (buffer)
  (with-output-to-string (stream)
    (loop for row below
          (elmtui.platform.backend.common.virtual-buffer:buffer-height buffer)
          do (loop for col below
                   (elmtui.platform.backend.common.virtual-buffer:buffer-width buffer)
                   do (write-char
                       (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char
                        (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at buffer row col))
                       stream)))))

(test input-selector-initial-frame-renders-options
  "The real initial paint buffer contains the selector's first option."
  (asdf:load-system :elmtui-examples)
  (let* ((pkg (find-package :elmtui.examples.input-selector))
         (app (find-symbol "INPUT-SELECTOR-APP" pkg))
         (init (find-symbol "INITIALIZE-APP-STATE-INPUT-SELECTOR-APP" pkg))
         (config (gethash app elmtui.core.globals:*applications*))
         (view (elmtui.app.api:app-config-view-fn-sym config))
         (root-id (getf (rest (elmtui.app.api:app-config-root-component-dsl config)) :id)))
    (multiple-value-bind (state commands) (funcall init)
      (declare (ignore commands))
      (dolist (entry '((:terminal-size (100 35)) (:size-known t)
                       (:pos-known t) (:first-ready-done t) (:cursor-pos (1 1))
                       (:width 100) (:height 30) (:offset-x 0) (:offset-y 0)))
        (setf (elmtui.state.api:state-ref state
                 (list :components root-id (first entry)))
              (second entry)))
      (let* ((rect (elmtui.view.geo:make-rectangle
                     :pos (elmtui.view.geo:make-pos :x 0 :y 0)
                     :size (elmtui.view.geo:make-size :w 100 :h 35)))
             (ctx (elmtui.contracts:make-app-context
                    :state state :view-fn (symbol-function view) :viewport-rect rect))
             (out (elmtui.pipeline:render-pipeline-0-to-5 ctx)))
        (is (search "Option 1"
                    (%buffer-text (elmtui.contracts:ctx-back-buffer out))))))))

(test mini-editor-control-q-routes-through-unsaved-guard
  "The editor-specific C-q binding must reach its dirty-buffer quit guard."
  (asdf:load-system :elmtui-examples)
  (elmtui.keymaps:initialise)
  (let* ((pkg (find-package :elmtui.examples.mini-text-editor))
         (init (symbol-function (find-symbol "%INITIAL-STATE" pkg)))
         (update (symbol-function (find-symbol "EDITOR-UPDATE" pkg)))
         (state (copy-list (funcall init)))
         (messages nil))
    (setf (getf state :dirty) t)
    (elmtui.keymaps:process-key-event
     (elmtui.core.event-types:make-key-event :key #\q :modifiers '(:ctrl))
     nil :app-state state
     :dispatch-fn (lambda (message)
                    (push (if (equal message '(:quit))
                              '(:app-quit-requested)
                              message)
                          messages)))
    (is (equal '((:editor-request-quit)) messages))
    (let ((result (funcall update (first messages) state)))
      (is (search "Unsaved changes"
                  (prin1-to-string (elmtui.state.api:ur-patches result))
                  :test #'char-equal)))))

(defparameter *support-only-example-components*
  '("neon-kit" "tmux-hover-demo"))

(defparameter *optional-example-files*
  '("async-weather" "fzy-picker" "tmux-glider" "tmux-slider" "workbench"))

(test example-source-inventory-is-classified-and-smoke-covered
  "Default ASDF files, optional files, and README classifications stay aligned."
  (asdf:load-system :elmtui-examples)
  (let* ((components
           (mapcar #'asdf:component-name
                   (asdf:component-children (asdf:find-system "elmtui-examples"))))
         (maintained (mapcar #'first *maintained-examples*))
         (accounted (append maintained *support-only-example-components*))
         (source-files (mapcar #'pathname-name (directory #P"examples/*.lisp")))
         (classified-files (append components *optional-example-files*))
         (readme (uiop:read-file-string "examples/README.md")))
    (is (null (set-difference components accounted :test #'string=))
        "Every default component must be smoke-covered or support-only: ~S"
        (set-difference components accounted :test #'string=))
    (is (null (set-difference accounted components :test #'string=))
        "Smoke/support entries must be default system components: ~S"
        (set-difference accounted components :test #'string=))
    (is (null (set-difference source-files classified-files :test #'string=))
        "Every top-level Lisp example must be default or explicitly optional: ~S"
        (set-difference source-files classified-files :test #'string=))
    (is (null (set-difference classified-files source-files :test #'string=))
        "Inventory entries must resolve to real top-level Lisp files: ~S"
        (set-difference classified-files source-files :test #'string=))
    (dolist (name source-files)
      (is (search (format nil "`~A.lisp`" name) readme)
          "README must classify ~A.lisp" name))
    (is (search "`examples/support/fzy-loader.lisp`" readme)
        "The nested optional-system loader must be classified too.")))

(test examples-cli-list-excludes-support-and-script-files
  "The CLI list includes runnable apps, not support sources or standalone scripts."
  (let ((names (elmtui.examples.runner:list-implemented-examples)))
    (is (member "async-weather" names :test #'string=))
    (is (member "neon-glider" names :test #'string=))
    (is (not (member "neon-kit" names :test #'string=)))
    (is (not (member "workbench" names :test #'string=)))))

(test examples-cli-rejects-support-files-with-a-specific-error
  "Support sources fail before they are treated as runnable applications."
  (dolist (runner (list #'elmtui.examples.runner::run-example
                        #'elmtui.examples.runner::build-example-binary))
    (let ((message
            (handler-case
                (progn (funcall runner "neon-kit") nil)
              (error (condition) (princ-to-string condition)))))
      (is (search "no examples CLI runner" message :test #'char-equal)))))
