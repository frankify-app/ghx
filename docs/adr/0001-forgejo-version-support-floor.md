# Forgejo version handling: support floor, gated in the dispatch table

ghx supports one Forgejo version floor: **15.0.2** (the version deployed today). No per-version compatibility adapters or response-shape translation — that would recreate the CLI-churn problem the REST-backend choice avoided. Verbs that need endpoints newer than the floor declare a minimum version as a column in the dispatch table. ghx reads the instance version from `GET /api/v1/version` once per host, caches it in the state dir, and rejects a gated verb below its minimum with a distinct exit code and `not supported on this Forgejo version`. Rejections are logged like every other dispatch decision, so demand for a gated verb is observable before anyone raises the floor.

GitHub is not version-gated in ghx: `gh` absorbs API drift; `doctor.sh` may check a minimum `gh` version.
