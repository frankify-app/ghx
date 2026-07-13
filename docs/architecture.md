# Architecture

Read [ghx](glossary/ghx.md) and this document before touching code.

## Shape

`skill/` is the distributable unit (ghx + shadow stubs, shipped together
via `npx skills`):

- `skill/bin/ghx` — entry point: parse verb → allowlist check → dispatch.
- `skill/lib/table.sh` — the verb table; single source of truth for what
  is implemented (usage strings, Forgejo minimum versions).
- `skill/lib/dispatch.sh` — backend detection from the git remote and
  routing to `<backend>_<verb>` handler functions.
- `skill/lib/github.sh` — thin forwards to `gh`.
- `skill/lib/forgejo.sh` — Forgejo REST calls (curl + jq), bodies built
  internally.
- `skill/lib/version_gate.sh` — stateless check-on-failure version gate
  ([ADR 0001](adr/0001-forgejo-version-support-floor.md)).
- `skill/lib/edit.sh`, `skill/lib/review.sh` — shared flag parsing and
  payload assembly used by both backends.
- `skill/lib/log.sh`, `skill/lib/stub.sh`, `skill/stubs/` — append-only
  invocation log and the PATH shadow stubs.

Rule of thumb from the spec: if a verb needs more than "build one call →
run it", it does not belong in ghx.
