# Preflight

Before changing a repository or host not opened in this conversation — and always before a
sweep across several — inspect it: live sessions (`tmux`/`screen`, running agents, editors
with the tree open), uncommitted files (`git status`), unpushed commits
(`git log @{upstream}..`), and stashes (`git stash list`). Reporting a repository's state
counts as acting on it: `fetch` before saying what is done, in flight, or unstarted.

What you find decides how you work, not whether you work:

- Never commit, stash, reset, rebase, or switch branches over someone else's uncommitted or
  unpushed work, or in a checkout with a live session. Those operations change or hide
  work that is not yours.
- A dirty tree is not a blocker when your change does not touch those files. Keep the
  change independent: stage only your own paths (`git add <path>`, never `git add -A` or
  `git commit -a`), do not switch branches in that checkout, and when the change needs a
  different branch, use a separate worktree (`git worktree add`) instead.
- When the change does touch files someone else has in flight, defer it; report what is in
  flight and the command that re-runs the change once the tree is clean.
