;;;; Conway Game of Life: interactive example powered by ElmTUI.

(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package :elmtui.examples.neon-kit)
    (load
     (merge-pathnames #P"neon-kit.lisp"
                      (or *load-truename* *compile-file-truename*)))))
(uiop/package:define-package :elmtui.examples.game-of-life (:use :cl)
                             (:import-from :elmtui.app #:defapplication)
                             (:import-from :elmtui.state.api #:make-update-result
                              #:state-ref)
                             (:import-from :elmtui.examples.neon-kit #:pressed-p
                              #:quit-message-p #:screen #:line)
                             (:export #:run-game-of-life #:run-game-of-life-app
                              #:game-of-life-update #:game-of-life-view
                              #:get-glider-pattern #:next-generation #:main))
(in-package :elmtui.examples.game-of-life)
(defun get-glider-pattern ()
  (let ((grid (make-array '(20 40) :element-type 'bit :initial-element 0)))
    (setf (aref grid 1 2) 1
          (aref grid 2 3) 1
          (aref grid 3 1) 1
          (aref grid 3 2) 1
          (aref grid 3 3) 1)
    grid))
(defun count-neighbors (grid x y width height)
  (let ((count 0))
    (dolist (dy '(-1 0 1))
      (dolist (dx '(-1 0 1))
        (unless (and (zerop dx) (zerop dy))
          (let ((nx (mod (+ x dx) width)) (ny (mod (+ y dy) height)))
            (incf count (aref grid ny nx))))))
    count))
(defun next-generation (grid)
  (let* ((height (array-dimension grid 0))
         (width (array-dimension grid 1))
         (new-grid
          (make-array (list height width) :element-type 'bit :initial-element 0)))
    (dotimes (y height)
      (dotimes (x width)
        (let ((neighbors (count-neighbors grid x y width height))
              (cell (aref grid y x)))
          (setf (aref new-grid y x)
                  (cond ((and (= cell 1) (or (= neighbors 2) (= neighbors 3))) 1)
                        ((and (= cell 0) (= neighbors 3)) 1) (t 0))))))
    new-grid))
(defun game-of-life-update (message app-state)
  (let ((grid (state-ref app-state :grid))
        (generation (state-ref app-state :generation 0))
        (running (state-ref app-state :running t)))
    (cond
     ((or (quit-message-p message) (pressed-p message :char #\q :keys '(:escape)))
      (make-update-result :patches '(((:should-quit) t))))
     ((pressed-p message :char #\ )
      (make-update-result :patches `(((:running) ,(not running)))))
     ((pressed-p message :char #\r)
      (make-update-result :patches
       `(((:grid) ,(get-glider-pattern)) ((:generation) 0))))
     ((pressed-p message :char #\s)
      (if running
          (make-update-result)
          (make-update-result :patches
           `(((:grid) ,(next-generation grid)) ((:generation) ,(1+ generation))))))
     ((or (eq message :tick) (and (consp message) (eq (first message) :tick)))
      (if running
          (make-update-result :patches
           `(((:grid) ,(next-generation grid)) ((:generation) ,(1+ generation))))
          (make-update-result)))
     (t (make-update-result)))))
(defun grid-row->string (grid y width)
  (coerce
   (loop for x below width
         collect (if (eql 1 (aref grid y x))
                     #\DARK_SHADE
                     #\MIDDLE_DOT))
   'string))
(defun game-of-life-view (app-state)
  (let* ((grid (state-ref app-state :grid))
         (height (array-dimension grid 0))
         (width (array-dimension grid 1))
         (generation (state-ref app-state :generation 0))
         (running (state-ref app-state :running t))
         (wall (make-string width :initial-element #\BOX_DRAWINGS_LIGHT_HORIZONTAL)))
    (screen :gol-content
     (append
      (list
       (line
        (format nil " LIFE / GLIDER LAB GEN ~3,'0D ~A" generation
                (if running
                    "● RUNNING"
                    "Ⅱ PAUSED"))
        :title)
       (line (format nil " ╭~A╮" wall) :border))
      (loop for y below height
            collect (line (format nil " │~A│" (grid-row->string grid y width))
                     :signal))
      (list (line (format nil " ╰~A╯" wall) :border)
            (line " SPACE PAUSE S STEP R RESET Q EXIT" :footer)))
     :width 60 :height 24)))
(defun %game-of-life-initial-state ()
  (list :grid (get-glider-pattern) :generation 0 :running t :should-quit nil))
(defapplication game-of-life-app :root-viewport-id :gol-root-vp :root-component-dsl
 '(:root-viewport :id :gol-root-vp :anchor :below-cursor :width 60 :height 24
   :blank-on-exit t :child-dsl-spec (:view nil))
 :initial-state-fn #'%game-of-life-initial-state :update-fn #'game-of-life-update
 :view-fn #'game-of-life-view :subscriptions-fn
 (lambda (state)
   (when (and (state-ref state :running t) (not (state-ref state :should-quit nil)))
     '(:timer (:interval 0.24 :message (:tick))))))
(defun main () (run-game-of-life-app :platform :terminal))
(defun run-game-of-life (&key (backend-type :terminal))
  (run-game-of-life-app :platform backend-type))