# Project rules

- Tests: for every new feature or bug fix, add new tests or extend existing ones. Only genuinely useful tests: real behavior, edge cases, regressions, error paths. Skip trivial tests that just restate the implementation.
- Version bump: create a git tag matching the version number on the bump commit.
  - On a bump request, first add all changes since the previous version to `CHANGELOG.md`, in Russian, following the existing format (newest version on top).
  - Show the proposed changelog entry and wait for the user's explicit approval before bumping the version, committing or tagging.
- No duplication: when the same logic appears in two or more places, extract it into a shared function, method or class proactively, before finishing the task. Don't wait to be asked.
- No formatters: never run code formatters (`dart format`, `flutter format`, prettier, autofix commands) unless the user explicitly asks. Make edits manually and keep unrelated formatting churn out of diffs. Read-only checks (analyzer, tests) are fine.
- Commit messages:
  - Read the diff first. Title: one short line based on the actual diff, high-level. No conventional commit prefixes (`feat:`, `fix:`, `chore:`).
  - Body: always present. Describe the essence and purpose of the change and why it matters from a feature/product perspective. Not the implementation journey: no bugs hit, debugging steps, root-cause investigation or fix play-by-play.
  - Never add a `Co-Authored-By` trailer or any mention of Claude/AI.
  - One logical change per commit; a fix and its test go together. Version bump is its own commit.
- Never `git commit` unless the user explicitly asks in that turn, even after earlier commit requests in the session.
