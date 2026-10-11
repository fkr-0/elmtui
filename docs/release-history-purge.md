# ElmTUI repository hygiene and historical purge

The original root contained transient shell and Lisp launchers, AI instruction
documents, exploratory plans, binary executables and scratch artifacts.
Removing these in a later commit did **not** remove their blobs from prior Git
history. This release-cleanroom lineage uses `git-filter-repo` to remove
all paths in `scripts/history-purge-paths.txt` across **all imported refs**.

## Source of truth

- Root contains only Git/package metadata, CHANGELOG, LICENSE, README and
  ASDF system files. Ordinary scripts and Lisp test/dev entry points live
  in `scripts/`; source libraries stay in `src/` and examples in `examples/`.
- CLI examples: `./scripts/examples.sh list` and `./scripts/examples.sh run NAME`.
- Test runner: `clpm bundle exec --with-client sbcl -- --noinform --load scripts/run-tests-clpm.lisp`.
- Coverage: `clpm bundle exec --with-client sbcl -- --noinform --load scripts/coverage.lisp`.
- Slynk: use the `slynk` bridge command (loads `scripts/run-slynk.lisp`).
- Replaced legacy `exe`/Roswell launchers and root scripts are **not**
  compatibility APIs; use `bridge.yml` and the dedicated scripts instead.

## Verification

```sh
python3 -m unittest discover -s tests -p 'test_release_tree.py' -v
python3 -m pytest -q tests/test_runner_contracts.py
bash -n scripts/examples.sh scripts/run-glider.sh
git diff --check
scripts/release-check.sh
```

The history check requires that old refs imported into the repository
have **also** been rewritten. Future forks that re-import pre-purge branch
tips or tags will reintroduce their objects and fail that guard.

## Scope and publication boundary

The original repository at `/home/user/code/lisp/elmtui.lisp` was
rewritten **in place** on 2026-10-12, including all local branches, tags,
stash and auxiliary refs, with:

```sh
git filter-repo --force --invert-paths \
  --paths-from-file scripts/history-purge-paths.txt
```

All historical commit IDs, including the local v0.2.0 tag's target, changed.
A pre-filter mirror backup is stored outside the rewritten repository under
`/home/user/code/lisp/.worktrees/elmtui-original-before-filter-20261012.git`.
Linked worktrees' dirty patches and status inventories are preserved under
`/home/user/code/lisp/.worktrees/elmtui-pre-filter-worktrees/`.
Only indexes for purged paths were updated in linked worktrees; old local
files remain on disk and are ignored via the main repository's local
`.git/info/exclude`, not deleted. The GitHub remote URL was restored after
filter-repo removed it; **no remote fetch or force-push occurred**.

Rewriting a repository with published refs requires coordinating all
contributors, dependent worktrees and automation. The rewrite is a new
lineage: old clones, forks, server caches, PRs, tags, and reflogs may retain
the original objects; deleting local objects does not delete remote copies.
Publish only after review, backup, a repository-wide migration decision and
a controlled replacement of *every affected ref*. Do not merge this rewrite
onto the original main branch: that restores old ancestors.

Only root and the enumerated transient paths were purged automatically.
Legitimate `src/`, `examples/`, `tests/`, `docs/`, `tasks/` and ASDF
definitions were retained unless expressly covered by the manifest. Any
further candidate for removal needs dependency and licensing review.
