#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

systems=(cl-events cl-inputs cl-state cl-styles)
warning_pattern='STYLE-WARNING|caught WARNING|caught ERROR|undefined variable|undefined function|compilation had style-warnings|compilation unit finished.*warning'

stdout_log="$(mktemp)"
stderr_log="$(mktemp)"
trap 'rm -f "${stdout_log}" "${stderr_log}"' EXIT

for system in "${systems[@]}"; do
  printf '\n==> testing %s independently\n' "${system}"
  : >"${stdout_log}"
  : >"${stderr_log}"

  set +e
  clpm bundle exec --with-client sbcl -- \
    --noinform --non-interactive \
    --eval '(require :asdf)' \
    --eval "(handler-bind
                ((warning
                   (lambda (condition)
                     (when (search \"redefining LOG4CL-IMPL:\"
                                   (princ-to-string condition))
                       (muffle-warning condition)))))
              (asdf:test-system \"${system}\"))" \
    >"${stdout_log}" 2>"${stderr_log}"
  rc=$?
  set -e

  cat "${stdout_log}"

  if [ "${rc}" -ne 0 ]; then
    cat "${stderr_log}" >&2
    exit "${rc}"
  fi

  if grep -Ei "${warning_pattern}" "${stderr_log}" >/dev/null; then
    echo "subsystem test emitted warning markers: ${system}" >&2
    cat "${stderr_log}" >&2
    exit 1
  fi

  cat "${stderr_log}" >&2
done

printf '\nAll reusable subsystem tests passed.\n'
