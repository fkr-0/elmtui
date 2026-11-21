---
# AI Metadata Tags
ai_keywords: [Utils Implementation, Utility Functions, Helper Macros, Common Lisp Utilities, Generic Functions]
ai_contexts: [implementation, development]
ai_relations: ["./overview.md"]
---

# Utils Module Implementation Details

<!-- AI-IMPORTANCE:level=low -->
## Technical Overview

The `utils` module, if it exists as a distinct entity (e.g., in `src/utils.lisp` or `src/utils/`), contains a collection of standalone Common Lisp functions and macros. These are designed to be pure, generic, and have minimal dependencies, ideally only on standard Common Lisp or very basic external libraries.

If a dedicated `utils` module/directory is not present, these utilities might be found within a common package (e.g., `elmtui.common`) or interspersed within other modules where they are primarily used. This documentation assumes they are logically grouped for discussion.

<!-- AI-CONTEXT-START:type=implementation -->
## Core Implementation Examples

### Macro Utilities
```lisp
;; Example: Anaphoric if
;; (defmacro aif (test-form then-form &optional else-form)
;;   `(let ((it ,test-form))
;;      (if it ,then-form ,else-form)))

;; Example: with-gensyms (if not using a library that provides it)
;; (defmacro with-gensyms (syms &body body)
;;   `(let ,(mapcar #'(lambda (s) `(,s (gensym)))
;;                  syms)
;;      ,@body))
```

### List Utilities
```lisp
;; Example: Flatten a list
;; (defun flatten (list)
;;   (cond ((null list) nil)
;;         ((atom list) (list list))
;;         (t (loop for a in list appending (flatten a)))))

;; Example: Safe car/cdr/cadr etc.
;; (defun safe-car (list &optional default)
;;   (if (consp list) (car list) default))
```

### String Utilities
```lisp
;; Example: Check if string starts with prefix
;; (defun starts-with-p (str prefix)
;;   (when (and (stringp str) (stringp prefix) (<= (length prefix) (length str)))
;;     (string= prefix str :end2 (length prefix))))
```

### Hash Table Utilities
```lisp
;; Example: Get a value from a hash table with a default, ensuring key presence check
;; (defun gethash-safe (key hash-table &optional default)
;;   (multiple-value-bind (value found-p) (gethash key hash-table)
;;     (if found-p value default)))
```

### General Predicates or Helpers
```lisp
;; Example: Ensure a value is within a range
;; (defun clamp (value min max)
;;   (cond ((< value min) min)
;;         ((> value max) max)
;;         (t value)))
```
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=development -->
## Development Guide

### Adding New Utilities
1.  **Necessity:** Ensure the utility is genuinely general-purpose and likely to be reused.
2.  **Purity:** Prefer pure functions where possible.
3.  **Clarity:** Name functions and macros clearly. Provide good docstrings.
4.  **Placement:** Add to an existing `utils.lisp` file or a relevant submodule (e.g., `utils/string.lisp`). If no such structure exists, consider creating one if the number of utilities grows.
5.  **Testing:** Write unit tests for new utilities.

### Important Notes
*   Avoid introducing dependencies on other Elmtui modules within `utils`.
*   If a utility becomes complex or domain-specific, consider if it belongs in a more specialized module.
*   Check if a similar utility is already provided by Common Lisp or a readily available library (e.g., Alexandria, Serapeum) before writing a new one. Elmtui might already depend on such libraries.
<!-- AI-CONTEXT-END -->

## Testing Strategy

*   Each utility function or macro should have its own set of unit tests covering various inputs, including edge cases.
*   Tests should verify return values and, for macros, correct expansion (if feasible to test directly).

## Known Limitations

*   The main "limitation" is ensuring the module remains a collection of genuinely useful, generic tools and doesn't become a dumping ground for miscellaneous code.