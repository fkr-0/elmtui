;;; == exampleproject/tests/keymaps-tests.lisp ==
;;;; FiveAM unit-tests for the unified ELMTUI keymap system
;;;; -------------------------------------------------------
;;;;  • Requires:  the :fiveam system and :elmtui.keymaps already loaded
;;;;  • Run with:  (fiveam:run! 'keymaps-suite)
;;;; -------------------------------------------------------

(uiop:define-package :elmtui.keymaps.tests
  (:use :cl :fiveam)
  (:import-from :elmtui.keymaps
                #:parse-key-string
                #:normalized-key->string
                #:key-event->normalized-key
                #:keymap!
                #:add-keybinding
                #:initialise
                #:process-key-event
                #:register-keymap
                #:define-keymap-context
                #:activate-context
                #:deactivate-context)
  ;; internal symbols we need for deep inspection
  (:import-from :elmtui.keymaps
                #:lookup
                #:lookup-binding
                #:keymap-bindings
                #:normalized-key-key
                #:normalized-key-modifiers))

(in-package :elmtui.keymaps.tests)

;;;; -----------------------------------------------------------------------
;;;; Test-suite definition
;;;; -----------------------------------------------------------------------

(def-suite keymaps-suite
  :description "Unit tests for :elmtui.keymaps")

(in-suite keymaps-suite)

;;;; -----------------------------------------------------------------------
;;;; 1)  Key-string parsing
;;;; -----------------------------------------------------------------------

(test parse-key-string-basic
  "C-a → NK with key #\\a and modifier :CTRL"
  (let ((nk (parse-key-string "C-a")))
    (is (char= #\a (normalized-key-key nk)))
    (is (equal '(:ctrl) (normalized-key-modifiers nk)))))

;;;; -----------------------------------------------------------------------
;;;; 2)  Normalised-key pretty-printer
;;;; -----------------------------------------------------------------------

(test normalized-key->string
  "Alt-Ctrl-Shift-Z prints exactly that"
  (let* ((nk (parse-key-string "Alt-Ctrl-Shift-Z"))
         (str (normalized-key->string nk)))
    (is (string= "Alt-Ctrl-Shift-Z" str))))

;;;; -----------------------------------------------------------------------
;;;; 3)  Add / lookup binding inside a keymap
;;;; -----------------------------------------------------------------------

(test add-and-lookup-binding
  (let* ((km  (keymap! :test-km)))
    (add-keybinding km "F1" :target '(:dummy))
    (is (not (null (lookup km (parse-key-string "F1")))))))

(test add-multi-key-binding
  "Space-separated key sequences are split into multiple normalized keys."
  (let ((km (keymap! :sequence-km)))
    (add-keybinding km "C-x C-s" :type :message :target '(:save))
    (is (equal '(:message :target (:save))
               (let ((binding (gethash "Ctrl-X Ctrl-S" (keymap-bindings km))))
                 (list (getf binding :type) :target (getf binding :target)))))))

;;;; -----------------------------------------------------------------------
;;;; 4)  Context-stack precedence (later-activated context wins)
;;;; -----------------------------------------------------------------------

(test context-precedence
  (let* ;; two keymaps, same key → different targets
      ((km1 (keymap! :km1))
       (km2 (keymap! :km2)))
    (add-keybinding km1 "F2" :type :message :target '(:one))
    (add-keybinding km2 "F2" :type :message :target '(:two))
    (register-keymap :km1 km1)
    (register-keymap :km2 km2)

    ;; define & activate contexts
    (let ((ctx-a (define-keymap-context :ctx-a :parent nil :keymaps (list :km1)))
          (ctx-b (define-keymap-context :ctx-b :parent nil :keymaps (list :km2))))
      (activate-context ctx-a)
      (activate-context ctx-b)

      (let* ((nk (parse-key-string "F2"))
             (binding (lookup-binding nk)))
        (is (equal '(:message (:two)) (list (getf binding :type) (getf binding :target)))))

      ;; deactivate second context → first now wins
      (deactivate-context ctx-b)
      (let* ((nk (parse-key-string "F2"))
             (binding (lookup-binding nk)))
        (is (equal '(:message (:one)) (list (getf binding :type) (getf binding :target))))))))

;;;; -----------------------------------------------------------------------
;;;; 5)  System bootstrap installs default global navigation map
;;;; -----------------------------------------------------------------------

(test initialise-defaults
  (initialise)
  (let ((binding (lookup-binding (parse-key-string "F1"))))
    (is (eq :message (getf binding :type)))
    (is (equal '(:show-help) (getf binding :target)))))


;;;; -----------------------------------------------------------------------
;;;; Helper: Run the suite when file is loaded from the REPL
;;;; -----------------------------------------------------------------------

;; (eval-when (:execute)
;;   (run! 'keymaps-suite))
;;; == end/keymaps-tests.lisp ==

(test default-message-bindings-dispatch-canonical-messages
  (initialise)
  (let ((seen nil))
    (flet ((dispatch (message) (setf seen message)))
      (dolist (case '((:f1 (:show-help))
                      (:f10 (:show-menu))
                      (:escape (:cancel))))
        (setf seen nil)
        (is-true (process-key-event (list :key (first case) :modifiers nil)
                                    nil
                                    :dispatch-fn #'dispatch))
        (is (equal (second case) seen)))
      (let ((dialog (define-keymap-context :post002-dialog
                                           :parent :global-context
                                           :keymaps '(:dialog))))
        (activate-context dialog)
        (setf seen nil)
        (is-true (process-key-event '(:key :enter :modifiers nil)
                                    nil
                                    :dispatch-fn #'dispatch))
        (is (equal '(:confirm) seen))))))

(test default-message-binding-without-dispatch-is-consumed
  (initialise)
  (is-true (process-key-event '(:key :f1 :modifiers nil)
                              nil
                              :dispatch-fn nil)))
