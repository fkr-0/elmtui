#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${TMUX:-}" && -z "${TMUX_PANE:-}" ]]; then
  printf 'run-glider.sh requires a live tmux pane; terminal unchanged.\n' >&2
  exit 2
fi
cd "$ROOT"
if command -v clpm >/dev/null 2>&1; then
  exec clpm bundle exec --with-client sbcl -- \
    --noinform --non-interactive --no-sysinit --no-userinit \
    --eval '(require :asdf)' \
    --eval '(asdf:load-system "elmtui")' \
    --load examples/tmux-glider.lisp \
    --eval '(elmtui.examples.tmux-glider:run-tmux-glider)'
else
  exec sbcl --noinform --non-interactive \
    --eval '(require :asdf)' \
    --eval '(asdf:load-system "elmtui")' \
    --load examples/tmux-glider.lisp \
    --eval '(elmtui.examples.tmux-glider:run-tmux-glider)'
fi
