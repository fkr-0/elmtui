(uiop:define-package :elmtui.examples.wifi-menu (:use :cl) (:import-from :elmtui.app #:defapplication) (:import-from :elmtui.core.async #:cmd-async) (:import-from :elmtui.core.event-types #:key-event #:key-event-key #:key-event-char) (:import-from :elmtui.state.api #:make-update-result #:state-ref) (:export #:wifi-network #:make-wifi-network #:wifi-network-active-p #:wifi-network-ssid #:wifi-network-bssid #:wifi-network-signal #:wifi-network-security #:wifi-network-device #:parse-nmcli-wifi-output #:wifi-scan-argv #:wifi-connect-argv #:wifi-disconnect-argv #:wifi-menu-update #:wifi-menu-view #:run-wifi-menu))

(in-package :elmtui.examples.wifi-menu)

(defstruct wifi-network (active-p nil :type boolean) (ssid "" :type string) (bssid "" :type string) (signal 0 :type integer) (security "" :type string) (device "" :type string))

(defun %split-escaped-fields (line) "Split one nmcli terse line while honoring backslash-escaped separators." (let ((fields nil) (buffer (make-string-output-stream)) (escaped nil)) (labels ((flush-field () (push (get-output-stream-string buffer) fields) (setf buffer (make-string-output-stream)))) (loop for character across line do (cond (escaped (write-char character buffer) (setf escaped nil)) ((char= character #\\) (setf escaped t)) ((char= character #\:) (flush-field)) (t (write-char character buffer)))) (when escaped (write-char #\\ buffer)) (flush-field) (nreverse fields))))

(defun %parse-nmcli-wifi-line (line) (let ((fields (%split-escaped-fields line))) (when (>= (length fields) 6) (destructuring-bind (in-use ssid bssid signal security device &rest ignored) fields (declare (ignore ignored)) (make-wifi-network :active-p (string= in-use "*") :ssid ssid :bssid bssid :signal (or (parse-integer signal :junk-allowed t) 0) :security security :device device)))))

(defun parse-nmcli-wifi-output (output) "Parse nmcli terse Wi-Fi rows and sort active/high-signal networks first." (let ((networks (loop with start = 0 for end = (position #\Newline output :start start) for line = (subseq output start (or end (length output))) for network = (and (plusp (length line)) (%parse-nmcli-wifi-line line)) when network collect network while end do (setf start (1+ end))))) (stable-sort networks (lambda (left right) (if (eq (wifi-network-active-p left) (wifi-network-active-p right)) (> (wifi-network-signal left) (wifi-network-signal right)) (wifi-network-active-p left))))))

(defun wifi-scan-argv (&key (rescan nil)) "Return the argv used for a read-only nmcli Wi-Fi scan." (list "nmcli" "--terse" "--colors" "no" "--escape" "yes" "-f" "IN-USE,SSID,BSSID,SIGNAL,SECURITY,DEVICE" "device" "wifi" "list" "--rescan" (if rescan "yes" "no")))

(defun wifi-connect-argv (network &key ask-for-secrets) "Return a password-free argv for connecting NETWORK." (append (list "nmcli") (when ask-for-secrets (list "--ask")) (list "--wait" "20" "--colors" "no" "device" "wifi" "connect" (wifi-network-ssid network)) (unless (string= (wifi-network-device network) "") (list "ifname" (wifi-network-device network))) (unless (string= (wifi-network-bssid network) "") (list "bssid" (wifi-network-bssid network)))))

(defun wifi-disconnect-argv (network) "Return argv for disconnecting the device carrying NETWORK." (list "nmcli" "--wait" "10" "--colors" "no" "device" "disconnect" (wifi-network-device network)))

(defun %run-command (argv &key input) (uiop:run-program argv :input input :output :string :error-output :output))

(defun %scan-wifi (&key rescan) (parse-nmcli-wifi-output (%run-command (wifi-scan-argv :rescan rescan))))

(defun %secured-network-p (network) (let ((security (wifi-network-security network))) (and (plusp (length security)) (not (string= security "--")) (not (string-equal security "open")))))

(defun %connect-wifi (network password) "Connect NETWORK without exposing PASSWORD in the process argument vector." (let ((argv (wifi-connect-argv network :ask-for-secrets (and password (plusp (length password)))))) (if (and password (plusp (length password))) (with-input-from-string (input (format nil "~A~%" password)) (%run-command argv :input input)) (%run-command argv))))

(defun %disconnect-wifi (network) (if (string= (wifi-network-device network) "") (error "Selected network has no NetworkManager device") (%run-command (wifi-disconnect-argv network))))

(defun %scan-command (&key rescan) (cmd-async (lambda (progress) (declare (ignore progress)) (%scan-wifi :rescan rescan)) :on-complete (lambda (networks) (list :wifi-scan-succeeded :networks networks)) :on-error (lambda (condition) (list :wifi-operation-failed :message (princ-to-string condition)))))

(defun %connect-command (network password) (cmd-async (lambda (progress) (declare (ignore progress)) (%connect-wifi network password)) :on-complete (lambda (output) (list :wifi-connect-succeeded :output output)) :on-error (lambda (condition) (list :wifi-operation-failed :message (princ-to-string condition)))))

(defun %disconnect-command (network) (cmd-async (lambda (progress) (declare (ignore progress)) (%disconnect-wifi network)) :on-complete (lambda (output) (list :wifi-disconnect-succeeded :output output)) :on-error (lambda (condition) (list :wifi-operation-failed :message (princ-to-string condition)))))

(defun %initial-state () (list :networks nil :selected-index 0 :mode :browse :password "" :busy nil :status "Waiting for NetworkManager; press r to refresh now." :should-quit nil))

(defun %network-list (app-state)
  "Return the networks slot as a proper list.

The hash-table state backend represents a NIL-valued initial key as an empty
hash table, so sequence operations must guard against non-list values."
  (let ((value (state-ref app-state :networks '())))
    (if (listp value) value '())))

(defun %flag-set-p (app-state key)
  "Whether boolean flag KEY is genuinely set.

NIL-valued initial keys can read back as empty hash tables; only non-empty,
non-hash-table values count as set."
  (let ((value (state-ref app-state key nil)))
    (not (or (null value)
             (and (hash-table-p value) (zerop (hash-table-count value)))))))

(defun %selected-network (app-state) (let* ((networks (%network-list app-state)) (selected (state-ref app-state :selected-index 0))) (and networks (nth (min selected (1- (length networks))) networks))))

(defun %selected-index-after-scan (app-state networks) (let ((previous (%selected-network app-state))) (or (and previous (position-if (lambda (network) (or (and (plusp (length (wifi-network-bssid previous))) (string= (wifi-network-bssid previous) (wifi-network-bssid network))) (string= (wifi-network-ssid previous) (wifi-network-ssid network)))) networks)) 0)))

(defun %event-character (event) (or (key-event-char event) (and (characterp (key-event-key event)) (key-event-key event))))

(defun %browse-key-update (event app-state) (let* ((key (key-event-key event)) (networks (%network-list app-state)) (selected (state-ref app-state :selected-index 0)) (network (%selected-network app-state))) (cond ((member key ' (:escape :q #\q #\Q) :test #'eql) (make-update-result :patches ' (((:should-quit) t)))) ((member key ' (:arrow-up :up #\k #\K) :test #'eql) (make-update-result :patches (list (list ' (:selected-index) (max 0 (1- selected)))))) ((member key ' (:arrow-down :down #\j #\J) :test #'eql) (make-update-result :patches (list (list ' (:selected-index) (if networks (min (1- (length networks)) (1+ selected)) 0))))) ((member key ' (:r #\r #\R) :test #'eql) (make-update-result :patches ' (((:busy) t) ((:status) "Refreshing Wi-Fi networks...")) :commands (list (%scan-command :rescan t)))) ((member key ' (:d #\d #\D) :test #'eql) (if (and network (plusp (length (wifi-network-device network)))) (make-update-result :patches ' (((:busy) t) ((:status) "Disconnecting selected Wi-Fi device...")) :commands (list (%disconnect-command network))) (make-update-result :patches ' (((:status) "No disconnectable Wi-Fi network selected."))))) ((member key ' (:enter :return) :test #'eq) (cond ((null network) (make-update-result :patches ' (((:status) "No Wi-Fi network selected.")))) ((string= (wifi-network-ssid network) "") (make-update-result :patches ' (((:status) "Hidden SSIDs require a named profile and are not changed by this demo.")))) ((%secured-network-p network) (make-update-result :patches ' (((:mode) :password) ((:password) "") ((:status) "Enter the Wi-Fi password; Enter connects, Esc cancels.")))) (t (make-update-result :patches ' (((:busy) t) ((:status) "Connecting to open Wi-Fi network...")) :commands (list (%connect-command network nil)))))) (t (make-update-result)))))

(defun %password-key-update (event app-state) (let* ((key (key-event-key event)) (character (%event-character event)) (password (state-ref app-state :password "")) (network (%selected-network app-state))) (cond ((eq key :escape) (make-update-result :patches (quote (((:password) "") ((:should-quit) t))))) ((member key ' (:backspace :delete) :test #'eq) (make-update-result :patches (list (list ' (:password) (if (plusp (length password)) (subseq password 0 (1- (length password))) ""))))) ((member key ' (:enter :return) :test #'eq) (if (or (null network) (zerop (length password))) (make-update-result :patches ' (((:status) "A password is required for this network."))) (let ((command (%connect-command network password))) (make-update-result :patches ' (((:mode) :browse) ((:password) "") ((:busy) t) ((:status) "Connecting through NetworkManager...")) :commands (list command))))) ((and character (graphic-char-p character)) (make-update-result :patches (list (list ' (:password) (concatenate 'string password (string character)))))) (t (make-update-result)))))

(defun wifi-menu-update (message app-state) "Update the NetworkManager Wi-Fi menu without running network commands inline." (cond ((and (consp message) (eq (first message) :keyevent) (typep (getf (rest message) :event) (quote key-event))) (wifi-menu-update (getf (rest message) :event) app-state)) ((typep message 'key-event) (if (eq (state-ref app-state :mode :browse) :password) (%password-key-update message app-state) (%browse-key-update message app-state))) ((and (consp message) (eq (first message) :wifi-refresh-tick)) (if (or (%flag-set-p app-state :busy) (eq (state-ref app-state :mode :browse) :password)) (make-update-result) (make-update-result :patches ' (((:busy) t) ((:status) "Updating Wi-Fi networks...")) :commands (list (%scan-command :rescan nil))))) ((and (consp message) (eq (first message) :wifi-scan-succeeded)) (let ((networks (getf (rest message) :networks ' ()))) (make-update-result :patches (list (list ' (:networks) networks) (list ' (:selected-index) (%selected-index-after-scan app-state networks)) (list ' (:busy) nil) (list ' (:status) (format nil "~D Wi-Fi network~:P visible." (length networks))))))) ((and (consp message) (member (first message) ' (:wifi-connect-succeeded :wifi-disconnect-succeeded) :test #'eq)) (make-update-result :patches (quote (((:busy) nil) ((:password) "") ((:should-quit) t))))) ((and (consp message) (eq (first message) :wifi-operation-failed)) (make-update-result :patches (list (list ' (:busy) nil) (list ' (:password) "") (list ' (:mode) :browse) (list ' (:status) (format nil "NetworkManager error: ~A" (getf (rest message) :message "unknown error")))))) ((and (consp message) (eq (first message) :app-quit-requested)) (make-update-result :patches ' (((:should-quit) t)))) (t (make-update-result))))

(defun %network-line (network selected-p) (format nil "~A ~A ~3D% ~12A ~A" (if selected-p ">" " ") (if (wifi-network-active-p network) "*" " ") (wifi-network-signal network) (if (%secured-network-p network) (wifi-network-security network) "open") (if (string= (wifi-network-ssid network) "") "<hidden>" (wifi-network-ssid network))))

(defparameter +panel-width+ 78
  "Painted width of every Wi-Fi panel row.")

(defparameter +visible-network-rows+ 8
  "Maximum network rows shown at once; the window follows the selection.")

(defun %neon-style (role)
  "Map a semantic ROLE onto the neon-kit palette (fg, bg, bold)."
  (case role
    (:title    '(:fg-color (97 233 250)  :bg-color (18 34 57) :bold t))
    (:accent   '(:fg-color (248 199 115) :bg-color (10 17 31) :bold t))
    (:selected '(:fg-color (103 245 206) :bg-color (18 34 57) :bold t))
    (:danger   '(:fg-color (254 124 149) :bg-color (10 17 31) :bold t))
    (:muted    '(:fg-color (125 143 169) :bg-color (10 17 31)))
    (:footer   '(:fg-color (190 171 250) :bg-color (18 25 45)))
    (t          '(:fg-color (216 225 242) :bg-color (10 17 31)))))

(defun %neon-row-style (role)
  "Full style plist for one panel row carrying ROLE."
  (append (list :width +panel-width+ :height 1) (%neon-style role)))

(defun %clip-text (text width)
  (let ((s (or text "")))
    (if (<= (length s) width) s (subseq s 0 width))))

(defun %network-window (networks selected &optional (limit +visible-network-rows+))
  "Window Networks around SELECTED, returning visible rows and start index."
  (let* ((count (length networks))
         (start (max 0 (min (max 0 (- selected (1- limit))) (max 0 (- count limit)))))
         (end (min count (+ start limit))))
    (values (subseq networks start end) start)))

(defun wifi-menu-view (app-state)
  "Render the neon-styled adaptive nmcli Wi-Fi chooser.

The panel height tracks discovery: title, status, one row per visible
network (windowed around the selection), an optional password row, and a
help row. With no results the panel collapses to four rows and grows as
networks appear, up to the windowed maximum."
  (let* ((networks (%network-list app-state))
         (selected (state-ref app-state :selected-index 0))
         (status (state-ref app-state :status ""))
         (busy (%flag-set-p app-state :busy))
         (mode (state-ref app-state :mode :browse))
         (password (state-ref app-state :password ""))
         (password-p (eq mode :password))
         (body-rows
           (if (null networks)
               (list `(:text :id :no-networks
                        :content ,(%clip-text "No scan results yet." +panel-width+)
                        :style ,(%neon-row-style :muted)))
               (multiple-value-bind (visible start)
                   (%network-window networks selected)
                 (loop for network in visible
                       for index from start
                       for role = (cond ((= index selected) :selected)
                                        ((wifi-network-active-p network) :accent)
                                        (t :body))
                       collect `(:text :id ,(intern (format nil "WIFI-~D" index) :keyword)
                                 :content ,(%clip-text (%network-line network (= index selected))
                                                       +panel-width+)
                                 :style ,(%neon-row-style role))))))
         (height (+ 2 (length body-rows) (if password-p 1 0) 1)))
    `(:container :id :wifi-menu-content
       :style (:display :flex :flex-direction :column
               :width ,+panel-width+ :height ,height :gap 0 :padding 0)
       :children
       ((:text :id :title
          :content ,(%clip-text "Wi-Fi / NetworkManager" +panel-width+)
          :style ,(%neon-row-style :title))
        (:text :id :status
          :content ,(%clip-text (format nil "~A~A" (if busy "⟳ " "") status) +panel-width+)
          :style ,(%neon-row-style (if busy :danger :accent)))
        ,@body-rows
        ,@(when password-p
            (list `(:text :id :password
                     :content ,(%clip-text
                                (format nil "Password: ~A"
                                        (make-string (length password)
                                                     :initial-element #\*))
                                +panel-width+)
                     :style ,(%neon-row-style :danger))))
        (:text :id :help
          :content ,(%clip-text
                     "Up/Down select | Enter connect | d disconnect | r rescan | q/Esc quit"
                     +panel-width+)
          :style ,(%neon-row-style :footer))))))

(defun wifi-subscriptions (app-state) (declare (ignore app-state)) ' (:timer (:interval 5.0 :message (:wifi-refresh-tick))))

(defapplication wifi-menu-app :root-viewport-id :wifi-menu-root :root-component-dsl ' (:root-viewport :id :wifi-menu-root :anchor :below-cursor :width 80 :height 13 :blank-on-exit t :child-dsl-spec (:view nil) :overflow-policy :scroll) :initial-state-fn #'%initial-state :update-fn #'wifi-menu-update :view-fn #'wifi-menu-view :subscriptions-fn (lambda (state) (wifi-subscriptions state)))

(defun run-wifi-menu (&key (backend-type :terminal) platform-options argv) "Run the nmcli-backed Wi-Fi chooser." (run-wifi-menu-app :platform backend-type :platform-options platform-options :argv argv))
