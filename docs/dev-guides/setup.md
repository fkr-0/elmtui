# Elmtui Development Environment Setup Guide

This guide provides instructions for setting up a development environment for working on the Elmtui library itself or building applications with Elmtui.

## Prerequisites

*   **Common Lisp Implementation:**
    *   A modern Common Lisp implementation is required. We primarily test with/recommend:
        *   **SBCL (Steel Bank Common Lisp):** (Provide version, e.g., 2.x.x or later)
        *   (Mention other supported implementations if any, e.g., CCL)
    *   Installation instructions for your Lisp implementation can typically be found on its official website.
*   **Quicklisp:**
    *   Quicklisp is a library manager for Common Lisp. If you don't have it, install it from [https://www.quicklisp.org/](https://www.quicklisp.org/).
*   **ASDF (Another System Definition Facility):**
    *   Usually comes bundled with modern Lisp implementations and Quicklisp.
*   **Git:**
    *   For cloning the Elmtui repository.
*   **Text Editor/IDE with Lisp Support:**
    *   **Emacs with SLIME or Sly:** Highly recommended for an interactive Lisp development experience.
    *   **VS Code with Alive:** A good alternative for VS Code users.
    *   (Other editors with Lisp plugins might also work).

## Setting Up Elmtui

### 1. Clone the Repository

```bash
git clone <repository_url_for_elmtui> elmtui
cd elmtui
```
*(Replace `<repository_url_for_elmtui>` with the actual URL)*

### 2. Make Elmtui Discoverable by ASDF

You need to tell ASDF where to find the Elmtui system definition. There are several ways to do this:

*   **Option A: Symlink to Quicklisp local-projects:**
    ```bash
    # Ensure this path is correct for your Quicklisp setup
    ln -s "$(pwd)" ~/quicklisp/local-projects/elmtui
    ```

*   **Option B: Add to ASDF source registry:**
    *   Add the path to the Elmtui directory to your Lisp implementation's ASDF source registry configuration. This is often done in `~/.config/common-lisp/source-registry.conf.d/` or a similar location.
    *   Example for `source-registry.conf`:
        ```lisp
        (:tree "/path/to/your/elmtui/directory/")
        ```

### 3. Install Dependencies (if using CLPM or a project-specific Quicklisp setup)

*   **Using CLPM:**
    *   If a `clpmfile` is present and you use CLPM:
        ```bash
        clpm install
        ```
*   **Using Quicklisp:**
    *   If dependencies are managed via Quicklisp, they should be automatically fetched when you load Elmtui, provided they are available in Quicklisp distributions.
    *   For project-local dependencies not in Quicklisp, ensure they are also in `~/quicklisp/local-projects/`.

### 4. Load Elmtui in Your Lisp Environment

Start your Lisp REPL (e.g., `sbcl`, or via SLIME/Sly in Emacs).

```lisp
;; Load Elmtui system
(ql:quickload :elmtui)

;; To load tests as well (if defined as a separate system or part of :elmtui)
;; (ql:quickload :elmtui-tests) or (ql:quickload "elmtui/tests")
```

### 5. Running Examples

*   Navigate to the `examples/` directory.
*   Load and run specific example files as per their instructions. For example:
    ```lisp
    ;; In your Lisp REPL, after loading :elmtui
    (load "examples/some-example.lisp")
    (elmtui-examples:run-some-example) ;; Or whatever the example's entry point is
    ```

## Troubleshooting

*   **System Not Found:** If ASDF cannot find `:elmtui`, double-check your ASDF source registry configuration or symlink in `local-projects`.
*   **Dependency Issues:** Ensure all required libraries are installed and accessible. Check Quicklisp or CLPM messages.
*   (Add more common setup issues and solutions as they become known).

---
*This guide will be updated with more specific instructions and troubleshooting tips.*