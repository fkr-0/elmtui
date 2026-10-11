
(uiop/package:define-package :elmtui.tests.wifi-inline (:use :cl :fiveam)
                             (:export #:wifi-inline-tests))

(in-package :elmtui.tests.wifi-inline)

(def-suite wifi-inline-tests :in elmtui.tests:elmtui-test :description
           "Inline Wi-Fi example parser, state transitions, and confirmation contract")

(in-suite wifi-inline-tests)

(defun %state (plist) (elmtui.state.api:plist-to-application-state plist))

(defun %wifi-symbol (name)
  (asdf/operate:load-system "elmtui-examples")
  (or (find-symbol name :elmtui.examples.wifi-inline)
      (error "wifi-inline example does not provide ~A" name)))

(defun %wifi-fn (name)
  (symbol-function (%wifi-symbol name)))

(defun %apply-result! (state result)
  (dolist (patch (elmtui.state.api:ur-patches result) state)
    (setf (elmtui.state.api:state-ref state (first patch)) (second patch))))

(test wifi-nmcli-parser-preserves-escaped-ssid
  (let ((network
         (funcall (%wifi-fn "PARSE-NMCLI-NETWORK-LINE") " :Cafe\\:Lab:82:WPA2")))
    (is (string= "Cafe:Lab" (getf network :ssid)))
    (is (= 82 (getf network :signal)))
    (is-false (getf network :in-use))
    (is (string= "WPA2" (getf network :security)))))

(test wifi-root-is-inline-and-startup-scan-is-one-shot
  (let* ((cfg
          (gethash (%wifi-symbol "WIFI-INLINE-APP")
                   elmtui.core.globals:*applications*))
         (root (elmtui.app.api:app-config-root-component-dsl cfg))
         (state (%state (funcall (%wifi-fn "INITIAL-STATE")))))
    (is (eq :root-viewport (first root)))
    (is (eq :below-cursor (getf (rest root) :anchor)))
    (is-true (getf (rest root) :blank-on-exit))
    (is
     (equal '(:timer (:interval 0.02 :message (:wifi-start-scan)))
            (funcall (%wifi-fn "WIFI-SUBSCRIPTIONS") state)))
    (setf (elmtui.state.api:state-ref state :status) :scanning)
    (is-false (funcall (%wifi-fn "WIFI-SUBSCRIPTIONS") state))))

(test wifi-connect-requires-explicit-second-confirmation
  (let* ((state (%state (funcall (%wifi-fn "INITIAL-STATE"))))
         (update (%wifi-fn "WIFI-UPDATE"))
         (enter (cl-events.types:make-key-event :type :key-down :key :enter))
         (down (cl-events.types:make-key-event :type :key-down :key :down)))
    ;; Deliver a completed scan with two networks, then select the second one.
    (%apply-result!
     state
     (funcall update
              '(:wifi-scan-complete :networks
                ((:in-use t :ssid "OfficeNet" :signal 71 :security "WPA2")
                 (:in-use nil :ssid "Cafe:Lab" :signal 82 :security "WPA2")))
              state))
    (%apply-result! state (funcall update down state))
    (is (= 1 (elmtui.state.api:state-ref state :selected-index)))
    ;; The first Enter only asks for confirmation; it must not run nmcli.
    (let ((request (funcall update enter state)))
      (is (null (elmtui.state.api:ur-commands request)))
      (let ((patch
             (find '(:confirm-ssid) (elmtui.state.api:ur-patches request) :test #'equal
                   :key #'first)))
        (is-true patch)
        (is (string= "Cafe:Lab" (second patch)))))
    (%apply-result! state (funcall update enter state))
    ;; The second Enter dispatches exactly one async connect command.
    (let* ((confirm (funcall update enter state))
           (commands (elmtui.state.api:ur-commands confirm))
           (status-patch
            (find '(:status) (elmtui.state.api:ur-patches confirm) :test #'equal :key
                  #'first)))
      (is (= 1 (length commands)))
      (is (eq :async (first (first commands))))
      (is (eq :connecting (second status-patch))))))

(test wifi-scan-normalization-deduplicates-and-prioritizes-active-network
  (let ((networks
         (funcall (%wifi-fn "%NORMALIZE-NETWORKS")
          '(" :Cafe\\:Lab:55:WPA2" " :Cafe\\:Lab:82:WPA2" "*:OfficeNet:71:WPA2"
            " :Guest:44:--"))))
    (is (= 3 (length networks)))
    (is (string= "OfficeNet" (getf (first networks) :ssid)))
    (is-true (getf (first networks) :in-use))
    (is (string= "Cafe:Lab" (getf (second networks) :ssid)))
    (is (= 82 (getf (second networks) :signal)))))

(test wifi-quit-key-requests-runtime-shutdown
  (let* ((state (%state (funcall (%wifi-fn "INITIAL-STATE"))))
         (event (cl-events.types:make-key-event :type :key-down :key :q :char #\q))
         (result (funcall (%wifi-fn "WIFI-UPDATE") event state)))
    (is (equal '(((:should-quit) t)) (elmtui.state.api:ur-patches result)))))
