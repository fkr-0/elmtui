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
    ("mini-rainbow" "MINI-RAINBOW")
    ("pong-below-cursor" "PONG-BELOW-CURSOR-APP")
    ("rainbow-app" "RAINBOW-EXAMPLE-APP")
    ("root-viewport-test-app" "ROOT-VIEWPORT-TEST-APP")
    ("scroll-panel-demo" "SCROLL-PANEL-DEMO-APP")
    ("tmux-hover-demo" "TMUX-HOVER-APP")
    ("tmux-idle-screensaver" "TMUX-IDLE-APP")))

(defparameter *dropped-legacy-example-files*
  '("examples/boxes-app.lisp"
    "examples/colorblocks-app.lisp"
    "examples/colortext-app.lisp"
    "examples/comprehensive-widgets-demo.lisp"
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
    (is (search ":BUTTON" (prin1-to-string view) :test #'char-equal))))

(test keymap-app-view-renders-from-initial-state
  (asdf:load-system "elmtui")
  (%assert-example-loads-and-has-entry "keymap-app")
  (let* ((app-symbol (intern "KEYMAP-EXAMPLE-APP" "ELMTUI.EXAMPLES.KEYMAP-APP"))
         (config (gethash app-symbol elmtui.core.globals:*applications*))
         (view-fn (and config (app-config-view-fn-sym config)))
         (state (and config (copy-list (elmtui.app.api:app-config-initial-state-plist config))))
         (view (funcall view-fn state)))
    (is (eq :root-viewport (first view)))
    (is (search ":COUNTER" (prin1-to-string view) :test #'char-equal))))

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
