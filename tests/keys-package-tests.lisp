;;;; tests/keys-package-tests.lisp — FiveAM suite for the elmtui.keys package.
;;;;
;;;; Verifies:
;;;; - All 6 symbols are external in ELMTUI.KEYS.
;;;; - All 5 deprecated symbols are still external in ELMTUI (backward compat).
;;;; - Symbols from both packages are EQ (same object, not copies).
;;;; - MAKE-KEY-EVENT is functional from ELMTUI.KEYS.
;;;; - KEY-EVENT-PARTS remains the recommended facade path.

(uiop:define-package :elmtui.tests.keys-package
  (:use :cl :fiveam)
  (:export #:keys-package-suite))

(in-package :elmtui.tests.keys-package)

(def-suite keys-package-suite
  :description "Tests for the elmtui.keys secondary package"
  :in elmtui.tests::elmtui-test)

(in-suite keys-package-suite)

;;;==============================================================
;;; Helper: check that a symbol is external in a package
;;;==============================================================

(defun symbol-external-p (name package-designator)
  "Return T if NAME (a string) is an external symbol in PACKAGE-DESIGNATOR."
  (multiple-value-bind (sym status)
      (find-symbol name package-designator)
    (declare (ignore sym))
    (eq status :external)))

;;;==============================================================
;;; 1. All 6 symbols are EXTERNAL in ELMTUI.KEYS
;;;==============================================================

(test keys-exports-key-event-external
  "KEY-EVENT is an external symbol of ELMTUI.KEYS."
  (is (symbol-external-p "KEY-EVENT" :elmtui.keys)))

(test keys-exports-key-event-p-external
  "KEY-EVENT-P is an external symbol of ELMTUI.KEYS."
  (is (symbol-external-p "KEY-EVENT-P" :elmtui.keys)))

(test keys-exports-key-event-key-external
  "KEY-EVENT-KEY is an external symbol of ELMTUI.KEYS."
  (is (symbol-external-p "KEY-EVENT-KEY" :elmtui.keys)))

(test keys-exports-key-event-char-external
  "KEY-EVENT-CHAR is an external symbol of ELMTUI.KEYS."
  (is (symbol-external-p "KEY-EVENT-CHAR" :elmtui.keys)))

(test keys-exports-key-event-modifiers-external
  "KEY-EVENT-MODIFIERS is an external symbol of ELMTUI.KEYS."
  (is (symbol-external-p "KEY-EVENT-MODIFIERS" :elmtui.keys)))

(test keys-exports-make-key-event-external
  "MAKE-KEY-EVENT is an external symbol of ELMTUI.KEYS."
  (is (symbol-external-p "MAKE-KEY-EVENT" :elmtui.keys)))

;;;==============================================================
;;; 2. All 5 deprecated symbols are still EXTERNAL in ELMTUI
;;;    (backward compatibility)
;;;==============================================================

(test facade-exports-key-event-external
  "KEY-EVENT is still an external symbol of the ELMTUI facade."
  (is (symbol-external-p "KEY-EVENT" :elmtui)))

(test facade-exports-key-event-p-external
  "KEY-EVENT-P is still an external symbol of the ELMTUI facade."
  (is (symbol-external-p "KEY-EVENT-P" :elmtui)))

(test facade-exports-key-event-key-external
  "KEY-EVENT-KEY is still an external symbol of the ELMTUI facade."
  (is (symbol-external-p "KEY-EVENT-KEY" :elmtui)))

(test facade-exports-key-event-char-external
  "KEY-EVENT-CHAR is still an external symbol of the ELMTUI facade."
  (is (symbol-external-p "KEY-EVENT-CHAR" :elmtui)))

(test facade-exports-key-event-modifiers-external
  "KEY-EVENT-MODIFIERS is still an external symbol of the ELMTUI facade."
  (is (symbol-external-p "KEY-EVENT-MODIFIERS" :elmtui)))

;;;==============================================================
;;; 3. Symbols from both packages are EQ (same object, not copies)
;;;==============================================================

(test key-event-is-eq
  "ELMTUI.KEYS:KEY-EVENT and ELMTUI:KEY-EVENT are the same symbol."
  (is (eq (find-symbol "KEY-EVENT" :elmtui.keys)
          (find-symbol "KEY-EVENT" :elmtui))))

(test key-event-p-is-eq
  "ELMTUI.KEYS:KEY-EVENT-P and ELMTUI:KEY-EVENT-P are the same symbol."
  (is (eq (find-symbol "KEY-EVENT-P" :elmtui.keys)
          (find-symbol "KEY-EVENT-P" :elmtui))))

(test key-event-key-is-eq
  "ELMTUI.KEYS:KEY-EVENT-KEY and ELMTUI:KEY-EVENT-KEY are the same symbol."
  (is (eq (find-symbol "KEY-EVENT-KEY" :elmtui.keys)
          (find-symbol "KEY-EVENT-KEY" :elmtui))))

(test key-event-char-is-eq
  "ELMTUI.KEYS:KEY-EVENT-CHAR and ELMTUI:KEY-EVENT-CHAR are the same symbol."
  (is (eq (find-symbol "KEY-EVENT-CHAR" :elmtui.keys)
          (find-symbol "KEY-EVENT-CHAR" :elmtui))))

(test key-event-modifiers-is-eq
  "ELMTUI.KEYS:KEY-EVENT-MODIFIERS and ELMTUI:KEY-EVENT-MODIFIERS are the same symbol."
  (is (eq (find-symbol "KEY-EVENT-MODIFIERS" :elmtui.keys)
          (find-symbol "KEY-EVENT-MODIFIERS" :elmtui))))

;;;==============================================================
;;; 4. make-key-event is functional from ELMTUI.KEYS
;;;==============================================================

(test make-key-event-from-keys-package
  "MAKE-KEY-EVENT from ELMTUI.KEYS creates a valid key-event."
  (let ((ev (elmtui.keys:make-key-event :type :key-down
                                         :key :a
                                         :char #\a
                                         :modifiers '(:control))))
    (is (elmtui.keys:key-event-p ev))
    (is (eq :a (elmtui.keys:key-event-key ev)))
    (is (eql #\a (elmtui.keys:key-event-char ev)))
    (is (equal '(:control) (elmtui.keys:key-event-modifiers ev)))))

(test make-key-event-cross-package-interop
  "A key-event created via ELMTUI.KEYS is recognized by ELMTUI:KEY-EVENT-P."
  (let ((ev (elmtui.keys:make-key-event :type :key-down :key :b)))
    ;; The predicate from the facade and from the keys package are the
    ;; same function, so both must agree.
    (is (funcall (symbol-function (find-symbol "KEY-EVENT-P" :elmtui)) ev))
    (is (elmtui.keys:key-event-p ev))))

;;;==============================================================
;;; 5. KEY-EVENT-PARTS remains the recommended facade path
;;;==============================================================

(test key-event-parts-in-facade
  "KEY-EVENT-PARTS is an external symbol of the ELMTUI facade."
  (is (symbol-external-p "KEY-EVENT-PARTS" :elmtui)))

(test key-event-parts-not-in-keys
  "KEY-EVENT-PARTS is not exported from ELMTUI.KEYS (it belongs to the facade)."
  (is (not (symbol-external-p "KEY-EVENT-PARTS" :elmtui.keys))))

(test key-event-parts-works-with-keys-struct
  "KEY-EVENT-PARTS (facade) works on a struct created via ELMTUI.KEYS."
  (let ((ev (elmtui.keys:make-key-event :type :key-down
                                         :key :escape
                                         :char nil
                                         :modifiers nil)))
    (multiple-value-bind (key char mods)
        (elmtui:key-event-parts ev)
      (is (eq :escape key))
      (is (null char))
      (is (null mods)))))
