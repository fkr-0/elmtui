(defpackage :elmtui.tests.coverage-focus
  (:use :cl :fiveam)
  (:local-nicknames (:focus :elmtui.core.focus) (:keys :elmtui.keymaps)))
(in-package :elmtui.tests.coverage-focus)
(def-suite coverage-focus-behavior-tests :in elmtui.tests:elmtui-test)
(in-suite coverage-focus-behavior-tests)

(defvar *action-calls* nil)
(defun child-action (state) (push (list :child state) *action-calls*))
(defun parent-action (state) (push (list :parent state) *action-calls*))

(defmacro with-isolated-keymaps (&body body)
  `(let ((keys:*registry* (make-hash-table :test 'eq))
         (keys:*contexts* (make-hash-table :test 'eq))
         (keys:*active-contexts* nil)
         (keys:*global-keymap-context* nil))
     ,@body))

(defun focus-tree ()
  '(:container (:id :root)
    (:button (:id :first :focusable t))
    (:container (:id :nested)
     (:button (:id :disabled :focusable t :disabled t))
     (:button (:focusable t))
     (:label (:id :label))
     (:button (:id :second :focusable t)))
    (:button (:id :third :focusable t))))

(test nested-tree-collection-and-preservation
  (let ((manager (focus:make-focus-manager :initial-focus :second)))
    (is (equal '(:first :second :third)
               (focus:recalculate-focusable-elements manager (focus-tree) :preserve-focus t)))
    (is (eq :second (focus:get-current-focus manager)))
    (is-false (focus:focus-manager-focus-ring-dirty-p manager))
    (is (= 3 (length (focus:collect-focusable-elements (focus-tree)))))
    (focus:recalculate-focusable-elements manager (focus-tree))
    (is (eq :first (focus:get-current-focus manager)))
    (focus:recalculate-focusable-elements manager nil :preserve-focus t)
    (is-false (focus:get-current-focus manager))
    (is-false (focus:collect-focusable-ids nil))))

(test legacy-tree-and-removed-focus-recovery
  (let ((manager (focus:make-focus-manager :initial-focus :removed)))
    (is (equal '(:kept :child)
               (focus:recalculate-focusable-elements
                manager '(:id :kept :focusable t :children
                          ((:id :off :focusable t :disabled t)
                           (:id :child :focusable t))) :preserve-focus t)))
    (is (eq :kept (focus:get-current-focus manager)))
    (is (equal '(:removed) (focus:focus-manager-focus-history manager)))))

(test tab-ring-wrap-and-unknown-origin
  (let ((manager (focus:make-focus-manager)))
    (focus:recalculate-focusable-elements manager (focus-tree))
    (is-false (focus:get-current-focus manager))
    (is (eq :first (focus:get-next-focusable manager :missing)))
    (is (eq :third (focus:get-previous-focusable manager :missing)))
    (focus:tab-navigate manager :backward)
    (is (eq :third (focus:get-current-focus manager)))
    (focus:tab-navigate manager :forward)
    (is (eq :first (focus:get-current-focus manager)))
    (focus:tab-navigate manager :backward)
    (is (eq :third (focus:get-current-focus manager)))
    (focus:tab-navigate manager :unsupported)
    (is (eq :third (focus:get-current-focus manager)))
    (focus:handle-tab-navigation manager (elmtui.core.event-types:make-key-event :key :tab :modifiers '(:shift)))
    (is (eq :second (focus:get-current-focus manager)))
    (is-false (focus:handle-tab-navigation manager :not-an-event))
    (is-false (focus:handle-tab-navigation manager (elmtui.core.event-types:make-key-event :key :enter)))))

(test empty-and-singleton-rings
  (let ((manager (focus:make-focus-manager)))
    (is-false (focus:get-next-focusable manager nil))
    (is-false (focus:get-previous-focusable manager nil))
    (is-false (focus:tab-navigate manager :forward))
    (focus:handle-focus-message manager '(:update-focusable-ids :ids (:only)))
    (is (eq :only (focus:get-current-focus manager)))
    (is-false (focus:tab-navigate manager :forward))
    (is-false (focus:focus-manager-focus-history manager))))

(test context-roundtrip-preserves-independent-focus
  (let ((manager (focus:make-focus-manager :initial-focus :editor
                                         :initial-context-ids '(:main :dialog)
                                         :initial-active-context :main)))
    (is (eq :editor (focus:get-context-last-focus manager :main)))
    (focus:register-focus-context manager :main)
    (is (eq :editor (focus:get-context-last-focus manager :main)))
    (is-false (focus:activate-focus-context manager :unknown))
    (is (eq :main (focus:focus-manager-active-focus-context manager)))
    (is (eq :dialog (focus:activate-focus-context manager :dialog)))
    (is-false (focus:get-current-focus manager))
    (focus:request-focus manager :confirm)
    (focus:activate-focus-context manager :main)
    (is (eq :editor (focus:get-current-focus manager)))
    (focus:activate-focus-context manager :dialog)
    (is (eq :confirm (focus:get-current-focus manager)))
    (is-false (focus:activate-focus-context manager :dialog))
    (is-false (focus:get-context-last-focus manager :unknown))
    (is-true (focus:focus-manager-focus-ring-dirty-p manager))))

(test focus-messages-repair-removed-target-and-reject-incomplete-request
  (let ((manager (focus:make-focus-manager :initial-focus :a)))
    (is-true (focus:handle-focus-message manager '(:update-focusable-ids :ids (:a :b :c))))
    (is (eq :a (focus:get-current-focus manager)))
    (is-true (focus:handle-focus-message manager '(:focus-previous)))
    (is (eq :c (focus:get-current-focus manager)))
    (is-true (focus:handle-focus-message manager '(:focus-next)))
    (is (eq :a (focus:get-current-focus manager)))
    (is-true (focus:handle-focus-message manager '(:request-focus :widget-id :b)))
    (is (eq :b (focus:get-current-focus manager)))
    (is-false (focus:handle-focus-message manager '(:request-focus)))
    (is-false (focus:handle-focus-message manager '(:unrecognized)))
    (focus:handle-focus-message manager '(:update-focusable-ids :ids (:c)))
    (is (eq :c (focus:get-current-focus manager)))
    (focus:handle-focus-message manager '(:update-focusable-ids :ids nil))
    (is-false (focus:get-current-focus manager))))

(test directional-fallback-is-consistent-with-tab-ring
  (let ((manager (focus:make-focus-manager :initial-focus :second)))
    (focus:recalculate-focusable-elements manager (focus-tree) :preserve-focus t)
    (is-true (focus:navigate-up manager))
    (is (eq :first (focus:get-current-focus manager)))
    (is-true (focus:navigate-left manager))
    (is (eq :third (focus:get-current-focus manager)))
    (is-true (focus:navigate-down manager))
    (is (eq :first (focus:get-current-focus manager)))
    (is-true (focus:navigate-right manager))
    (is (eq :second (focus:get-current-focus manager)))
    (focus:clear-focus manager)
    (is-false (focus:navigate-right manager))))

(test default-navigation-reports-handled-and-updates-focus
  (let ((manager (focus:make-focus-manager)))
    (focus:recalculate-focusable-elements manager (focus-tree))
    (dolist (step '((:end :third) (:home :first) (:tab :second) (:escape nil)))
      (is-true (focus:handle-default-navigation-keys
                manager (elmtui.core.event-types:make-key-event :key (first step))))
      (is (eq (second step) (focus:get-current-focus manager))))))

(test history-navigation-consumes-previous-entry
  (let ((manager (focus:make-focus-manager)))
    (focus:set-focus manager :a)
    (focus:set-focus manager :b)
    (focus:set-focus manager :c)
    (focus:focus-previous-from-history manager)
    (is (eq :b (focus:get-current-focus manager)))
    (focus:focus-previous-from-history manager)
    (is (eq :a (focus:get-current-focus manager)))))

(test focused-keymap-action-and-parent-fallback
  (with-isolated-keymaps
    (let* ((state (elmtui.state.api:make-application-state))
           (*action-calls* nil)
           (parent-map (keys::make-keymap :name :parent-map))
           (child-map (keys::make-keymap :name :child-map))
           (parent (keys:make-keymap-context :name :parent :keymaps (list parent-map)))
           (child (keys:define-keymap-context :child :parent nil :keymaps (list child-map)))
           (manager (focus:make-focus-manager)))
      (setf (keys:keymap-context-parent child) parent)
      (keys:add-keybinding parent-map "F2" :type :action :target 'parent-action)
      (keys:add-keybinding child-map "F1" :type :action :target 'child-action)
      (setf (elmtui.state.api:state-ref state '(:widgets :editor))
            '(:keymap-id :child))
      (focus:set-focus manager :editor :app-state state)
      (is (eq child (keys:current-context)))
      (is-true (elmtui.core.focus::handle-key-event manager (elmtui.core.event-types:make-key-event :key :f1) :app-state state))
      (is (equal (list :child state) (first *action-calls*)))
      (is-true (elmtui.core.focus::handle-key-event manager (elmtui.core.event-types:make-key-event :key :f2) :app-state state))
      (is (equal (list :parent state) (first *action-calls*)))
      (focus:clear-focus manager :app-state state)
      (is-false (member child keys:*active-contexts*)))))

(test listing-single-and-multi-key-bindings
  (with-isolated-keymaps
    (let* ((km (keys::make-keymap :name :listing))
           (context (keys:make-keymap-context :name :listing :keymaps (list km))))
      (keys:add-keybinding km "F1" :type :action :target 'child-action
                          :description "Help")
      (keys:add-keybinding km "C-x C-s" :type :action :target 'parent-action
                          :description "Save")
      (keys:activate-context context)
      (let ((bindings (focus:list-active-keybindings (focus:make-focus-manager))))
        (is (= 2 (length bindings)))
        (is (equal '("Help" "Save")
                   (sort (mapcar (lambda (b) (getf b :description)) bindings) #'string<)))))))

(defun spatial-node (id x y &key (width 4) (height 2))
  (list :button (list :id id :focusable t
                     :x x :y y :width width :height height)))

(test spatial-navigation-prefers-alignment-and-nearest-target
  (let* ((tree (list :container '(:id :root)
                     (spatial-node :center 20 20)
                     (spatial-node :north 20 10)
                     (spatial-node :far-north 20 0)
                     (spatial-node :south 20 30)
                     (spatial-node :west 10 20)
                     (spatial-node :east 30 20)
                     (spatial-node :diagonal 26 16)))
         (manager (focus:make-focus-manager :initial-focus :center)))
    (focus:recalculate-focusable-elements manager tree :preserve-focus t)
    (dolist (step '((:up :north) (:down :south) (:left :west) (:right :east)))
      (focus:set-focus manager :center)
      (is-true (focus::navigate-direction manager (first step) :ui-tree tree))
      (is (eq (second step) (focus:get-current-focus manager))))
    (focus:set-focus manager :far-north)
    (is-false (focus:navigate-up manager :ui-tree tree))
    (is (eq :far-north (focus:get-current-focus manager)))
    (focus:set-focus manager :missing)
    (is-false (focus:navigate-right manager :ui-tree tree))
    (is (eq :missing (focus:get-current-focus manager)))))

(test component-dispatch-reports-handled
  (with-isolated-keymaps
    (let* ((*action-calls* nil)
           (km (keys::make-keymap :name :dispatch))
           (ctx (keys:make-keymap-context :name :dispatch :keymaps (list km)))
           (manager (focus:make-focus-manager :initial-focus :editor)))
      (keys:add-keybinding km "F1" :type :action :target 'child-action)
      (keys:activate-context ctx)
      (is-true (focus:handle-key-event-for-component
                manager (elmtui.core.event-types:make-key-event :key :f1)
                :editor :app-state :sentinel))
      (is (equal '((:child :sentinel)) *action-calls*)))))

(test direct-component-keymap-inherits-global-context
  (with-isolated-keymaps
    (let* ((state (elmtui.state.api:make-application-state))
           (km (keys::make-keymap :name :editor-map))
           (keys:*global-keymap-context* (keys:make-keymap-context :name :global)))
      (setf (elmtui.state.api:state-ref state '(:widgets :editor))
            (list :active-keymap km))
      (let ((context (focus:find-component-keymap-context :editor state)))
        (is (eq :editor (keys:keymap-context-name context)))
        (is (equal (list km) (keys:keymap-context-keymaps context)))
        (is (eq keys:*global-keymap-context* (keys:keymap-context-parent context))))
      (is-false (focus:find-component-keymap-context nil state))
      (is-false (focus:find-component-keymap-context :editor nil))
      (is-false (focus:find-component-keymap-context :missing state))
      (setf (elmtui.state.api:state-ref state '(:widgets :unmapped))
            '(:keymap-id :unregistered))
      (is-false (focus:find-component-keymap-context :unmapped state)))))

(test unknown-binding-and-unbound-action-do-not-execute
  (let ((*action-calls* nil))
    (is-false (focus::handle-key-binding '(:type :unknown :target child-action)))
    (is-false (focus::handle-key-binding '(:type :action :target nonexistent-action)))
    (is-false *action-calls*)))

(test component-dispatch-does-not-consume-invalid-bindings
  (with-isolated-keymaps
    (let* ((km (keys::make-keymap :name :invalid))
           (ctx (keys:make-keymap-context :name :invalid :keymaps (list km)))
           (manager (focus:make-focus-manager :initial-focus :editor)))
      (keys:add-keybinding km "F1" :type :action :target 'nonexistent-action)
      (keys:activate-context ctx)
      (is-false (focus:handle-key-event-for-component
                 manager (elmtui.core.event-types:make-key-event :key :f1) :editor)))))
