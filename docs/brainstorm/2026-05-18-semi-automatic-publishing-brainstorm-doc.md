---
date: 2026-05-18
topic: semi-automatic-publishing
---

# Semi-Automatic Publishing for OpenUI Flutter Packages

## What We're Building

A release pipeline for the four publishable packages in this workspace (`openui_core`, `openui`, `openui_components`, `openui_mcp`) where a maintainer runs one local command to bump versions and tag the repo, and GitHub Actions handles the actual `dart pub publish` via pub.dev's trusted-publisher (OIDC) mechanism. Versions and changelogs are derived from conventional-commit PR titles already enforced on the repo, so the bump step is mechanical rather than a manual edit.

The private packages stay out of the release flow automatically. Both `openui_test_helpers` (`packages/openui_test_helpers/pubspec.yaml:9`) and `openui_flutter_example` (`apps/openui_flutter_example/pubspec.yaml:4`) declare `publish_to: none`, which makes melos's `noPrivate: true` filter skip them. The existing `melos publish:dry-run` script already proves this works end-to-end — the CI publish workflow uses the same filter, and trusted-publisher will only be configured on pub.dev for the four real packages, so a misconfigured pubspec can't accidentally push the example app.

## Why This Approach

Three release models were considered:

1. **Local-only `melos publish`** — matches the original MVP list but requires every maintainer to hold pub.dev credentials and run the publish step by hand. Easy to skip, hard to audit.
2. **CI publish on tag via pub.dev trusted publisher (chosen)** — maintainer runs `melos version` locally (it computes bumps, writes changelogs, commits, tags, pushes). The push triggers a release workflow that runs `dart pub publish` for each tagged package using OIDC. No credentials live in GitHub secrets. pub.dev recommends this path.
3. **Single `workflow_dispatch` button** — fully automates version + publish, but skips the human review of the version bump diff. Loses a useful sanity check given semi-automatic was the stated goal.

The MVP list in the brief already gets us most of the way there. The only addition is the CI publish workflow itself, which is small and gives us the auth posture we want from day one.

## Key Decisions

- **Publish runner: GitHub Actions on tag, pub.dev trusted publisher.** Maintainers run `melos version` and `git push --follow-tags`; the workflow does the rest. One-time per-package trusted-publisher setup on pub.dev pointing at this repo + workflow file.

- **Versioning: graph-aware (independent + dependent bumps).** Melos default. A feature commit scoped to `openui_core` bumps `openui_core` *and* every workspace package that depends on it (`openui`, `openui_components`, `openui_mcp`) as a patch. Per-package consumers see only the version moves that actually affect them; reverse-dep bumps prevent stale transitive references.

- **`melos.yaml` config:** add `command.version` block with `linkToCommits: true` (changelogs link to the commit), `workspaceChangelog: true` (root rollup), `branch: main`, and `updateGitTagRefs: true`. No `preCommit` hooks needed — no version strings are embedded in Dart source (grep confirmed). The existing `publish:dry-run` script stays as a pre-release smoke check.

- **Changelogs: per-package + root workspace.** `workspaceChangelog: true` writes a rolled-up root `CHANGELOG.md`; each package keeps its own `CHANGELOG.md` containing only commits scoped to it. The existing hand-written `0.1.0 (unreleased)` entries get replaced on first run — call this out in CONTRIBUTING so nobody hand-edits in parallel.

- **PR scopes: restricted allowlist.** Extend the existing `semantic_pull_request.yml` workflow with `scopes` matching the workspace package names (`openui_core`, `openui`, `openui_components`, `openui_mcp`, `openui_test_helpers`, `openui_flutter_example`) plus a `repo` scope for cross-cutting changes (CI, docs, melos config). `requireScope: true`. This is what melos uses to attribute commits to packages for the per-package changelog.

- **Squash-merge required in GitHub repo settings.** Not a code change. Repo admin needs to set "Allow squash merging" + disable merge commits/rebase in `Settings → General → Pull Requests` so the PR title (already validated) becomes the commit subject on `main`. Document this as a manual prerequisite.

- **CONTRIBUTING.md release recipe.** New file at repo root. Covers: the conventional-commit rules in plain English with examples, how to run `melos version` (including `--prerelease`, `--graduate`, and `-d` dry-run flags), what the version-bump commit + tag push looks like, where to watch the publish workflow, and how to hotfix a failed publish (re-run the workflow; don't re-tag).

- **Private-package guardrails (defense in depth).** The publish workflow uses `melos publish --no-dry-run --yes` with `packageFilters: noPrivate: true` (same filter as the existing `publish:dry-run` script). On top of that, trusted-publisher on pub.dev is only configured for `openui_core`, `openui`, `openui_components`, `openui_mcp` — so even if `publish_to: none` were accidentally removed from `openui_flutter_example` or `openui_test_helpers`, pub.dev would reject the push for lack of a publisher relationship. CONTRIBUTING.md should call out: never remove `publish_to: none` from app/test-helper packages.

- **Out of scope for this iteration:** automatic release-PR bots (release-please style), prerelease channels (`-dev.N` builds on every main push), and any cross-repo coordination. Keep the workflow simple; revisit if multi-package consumer churn becomes a real problem.

## Open Questions

- Trusted-publisher setup on pub.dev requires each package to be claimed at least once. Who does the initial `0.1.0` publish for each package to seed ownership, and does that happen before or after this pipeline lands?
- Should the release workflow gate on per-package CI (the existing `openui_core.yml`, `openui.yml`, etc.) being green for the tagged commit, or trust that those already ran on `main`? Cleanest is a `workflow_call`-style dependency or a `gh run list` check before publish.
- Tag format: melos defaults to `<package>-v<version>` per package on independent versioning. Confirm that matches the trusted-publisher tag pattern pub.dev expects when configured (it's flexible, but the regex needs to be set correctly per package).
- Do we want a `melos run` script wrapper (e.g. `melos run release:dry`) that chains `publish:dry-run` + `version --dry-run` so contributors get a single command to preview a release locally?
