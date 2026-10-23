# Git commits

Use Conventional Commits: `<type>(<scope>): <subject>`. A repository's enforced convention (commitlint/CI config, CONTRIBUTING.md, clearly dominant `git log` style) wins.

- Types: `feat`, `fix`, `refactor` (no behavior change, including pure performance work), `docs`, `test`, `chore` (build system, dependencies such as `go.mod`/`Makefile`/Dockerfile, CI, formatting only), `revert`.
- Scope optional: affected package/area, lowercase in parentheses. Maintain a stable scope vocabulary; no new scope per commit.
- Subject imperative, lowercase except proper nouns/brands and acronyms; preserve literal casing for identifiers, paths, and code tokens. No trailing period. Aim for 50 characters or fewer; hard limit 72 for the entire header.
- Body optional: separate by a blank line, wrap at 72, explain what and why rather than how; normal sentence casing.
- Never use `!` for breaking changes. Use a final `BREAKING CHANGE:` footer for backward incompatibility and irreversible changes (destructive migrations, data deletions, one-way operations); state what breaks or why rollback is impossible, and what to do about it.
- Atomic commits: one logical change each; accompanying tests and documentation ride in that change's commit. `test:`/`docs:` only for standalone test-only or doc-only work.
- Work-in-progress commit messages on feature branches need no polish; make the commit that lands on `main`, `stage`, `prod`, or `dev` (the branch-closing squash or `gh pr merge --squash`) follow every rule here and include a body covering what changed and why across the whole branch; always pass `--subject` and `--body` to `gh pr merge --squash`.
- When the commit-message hook rejects a message, retry once with its corrected message verbatim, changing it only where it misstates the change; if that is rejected too or names no real violation, leave the change staged, report the hook output verbatim to the owner, and record a hook defect; never bypass the hook with `--no-verify` or choose a different subject only to get past it.
