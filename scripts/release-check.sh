#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

printf '==> checking repository topology and release manifest\n'

if [ -e .gitmodules ]; then
  echo 'release-check: .gitmodules must not exist; reusable libraries are in-tree systems' >&2
  exit 1
fi

for library in cl-events cl-inputs cl-state cl-styles; do
  if find "${library}" -name .git -print -quit | grep -q .; then
    echo "release-check: nested Git metadata found under ${library}" >&2
    exit 1
  fi
done

required_files=(
  LICENSE
  CHANGELOG.md
  README.org
  bridge.yml
  clpmfile
  clpmfile.lock
  dev/clpmfile
  dev/clpmfile.lock
  elmtui.asd
  elmtui-tests.asd
  elmtui-examples.asd
  elmtui-examples-fzy.asd
  elmtui-widgets-enhanced.asd
  docs/architecture/library-boundaries.md
  docs/release-checklist.md
  examples/README.md
  scripts/release-check.sh
  scripts/test-subsystems.sh
  scripts/test-subproject-bundles.sh
  scripts/run-tests-warning-clean.sh
  cl-events/LICENSE
  cl-events/README.md
  cl-events/CHANGELOG.md
  cl-events/clpmfile
  cl-events/clpmfile.lock
  cl-events/cl-events.asd
  cl-events/cl-events-tests.asd
  cl-inputs/LICENSE
  cl-inputs/README.md
  cl-inputs/CHANGELOG.md
  cl-inputs/clpmfile
  cl-inputs/clpmfile.lock
  cl-inputs/cl-inputs.asd
  cl-inputs/tests/ansii-tests.lisp
  cl-state/LICENSE
  cl-state/README.md
  cl-state/CHANGELOG.md
  cl-state/clpmfile
  cl-state/clpmfile.lock
  cl-state/cl-state.asd
  cl-state/cl-state-tests.asd
  cl-styles/LICENSE
  cl-styles/README.md
  cl-styles/CHANGELOG.md
  cl-styles/clpmfile
  cl-styles/clpmfile.lock
  cl-styles/cl-styles.asd
)

for file in "${required_files[@]}"; do
  if [ ! -f "${file}" ]; then
    echo "release-check: required file is missing: ${file}" >&2
    exit 1
  fi
  if ! git ls-files --error-unmatch "${file}" >/dev/null 2>&1; then
    echo "release-check: required file is not tracked: ${file}" >&2
    exit 1
  fi
done

if grep -Eq '"/|"[A-Za-z]:\\\\' \
     clpmfile clpmfile.lock dev/clpmfile dev/clpmfile.lock; then
  echo 'release-check: CLPM metadata contains an absolute local path' >&2
  grep -En '"/|"[A-Za-z]:\\\\' \
    clpmfile clpmfile.lock dev/clpmfile dev/clpmfile.lock >&2
  exit 1
fi

printf '\n==> checking staged and unstaged patch whitespace\n'
git diff --check
git diff --cached --check

printf '\n==> validating public API documentation metadata\n'
scripts/check-docstrings.sh

printf '\n==> validating standalone subsystem bundles\n'
scripts/test-subproject-bundles.sh

printf '\n==> validating reusable systems in the root bundle\n'
scripts/test-subsystems.sh

printf '\n==> running warning-clean ElmTUI integration suite\n'
scripts/run-tests-warning-clean.sh

printf '\nElmTUI release checks passed.\n'
