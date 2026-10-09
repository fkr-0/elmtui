(require :asdf)

(asdf:load-system "cl-state")

(in-package :cl-user)

(defun %state-bench-fresh (width) (let ((branches nil)) (dotimes (i width) (setf branches (list* (intern (format nil "K~D" i) :keyword) (list :value i :payload (vector i (1+ i) (+ i 2))) branches))) (cl-state.core:make-state :initial (list :branches branches))))

(defun %state-bench-measure (fn) #+sbcl (sb-ext:gc :full t) (let ((before #+sbcl (sb-ext:get-bytes-consed) #-sbcl 0) (start (get-internal-real-time))) (let ((result (funcall fn))) (values (/ (- (get-internal-real-time) start) internal-time-units-per-second) (- #+sbcl (sb-ext:get-bytes-consed) #-sbcl 0 before) result))))

(defun %state-bench-transactional (width iterations path) (let ((state (%state-bench-fresh width))) (dotimes (step iterations state) (cl-state.patch:apply-patches state (list (list path step))))))

(defun %state-bench-eager (width iterations path) (let ((state (%state-bench-fresh width))) (dotimes (step iterations state) (setf state (cl-state.patch:apply-patches-persistent state (list (list path step)) :name :bench-eager)))))

(defun %state-bench-shared (width iterations path) (let ((state (%state-bench-fresh width))) (dotimes (step iterations state) (setf state (cl-state.patch::apply-patches-shared state (list (list path step)) :name :bench-shared)))))

(defun %state-bench-env-int (name default) (or (ignore-errors (parse-integer (or (uiop:getenv name) ""))) default))

(defun %state-bench-report (width iterations tx-seconds tx-bytes eager-seconds eager-bytes shared-seconds shared-bytes) (format t "STATE-BENCH width=~D iterations=~D~%" width iterations) (format t "transactional sec=~,6F bytes=~D~%" tx-seconds tx-bytes) (format t "eager sec=~,6F bytes=~D~%" eager-seconds eager-bytes) (format t "shared sec=~,6F bytes=~D~%" shared-seconds shared-bytes) (format t "shared/eager time=~,4F alloc=~,4F~%" (/ shared-seconds eager-seconds) (/ shared-bytes (float eager-bytes))) (format t "shared/transaction time=~,4F alloc=~,4F~%" (/ shared-seconds tx-seconds) (/ shared-bytes (float tx-bytes))))

(defun run-state-semantics-benchmark () (let* ((width (%state-bench-env-int "ELMTUI_STATE_BENCH_WIDTH" 2000)) (iterations (%state-bench-env-int "ELMTUI_STATE_BENCH_ITERS" 120)) (path (list :branches (intern (format nil "K~D" (floor width 2)) :keyword) :value)) (tx (multiple-value-list (%state-bench-measure (lambda () (%state-bench-transactional width iterations path))))) (eager (multiple-value-list (%state-bench-measure (lambda () (%state-bench-eager width iterations path))))) (shared (multiple-value-list (%state-bench-measure (lambda () (%state-bench-shared width iterations path)))))) (unless (= (cl-state.core:state-ref (third tx) path) (cl-state.core:state-ref (third eager) path) (cl-state.core:state-ref (third shared) path)) (error "State semantics benchmark detected divergent final state.")) (apply #'%state-bench-report width iterations (append (subseq tx 0 2) (subseq eager 0 2) (subseq shared 0 2)))))

(run-state-semantics-benchmark)
