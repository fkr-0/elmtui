# 0.1.0 release status

ElmTUI is preparing a **first public 0.1.0 release candidate**, with the Workbench included as the flagship example. This page records the work remaining before a GitHub release tag is cut.

**Not a release announcement.** Current local metadata still identifies the framework as 0.2.0 and the repository contains a prior v0.2.0 tag. Those facts must be reconciled before publishing an official 0.1.0 tag.

Critical gates:

1. Independently qualify Workbench startup, editor, completion, evaluation, inspector, resize and terminal restoration in real PTYs.
2. Finish the maintained example regression sweep; record pass/fail per app, including scrollback and idle-output behavior.
3. Review public documentation against exported APIs and regenerate the API reference.
4. Agree on the release version and compatibility story, pin clean support-library revisions and confirm license/provenance.
5. Validate all CI jobs and Pages deployment. Supply the Workbench screenshot and animation assets.

See the [detailed release checklist](https://github.com/fkr-0/elmtui/blob/main/docs/release-0.1.0-checklist.md) in the repository.
