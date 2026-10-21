# Git workflow

How branches, commits and releases work in this repo. There is no pull request
workflow: work lands by direct commits.

- CI and the release pipeline: [ci-cd.md](ci-cd.md)
- Cutting a release: [release-runbook.md](release-runbook.md)

---

## Branches

| Branch | Role |
|---|---|
| `develop` | Where all work lands. Direct commits and pushes. The pre-push hook and the `Flutter CI` check guard it. |
| `master` | What is shipped. Only the release workflow moves it: it commits the version bump and tags the release. Force-pushes and deletion are blocked. |

Do not use `main`. This repo has no `main` branch.

### Making a change

```sh
git checkout develop
# ... make the change, with its tests ...
git add <files>
git commit -m "fix(scope): what changed and why"
git push origin develop          # the pre-push hook runs analyze, tests, format-check, tooling tests
```

If you need isolation (for example, a git worktree for a background agent), make
the branch, do the work there, then merge it into `develop` directly. Do not open
a pull request for it.

### Shipping

Releases are cut from `develop` with `make release MODE=develop BUMP=patch|minor|major`,
which promotes `develop` to `master`, releases it, and syncs `develop` back. The
full procedure, including the dry run and the manual fallback from `master`, is in
[release-runbook.md](release-runbook.md).

Never tag by hand. The release workflow computes the version and creates the tag.

---

## Commits

Conventional Commits: `type(scope): subject`. Changelogs are generated from these
messages, so write them for the reader of the release notes.

| Type | Use for |
|---|---|
| `feat` | A new user-facing or developer-facing capability |
| `fix` | A bug fix |
| `docs` | Documentation only |
| `test` | Tests only |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance change |
| `build` | Build configuration, dependencies, Makefile |
| `ci` | Workflows and release tooling |
| `chore` | Housekeeping, such as the release version commit |

Do not add `Co-Authored-By` trailers or AI attribution lines to commit messages.

---

## Hooks

```sh
make setup-hooks   # git config core.hooksPath .githooks, once per clone
```

`.githooks/pre-push` runs on every push: `flutter analyze --fatal-warnings`,
`flutter test`, `make format-check` and `python3 -m unittest discover -s test/tool`.
Do not bypass it routinely (`git push --no-verify` is for emergencies).

---

## Recovering from mistakes

- **Undo a commit that is already pushed:** `git revert <sha>`, which adds a new
  commit. Do not rewrite shared history.
- **Force-push:** only to your own unmerged branch, with
  `git push --force-with-lease`. Never to `develop` or `master`.
- **Wrong branch:** `git reflog` shows where a branch pointed before.
- **Release workflow errors:** see [release-runbook.md](release-runbook.md),
  "Failure points and recovery". Do not hand-edit tags or `master` to get around a
  failed run.
