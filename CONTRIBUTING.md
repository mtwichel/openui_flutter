# Contributing

Thanks for working on `openui_flutter`. This document covers the conventions you need to follow to land a PR and the recipe maintainers use to cut a release.

## Conventional commits and PR titles

This repo squash-merges every PR, so the **PR title becomes the commit subject on `main`**. PR titles are validated by `.github/workflows/semantic_pull_request.yml` and must follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>
```

`melos version` parses these titles to decide version bumps and to attribute changes to per-package changelogs. A typo in the scope means the change ends up in the wrong changelog (or nowhere). Take the scope seriously.

### Allowed types

| Type | When to use it | Effect on version |
|------|----------------|-------------------|
| `feat` | New user-visible behavior | Minor bump |
| `fix` | Bug fix | Patch bump |
| `refactor` | Internal rewrite, no behavior change | Patch bump |
| `perf` | Performance improvement | Patch bump |
| `docs` | Documentation only | No bump |
| `test` | Tests only | No bump |
| `build` | Build system, tooling | No bump |
| `ci` | CI config | No bump |
| `chore` | Anything else | No bump |

A trailing `!` (e.g., `feat(openui_core)!:`) or a `BREAKING CHANGE:` footer signals a breaking change and triggers a major bump.

### Allowed scopes

Every PR title must carry a scope. The allowed scopes are:

**Package scopes** — use when the change maps to a single workspace package. Melos attributes the commit to that package's `CHANGELOG.md`:

- `openui_core`
- `openui`
- `openui_components`
- `openui_mcp`
- `openui_test_helpers`
- `openui_flutter_example`

**Cross-cutting scopes** — use when no single package owns the change. These don't show up in per-package changelogs:

- `ci` — workflow files, `melos.yaml`, repo automation
- `deps` — dependency bumps that don't fit a single package
- `docs` — top-level docs (`README.md`, `CONTRIBUTING.md`, `docs/`)
- `chore` — everything else cross-cutting

Multiple scopes are allowed when a change genuinely spans packages: `feat(openui_core,openui): ...` (comma-separated, no space).

### Examples

```
feat(openui_core): add @Each loop variable support
fix(openui_components): correct disabled-button contrast in dark theme
feat(openui_mcp)!: rename McpToolProvider.invoke -> McpToolProvider.call
ci: gate publish workflow on per-package CI green
docs: document the release recipe
chore(deps): bump very_good_analysis to 9.0.0
```

## Releasing

A release is cut by a maintainer with merge access. There's no release bot. The release flow is the same for every publishable package.

### Publishable packages

Only these four are published to pub.dev:

- `openui_core`
- `openui`
- `openui_components`
- `openui_mcp`

`openui_test_helpers` and `openui_flutter_example` are private. Both declare `publish_to: none` in their pubspec. **Never remove that line.** `noPrivate: true` in `melos.yaml` keeps them out of the release flow, and pub.dev has no trusted-publisher relationship for either — but `publish_to: none` is the load-bearing guardrail. Removing it would let an accidental tag push attempt a publish.

### Release recipe

```bash
# 1. Sanity check: confirm every publishable package is in a publishable state.
melos publish --dry-run

# 2. Cut the release. Melos parses conventional-commit subjects since the last
#    tag, bumps versions across the dependency graph, writes per-package and
#    workspace changelogs, commits the result, and tags each bumped package as
#    <package>-v<version>.
melos version

# 3. Review the diff before pushing. The commit and tags are local until the
#    next step. If the bump or changelog content is wrong, undo with:
#      git reset --hard HEAD~1
#      git tag -d <each-tag-melos-just-created>
#    Fix the offending PR titles on main first, then rerun `melos version`.

# 4. Push commits and tags. The tag push triggers .github/workflows/publish.yml,
#    which publishes each tagged package via pub.dev OIDC trusted-publisher.
git push --follow-tags

# 5. Watch the publish workflow.
gh run watch --workflow=publish.yml
```

`melos version` writes new `## <version>` headers above existing entries in each `CHANGELOG.md`. Reviewing that diff before pushing is the human checkpoint that makes this "semi-automatic" rather than fully automatic.

> Note: `melos version` in melos 7.x has no `--dry-run` flag. Passing `--no-git-commit-version --no-git-tag-version` runs the version logic and leaves the working tree dirty without committing or tagging, which is the closest equivalent to a preview. After previewing, `git checkout .` to revert before running the real `melos version`.

### Hotfix procedure

If a publish job fails:

1. **Re-run the workflow.** `gh run rerun <run-id>` or click "Re-run failed jobs" in the GitHub UI. Most failures are transient (pub.dev hiccup, OIDC token race).
2. **Do not re-tag.** Once a tag exists on `main`, leave it. Re-tagging the same version moves the tag pointer and confuses consumers who already saw the original SHA. If a different commit needs to publish under that version, bump to the next version instead and tag that.
3. **If the publish must be abandoned**, leave the tag in place and document why in the next release's CHANGELOG. pub.dev never had the version, so consumers won't see a gap.

## First-time pub.dev setup

These steps happen once per package, before the publish pipeline can succeed for that package. They're manual and require a maintainer with pub.dev access.

### 1. Seed the initial publish

The publish pipeline assumes each package already exists on pub.dev. Before this PR's pipeline takes over, run from each publishable package directory:

```bash
cd packages/openui_core && dart pub publish
cd packages/openui && dart pub publish
cd packages/openui_components && dart pub publish
cd packages/openui_mcp && dart pub publish
```

This publishes `0.0.1-dev.1` of each package using the maintainer's pub.dev credentials. After this point, no maintainer needs pub.dev credentials again.

### 2. Configure trusted-publisher per package

For each of the four publishable packages, go to `https://pub.dev/packages/<package>/admin` and configure **GitHub Actions trusted publishing** with:

| Field | Value |
|-------|-------|
| Repository | `VeryGoodOpenSource/openui_flutter` |
| Workflow file | `.github/workflows/publish.yml` |
| Environment | _leave empty_ |
| Tag pattern | `<package>-v.*` (e.g., `openui_core-v.*`) |

The tag pattern must match the tag pattern in `.github/workflows/publish.yml`'s `on.push.tags` array. If you ever rename a package, update both places — there's a comment at the top of `publish.yml` pointing here.

## Repo settings prerequisite

For the PR-title-as-commit-subject contract to hold, a repo admin must configure:

- `Settings → General → Pull Requests`: enable **Allow squash merging** only. Disable merge commits and rebase merging.
- Under the same section: enable **Default to PR title for squash merge commits**.

Without these, `main` commits may not match the validated PR title, and melos's conventional-commit parsing will misattribute or skip commits.

## Renaming a package

If you ever rename a workspace package:

1. Rename the directory under `packages/` or `apps/`.
2. Update the `name:` field in its `pubspec.yaml`.
3. Update the per-package CI workflow under `.github/workflows/<package>.yml`.
4. Update the tag pattern in `.github/workflows/publish.yml` (`on.push.tags`).
5. Update the tag pattern on pub.dev under `https://pub.dev/packages/<package>/admin`.
6. Update the scope allowlist in `.github/workflows/semantic_pull_request.yml`.
7. Update the scope list in this file.

A rename is a major version bump for that package. Coordinate the rename PR with a release.
