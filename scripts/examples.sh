#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

run_examples_cli() {
  local -a sbcl_args=(
    --noinform
    --non-interactive
    --no-sysinit
    --no-userinit
    --eval '(require :asdf)'
    --eval '(setf *compile-verbose* nil *load-verbose* nil)'
    --load "${ROOT_DIR}/scripts/load-examples-cli.lisp"
    --eval '(let ((args (uiop:command-line-arguments))) (when (and args (string= (first args) "--")) (pop args)) (elmtui.examples.runner:main args))'
    --
    "$@"
  )

  if command -v clpm >/dev/null 2>&1 && [[ -f "${ROOT_DIR}/clpmfile" ]]; then
    exec clpm bundle exec --with-client sbcl -- "${sbcl_args[@]}"
  else
    exec sbcl "${sbcl_args[@]}"
  fi
}

run_examples_cli "$@"
