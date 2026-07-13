---
name: ghx
description: Forge gateway CLI for agents. One gh-shaped interface routed to GitHub (gh) or the Forgejo REST API. Use for ALL issue/PR/CI interaction with the repo's forge; raw gh and Forgejo CLIs are shadowed.
---

# ghx — forge gateway

Use `ghx <resource> <verb> [args...]` for all forge work. Same syntax on
GitHub and Forgejo repos — you never need to know the host.

## Setup (once per agent session)

Put the gateway and the shadow stubs on PATH, stubs first:

```bash
export PATH="<this-skill-dir>/stubs:<this-skill-dir>/bin:$PATH"
```

Forgejo repos additionally need `GHX_FORGEJO_TOKEN` (a scoped access
token) plus `curl` and `jq`. GitHub repos need `gh` installed and
authenticated.

## Implemented verbs

Run `ghx --help` for the authoritative list with usage. Highlights:

- Issues: `create`, `view [--comments]`, `list`, `comment`, `edit`
  (metadata only: labels/assignees/milestone)
- PRs: `create [--closes <n>]`, `view [--comments]`, `list`, `comment`,
  `edit` (metadata + reviewers), `review [--body ...]
  [--code-comment path:line:text]...`, `checks`, `status`
- CI: `run list`, `run view <id>`

Anything else exits 3 with `not a ghx command` — there is no
passthrough. Corrections go in follow-up comments; title/body editing is
deliberately absent.

## Notes

- `gh`, `tea`, and `fj` are shadowed on PATH; they redirect here.
- Every invocation is logged to
  `${XDG_STATE_HOME:-~/.local/state}/ghx/ghx.log`.
- On Forgejo below the support floor (15.0.2, see
  `docs/adr/0001-forgejo-version-support-floor.md`), CI-read verbs fail
  with `not supported on this Forgejo version`.
