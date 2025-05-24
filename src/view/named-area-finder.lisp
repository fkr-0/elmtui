;; Add before compute-grid-layout function

(defun find-named-area-coordinates (template-areas area-name)
  "Find the coordinates of a named area in a grid template.
   TEMPLATE-AREAS: The parsed grid template areas
   AREA-NAME: The name of the area to find
   Returns (values coords found) where coords is a plist with
   :row-start, :row-end, :col-start, :col-end and found is a boolean"
  (when (and template-areas area-name
             (stringp area-name))
    (let ((start-row nil)
          (start-col nil)
          (end-row nil)
          (end-col nil)
          (num-rows (length template-areas))
          (area-found nil))
      
      ;; First, find the start coordinates by scanning the grid
      (loop for row from 0 below num-rows
            until area-found
            do (let ((columns (nth row template-areas)))
                 (loop for col from 0 below (length columns)
                       for cell = (nth col columns)
                       when (and cell (string= cell area-name))
                       do (setf start-row row
                                start-col col
                                area-found t)
                       (return))))
      
      ;; If area was found, find its bounds
      (when area-found
        (multiple-value-bind (sr sc er ec)
            (compute-area-bounds template-areas start-row start-col area-name)
          (setf start-row sr
                start-col sc
                end-row er
                end-col ec)
          (values
           (list :row-start (1+ start-row)  ; Convert to 1-based
                 :col-start (1+ start-col)
                 :row-end (+ end-row 2)     ; end is exclusive, so add 1 more
                 :col-end (+ end-col 2))
           t)))
      (values nil nil))))
