# GitHub CLI access

- Prefer `gh` for GitHub operations and `gh api` for endpoints not covered by higher-level commands.
- Determine the repository and host (`gh repo view` or `git remote -v`) and verify the authenticated account before operations when not already established. Use `gh api user --jq .login` for that: `gh auth` commands are denied in this environment, and `gh auth status`/`gh auth token` would print token details.
- Never print a token: no `gh auth token`, no `echo $GH_TOKEN`/`$GITHUB_TOKEN`, no `cat` of `hosts.yml`, no token in command output, logs, or reports. If a check needs the token, pass it through the environment and show only the login it resolves to.
- Authentication is not authorization: available token scopes do not grant permission to perform an action under `AGENTS.md`.
- Do not store access tokens, secrets, or machine-specific credentials in skill files. If authentication is missing, request only the necessary owner action.
