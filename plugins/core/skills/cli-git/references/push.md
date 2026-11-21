# Push and history safety

- Non-protected branches may be pushed without asking, overriding a default of pushing only on explicit request.
- Direct push to `main`, `stage`, or `prod` requires an explicit user request.
- Never create, move, or delete a release tag, one that spends a release index or deploys to production: the user alone cuts them. Tags that deploy only to a stage or test environment and spend no release index may be cut and pushed freely, as many as testing needs.
- Force-pushing and rewriting pushed history require explicit approval, except on `dev`: rewrite and force-push it without asking, pinning the lease (`--force-with-lease=dev:<pushed-tip>`).
- starterkit is public: before every push to it, `public-gate.sh --range "<remote branch or base>..HEAD"` must report 0 failing. Fix a hit by removing the personal fact from the commits; never bypass the gate or the pre-push hook (`--no-verify`, a hooks-path override).
- Fetching immediately before an unpinned `--force-with-lease` refreshes the local remote-tracking ref and can make the lease accept an unseen remote commit. For destructive recovery, pin the expected remote value explicitly and preserve rescue refs/reflog evidence before rewriting.
