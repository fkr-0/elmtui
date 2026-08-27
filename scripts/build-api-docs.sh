#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

clpm bundle exec --with-client sbcl -- --noinform \
  --eval '(asdf:load-system :elmtui-docs)' \
  --eval '(multiple-value-bind (markdown html) (elmtui.docs:build-api-docs) (format t "API docs:~%  ~A~%  ~A~%" markdown html))' \
  --quit
