# GitHub pull requests

For the defined GitHub issue delivery workflow:

- Push the issue branch and open a PR whose body contains `Closes #N`.
- Verify the PR base is the intended default branch; a stacked PR may merge into its parent rather than the intended default branch. Check `baseRefName` before handoff/merge.
- Move the issue to `Blocked` while awaiting owner review/merge. Never self-merge.
- Respect `AGENTS.md` authorization for posting under the user's identity.
