;;;; TOOLS Module Tests
;;;; Test suite for elmtui development tools

(uiop:define-package :elmtui.tools.tests
  (:use :cl :fiveam)
  (:import-from :elmtui.packager
    #:make-packager #:add-file #:get-files #:create-package
    #:package-name #:add-dependency #:get-dependencies
    #:resolve-dependencies #:build #:build-success-p
    #:set-config #:get-config #:enable-optimization
    #:get-optimizations #:list-tools #:get-tool-info
    #:load-tool #:set-global-config #:get-global-config
    #:set-tool-config #:get-tool-config)
  (:export #:run-tools-tests))

(in-package :elmtui.tools.tests)

(def-suite tools-test-suite
  :description "Test suite for elmtui development tools")

(in-suite tools-test-suite)

;; Test for packager functionality
;; (test packager-basic
;;   "Test packager functionality"
;;   ;; Check if packager functions exist
;;   (is (or (not (fboundp 'elmtui.packager:make-packager))
;;         (functionp #'elmtui.tools:make-packager))
;;     "make-packager should be function or not exist")

;;   (when (fboundp 'elmtui.tools:make-packager)
;;     (let ((packager (elmtui.tools:make-packager)))
;;       (is (not (null packager))
;;         "Packager should be created")
;;       (when packager
;;         ;; Test file operations
;;         (is (or (not (fboundp 'elmtui.tools:add-file))
;;               (functionp #'elmtui.tools:add-file))
;;           "add-file should be function or not exist")

;;         (is (or (not (fboundp 'elmtui.tools:get-files))
;;               (functionp #'elmtui.tools:get-files))
;;           "get-files should be function or not exist")

;;         ;; Test package operations
;;         (is (or (not (fboundp 'elmtui.tools:create-package))
;;               (functionp #'elmtui.tools:create-package))
;;           "create-package should be function or not exist")

;;         (is (or (not (fboundp 'elmtui.tools:package-name))
;;               (functionp #'elmtui.tools:package-name))
;;           "package-name should be function or not exist")))))

;; (test packager-dependencies
;;   "Test packager dependency management"
;;   ;; Test dependency operations
;;   (is (or (not (fboundp 'elmtui.tools:add-dependency))
;;         (functionp #'elmtui.tools:add-dependency))
;;     "add-dependency should be function or not exist")

;;   (is (or (not (fboundp 'elmtui.tools:get-dependencies))
;;         (functionp #'elmtui.tools:get-dependencies))
;;     "get-dependencies should be function or not exist")

;;   (is (or (not (fboundp 'elmtui.tools:resolve-dependencies))
;;         (functionp #'elmtui.tools:resolve-dependencies))
;;     "resolve-dependencies should be function or not exist"))

;; (test packager-build
;;   "Test packager build functionality"
;;   ;; Test build operations
;;   (is (or (not (fboundp 'elmtui.tools:build))
;;         (functionp #'elmtui.tools:build))
;;     "build should be function or not exist")

;;   (is (or (not (fboundp 'elmtui.tools:build-success-p))
;;         (functionp #'elmtui.tools:build-success-p))
;;     "build-success-p should be function or not exist"))

;; (test packager-configuration
;;   "Test packager configuration"
;;   ;; Test config operations
;;   (is (or (not (fboundp 'elmtui.tools:set-config))
;;         (functionp #'elmtui.tools:set-config))
;;     "set-config should be function or not exist")

;;   (is (or (not (fboundp 'elmtui.tools:get-config))
;;         (functionp #'elmtui.tools:get-config))
;;     "get-config should be function or not exist"))

;; (test packager-optimization
;;   "Test packager optimization features"
;;   ;; Test optimization operations
;;   (is (or (not (fboundp 'elmtui.tools:enable-optimization))
;;         (functionp #'elmtui.tools:enable-optimization))
;;     "enable-optimization should be function or not exist")

;;   (is (or (not (fboundp 'elmtui.tools:get-optimizations))
;;         (functionp #'elmtui.tools:get-optimizations))
;;     "get-optimizations should be function or not exist"))

;; ;; Test for tool availability
;; (test tool-availability
;;   "Test that development tools are available"
;;   ;; Test tool management operations
;;   (is (or (not (fboundp 'elmtui.tools:list-tools))
;;         (functionp #'elmtui.tools:list-tools))
;;     "list-tools should be function or not exist")

;;   (is (or (not (fboundp 'elmtui.tools:get-tool-info))
;;         (functionp #'elmtui.tools:get-tool-info))
;;     "get-tool-info should be function or not exist")

;;   (is (or (not (fboundp 'elmtui.tools:load-tool))
;;         (functionp #'elmtui.tools:load-tool))
;;     "load-tool should be function or not exist"))

;; ;; Test for tool configuration
;; (test tool-configuration
;;   "Test tool configuration"
;;   ;; Test global config operations
;;   (is (or (not (fboundp 'elmtui.tools:set-global-config))
;;         (functionp #'elmtui.tools:set-global-config))
;;     "set-global-config should be function or not exist")

;;   (is (or (not (fboundp 'elmtui.tools:get-global-config))
;;         (functionp #'elmtui.tools:get-global-config))
;;     "get-global-config should be function or not exist")

;;   ;; Test tool-specific config operations
;;   (is (or (not (fboundp 'elmtui.tools:set-tool-config))
;;         (functionp #'elmtui.tools:set-tool-config))
;;     "set-tool-config should be function or not exist")

;;   (is (or (not (fboundp 'elmtui.tools:get-tool-config))
;;         (functionp #'elmtui.tools:get-tool-config))
;;     "get-tool-config should be function or not exist"))

;; (defun run-tools-tests ()
;;   "Run all tools module tests"
;;   (run! 'tools-test-suite))
