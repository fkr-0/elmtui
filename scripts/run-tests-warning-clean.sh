#!/usr/bin/env bash
set -euo pipefail

# Run the declared CLPM test entrypoint and fail if stderr contains unexpected
# compiler/runtime warning markers. Keep captured logs for inspection on failure.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ELMTUI_TEST_OUTPUT_DIR:-${ROOT_DIR}/test-output}"
mkdir -p "${OUT_DIR}"

STAMP="${ELMTUI_TEST_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
STDOUT_LOG="${OUT_DIR}/warning-clean-${STAMP}.stdout.log"
STDERR_LOG="${OUT_DIR}/warning-clean-${STAMP}.stderr.log"

cd "${ROOT_DIR}"

set +e
clpm bundle exec --with-client sbcl -- --noinform --load scripts/run-tests-clpm.lisp \
  >"${STDOUT_LOG}" \
  2>"${STDERR_LOG}"
rc=$?
set -e

if [ "${rc}" -ne 0 ]; then
  echo "warning-clean: test command failed with exit code ${rc}" >&2
  echo "warning-clean: stdout log: ${STDOUT_LOG}" >&2
  echo "warning-clean: stderr log: ${STDERR_LOG}" >&2
  exit "${rc}"
fi

warning_pattern='STYLE-WARNING|caught WARNING|caught ERROR|undefined variable|undefined function|compilation had style-warnings|compilation unit finished.*warning'

if grep -E "${warning_pattern}" "${STDERR_LOG}" >/dev/null; then
  echo "warning-clean: unexpected warning markers in ${STDERR_LOG}" >&2
  grep -nE "${warning_pattern}" "${STDERR_LOG}" >&2
  echo "warning-clean: stdout log: ${STDOUT_LOG}" >&2
  exit 1
fi

echo "warning-clean: ok"
echo "warning-clean: stdout log: ${STDOUT_LOG}"
echo "warning-clean: stderr log: ${STDERR_LOG}"
