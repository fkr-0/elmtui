(uiop:define-package :elmtui.tests.root-viewport
  (:use :cl :fiveam :alexandria)
  (:import-from :elmtui.ui.widgets.root-viewport
                #:root-viewport #:make-root-viewport #:anchor-type
                #:compute-anchor-offset #:compute-view-size
                #:get-cleanup-info #:root-viewport-anchor
                #:root-viewport-initial-cursor-row
                #:root-viewport-initial-cursor-col)
  (:import-from :elmtui.ui.api
                #:init #:update #:view #:id-from-path #:get-path)
  (:import-from :elmtui.app.api #:get-component-instance)
  (:import-from :elmtui.tea-state #:application-state-plist) ; For accessing state in a structured way
  (:import-from :elmtui.core.event-types #:key-event) ; For :terminal-resized structure
  (:shadowing-import-from :elmtui.ui.widgets.root-viewport ;; Ensure we are testing the correct compute functions
                          #:compute-anchor-offset #:compute-view-size))

(in-package :elmtui.tests.root-viewport)

(def-suite root-viewport-tests
  :description "Tests for the root-viewport component.")
(in-suite root-viewport-tests)

;;;------------------------------------------------------------------------------------
;;; Test Helpers
;;;------------------------------------------------------------------------------------
;; Mock app-state structure for testing get-cleanup-info and other state-dependent functions
(defun make-mock-app-state (root-vp-id-path &optional rvp-state-plist)
  (let ((app-state (make-hash-table :test 'equal)))
    (when rvp-state-plist
      (setf (gethash (append root-vp-id-path '(:state)) app-state) rvp-state-plist))
    app-state))

;; Helper to get nested values from a hash-table based state
;; This is a simplified version of elmtui.state:get-path for hash-tables
(defmethod get-path ((state hash-table) path &optional default)
  (if (null path)
      state
      (let ((current state))
        (dolist (key path default)
          (multiple-value-bind (value foundp) (gethash key current)
            (if foundp
                (setf current value)
                (return default))))
        current)))


;;;------------------------------------------------------------------------------------
;;; Tests for compute-anchor-offset, compute-view-size, init, update, get-cleanup-info
(test compute-anchor-offset-tests
  (let ((vp-w 10) (vp-h 5) (term-w 80) (term-h 24) (cur-r 10) (cur-c 20))
    (flet ((check (anchor expected-oy expected-ox)
             (multiple-value-bind (oy ox)
                 (compute-anchor-offset anchor vp-w vp-h term-w term-h cur-r cur-c)
               (is (= oy expected-oy) "Anchor ~A: Offset Y mismatch. Expected ~D, Got ~D" anchor expected-oy oy)
               (is (= ox expected-ox) "Anchor ~A: Offset X mismatch. Expected ~D, Got ~D" anchor expected-ox ox))))
      ;; Top
      (check :top-left 0 0)
      (check :top 0 (floor (- term-w vp-w) 2))
      (check :top-right 0 (- term-w vp-w))
      ;; Middle
      (check :left (floor (- term-h vp-h) 2) 0)
      (check :center (floor (- term-h vp-h) 2) (floor (- term-w vp-w) 2))
      (check :right (floor (- term-h vp-h) 2) (- term-w vp-w))
      ;; Bottom
      (check :bottom-left (- term-h vp-h) 0)
      (check :bottom (- term-h vp-h) (floor (- term-w vp-w) 2))
      (check :bottom-right (- term-h vp-h) (- term-w vp-w))
      ;; Cursor-relative
      (check :below-cursor (min (1+ cur-r) (- term-h vp-h))
             (max 0 (min cur-c (- term-w vp-w))))
      (check :above-cursor (max 0 (- cur-r vp-h))
             (max 0 (min cur-c (- term-w vp-w))))
      ))

  ;; Test edge cases for cursor-relative positioning
  (let ((vp-w 10) (vp-h 5) (term-w 80) (term-h 24))
    (flet ((check (anchor cur-r cur-c expected-oy expected-ox)
             (multiple-value-bind (oy ox)
                 (compute-anchor-offset anchor vp-w vp-h term-w term-h cur-r cur-c)
               (is (= oy expected-oy) "Anchor ~A (Edge): OY mismatch. Cur(~D,~D) Expected ~D, Got ~D" anchor cur-r cur-c expected-oy oy)
               (is (= ox expected-ox) "Anchor ~A (Edge): OX mismatch. Cur(~D,~D) Expected ~D, Got ~D" anchor cur-r cur-c expected-ox ox))))
      ;; :below-cursor
      (check :below-cursor 0 0 (min 1 (- term-h vp-h)) (max 0 (min 0 (- term-w vp-w))))
      (check :below-cursor (- term-h 1) (- term-w 1) (- term-h vp-h) (- term-w vp-w))
      (check :below-cursor (- term-h vp-h) 0 (- term-h vp-h) 0)
      (check :below-cursor (- term-h vp-h -1) 0 (- term-h vp-h) 0)
      ;; :above-cursor
      (check :above-cursor 0 0 (max 0 (- 0 vp-h)) (max 0 (min 0 (- term-w vp-w))))
      (check :above-cursor vp-h 0 (max 0 (- vp-h vp-h)) 0)
      (check :above-cursor (1- vp-h) 0 (max 0 (- (1- vp-h) vp-h)) 0)
      (check :above-cursor (- term-h 1) (- term-w 1) (max 0 (- (- term-h 1) vp-h)) (- term-w vp-w))
      )))

(test compute-view-size-tests
  (let ((term-w 80) (term-h 24) (cur-r 10))
    (flet ((check (anchor expected-w expected-h expected-oy)
             (multiple-value-bind (w h oy)
                 (compute-view-size anchor term-w term-h cur-r)
               (is (= w expected-w) "Anchor ~A: Width mismatch. Expected ~D, Got ~D" anchor expected-w w)
               (is (= h expected-h) "Anchor ~A: Height mismatch. Expected ~D, Got ~D" anchor expected-h h)
               (is (= oy expected-oy) "Anchor ~A: Offset Y mismatch. Expected ~D, Got ~D" anchor expected-oy oy))))
      ;; Cursor-relative
      (check :below-cursor term-w (- term-h cur-r 1) 0)
      (check :above-cursor term-w cur-r 0)

      ;; Full screen anchors
      (dolist (anchor '(:top-left :top :top-right
                        :left :center :right
                        :bottom-left :bottom :bottom-right))
        (check anchor term-w term-h 0)))))

(test root-viewport-init-tests
  (let* ((id :my-rvp)
         (id-path `(:app ,id))
         (term-dims '(80 . 24))
         (term-w (car term-dims))
         (term-h (cdr term-dims))
         (cursor-pos '(10 . 20))
         (cur-r (car cursor-pos))
         (cur-c (cdr cursor-pos))
         (child-spec `(:label :id :child-label :text "Hello")))

    (flet ((find-patch (patches key-path)
             (assoc key-path patches :test #'equal))
           (get-patch-value (patch)
             (second patch)))

      (dolist (anchor '(:top-left :center :below-cursor :above-cursor))
        (let* ((rvp (make-root-viewport id :anchor anchor :initial-cursor-pos cursor-pos))
               (patches (init rvp :id-path id-path
                                  :initial-terminal-dimensions term-dims
                                  :initial-cursor-pos cursor-pos
                                  :anchor anchor
                                  :initial-child-spec child-spec)))
          (is (listp patches) "Patches should be a list for anchor ~A" anchor)

          (let ((type-patch (find-patch patches (append id-path '(:type)))))
            (is-true type-patch "Type patch missing for anchor ~A" anchor)
            (is (eq 'elmtui.ui.widgets.root-viewport:root-viewport (get-patch-value type-patch))
                "Type patch incorrect for anchor ~A" anchor))

          (let ((id-patch (find-patch patches (append id-path '(:id)))))
            (is-true id-patch "ID patch missing for anchor ~A" anchor)
            (is (eq id (get-patch-value id-patch)) "ID patch incorrect for anchor ~A" anchor))

          (let* ((state-patch (find-patch patches (append id-path '(:state))))
                 (state-plist (get-patch-value state-patch)))
            (is-true state-patch "State patch missing for anchor ~A" anchor)
            (is (listp state-plist) "State value should be a plist for anchor ~A" anchor)

            (multiple-value-bind (expected-vp-w expected-vp-h)
                (compute-view-size anchor term-w term-h cur-r)
              (multiple-value-bind (expected-offset-y expected-offset-x)
                  (compute-anchor-offset anchor expected-vp-w expected-vp-h term-w term-h cur-r cur-c)
                (is (= (getf state-plist :width) expected-vp-w) "State :width incorrect for anchor ~A" anchor)
                (is (= (getf state-plist :height) expected-vp-h) "State :height incorrect for anchor ~A" anchor)
                (is (= (getf state-plist :offset-x) expected-offset-x) "State :offset-x incorrect for anchor ~A" anchor)
                (is (= (getf state-plist :offset-y) expected-offset-y) "State :offset-y incorrect for anchor ~A" anchor)
                (is (eq (getf state-plist :anchor) anchor) "State :anchor incorrect for anchor ~A" anchor)
                (is (= (getf state-plist :initial-cursor-row) cur-r) "State :initial-cursor-row incorrect for anchor ~A" anchor)
                (is (= (getf state-plist :initial-cursor-col) cur-c) "State :initial-cursor-col incorrect for anchor ~A" anchor)))))

        (let ((child-patch (find-patch patches (append id-path '(:child)))))
          (is-true child-patch "Child patch missing for anchor ~A" anchor)
          (is (equal (get-patch-value child-patch) child-spec) "Child patch incorrect for anchor ~A" anchor))))

    (let* ((rvp (make-root-viewport id :anchor :center :initial-cursor-pos cursor-pos))
           (patches (init rvp :id-path id-path
                              :initial-terminal-dimensions term-dims
                              :initial-cursor-pos cursor-pos
                              :anchor :center)))
      (is (null (find-patch patches (append id-path '(:child))))
          "Child patch should be absent when :initial-child-spec is not provided"))))

;;; Mock child component for testing update delegation
(defclass mock-child-component (elmtui.ui.api:component)
  ((id :initarg :id :reader elmtui.ui.api:component-id)
   (update-called-with :initform nil :accessor mock-child-update-called-with)))

(defmethod elmtui.ui.api:init ((component mock-child-component) &key id-path &allow-other-keys)
  (list (list (append id-path '(:type)) (type-of component))
        (list (append id-path '(:id)) (elmtui.ui.api:component-id component))))

(defmethod elmtui.ui.api:update ((component mock-child-component) state message &key id-path)
  (declare (ignore state id-path))
  (setf (mock-child-update-called-with component) message)
  `((,(append (list :mock-child-updated (elmtui.ui.api:component-id component))) ,message)))

(defmethod elmtui.ui.api:view ((component mock-child-component) state &key id-path)
  (declare (ignore state id-path))
  `(:mock-child :id ,(elmtui.ui.api:component-id component)))

(test root-viewport-update-tests
  (let* ((id :my-rvp)
         (id-path `(:app ,id))
         (initial-term-dims '(80 . 24))
         (initial-cur-pos '(0 . 0))
         (initial-anchor :center)
         (rvp (make-root-viewport id :anchor initial-anchor :initial-cursor-pos initial-cur-pos)))

    (flet ((find-patch (patches key-path)
             (assoc key-path patches :test #'equal))
           (get-patch-value (patch)
             (second patch))
           (setup-initial-state (anchor term-dims cur-pos)
             (let* ((init-patches (init rvp :id-path id-path
                                            :initial-terminal-dimensions term-dims
                                            :initial-cursor-pos cur-pos
                                            :anchor anchor))
                    (app-state (make-hash-table :test 'equal)))
               (dolist (patch init-patches)
                 (setf (gethash (first patch) app-state) (second patch)))
               app-state)))

      (dolist (anchor '(:top-left :center :below-cursor :above-cursor))
        (let* ((current-app-state (setup-initial-state anchor initial-term-dims initial-cur-pos))
               (new-term-dims '(100 . 30))
               (new-term-w (car new-term-dims))
               (new-term-h (cdr new-term-dims))
               (message `(:terminal-resized :new-dimensions ,new-term-dims))
               (update-patches (update rvp current-app-state message :id-path id-path)))

          (is (listp update-patches) "Update patches should be a list for :terminal-resized, anchor ~A" anchor)
          (is (= 4 (length update-patches)) "Should get 4 patches for resize, anchor ~A" anchor)

          (let ((state-after-init (gethash (append id-path '(:state)) current-app-state)))
            (multiple-value-bind (expected-vp-w expected-vp-h)
                (compute-view-size anchor new-term-w new-term-h (getf state-after-init :initial-cursor-row))
              (multiple-value-bind (expected-offset-y expected-offset-x)
                  (compute-anchor-offset anchor expected-vp-w expected-vp-h
                                         new-term-w new-term-h
                                         (getf state-after-init :initial-cursor-row)
                                         (getf state-after-init :initial-cursor-col))

                (let ((width-patch (find-patch update-patches (append id-path '(:state :width)))))
                  (is-true width-patch "Width patch missing for resize, anchor ~A" anchor)
                  (is (= (get-patch-value width-patch) expected-vp-w) "Updated width incorrect for anchor ~A" anchor))

                (let ((height-patch (find-patch update-patches (append id-path '(:state :height)))))
                  (is-true height-patch "Height patch missing for resize, anchor ~A" anchor)
                  (is (= (get-patch-value height-patch) expected-vp-h) "Updated height incorrect for anchor ~A" anchor))

                (let ((offset-x-patch (find-patch update-patches (append id-path '(:state :offset-x)))))
                  (is-true offset-x-patch "Offset-X patch missing for resize, anchor ~A" anchor)
                  (is (= (get-patch-value offset-x-patch) expected-offset-x) "Updated offset-x incorrect for anchor ~A" anchor))

                (let ((offset-y-patch (find-patch update-patches (append id-path '(:state :offset-y)))))
                  (is-true offset-y-patch "Offset-Y patch missing for resize, anchor ~A" anchor)
                  (is (= (get-patch-value offset-y-patch) expected-offset-y) "Updated offset-y incorrect for anchor ~A" anchor)))))))


      (let* ((child-id :my-child)
             (child-instance (make-instance 'mock-child-component :id child-id))
             (app-state-with-child (setup-initial-state initial-anchor initial-term-dims initial-cur-pos))
             (child-id-path (append id-path (list child-id))))

        (setf (gethash (append id-path '(:child)) app-state-with-child) child-id)
        (setf (gethash child-id-path app-state-with-child) child-instance)

        (let ((original-get-component-instance (fdefinition 'elmtui.app.api:get-component-instance)))
          (unwind-protect
               (progn
                 (setf (fdefinition 'elmtui.app.api:get-component-instance)
                       (lambda (path state)
                         (declare (ignore state))
                         (if (equal path child-id-path)
                             child-instance
                             nil)))

                 (let* ((test-message '(:custom-message :data "hello"))
                        (update-patches (update rvp app-state-with-child test-message :id-path id-path)))
                   (is-true (mock-child-update-called-with child-instance) "Child update should have been called.")
                   (is (equal test-message (mock-child-update-called-with child-instance)) "Child update called with wrong message.")
                   (is (listp update-patches) "Update patches from child should be a list.")
                   (is (equal `((:mock-child-updated ,child-id) ,test-message) (first update-patches))
                       "Expected patch from mock child not found.")))
            (setf (fdefinition 'elmtui.app.api:get-component-instance) original-get-component-instance))))

      (let* ((app-state-no-child (setup-initial-state initial-anchor initial-term-dims initial-cur-pos))
             (test-message '(:another-message))
             (update-patches (update rvp app-state-no-child test-message :id-path id-path)))
        (is (null update-patches) "Update should return no patches if no child and not a resize message.")))
    ))
;;;------------------------------------------------------------------------------------
;; Tests will be added here
(test get-cleanup-info-tests
  (let ((rvp-id :my-rvp)
        (rvp-id-path `(:app ,rvp-id)))

    (test "get-cleanup-info with valid state"
      (let* ((initial-cursor-row 10)
             (anchor :below-cursor)
             (rvp-state-plist `(:initial-cursor-row ,initial-cursor-row :anchor ,anchor))
             (app-state (make-mock-app-state rvp-id-path rvp-state-plist))
             (cleanup-info (get-cleanup-info rvp-id app-state)))
        (is (listp cleanup-info) "Cleanup info should be a plist.")
        (is (eq (getf cleanup-info :anchor) anchor) "Incorrect anchor in cleanup info.")
        (is (= (getf cleanup-info :initial-cursor-row) initial-cursor-row)
            "Incorrect initial-cursor-row in cleanup info.")))

    (test "get-cleanup-info with missing state"
      (let* ((app-state (make-mock-app-state rvp-id-path nil)) ; No state for rvp-id
             (cleanup-info (get-cleanup-info rvp-id app-state)))
        ;; Expecting a warning and nil. Testing for log output is tricky in unit tests,
        ;; so we'll focus on the nil return value.
        (is (null cleanup-info) "Cleanup info should be nil when state is missing.")))

    (test "get-cleanup-info with partial state (missing anchor)"
      (let* ((initial-cursor-row 10)
             (rvp-state-plist `(:initial-cursor-row ,initial-cursor-row)) ; Anchor is missing
             (app-state (make-mock-app-state rvp-id-path rvp-state-plist))
             (cleanup-info (get-cleanup-info rvp-id app-state)))
        (is (listp cleanup-info) "Cleanup info should be a plist even with partial state.")
        (is (eq (getf cleanup-info :anchor :default-anchor) :default-anchor)
            "Anchor should be nil or default if missing.")
        (is (= (getf cleanup-info :initial-cursor-row) initial-cursor-row)
            "Incorrect initial-cursor-row with partial state.")))

    (test "get-cleanup-info with partial state (missing initial-cursor-row)"
      (let* ((anchor :center)
             (rvp-state-plist `(:anchor ,anchor)) ; initial-cursor-row is missing
             (app-state (make-mock-app-state rvp-id-path rvp-state-plist))
             (cleanup-info (get-cleanup-info rvp-id app-state)))
        (is (listp cleanup-info) "Cleanup info should be a plist even with partial state.")
        (is (eq (getf cleanup-info :anchor) anchor) "Incorrect anchor with partial state.")
        (is (eq (getf cleanup-info :initial-cursor-row :default-row) :default-row)
            "Initial-cursor-row should be nil or default if missing.")))

    (test "get-cleanup-info with completely empty state plist"
      (let* ((rvp-state-plist `()) ; Empty plist
             (app-state (make-mock-app-state rvp-id-path rvp-state-plist))
             (cleanup-info (get-cleanup-info rvp-id app-state)))
        (is (listp cleanup-info) "Cleanup info should be a plist even with empty state plist.")
        (is (eq (getf cleanup-info :anchor :default-anchor) :default-anchor)
            "Anchor should be nil or default with empty state plist.")
        (is (eq (getf cleanup-info :initial-cursor-row :default-row) :default-row)
            "Initial-cursor-row should be nil or default with empty state plist.")))
    ))
