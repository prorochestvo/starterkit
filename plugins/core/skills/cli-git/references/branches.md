# Branches

- Commits on non-protected branches do not require separate approval.
- On `main`, `stage`, and `prod`, branch first. Direct commits or pushes require an explicit user request.
- In the defined GitHub issue delivery workflow, branch from the repository default branch as `feat/<issue>-<slug>` or `fix/<issue>-<slug>`. Never commit directly to the default branch.
- Respect repository-specific branch policies and documented conventions.
- Delete a branch once its pull request is merged (`gh pr view <branch> --json state,headRefOid,author` reports `MERGED`): if `git ls-remote --heads origin refs/heads/<branch>` reports `headRefOid` as the branch's tip, run `git push origin --delete <branch>`; if the local tip equals `headRefOid`, run `git branch -D <branch>` (a squash-merged branch is not an ancestor of the base, so `git branch -d` refuses it). Leave `main`, `stage`, `prod`, `dev`, `alpha`, any branch the repository's working agreement names as its integration branch (a promotion pull request between them also reports `MERGED`), a branch with an open pull request, a branch checked out in a worktree, a local branch with commits beyond `headRefOid`, and a branch whose pull request another person authored; never delete the head branch of a merged promotion pull request (for example, `dev` into `main`).
