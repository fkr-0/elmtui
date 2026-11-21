---
# AI Metadata Tags
ai_keywords: [Clevelib Implementation, CFFI Internals, FFI Bindings, Native Code, System Call Wrappers, Termios Bindings]
ai_contexts: [implementation, development]
ai_relations: ["./overview.md", "../platform/implementation.md", "../core/implementation.md", "../../architecture/system-overview.md", "../../architecture/module-dependencies.md"]
---

# Clevelib Module Implementation Details

<!-- AI-IMPORTANCE:level=normal -->
## Technical Overview

The `clevelib` module encapsulates direct interactions with C libraries or system-level APIs. This is primarily achieved using CFFI (C Foreign Function Interface) for Common Lisp. The implementation involves defining Lisp equivalents of C types, structures, and functions, and providing Lisp-friendly wrappers around them. An example is the interaction with `termios.h` for terminal control, likely found in `src/clevelib/termios.lisp`.

*(Specific C libraries used, e.g., ncurses, termios, or custom C code, need to be identified from `src/clevelib/`.)*

<!-- AI-CONTEXT-START:type=implementation -->
## Core Implementation

### CFFI Definitions
(This section will detail the CFFI bindings. Actual content depends on the C libraries being interfaced, such as those in `src/clevelib/termios.lisp`.)

**Example (Hypothetical - for `termios.h` functions):**
```lisp
;; Loading the C library
;; (cffi:define-foreign-library libterminos
;;   (:unix (:or "libtermcap.so" "libtinfo.so" "libncurses.so"))
;;   (t (:default "libtermcap")))
;; (cffi:use-foreign-library libterminos)

;; Defining C structures
;; (cffi:defcstruct termios
;;   (c_iflag :unsigned-long)
;;   (c_oflag :unsigned-long)
;;   ;; ... other fields
;;   )

;; Defining C functions
;; (cffi:defcfun ("tcgetattr" tcgetattr) :int
;;   (fd :int)
;;   (termios-p :pointer))

;; (cffi:defcfun ("tcsetattr" tcsetattr) :int
;;   (fd :int)
;;   (optional-actions :int)
;;   (termios-p :pointer))
```

### Lisp Wrapper Functions
High-level Lisp functions are typically written to provide a more idiomatic interface over the raw CFFI calls. These wrappers handle:
- Memory management (e.g., `cffi:with-foreign-object`, `cffi:foreign-alloc`, `cffi:foreign-free`).
- Error checking and conversion of return codes to Lisp conditions.
- Conversion between Lisp types and C types.

**Example (Hypothetical wrapper):**
```lisp
;; (defun get-terminal-attributes (fd)
;;   (cffi:with-foreign-object (termios-ptr '(:struct termios))
;;     (let ((ret (tcgetattr fd termios-ptr)))
;;       (if (zerop ret)
;;           (cffi:foreign-slot-value termios-ptr '(:struct termios) 'c_lflag) ; Example
;;           (error "Error getting terminal attributes: ~a" ret)))))
```

### Resource Management
- Ensuring that any allocated C memory is properly freed.
- Handling file descriptors or other native resources carefully.

### Conditional Compilation (if any)
- Using Lisp features like `#+os-unix` or `#+sbcl` for platform-specific or implementation-specific C calls.
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=development -->
## Development Guide

### Key Public APIs (Internal to Elmtui)
(List the main Lisp functions exported by `clevelib` for use by other Elmtui modules, not for end-users.)
*   `get-terminal-size () => (values rows columns error-p)`
*   `set-terminal-raw-mode (fd)`
*   `restore-terminal-mode (fd original-settings)`

### Important Notes for Elmtui Developers
*   **Error Handling:** Functions in `clevelib` should signal Lisp conditions on C errors rather than returning raw error codes.
*   **Resource Leaks:** Be extremely careful about managing foreign memory and other native resources. Use `unwind-protect` or CFFI's `with-foreign-*` macros.
*   **Portability:** Abstract platform differences within `clevelib` as much as possible.
*   **Thread Safety:** If C libraries are not thread-safe, ensure appropriate locking mechanisms are used if `clevelib` functions can be called from multiple threads.

### Adding New C Bindings
1.  Identify the C functions/structs needed.
2.  Define CFFI bindings.
3.  Write Lisp wrapper functions with proper error handling and resource management.
4.  Add tests for the new bindings.
<!-- AI-CONTEXT-END -->

## Testing Strategy

*   Testing that C functions can be called successfully.
*   Verifying that data is correctly marshalled between Lisp and C.
*   Testing error handling for C function failures.
*   Ensuring no memory leaks from CFFI allocations.
*   (Mocking C calls might be necessary for some unit tests if direct system interaction is problematic in a test environment.)

## Known Limitations

*   Dependencies on specific C libraries might affect portability.
*   Complexity of managing manual memory allocation if not using `with-foreign-*` macros extensively.

## Related Resources
- [Clevelib Module Overview](./overview.md)
- [Platform Module Implementation Details](../platform/implementation.md)
- [Core Module Implementation Details](../core/implementation.md)
- [System Overview](../../architecture/system-overview.md)
- [Module Dependencies](../../architecture/module-dependencies.md)
- [CFFI User Manual](https://cffi.common-lisp.dev/manual/)