---
title: feat: semi-automatic publishing for openui_flutter packages
type: feat
date: 2026-05-18
---

## feat: semi-automatic publishing for openui_flutter packages - Standard

## Overview

Wire up a release pipeline so a maintainer runs `melos version` locally, pushes the resulting commit and tags, and GitHub Actions publishes each tagged package to pub.dev via OIDC trusted-publisher. Versions and CHANGELOGs are derived from conventional-commit PR titles already enforced on the repo. Private packages (`openui_test_helpers`, `openui_flutter_example`) are excluded by the `noPrivate` filter in melos and by not being claimed on pub.dev.

Scope of this PR: configure melos for graph-aware versioning + workspace changelog, restrict PR-title scopes to package names, add a release workflow triggered on tag push, write `CONTRIBUTING.md` with the release recipe, and normalize the existing hand-written `(unreleased)` CHANGELOG entries so the first automated run produces clean output.

Source brainstorm: `docs/brainstorm/2026-05-18-semi-automatic-publishing-brainstorm-doc.md`.

## Problem Statement / Motivation

Today four packages (`openui_core`, `openui`, `openui_components`, `openui_mcp`) sit at `0.1.0 (unreleased)` with no automated path to pub.dev. CHANGELOGs are written by hand and version bumps would require touching four pubspecs in lockstep. No release has shipped yet, so this is the moment to wire the pipeline before manual habits set in.

Three forces push for a CI-driven path over a `melos publish` from a laptop:

1. **No long-lived pub.dev credentials.** Trusted-publisher via OIDC means the only thing GitHub knows about pub.dev is which workflow file is allowed to publish which package.
2. **Audit trail.** Every release is a tag + a workflow run, both visible in GitHub. A local `melos publish` leaves no trace beyond the maintainer's shell history.
3. **Bus factor.** Anyone with merge access can cut a release without first being granted pub.dev permissions.

The semantic-PR workflow already exists (`.github/workflows/semantic_pull_request.yml`), conventional commits are already the norm, no version strings are embedded in Dart source (grep-confirmed). The remaining gap is small.

## Proposed Solution

### Five concrete changes

1. **`melos.yaml`**: add a `command.version` block (graph-aware bumps, workspace changelog, link to commits, `branch: main`).
2. **`.github/workflows/semantic_pull_request.yml`**: add `scopes` allowlist + `requireScope: true`.
3. **`.github/workflows/publish.yml`** (new): triggers on tags matching `<package>-v*`. Resolves the tag to a package directory, runs `dart pub publish --force` from that directory under `dart-lang/setup-dart@v1` with OIDC permissions. One job per tag; tag-push of N tags fans out to N jobs.
4. **`CONTRIBUTING.md`** (new): conventional-commit rules with examples scoped to the allowed scopes, release recipe (`melos version` → review diff → `git push --follow-tags` → watch workflow), hotfix procedure, and the "never remove `publish_to: none`" rule.
5. **Existing CHANGELOGs**: rewrite each `## 0.1.0 (unreleased)` → `## 0.1.0` so the first automated `melos version --graduate` (run as part of release `0.2.0`) doesn't fight hand-written headers. The `0.1.0` content stays — it documents what's actually in the seed release.

### Maintainer release flow (the recipe documented in CONTRIBUTING.md)

```bash
# preview
melos publish --dry-run
melos version --dry-run

# cut release
melos version            # bumps, writes CHANGELOGs, commits, tags
git push --follow-tags   # triggers publish workflow per tag
# watch: gh run watch --workflow=publish.yml
```

### Initial seed publish (one-time, before this pipeline takes over)

A maintainer with pub.dev access runs `dart pub publish` from each of the four publishable package directories at `0.1.0`. After that, claim each package on pub.dev and configure trusted-publisher pointing at this repo (`VeryGoodOpenSource/openui_flutter`), workflow file (`publish.yml`), and tag pattern (`<package>-v*`). This step is not part of the PR — it's a prerequisite documented in CONTRIBUTING.md under "First-time pub.dev setup."

### What `melos.yaml` actually gets

```yaml
command:
  version:
    branch: main
    linkToCommits: true
    workspaceChangelog: true
    updateGitTagRefs: true
    # graph-aware dependent bumps are melos's default — bumping `openui_core`
    # also bumps `openui`, `openui_components`, `openui_mcp` as a patch.

scripts:
  # existing scripts stay as-is — `publish:dry-run` already covers the
  # preview case the brainstorm flagged. No new wrapper script needed.
  publish:dry-run:
    description: Run `dart pub publish --dry-run` for every publishable package.
    exec: dart pub publish --dry-run
    packageFilters:
      noPrivate: true
```

### What the publish workflow looks like

Delegates to VGV's reusable `flutter_pub_publish.yml@v1`, which supports pub.dev OIDC trusted-publisher and matches the pattern already used by every other CI workflow in this repo (e.g., `.github/workflows/openui_core.yml:20` calls `flutter_package.yml@v1`).

```yaml
# .github/workflows/publish.yml
name: publish

on:
  push:
    tags:
      - 'openui_core-v*'
      - 'openui-v*'
      - 'openui_components-v*'
      - 'openui_mcp-v*'

jobs:
  resolve:
    runs-on: ubuntu-latest
    outputs:
      package: ${{ steps.pkg.outputs.name }}
    steps:
      - id: pkg
        run: |
          tag="${GITHUB_REF_NAME}"
          # tag format: <package>-v<version>
          echo "name=${tag%-v*}" >> "$GITHUB_OUTPUT"

  publish:
    needs: resolve
    uses: VeryGoodOpenSource/very_good_workflows/.github/workflows/flutter_pub_publish.yml@v1
    with:
      working_directory: packages/${{ needs.resolve.outputs.package }}
      flutter_channel: stable
      flutter_version: 3.41.9
```

Notes on the workflow:
- Tag patterns are explicit (one per package). The example app and test helpers are absent — no possible misroute.
- `flutter_pub_publish.yml@v1` runs `dart-lang/setup-dart` with OIDC, so no `pub_credentials` secret is needed. The Flutter install also covers pure-Dart packages without branching on package type.
- The `resolve` job parses the tag into a package name. The `publish` job consumes it as the `working_directory` input. Two-job structure is the simplest way to feed a computed value into a reusable workflow's `with:` block (reusable workflows can't reference `steps.*` from the caller).

### Semantic-PR scopes

Update `.github/workflows/semantic_pull_request.yml` to declare allowed scopes and require one on every PR:

```yaml
- uses: amannn/action-semantic-pull-request@v5
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    requireScope: true
    scopes: |
      openui_core
      openui
      openui_components
      openui_mcp
      openui_test_helpers
      openui_flutter_example
      ci
      deps
      docs
      chore
```

Scope buckets:
- Six **package names** for changes that map to a single workspace package. Melos uses these to attribute commits to per-package CHANGELOGs.
- Four **conventional buckets** for changes that don't map to a single package: `ci` (workflows, melos config), `deps` (dependency bumps), `docs` (top-level docs, READMEs), `chore` (everything else cross-cutting). These keep cross-cutting changes out of the per-package changelogs without forcing a generic `repo` catch-all.

Multiple scopes per PR are allowed by the action (`feat(openui_core, openui): ...` is valid).

**Deviation from VGV reusable workflow.** VGV publishes `very_good_workflows/.github/workflows/semantic_pull_request.yml@v1`, but it exposes only a `scopes` input — no `requireScope`. We keep the direct `amannn/action-semantic-pull-request@v5` invocation because `requireScope: true` is load-bearing: without it, a PR titled `feat: something` (no scope) merges into `main` and melos can't attribute it to any package. Comment this rationale at the top of the workflow file.

## Technical Considerations

### Architecture impacts

None on Dart code. All changes are in `melos.yaml`, two GitHub workflows, one new top-level doc, and six CHANGELOG.md headers. No package APIs change; the workspace dependency graph (`openui_core` ← `openui` ← `openui_components`, `openui_core` ← `openui_mcp`) is what drives melos's dependent-bump logic and stays as-is.

### Tag format must match trusted-publisher regex

Open question 3 from the brainstorm. Melos produces per-package tags of the form `openui_core-v0.2.0`. When configuring trusted-publisher on pub.dev for each package, set the tag pattern to:

| Package | Tag pattern on pub.dev |
|---------|------------------------|
| `openui_core` | `openui_core-v.*` |
| `openui` | `openui-v.*` |
| `openui_components` | `openui_components-v.*` |
| `openui_mcp` | `openui_mcp-v.*` |

The workflow's `on.push.tags` array uses the same patterns. Tag pattern is the single bottleneck — if it doesn't match, pub.dev rejects the publish and the workflow job fails loudly (good failure mode).

### Should the publish workflow gate on per-package CI?

Open question 2 from the brainstorm. Decision: **no explicit gate in this PR**. The per-package CI workflows (`openui_core.yml`, etc.) run on `push: branches: [main]`, so the commit being tagged has already been validated on main. A future iteration can add a `gh run list --status success --commit "$GITHUB_SHA"` pre-flight check if we see flaky releases. Keep this PR small.

### Existing CHANGELOG content

The four publishable packages have hand-written `## 0.1.0 (unreleased)` entries describing real work. Strategy:

1. Rename `## 0.1.0 (unreleased)` → `## 0.1.0` in each `CHANGELOG.md`. Content stays.
2. The seed `0.1.0` publish happens manually (see "Initial seed publish" above) using these as the actual release notes.
3. Future bumps are driven by melos. `melos version` prepends `## <new-version>` above `## 0.1.0` and stops there.

`openui_test_helpers/CHANGELOG.md` keeps `## 0.0.1 (unreleased)` as-is — it's private, never publishes, doesn't affect the pipeline.

### Squash-merge GitHub setting

Not a code change. Repo admin must set:

- `Settings → General → Pull Requests`: enable **Allow squash merging** only; disable merge commits and rebase merging.
- `Settings → General → Pull Requests → Default to PR title for squash merge commits`: enable.

Document this as a manual prerequisite in CONTRIBUTING.md. Without it, the commit on `main` won't be the PR title, and conventional-commit parsing in melos breaks.

### Performance implications

None. Workflow runs only on tag push (release-time). Adds 1-4 short jobs per release, parallel by tag.

### Security considerations

- OIDC-only auth to pub.dev. No `PUB_DEV_TOKEN` secret in the repo. The trusted-publisher relationship lives on pub.dev's side and points at this exact repo + workflow file path.
- The publish workflow needs `id-token: write` permission; everything else is `contents: read`.
- Tag patterns on `on.push.tags` are explicit per package, so an attacker who pushes a `openui_flutter_example-v1.0.0` tag does not trigger the workflow. Even if they did, pub.dev would reject (no trusted publisher for `openui_flutter_example`).
- `requireScope: true` on PR titles prevents typos like `feat(openui_cre): ...` from being attributed to a non-existent package in changelogs.

## Acceptance Criteria

- [ ] `melos.yaml` has a `command.version` block with `branch: main`, `linkToCommits: true`, `workspaceChangelog: true`, `updateGitTagRefs: true`.
- [ ] `.github/workflows/semantic_pull_request.yml` declares `requireScope: true` and the ten-scope allowlist (`openui_core`, `openui`, `openui_components`, `openui_mcp`, `openui_test_helpers`, `openui_flutter_example`, `ci`, `deps`, `docs`, `chore`) with a comment explaining why the direct action is used instead of the VGV reusable.
- [ ] `.github/workflows/publish.yml` exists, triggers on the four publishable-package tag patterns, has a `resolve` job that parses the tag and a `publish` job that calls `VeryGoodOpenSource/very_good_workflows/.github/workflows/flutter_pub_publish.yml@v1` with the resolved `working_directory`.
- [ ] `CONTRIBUTING.md` exists at repo root and covers: conventional-commit format with scope examples, the release recipe, the first-time pub.dev trusted-publisher setup instructions, the squash-merge repo setting requirement, the hotfix procedure (re-run failed workflow; never re-tag), the "never remove `publish_to: none`" rule.
- [ ] Each publishable package's `CHANGELOG.md` has `## 0.1.0 (unreleased)` rewritten to `## 0.1.0`. `openui_test_helpers/CHANGELOG.md` is untouched.
- [ ] `melos version --dry-run` against `main` produces clean output (no parse errors, no duplicate header conflicts).
- [ ] PR title for this change uses scope `ci` (the workflow + melos config bucket) to validate the new scope allowlist on its own merge.

### Manual verification (out of band, by the maintainer)

These can't be tested in CI but the PR is not "done" until they pass:

- [ ] On a throwaway fork or `act`-run: trigger a fake tag push and confirm the workflow job resolves the right package directory.
- [ ] Once merged: maintainer runs `melos version --prerelease=rc` on a branch, pushes a `-v0.2.0-rc.0` tag, and confirms the publish workflow either succeeds or fails for the expected reason (no trusted-publisher yet → pub.dev rejects with a clear error).

## Success Metrics

- A maintainer can cut a release of any of the four packages with three commands (`melos version`, review, `git push --follow-tags`) and zero pubspec edits.
- Zero pub.dev credentials live in the repo or in GitHub Secrets.
- CHANGELOGs are never edited by hand again after this PR lands. PR title authoring becomes the changelog authoring.
- The semantic-PR workflow fails any PR whose title doesn't carry one of the seven allowed scopes — visible in the GitHub Checks UI on the PR itself.

## Dependencies & Risks

### Dependencies

- **GitHub repo settings (manual).** Squash-merge must be enabled and set as the default merge method with "use PR title as commit subject." Document, don't automate. This blocks the *value* of the pipeline (without it, `main` commits won't be the PR titles), not the PR's mergeability.
- **pub.dev trusted-publisher setup (manual, post-merge).** Each package must be claimed by a publisher account at least once and configured with the tag pattern and workflow file. Until this is done per package, the publish workflow will fail with an auth error for that package. Document the steps; expect to do them once.
- **Initial seed `0.1.0` publish (manual, post-merge).** Same constraint as above — pub.dev needs the package to exist before trusted-publisher can be configured on it.

### Risks

- **Tag-pattern drift.** If someone later renames a package directory or changes melos's tag template, the workflow's `on.push.tags` array and the pub.dev tag pattern both need updating. Mitigation: comment in both places pointing at the other; mention in CONTRIBUTING.md's "renaming a package" section.
- **First `melos version --graduate` after this lands.** It runs against the existing `0.1.0` headers. If we leave them as `(unreleased)`, melos may produce duplicate `## 0.1.0` headers or refuse to bump. Mitigation: the CHANGELOG normalization is part of this PR.
- **Workspace resolution + `dart pub publish`.** Each publishable package has `resolution: workspace`. Confirm `dart pub publish --dry-run` works cleanly inside a workspace member before wiring the workflow; if not, the publish step needs `melos publish` instead.
- **`dart-lang/setup-dart` OIDC support.** Available since `setup-dart@v1.5+`. The VGV reusable workflow handles this; we don't pin directly.

## References & Research

- Source brainstorm: `docs/brainstorm/2026-05-18-semi-automatic-publishing-brainstorm-doc.md`
- Existing semantic-PR workflow: `.github/workflows/semantic_pull_request.yml`
- Existing publish dry-run script: `melos.yaml:30-35` (the `publish:dry-run` script)
- Per-package CI workflows (the pattern this builds on): `.github/workflows/openui_core.yml`, `.github/workflows/openui.yml`, `.github/workflows/openui_components.yml`, `.github/workflows/openui_mcp.yml`
- Workspace pubspec: `pubspec.yaml:5-12` (the `workspace:` block defines which packages melos sees)
- Private-package declarations: `apps/openui_flutter_example/pubspec.yaml:4`, `packages/openui_test_helpers/pubspec.yaml:9`
- Hand-written changelogs to normalize: `packages/openui_core/CHANGELOG.md`, `packages/openui/CHANGELOG.md`, `packages/openui_components/CHANGELOG.md`, `packages/openui_mcp/CHANGELOG.md`
- Melos versioning + workspace changelog: https://melos.invertase.dev/commands/version
- pub.dev trusted-publisher (GitHub Actions OIDC): https://dart.dev/tools/pub/automated-publishing
- `amannn/action-semantic-pull-request` scope config: https://github.com/amannn/action-semantic-pull-request#configuration
