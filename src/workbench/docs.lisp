(in-package :elmtui.workbench.completion)

(defun %selected-symbol (candidate)
  (typecase candidate
    (completion-candidate (completion-candidate-symbol candidate))
    (symbol candidate)))

(defun %selected-id (candidate)
  (typecase candidate
    (completion-candidate (completion-candidate-id candidate))
    (string candidate)
    (symbol (symbol-name candidate))))

(defun %function-arglist (symbol)
  (when (fboundp symbol)
    (ignore-errors (require :sb-introspect))
    (let* ((namespace (find-package "SB-INTROSPECT"))
           (accessor (and namespace (find-symbol "FUNCTION-LAMBDA-LIST" namespace))))
      (when (and accessor (fboundp accessor))
        (handler-case
            (return-from %function-arglist
              (values (funcall (symbol-function accessor) (fdefinition symbol)) t))
          (error () nil)))
      (ignore-errors
        (multiple-value-bind (expression closure name)
            (function-lambda-expression (fdefinition symbol))
          (declare (ignore closure name))
          (when (and (consp expression) (eq (first expression) 'lambda))
            (values (second expression) t)))))))

(defun signature-for (candidate)
  (let ((symbol (%selected-symbol candidate)))
    (when symbol
      (let ((*print-circle* t) (*print-length* 24) (*print-level* 5))
        (multiple-value-bind (arguments available)
            (%function-arglist symbol)
          (when available
            (format nil "(~A~{ ~S~})" (symbol-name symbol) arguments)))))))

(defun documentation-for (candidate &key (max-length 2048))
  (let ((symbol (%selected-symbol candidate)))
    (when symbol
      (let ((text (loop for kind in '(function variable type structure setf)
                        for value = (ignore-errors (documentation symbol kind))
                        when (and (stringp value) (plusp (length value)))
                          return value)))
        (when text
          (subseq text 0 (min (length text) (max 0 max-length))))))))

(defun schedule-documentation-dwell (state candidate generation
                                      &key (now (get-internal-real-time)) (delay-ms 450))
  (setf (documentation-dwell-state-generation state) generation
        (documentation-dwell-state-candidate-id state) (%selected-id candidate)
        (documentation-dwell-state-due-at state)
        (+ now (ceiling (* (max 0 delay-ms) internal-time-units-per-second) 1000)))
  state)

(defun cancel-documentation-dwell (state)
  (setf (documentation-dwell-state-generation state) nil
        (documentation-dwell-state-candidate-id state) nil
        (documentation-dwell-state-due-at state) nil)
  state)

(defun documentation-dwell-due-p (state generation candidate
                                   &key (now (get-internal-real-time)))
  (and (documentation-dwell-state-due-at state)
       (eql generation (documentation-dwell-state-generation state))
       (equal (%selected-id candidate) (documentation-dwell-state-candidate-id state))
       (>= now (documentation-dwell-state-due-at state))))

(defun consume-documentation-dwell (state generation candidate
                                     &key (now (get-internal-real-time)))
  (when (documentation-dwell-due-p state generation candidate :now now)
    (prog1 (list :wb-doc-dwell :generation generation
                 :candidate-id (documentation-dwell-state-candidate-id state))
      (cancel-documentation-dwell state))))
