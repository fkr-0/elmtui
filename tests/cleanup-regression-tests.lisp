(uiop:define-package :elmtui.tests.cleanup-regressions
  (:use :cl :fiveam)
  (:import-from :elmtui.utils
                #:string-prefix-p
                #:split-string-literal)
  (:export #:cleanup-regressions-suite))

(in-package :elmtui.tests.cleanup-regressions)

(def-suite cleanup-regressions-suite
  :in elmtui.tests:elmtui-test
  :description "Regression tests for architecture cleanup and stale-file pruning.")

(in-suite cleanup-regressions-suite)

(defun %elmtui-root ()
  (asdf:system-source-directory "elmtui"))

(defun %project-file (relative)
  (merge-pathnames relative (%elmtui-root)))

(defun %file-text (relative)
  (with-open-file (in (%project-file relative) :direction :input)
    (let* ((len (file-length in))
           (buf (make-string len)))
      (read-sequence buf in)
      buf)))

(test legacy-app-dsl-registry-package-is-gone
  "The transitional app-side DSL registry package should no longer be loaded."
  (is (null (find-package :elmtui.app.dsl-type-registry))))

(test stale-widget-files-pruned-from-main-tree
  "Non-loaded legacy widget files should be removed from src/ui/widgets."
  (dolist (relative '("src/ui/widgets/layout2.lisp"
                      "src/ui/widgets/panel.lisp"
                      "src/ui/widgets/form.lisp"
                      "src/ui/widgets/table.lisp"))
    (is (null (probe-file (%project-file relative)))
        "Expected stale file to be removed: ~A"
        relative)))

(test state-update-has-no-runtime-symbol-probing
  "State update should call core async interpreter directly without package probing."
  (let ((text (%file-text "src/state/update.lisp")))
    (is-false (search "find-package" text))
    (is-false (search "find-symbol" text))))

(test state-update-uses-cl-state-path-context-boundary
  "State update path composition should route through cl-state boundary module."
  (let ((text (%file-text "src/state/update.lisp")))
    (is-true (search "elmtui.cl-state.path-context" text))
    (is-false (search "(defun %full-path" text))))

(test contracts-no-runtime-symbol-fallback-for-message-validation
  "Contracts typed validation should use canonicalization API, not find-symbol probing."
  (let ((text (%file-text "src/contracts.lisp")))
    (is-false (search "find-symbol" text))))

(test runtime-protocol-boundary-used-by-driver
  "Driver dispatch uses the runtime protocol; option validation uses the public API."
  (let ((text (%file-text "src/platform/driver.lisp")))
    (is-true (search "elmtui.runtime.protocol" text))
    (is-false (search "elmtui.app::dispatch-to-root" text))
    (is-true (search "elmtui.app.api:validate-platform-options" text))))

(test system-events-delegate-to-cl-events
  "System event constructors should delegate through cl-events boundary."
  (let ((text (%file-text "src/core/system-events.lisp")))
    (is-true (search "cl-events.system-events" text))
    (is-false (search "(defmsg SystemEvent" text))))

(test platform-input-uses-cl-inputs-normalization-boundary
  "Platform input should consume cl-inputs adapters instead of local token decoding."
  (let ((text (%file-text "src/platform/input.lisp")))
    (is-true (search "cl-inputs.adapters" text))
    (is-true (search "token->normalized-event" text))
    (is-false (search "normalize-key-symbol" text))))

(test terminal-style-conversion-uses-cl-styles-adapter
  "Terminal style conversion should normalize through cl-styles adapter boundary."
  (let ((text (%file-text "src/platform/backend/terminal/terminal.lisp")))
    (is-true (search "cl-styles.adapters" text))
    (is-true (search "normalize-tui-style-plist" text))))

(test flex-layout-has-no-runtime-layout-probing
  "Flex layout should dispatch through canonical layout-node, not runtime package probes."
  (let ((text (%file-text "src/view/layout/flex.lisp")))
    (is-false (search "find-package" text))
    (is-false (search "(intern \"COMPUTE-LAYOUT\"" text))
    (is-false (search "(intern \"LAYOUT-NODE\"" text))))

(test keymap-archive-packages-removed
  "Archived keymap packages should not be present after cleanup."
  (dolist (pkg '(:elmtui.core.keymap
                 :elmtui.core.keymap.registry
                 :elmtui.core.keymap.sequence
                 :elmtui.core.keymap.event-integration
                 :elmtui.core.keymap-system))
    (is (null (find-package pkg)) "Expected package to be removed: ~S" pkg)))

(test legacy-platform-subtree-archived
  "Legacy platform source subtree should be absent from the main src tree."
  (is (null (probe-file (%project-file "src/platform/legacy/")))))

(defun %allowed-runtime-probe-file-p (relative)
  (or (string-prefix-p "src/dev/" relative)
      (string-prefix-p "src/workbench/" relative)
      (string= relative "src/view/base-elements.lisp")))

(test runtime-probes-confined-to-allowed-files
  "Mainline src/ should not contain find-package/find-symbol except approved extension points."
  (let* ((cmd (list "rg" "-n" "find-package|find-symbol" "src"))
         (out (uiop:run-program cmd :output :string :ignore-error-status t))
         (lines (remove-if (lambda (s) (or (null s) (string= s "")))
                           (split-string-literal #\Newline out))))
    (dolist (line lines)
      (let* ((parts (split-string-literal ":" line :limit 3))
             (file (first parts)))
        (is-true (%allowed-runtime-probe-file-p file)
                 "Disallowed runtime probe occurrence: ~A" line)))))

(test message-normalization-boundary-does-not-redefine-state-symbols
  "Boundary wrappers must not import and redefine elmtui.state.msg symbols."
  (is-false (eq 'elmtui.cl-state.message-normalization:canonicalize-message-variant
                'elmtui.state.msg:canonicalize-message-variant))
  (is-false (eq 'elmtui.cl-state.message-normalization:message-variant-p
                'elmtui.state.msg:message-variant-p)))
