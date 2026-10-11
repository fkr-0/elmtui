
(uiop/package:define-package :elmtui.examples.wifi-inline (:use :cl)
                             (:import-from :elmtui.app #:defapplication)
                             (:import-from :elmtui.app.api #:run-application)
                             (:import-from :elmtui.core.async #:cmd-async)
                             (:import-from :elmtui.core.event-types #:key-event
                              #:key-event-key #:key-event-char)
                             (:import-from :elmtui.state.api #:state-ref
                              #:make-update-result)
                             (:export #:run-wifi-inline #:wifi-update #:wifi-view
                              #:initial-state #:parse-nmcli-network-line #:scan-networks))

(in-package :elmtui.examples.wifi-inline)

(define-condition nmcli-command-error
    (error)
    ((argv :initarg :argv :reader nmcli-error-argv)
     (status :initarg :status :reader nmcli-error-status)
     (stderr :initarg :stderr :reader nmcli-error-stderr))
  (:report
   (lambda (condition stream)
     (format stream "nmcli failed (~D): ~A" (nmcli-error-status condition)
             (string-trim '(#\  #\Tab #\Newline #\Return)
                          (nmcli-error-stderr condition))))))

(defun %nmcli-program ()
  "Return the configured nmcli executable without invoking a shell."
  (or (uiop/os:getenv "ELMTUI_NMCLI") "nmcli"))

(defun %run-nmcli (arguments)
  "Run nmcli with ARGUMENTS and return stdout, signalling on non-zero exit."
  (let ((argv (cons (%nmcli-program) arguments)))
    (multiple-value-bind (stdout stderr status)
        (uiop/run-program:run-program argv :output :string :error-output :string
                                      :ignore-error-status t)
      (unless (zerop status)
        (error 'nmcli-command-error :argv argv :status status :stderr stderr))
      (string-trim '(#\  #\Tab #\Newline #\Return) stdout))))

(defun %split-nmcli-fields (line)
  "Split one nmcli --terse --escape=yes record on unescaped colons."
  (let ((fields nil) (buffer (make-string-output-stream)) (escaped-p nil))
    (loop for character across line
          do (cond (escaped-p (write-char character buffer) (setf escaped-p nil))
                   ((char= character #\\) (setf escaped-p t))
                   ((char= character #\:) (push (get-output-stream-string buffer) fields))
                   (t (write-char character buffer))))
    (when escaped-p (write-char #\\ buffer))
    (push (get-output-stream-string buffer) fields)
    (nreverse fields)))

(defun %safe-signal (text) (or (ignore-errors (parse-integer text :junk-allowed t)) 0))

(defun parse-nmcli-network-line (line)
  "Parse one nmcli Wi-Fi line into a plist, or NIL for hidden/invalid SSIDs."
  (let ((fields (%split-nmcli-fields line)))
    (when (>= (length fields) 4)
      (let ((ssid (second fields)))
        (unless (string= ssid "")
          (list :in-use (string= "*" (string-trim '(#\  #\Tab) (first fields))) :ssid ssid
                :signal (%safe-signal (third fields)) :security (fourth fields)))))))

(defun %network-precedes-p (left right)
  (cond ((and (getf left :in-use) (not (getf right :in-use))) t)
        ((and (not (getf left :in-use)) (getf right :in-use)) nil)
        ((/= (getf left :signal 0) (getf right :signal 0))
         (> (getf left :signal 0) (getf right :signal 0)))
        (t (string-lessp (getf left :ssid "") (getf right :ssid "")))))

(defun %normalize-networks (lines)
  "Deduplicate SSIDs, keeping the active or strongest observation, then sort."
  (let ((by-ssid (make-hash-table :test 'equal)))
    (dolist (line lines)
      (let ((candidate (parse-nmcli-network-line line)))
        (when candidate
          (let* ((ssid (getf candidate :ssid)) (existing (gethash ssid by-ssid)))
            (when (or (null existing) (%network-precedes-p candidate existing))
              (setf (gethash ssid by-ssid) candidate))))))
    (let ((networks nil))
      (maphash (lambda (_ssid network) (declare (ignore _ssid)) (push network networks))
               by-ssid)
      (sort networks #'%network-precedes-p))))

(defun scan-networks ()
  "Perform one NetworkManager rescan and return normalized Wi-Fi network plists."
  (let* ((output
          (%run-nmcli
           '("--colors" "no" "--terse" "--escape" "yes" "--fields"
             "IN-USE,SSID,SIGNAL,SECURITY" "--wait" "15" "device" "wifi" "list" "--rescan"
             "yes")))
         (lines (uiop/utility:split-string output :separator '(#\Newline))))
    (%normalize-networks lines)))

(defun connect-network (ssid)
  "Ask NetworkManager to connect to SSID using saved credentials or open auth."
  (%run-nmcli (list "--colors" "no" "--wait" "15" "device" "wifi" "connect" ssid)))

(defun %scan-command ()
  (cmd-async (lambda (progress) (declare (ignore progress)) (scan-networks)) :on-complete
             (lambda (networks) (list :wifi-scan-complete :networks networks)) :on-error
             (lambda (condition)
               (list :wifi-scan-failed :message (princ-to-string condition)))))

(defun %connect-command (ssid)
  (cmd-async (lambda (progress) (declare (ignore progress)) (connect-network ssid))
             :on-complete
             (lambda (_output)
               (declare (ignore _output))
               (list :wifi-connect-complete :ssid ssid))
             :on-error
             (lambda (condition)
               (list :wifi-connect-failed :ssid ssid :message
                     (princ-to-string condition)))))

(defun initial-state ()
  (list :status :boot :networks nil :selected-index 0 :confirm-ssid nil :message
        "Starting Wi-Fi scan..." :should-quit nil))

(defun %quit-result ()
  (make-update-result :patches '(((:should-quit) t))))

(defun %message-value (message key &optional default) (getf (rest message) key default))

(defun %key-char-p (message character)
  (and (typep message 'key-event) (key-event-char message)
       (char-equal (key-event-char message) character)))

(defun %selected-network (state)
  (let* ((networks (state-ref state :networks nil))
         (index (state-ref state :selected-index 0)))
    (when (and (listp networks) (<= 0 index) (< index (length networks)))
      (nth index networks))))

(defun %menu-interactive-p (state)
  (member (state-ref state :status :boot) '(:ready :error :connected)))

(defun %move-selection (state delta)
  (let* ((networks (state-ref state :networks nil))
         (count (length networks))
         (current (state-ref state :selected-index 0)))
    (if (zerop count)
        (make-update-result)
        (make-update-result :patches
                            `(((:selected-index) ,(mod (+ current delta) count)))))))

(defun %start-scan-result ()
  (make-update-result :patches
                      '(((:status) :scanning) ((:confirm-ssid) nil)
                        ((:message) "Scanning with NetworkManager..."))
                      :commands (list (%scan-command))))

(defun %request-connect-result (state)
  (let ((network (%selected-network state)))
    (if network
        (make-update-result :patches
                            `(((:confirm-ssid) ,(getf network :ssid))
                              ((:message)
                               ,(format nil "Confirm connection to ~A"
                                        (getf network :ssid)))))
        (make-update-result))))

(defun %pending-confirmation (state)
  "Return the SSID awaiting connection confirmation, if any.

The hash-table state backend represents a NIL-valued initial key as an empty
hash table, so only a non-empty string counts as an active confirmation."
  (let ((value (state-ref state :confirm-ssid nil)))
    (and (stringp value) (plusp (length value)) value)))

(defun %confirm-connect-result (state)
  (let ((ssid (%pending-confirmation state)))
    (if ssid
        (make-update-result :patches
                            `(((:status) :connecting) ((:confirm-ssid) nil)
                              ((:message) ,(format nil "Connecting to ~A..." ssid)))
                            :commands (list (%connect-command ssid)))
        (make-update-result))))

(defun %handle-key-event (message state)
  (let ((key (key-event-key message)) (confirm-ssid (%pending-confirmation state)))
    (cond ((%key-char-p message #\q) (%quit-result))
          ((and confirm-ssid (or (eq key :escape) (%key-char-p message #\n)))
           (make-update-result :patches
                               '(((:confirm-ssid) nil)
                                 ((:message) "Connection cancelled."))))
          ((and confirm-ssid (or (eq key :enter) (%key-char-p message #\y)))
           (%confirm-connect-result state))
          ((eq key :escape) (%quit-result))
          ((and (%menu-interactive-p state) (or (eq key :up) (%key-char-p message #\k)))
           (%move-selection state -1))
          ((and (%menu-interactive-p state) (or (eq key :down) (%key-char-p message #\j)))
           (%move-selection state 1))
          ((and (%menu-interactive-p state) (eq key :enter))
           (%request-connect-result state))
          ((and (not (eq (state-ref state :status :boot) :connecting))
                (%key-char-p message #\r))
           (%start-scan-result))
          (t (make-update-result)))))

(defun wifi-update (message state)
  (cond ((typep message 'key-event) (%handle-key-event message state))
        ((and (consp message) (eq (first message) :wifi-start-scan))
         (if (eq (state-ref state :status :boot) :boot)
             (%start-scan-result)
             (make-update-result)))
        ((and (consp message) (eq (first message) :wifi-scan-complete))
         (let ((networks (%message-value message :networks nil)))
           (make-update-result :patches
                               `(((:status) :ready) ((:networks) ,networks)
                                 ((:selected-index) 0)
                                 ((:message)
                                  ,(format nil "~D network~:P found."
                                           (length networks)))))))
        ((and (consp message) (eq (first message) :wifi-scan-failed))
         (make-update-result :patches
                             `(((:status) :error)
                               ((:message)
                                ,(%message-value message :message "Wi-Fi scan failed.")))))
        ((and (consp message) (eq (first message) :wifi-connect-complete))
         (let ((ssid (%message-value message :ssid "network")))
           (make-update-result :patches
                               `(((:status) :connected)
                                 ((:message) ,(format nil "Connected to ~A." ssid))))))
        ((and (consp message) (eq (first message) :wifi-connect-failed))
         (make-update-result :patches
                             `(((:status) :error)
                               ((:message)
                                ,(%message-value message :message "Connection failed.")))))
        ((and (consp message) (eq (first message) :app-quit-requested)) (%quit-result))
        (t (make-update-result))))

(defun wifi-subscriptions (state)
  "Schedule exactly one startup scan; reconciliation removes it after status changes."
  (when (eq (state-ref state :status :boot) :boot)
    '(:timer (:interval 0.02 :message (:wifi-start-scan)))))

(defun %signal-bars (signal)
  (cond ((>= signal 80) "||||") ((>= signal 60) "|||.") ((>= signal 40) "||..")
        ((>= signal 20) "|...") (t "....")))

(defun %security-label (security)
  (if (or (null security) (string= security "") (string= security "--"))
      "open"
      security))

(defun %network-window (networks selected &optional (limit 6))
  (let* ((rows (if (listp networks) networks '()))
         (count (length rows))
         (start (max 0 (min (max 0 (- selected (1- limit))) (max 0 (- count limit)))))
         (end (min count (+ start limit))))
    (values (subseq rows start end) start)))

(defun %network-line (network absolute-index selected-index)
  (format nil "~A ~A ~3D% ~4A  ~A  ~A"
          (if (= absolute-index selected-index)
              ">"
              " ")
          (if (getf network :in-use)
              "*"
              " ")
          (getf network :signal 0) (%signal-bars (getf network :signal 0))
          (getf network :ssid "") (%security-label (getf network :security))))

(defun wifi-view (state)
  (let* ((status (state-ref state :status :boot))
         (message (state-ref state :message ""))
         (networks (state-ref state :networks nil))
         (selected (state-ref state :selected-index 0))
         (confirm-ssid (%pending-confirmation state)))
    (multiple-value-bind (visible start)
        (%network-window networks selected)
      `(:container :id :wifi-menu :style
        (:display :flex :flex-direction :column :width 68 :height 12 :padding 0) :children
        ((:text :id :wifi-title :content "Wi-Fi / NetworkManager")
         (:text :id :wifi-status :content ,(format nil "[~(~A~)] ~A" status message))
         ,@(if visible
               (loop for network in visible
                     for offset from 0
                     collect `(:text :content
                               ,(%network-line network (+ start offset) selected)))
               '((:text :content "  (waiting for scan results)")))
         ,(if confirm-ssid
              `(:text :id :wifi-confirm :content
                ,(format nil "Connect to \"~A\"? Enter/y confirm - n/Esc cancel"
                         confirm-ssid))
              '(:text :id :wifi-help :content
                "Up/Down or j/k - Enter connect - r rescan - q/Esc quit")))))))

(defapplication wifi-inline-app :root-viewport-id :wifi-root :root-component-dsl
                '(:root-viewport :id :wifi-root :anchor :below-cursor :width 68 :height 12
                  :overflow-policy :truncate :blank-on-exit t :child-dsl-spec (:view nil))
                :initial-state-fn #'initial-state :update-fn #'wifi-update :view-fn
                #'wifi-view :subscriptions-fn wifi-subscriptions :binary t)

(defun run-wifi-inline (&key (backend-type :terminal))
  "Run the inline Wi-Fi selector below the current cursor."
  (run-application 'wifi-inline-app :backend-type backend-type))
