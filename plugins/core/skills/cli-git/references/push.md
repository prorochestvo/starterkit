# Push and history safety

- Non-protected branches may be pushed without asking, overriding a default of pushing only on explicit request.
- Direct push to `main`, `stage`, or `prod` requires an explicit user request.
- Force-push and rewriting pushed history always require explicit approval.
- Fetching immediately before an unpinned `--force-with-lease` refreshes the local remote-tracking ref and can make the lease accept an unseen remote commit. For destructive recovery, pin the expected remote value explicitly and preserve rescue refs/reflog evidence before rewriting.
