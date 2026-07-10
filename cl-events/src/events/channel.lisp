;;; src/events/channel.lisp
(in-package :cl-events.channel)

(defstruct (channel (:constructor %make-channel))
  queue lock not-empty not-full capacity closed-p)

(defstruct (filtered-channel (:constructor %make-filtered-channel))
  channel filters)

(defun %condition-broadcast (condition)
  "Wake all waiters on CONDITION when the implementation exposes broadcast.
Falls back to CONDITION-NOTIFY on Bordeaux-Threads implementations without it."
  (let* ((bt-broadcast (find-symbol "CONDITION-BROADCAST" :bt))
         (sb-broadcast (find-symbol "CONDITION-BROADCAST" :sb-thread))
         (fn (or (and bt-broadcast (fboundp bt-broadcast) (symbol-function bt-broadcast))
                 (and sb-broadcast (fboundp sb-broadcast) (symbol-function sb-broadcast)))))
    (if fn
        (funcall fn condition)
        (bt:condition-notify condition))))

(defun make-channel (&key (capacity 256))
  (%make-channel :queue (make-array capacity :adjustable nil :fill-pointer 0)
    :lock (bt:make-lock "chan-lock")
    :not-empty (bt:make-condition-variable :name "chan-not-empty")
    :not-full  (bt:make-condition-variable :name "chan-not-full")
    :capacity capacity))

(defun make-filtered-channel (&key (capacity 256) (filters nil))
  (%make-filtered-channel :channel (make-channel :capacity capacity)
                          :filters (copy-list filters)))

(defun channel-add-filter (ch filter)
  "Add FILTER to filtered channel CH. FILTER must be callable."
  (check-type filter function)
  (when (typep ch 'filtered-channel)
    (push filter (filtered-channel-filters ch)))
  ch)

(defun channel-remove-filter (ch filter)
  (when (typep ch 'filtered-channel)
    (setf (filtered-channel-filters ch)
          (remove filter (filtered-channel-filters ch))))
  ch)

(defun %filtered-pass-p (filters value)
  (every (lambda (f) (funcall f value)) filters))

(defun %chan-put (ch item)
  (bt:with-lock-held ((channel-lock ch))
    (loop while (and (>= (fill-pointer (channel-queue ch)) (channel-capacity ch))
                  (not (channel-closed-p ch)))
      do (bt:condition-wait (channel-not-full ch) (channel-lock ch)))
    (when (channel-closed-p ch) (return-from %chan-put nil))
    (vector-push-extend item (channel-queue ch))
    (bt:condition-notify (channel-not-empty ch))
    t))

(defun chan-put (ch item)
  (if (typep ch 'filtered-channel)
      (let ((filters (filtered-channel-filters ch)))
        (if (and filters (not (%filtered-pass-p filters item)))
            nil
            (%chan-put (filtered-channel-channel ch) item)))
      (%chan-put ch item)))

(defun %chan-take (ch)
  (bt:with-lock-held ((channel-lock ch))
    (loop while (and (zerop (fill-pointer (channel-queue ch)))
                  (not (channel-closed-p ch)))
      do (bt:condition-wait (channel-not-empty ch) (channel-lock ch)))
    (when (and (zerop (fill-pointer (channel-queue ch))) (channel-closed-p ch))
      (return-from %chan-take (values nil :closed)))
    ;; NOTE: O(n) shift due to array compaction. A ring-buffer with head/tail
    ;; pointers would give O(1) dequeue but requires a larger refactor.
    (let* ((q (channel-queue ch))
            (item (aref q 0)))
      (replace q q :start1 0 :start2 1 :end2 (fill-pointer q))
      (decf (fill-pointer q))
      (bt:condition-notify (channel-not-full ch))
      item)))

(defun chan-take (ch)
  (if (typep ch 'filtered-channel)
      (%chan-take (filtered-channel-channel ch))
      (%chan-take ch)))

(defun chan-close (ch)
  (let ((real-ch (if (typep ch 'filtered-channel)
                     (filtered-channel-channel ch)
                     ch)))
    (bt:with-lock-held ((channel-lock real-ch))
      (setf (channel-closed-p real-ch) t)
      (%condition-broadcast (channel-not-empty real-ch))
      (%condition-broadcast (channel-not-full real-ch))
      t)))

(defun no-wait (ch &key (send t))
  (let ((real-ch (if (typep ch 'filtered-channel)
                     (filtered-channel-channel ch)
                     ch)))
    (bt:with-lock-held ((channel-lock real-ch))
      (cond
        (send
         (if (or (channel-closed-p real-ch)
                 (>= (fill-pointer (channel-queue real-ch)) (channel-capacity real-ch)))
             (values nil nil)
             (values t t)))
        (t
         (if (zerop (fill-pointer (channel-queue real-ch)))
             (values nil nil)
             (let* ((q (channel-queue real-ch))
                    (item (aref q 0)))
               (replace q q :start1 0 :start2 1 :end2 (fill-pointer q))
               (decf (fill-pointer q))
               (bt:condition-notify (channel-not-full real-ch))
               (values item t))))))))

(defun channel-length (ch)
  "Return the current queue length of CH."
  (let ((real-ch (if (typep ch 'filtered-channel)
                     (filtered-channel-channel ch)
                     ch)))
    (bt:with-lock-held ((channel-lock real-ch))
      (fill-pointer (channel-queue real-ch)))))

(defun channel-put! (ch item)
  (chan-put ch item))

(defun channel-take! (ch)
  (chan-take ch))

(defun try-put (ch item)
  "Atomically check capacity and enqueue ITEM under the channel lock.
Returns T on success, NIL if channel is full or closed."
  (let ((real-ch (if (typep ch 'filtered-channel)
                     (filtered-channel-channel ch)
                     ch)))
    (when (and (typep ch 'filtered-channel)
               (filtered-channel-filters ch)
               (not (%filtered-pass-p (filtered-channel-filters ch) item)))
      (return-from try-put nil))
    (bt:with-lock-held ((channel-lock real-ch))
      (cond
        ((channel-closed-p real-ch) nil)
        ((>= (fill-pointer (channel-queue real-ch)) (channel-capacity real-ch)) nil)
        (t
         (vector-push-extend item (channel-queue real-ch))
         (bt:condition-notify (channel-not-empty real-ch))
         t)))))

(defun -> (ch item)
  (chan-put ch item))

(defun <- (ch)
  (chan-take ch))

(defmacro select (&rest args)
  "Usage: (select [:timeout SEC] (<- ch) (-> ch val) …)
Returns 2 values – DATA and CHANNEL – or NIL on timeout."
  (let* ((timeout-pos (position :timeout args))
         (timeout-form (when timeout-pos (nth (1+ timeout-pos) args)))
         (clause-forms (if timeout-pos
                           (append (subseq args 0 timeout-pos)
                                   (subseq args (+ timeout-pos 2)))
                           args)))
    (let ((clause-checks
            (mapcar
             (lambda (form)
               (etypecase form
                 ((cons (eql <-) (cons t null))
                  (let ((ch (second form)))
                    `(multiple-value-bind (val okp)
                         (no-wait ,ch :send nil)
                       (when okp (return (values val ,ch))))))
                 ((cons (eql ->) (cons t (cons t null)))
                  (let ((ch (second form))
                        (val (third form)))
                    `(when (try-put ,ch ,val)
                       (return (values t ,ch)))))))
             clause-forms)))
      (if timeout-form
          `(let ((deadline (+ (get-internal-real-time)
                              (* ,timeout-form internal-time-units-per-second))))
             (loop
               ,@clause-checks
               (when (> (get-internal-real-time) deadline)
                 (return nil))
               (sleep 0.001)))
          `(loop
             ,@clause-checks
             (sleep 0.001))))))

;;; Simple mailbox (single-slot, last-writer-wins)
(defstruct (mailbox (:constructor %make-mailbox))
  slot lock cv closed-p)

(defun make-mailbox () (%make-mailbox :lock (bt:make-lock "mb") :cv (bt:make-condition-variable)))
(defun mb-put (mb item)
  (bt:with-lock-held ((mailbox-lock mb))
    (setf (mailbox-slot mb) item)
    (bt:condition-notify (mailbox-cv mb))
    t))
(defun mb-take (mb)
  (bt:with-lock-held ((mailbox-lock mb))
    (loop while (and (null (mailbox-slot mb)) (not (mailbox-closed-p mb)))
      do (bt:condition-wait (mailbox-cv mb) (mailbox-lock mb)))
    (prog1 (mailbox-slot mb) (setf (mailbox-slot mb) nil))))
(defun mb-empty-p (mb) (null (mailbox-slot mb)))
