# Elmtui Contribution Guide

Thank you for your interest in contributing to Elmtui! We welcome contributions of all kinds, from bug reports and documentation improvements to new features and code enhancements.

## Ways to Contribute

*   **Reporting Bugs:** If you find a bug, please submit an issue on our issue tracker (link to be provided). Include steps to reproduce, expected behavior, actual behavior, and relevant environment details.
*   **Suggesting Enhancements:** Have an idea for a new feature or an improvement to an existing one? Open an issue to discuss it.
*   **Improving Documentation:** Clear and accurate documentation is crucial. If you find errors, omissions, or areas that could be clearer, please submit a pull request or open an issue.
*   **Writing Code:**
    *   Fixing bugs.
    *   Implementing new features or widgets.
    *   Refactoring code for clarity or performance.
*   **Adding Examples:** New examples showcasing Elmtui's features are always welcome.
*   **Writing Tests:** Help us improve test coverage.

## Getting Started with Code Contributions

1.  **Set up your Development Environment:** Follow the [Setup Guide](./setup.md).
2.  **Fork the Repository:** Create your own fork of the Elmtui repository on (GitHub/GitLab/etc. - specify platform).
3.  **Create a Branch:** Create a new branch in your fork for your changes (e.g., `git checkout -b feature/my-new-feature` or `fix/issue-123`).
4.  **Understand the Codebase:**
    *   Familiarize yourself with the [Core Concepts](../architecture/core-concepts.md) and [System Architecture](../architecture/system-overview.md).
    *   Browse the relevant module documentation in `docs/modules/`.
5.  **Follow Coding Standards:** Adhere to the project's [Coding Standards](./coding-standards.md).
6.  **Write Tests:**
    *   For bug fixes, add a test that reproduces the bug and verifies the fix.
    *   For new features, write tests to cover the new functionality.
    *   Ensure all tests pass before submitting.
7.  **Write Clear Commit Messages:** Follow conventional commit message formats if applicable, or at least ensure your messages are descriptive.
8.  **Keep Your Branch Up-to-Date:** Regularly rebase your branch on the latest `main` (or `develop`) branch of the upstream repository.
    ```bash
    git fetch upstream
    git rebase upstream/main
    ```
9.  **Submit a Pull Request (PR):**
    *   Push your changes to your fork.
    *   Open a Pull Request against the `main` (or `develop`) branch of the upstream Elmtui repository.
    *   Provide a clear description of your changes in the PR. Link to any relevant issues.
    *   Be prepared to discuss your changes and make adjustments based on feedback from maintainers.

## Code Review Process

*   Maintainers will review your PR for correctness, style, and adherence to project goals.
*   Constructive feedback may be provided. Please address any comments or suggestions.
*   Once the PR is approved, it will be merged by a maintainer.

## Community and Communication

*   **Issue Tracker:** (Link to issue tracker)
*   **Mailing List / Forum:** (If applicable)
*   **Chat (Discord/Slack/IRC):** (If applicable)

We appreciate your contributions to making Elmtui better!

---
*This guide will be updated with specific links and further details as the project's contribution infrastructure is formalized.*