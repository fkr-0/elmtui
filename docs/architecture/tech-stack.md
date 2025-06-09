# Elmtui Technology Stack

This document details the primary technologies and libraries used in the Elmtui project.

## Core Language

*   **Common Lisp:** Elmtui is implemented in Common Lisp.
    *   **Specific Implementation(s):** (e.g., SBCL, CCL - specify which are primarily targeted or tested)
    *   **Key Lisp Features Leveraged:** (e.g., CLOS, macros, conditions)

## Key Dependencies / Libraries

*(This section will be populated by analyzing the project's system definition files like `elmtui.asd` or `clpmfile`)*

*   **UI / Graphics (Low-level):**
    *   (e.g., Any libraries for terminal control, character manipulation, color handling if not purely custom)
*   **Concurrency / Asynchronous Operations:**
    *   (e.g., Bordeaux-threads, Lparallel, or custom threading utilities)
*   **Testing:**
    *   (e.g., FiveAM, Parachute, Lisp-Unit)
*   **Build / System Definition:**
    *   ASDF (Another System Definition Facility)
    *   CLPM (Common Lisp Project Manager) - if `clpmfile` is actively used for dependency management.
*   **Other Utility Libraries:**
    *   (e.g., Alexandria, Serapeum, etc., if used)

## Development Tools

*   **Editor/IDE:** (e.g., Emacs with SLIME/Sly, VS Code with Alive)
*   **Build System:** (Primarily ASDF, potentially with CLPM commands)
*   **Version Control:** Git

## Platform Support

*   **Operating Systems:** (e.g., Linux, macOS, Windows - specify targeted/tested OSes)
*   **Terminal Emulators:** (e.g., urxvt, xterm, GNOME Terminal, iTerm2 - specify any known compatibility or specific features leveraged)

---
*This document will be updated as the project evolves and more specific details about dependencies are confirmed.*