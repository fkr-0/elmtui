;;;; elmtui.view.api  ---  Public View-Pipeline Abstractions      -*- Lisp -*-
;;;
;;; This file is part of the *ElmTUI* project.
;;; License: MIT  •  Version: 0.2.0  •  2025-06-05
;;;
;;; This package defines:
;;;   • Generic functions constituting the canonical View-pipeline
;;;   • Abstract superclass hierarchy for UI-nodes
;;;   • Diff/patch helpers for back-buffer rendering
;;;
;;; Concrete back-ends are expected to :USE or :IMPORT-FROM this package
;;; and specialise the generics on their own subclasses.
;;; -----------------------------------------------------------------------

(defpackage #:elmtui.view.api
  (:use #:cl)
  (:export
   ;; Transformation generics
   #:render-view
   #:apply-style
   #:resolve-view
   #:layout-view
   #:render-to-buffer
   ;; Diff-pipeline generics
   #:diff-buffer
   #:apply-diff
   ;; Abstract node classes
   #:ui-node
   #:styled-ui-node
   #:atomic-ui-node
   #:laid-out-ui-node))

(in-package #:elmtui.view.api)

;;; -----------------------------------------------------------------------
;;; PROTOCOL NOTES
;;; -----------------------------------------------------------------------
;;; • Every transformation step is a *pure* function except RENDER-TO-BUFFER,
;;;   which may cause side-effects on a mutable back-buffer object.
;;; • Each generic is intentionally *single-dispatch* on its first parameter
;;;   to keep method selection simple.  If additional context is needed
;;;   (theme, runtime, etc.) thread it via &KEY to avoid exploding the
;;;   dispatch space.
;;; -----------------------------------------------------------------------
;;; -----------------------------------------------------------------------
;;; PROTOCOL NOTES  (extended)
;;; -----------------------------------------------------------------------
;;;  • PIPELINE INVARIANTS
;;;    - Every step is *referentially transparent* except RENDER-TO-BUFFER
;;;      and APPLY-DIFF, which are the only allowed points of side-effects.
;;;    - No step may *mutate* its input tree; always return a fresh (or
;;;      persistent-structure) copy.  This guarantees safe caching and
;;;      structural-sharing diff algorithms.
;;;
;;;  • DISPATCH & EXTENSIBILITY
;;;    - Single dispatch is on the first argument by design.  Additional
;;;      context must be passed via &KEY or captured in the object itself to
;;;      prevent an explosion of method specialisations.
;;;    - Back-ends SHOULD specialise *exactly one* concrete subclass per
;;;      abstract node-class to keep layout and diff logic predictable.
;;;
;;;  • STABILITY REQUIREMENTS
;;;    - NODE-ID: Implementations SHOULD provide a stable identifier
;;;      (e.g. UUID or hash) in the PROPS plist; the diff phase may rely on
;;;      it when structural equality is insufficient.
;;;    - SLOT CONTRACTS: Do **not** add or remove required slots in the
;;;      base classes—extend via :around methods or mixins instead.
;;;
;;;  • ERROR & CONDITION SYSTEM
;;;    - All pipeline errors MUST signal conditions inheriting from
;;;      VIEW-ERROR.  This allows caller-supplied restarts like
;;;      :RETRY, :ABORT-FRAME, or :FALLBACK-RENDER.
;;;    - RENDER-TO-BUFFER and APPLY-DIFF must guarantee terminal integrity
;;;      even on non-local exits (use UNWIND-PROTECT).
;;;
;;;  • PERFORMANCE GUIDELINES
;;;    - Target complexity: O(n) over the number of nodes; avoid quadratic
;;;      scans in deep trees.
;;;    - Consider memoising APPLY-STYLE and RESOLVE-VIEW results keyed by
;;;      (NODE-ID + THEME) for large static sub-trees.
;;;
;;;  • THREAD-SAFETY
;;;    - Implementations must be *re-entrant*; no global *current-theme*
;;;      variables.  If global caches are used, guard them with
;;;      `bt:mutex` (or equivalent) or ensure immutability.
;;;
;;;  • DEBUGGABILITY
;;;    - Define a PRINT-OBJECT method for each concrete node class that shows
;;;      TYPE, essential props, and a condensed style-map; keep it within 80
;;;      columns for REPL readability.
;;; -----------------------------------------------------------------------


;;; =======================================================================
;;; 1. Generic functions  (pipeline steps)
;;; =======================================================================

(defgeneric render-view (app-state)
  (:documentation
   "High-level entry point of the View-pipeline.

APP-STATE  – Any object representing the current model.
RESULT     – Tree of UI-NODE instances in their *rich* form (labels, list-boxes, …).
The result *must* be a pure value; no side-effects allowed."))

(defgeneric apply-style (rich-tree)
  (:documentation
   "Normalise and merge style information.

RICH-TREE  – Tree produced by RENDER-VIEW.
RESULT     – Tree of STYLED-UI-NODE objects whose STYLE-MAP slot is *complete*.
Must not change tree topology."))

(defgeneric resolve-view (styled-tree)
  (:documentation
   "Lower complex widgets to a minimal atomic vocabulary.

STYLED-TREE – Output of APPLY-STYLE.
RESULT       – Tree of ATOMIC-UI-NODE objects (:drawable-content, :layout, …)."))

(defgeneric layout-view (atomic-tree available-rect)
  (:documentation
   "Compute absolute geometry for every node.

ATOMIC-TREE     – Result of RESOLVE-VIEW.
AVAILABLE-RECT  – Rect structure (x y w h) representing constraints.
RESULT          – Tree of LAID-OUT-UI-NODE objects with LAYOUT-RECT populated."))

(defgeneric render-to-buffer (laid-out-tree backbuffer)
  (:documentation
   "Emit drawing commands into BACKBUFFER.

LAID-OUT-TREE – Fully laid-out tree from LAYOUT-VIEW.
BACKBUFFER    – Mutable device-buffer object.
Side-effects  – BACKBUFFER contents are updated in-place.
Return value  – Implementation-defined (usually BACKBUFFER or NIL)."))

;;; -----------------------------------------------------------------------
;;; 2. Diff/patch helpers  (optional but recommended)
;;; -----------------------------------------------------------------------

(defgeneric diff-buffer (prev-buffer curr-buffer)
  (:documentation
   "Compute *minimal* diff operations to transform PREV-BUFFER into CURR-BUFFER.

Return value – A list/stream of diff operations understood by APPLY-DIFF."))

(defgeneric apply-diff (backend diff-ops terminal-origin)
  (:documentation
   "Apply DIFF-OPS to the physical terminal via BACKEND.

BACKEND          – Backend instance responsible for IO.
DIFF-OPS         – Result of DIFF-BUFFER.
TERMINAL-ORIGIN  – (x . y) top-left corner offset when drawing.
Return value     – Implementation-defined (often NIL)."))

;;; =======================================================================
;;; 3. Class hierarchy for UI-nodes
;;; =======================================================================

(defclass ui-node ()
  ((type
    :initarg :type
    :reader ui-node-type
    :type symbol
    :documentation "Semantic node type keyword, e.g. :label or :listbox.")
   (props
    :initarg :props
    :reader ui-node-props
    :type plist
    :documentation "Raw property plist passed by the component’s view function.")
   (children
    :initarg :children
    :accessor ui-node-children
    :type list
    :documentation "List of child UI-NODEs (may be empty)."))
  (:documentation
   "Rich UI node produced directly by a component’s view.
These nodes may still be declarative/high-level."))

(defclass styled-ui-node (ui-node)
  ((style-map
    :initarg :style-map
    :reader styled-ui-node-style-map
    :type plist
    :documentation "Fully-resolved style plist after APPLY-STYLE."))
  (:documentation
   "UI node after stylesheet cascade expansion and normalisation."))

(defclass atomic-ui-node (styled-ui-node)
  ()
  (:documentation
   "UI node lowered to the *atomic* language understood by the layout engine.
Allowed TYPEs: :drawable-content, :layout, :viewport, …"))

(defclass laid-out-ui-node (atomic-ui-node)
  ((layout-rect
    :initarg :layout-rect
    :reader laid-out-ui-node-layout-rect
    :type list        ;; (x y w h) or RECT struct
    :documentation "Absolute rectangle in terminal cells."))
  (:documentation
   "Atomic UI node after absolute geometry has been assigned."))

;;; -----------------------------------------------------------------------
;;; END OF FILE
;;; -----------------------------------------------------------------------
