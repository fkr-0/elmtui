;;;; Scoped configuration contracts: validation, inheritance and unwind restoration.
(defpackage :elmtui.tests.coverage-defaults
  (:use :cl :fiveam)
  (:local-nicknames (:defaults :elmtui.core.defaults)))
(in-package :elmtui.tests.coverage-defaults)
(def-suite coverage-defaults-behavior-tests :in elmtui.tests:elmtui-test)
(in-suite coverage-defaults-behavior-tests)

(test default-registry-validates-values-and-reports-missing-keys
  (let ((defaults:*default-registry* (make-hash-table :test #'equal)))
    (defaults:register-default :limit 8 :type (integer 1 *) :category :dimensions
                               :documentation "Limit" :validator #'evenp)
    (is (= 8 (defaults:get-default :limit)))
    (is (= 8 (defaults:get-default-or-error :limit)))
    (is-false (defaults:get-default :missing))
    (signals error (defaults:get-default-or-error :missing))
    (is (= 99 (defaults::ensure-default-value :missing 99)))
    (is (= 2 (length (defaults::list-all-defaults))))
    (is (= 99 (defaults:get-default :missing)))
    (is (= 1 (length (defaults::list-defaults-by-category :dimensions))))
    (let ((printed (with-output-to-string (out)
                     (let ((*standard-output* out))
                       (is-true (defaults::validate-all-defaults))))))
      (is (search "All defaults are valid" printed)))
    (setf (defaults::default-spec-value (gethash :limit defaults:*default-registry*)) 3)
    (signals error (defaults:get-default :limit))
    (let ((printed (with-output-to-string (out)
                     (let ((*standard-output* out))
                       (is-false (defaults::validate-all-defaults))))))
      (is (search "LIMIT" printed)))))

(test invalid-default-fallback-is-explicit-and-does-not-replace-registration
  (let ((defaults:*default-registry* (make-hash-table :test #'equal)) (warnings 0))
    (defaults:register-default :limit "bad" :type integer :fallback 10)
    (handler-bind ((warning (lambda (condition) (incf warnings) (muffle-warning condition))))
      (is (= 10 (defaults:get-default :limit))))
    (is (= 1 warnings))
    (is (string= "bad" (defaults::default-spec-value (gethash :limit defaults:*default-registry*))))))

(test scoped-defaults-restore-after-return-and-error
  (let ((defaults:*default-registry* (make-hash-table :test #'equal)))
    (defaults:register-default :limit 8 :type integer)
    (let ((original defaults:*default-registry*))
      (defaults:with-defaults '(:limit 20) nil
        (is (= 20 (defaults:get-default :limit)))
        (defaults:with-defaults '(:limit 30) nil
          (is (= 30 (defaults:get-default :limit))))
        (is (= 20 (defaults:get-default :limit))))
      (is (eq original defaults:*default-registry*))
      (signals error (defaults:with-defaults '(:limit 40) nil (error "test unwind")))
      (is (eq original defaults:*default-registry*))
      (is (= 8 (defaults:get-default :limit))))))

(test child-default-context-overrides-parent
  (let ((defaults:*default-registry* (make-hash-table :test #'equal)))
    (defaults:register-default :limit 8 :type integer)
    (let* ((parent (defaults:make-default-context))
           (child (defaults:make-default-context parent)))
      (setf (gethash :limit (defaults::default-context-overrides parent)) 20
            (gethash :limit (defaults::default-context-overrides child)) 30)
      (let ((defaults:*default-registry*
              (defaults::make-context-aware-registry child defaults:*default-registry*)))
        (is (= 30 (defaults:get-default :limit))))
      (defaults:with-defaults '(:limit 40) child
        (is (= 40 (defaults:get-default :limit))))
      (is (= 8 (defaults:get-default :limit))))))

(test scoped-defaults-do-not-leak-into-another-thread
  ;; Deliberately do not dynamically bind the registry: ordinary callers must
  ;; not expose a WITH-DEFAULTS override through the global special value.
  (let ((key (gensym "SCOPED-DEFAULT-"))
        (original-registry defaults:*default-registry*))
    (unwind-protect
         (progn
           (defaults:register-default key 8 :type integer)
           (defaults:with-defaults (list key 20) nil
             (is (= 20 (defaults:get-default key)))
             (is (= 8 (bt:join-thread (bt:make-thread (lambda () (defaults:get-default key))))))))
      (remhash key original-registry))))
