(uiop:define-package :elmtui.tests.modal-dialog
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.widgets.modal-dialog
                #:open-modal-dialog #:modal-dialog-p #:modal-dialog-input
                #:modal-handle-key #:modal-dialog-lines #:modal-dialog-view)
  (:export #:modal-dialog-tests))
(in-package :elmtui.tests.modal-dialog)
(def-suite modal-dialog-tests :in elmtui.tests:elmtui-test)
(in-suite modal-dialog-tests)

(test prompt-lifecycle
  (let ((dialog (open-modal-dialog :kind :prompt
                                  :title "Save As" :return-focus :editor)))
    (is (modal-dialog-p dialog))
    (multiple-value-bind (next result)
        (modal-handle-key dialog :a #\a nil)
      (is (null result))
      (is (string= (modal-dialog-input dialog) ""))
      (is (string= (modal-dialog-input next) "a"))
      (multiple-value-bind (again result)
          (modal-handle-key next :backspace nil nil)
        (is (null result))
        (is (string= (modal-dialog-input again) "")))
      (multiple-value-bind (done result)
          (modal-handle-key next :enter nil nil)
        (is (null done))
        (is (eq (getf result :action) :accept))
        (is (string= (getf result :value) "a"))
        (is (eq (getf result :return-focus) :editor))))))

(test confirmation-traps-keys
  (let ((dialog (open-modal-dialog
                 :title "Unsaved"
                 :choices '((#\s . :save) (#\d . :discard)))))
    (multiple-value-bind (next result)
        (modal-handle-key dialog :up nil nil)
      (is (eq dialog next))
      (is (null result)))
    (multiple-value-bind (next result)
        (modal-handle-key dialog :d #\D nil)
      (is (null next))
      (is (eq (getf result :action) :discard)))
    (multiple-value-bind (next result)
        (modal-handle-key dialog :enter nil nil)
      (is (null next))
      (is (eq (getf result :action) :cancel)))
    (multiple-value-bind (next result)
        (modal-handle-key dialog :escape nil nil)
      (is (null next))
      (is (eq (getf result :action) :cancel)))))

(test prompt-validation-and-keyboard
  (let ((dialog (open-modal-dialog :kind :prompt :input "")))
    (multiple-value-bind (next result)
        (modal-handle-key dialog :enter nil nil)
      (is (eq next dialog))
      (is (null result)))
    (multiple-value-bind (next result)
        (modal-handle-key dialog :s #\s '(:control))
      (is (eq next dialog))
      (is (null result)))
    (multiple-value-bind (next result)
        (modal-handle-key dialog :unknown #\λ nil)
      (is (null result))
      (is (string= (modal-dialog-input next) "λ")))))

(test bounded-presentation
  (let* ((dialog (open-modal-dialog :kind :prompt
                                    :title "Save As"
                                    :input (concatenate 'string
                                                       (make-string 95 :initial-element #\x)
                                                       (string #\Newline)
                                                       "ok")))
         (lines (modal-dialog-lines dialog :width 48))
         (nodes (modal-dialog-view dialog :width 48)))
    (is (= 5 (length lines)))
    (is (= 5 (length nodes)))
    (is (every (lambda (line) (= 48 (length line))) lines))
    (is (every (lambda (line) (not (find #\Newline line))) lines))
    (is (every (lambda (node) (eq (first node) :text)) nodes))
    (is (search "ok" (third lines)))))

(test invalid-modal-configuration
  (signals error (open-modal-dialog :kind :other))
  (signals error (open-modal-dialog :choices '(("y" . :yes))))
  (signals error (modal-dialog-lines (open-modal-dialog) :width 8)))
