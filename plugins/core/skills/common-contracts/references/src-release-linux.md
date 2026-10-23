# Release contract

Standard Linux service deployment uses immutable versioned artifacts
plus named channel symlinks. The goals are atomic switching, one-command
rollback, and a CI account that cannot read secrets or service state.

## Layout

``` text
/opt/<app>/                      root:root
    .env                         root:root 0600
    *.sh                         root:root 0750
    logs/                        <svc>:<svc>
    artifacts/                   <ci>:<ci>
        <VERSION_ID>/            immutable release contents
    bin/                         <ci>:<ci>
        release -> ../artifacts/<VERSION_ID>
        stage   -> ../artifacts/<VERSION_ID>
        dev     -> ../artifacts/<VERSION_ID>
```

Mutable service state such as SQLite databases lives outside the
CI-writable tree, typically under `/var/lib/<app>/`, owned by the
runtime account. Remember that SQLite needs directory write access for
WAL/SHM/journal files.

## Version IDs and channels

Use UTC sortable version IDs:

``` text
<YYYYMMDDhhmmss>-<TAG>
```

The tag starts with the channel/intent (`r`, `s`, `d`, or a
project-specific channel letter). Channel symlinks use relative targets
(`../artifacts/<VERSION_ID>`).

Deploy: 1. upload a new immutable artifact directory; 2. atomically
repoint the channel symlink; 3. restart; 4. readiness-check; 5. on
failure, repoint to the previous version and restart.

Promotion reuses the already-built artifact; do not rebuild between
stage and release.

Each channel is a full environment with its own service
unit/config/state. Sharing an artifact does not mean sharing environment
state.

## Permission boundary

The CI deploy user may write only the artifact store and channel
symlinks. It must not read `.env`, service state, or privileged
wrappers.

Keep the base/config/secrets root-owned. Grant only the minimum sudo
needed for service restart/status where CI must perform it. Validate
sudoers syntax and scope; do not give generic shell/root access.

A leaked CI key must hit a privilege wall before secrets or mutable
state.

## Pruning

Never delete: - any version currently targeted by a channel; - versions
required by the retention policy.

Prune by channel-aware artifact identity, not merely directory age.
Preserve enough previous versions for rollback.

## systemd

Units execute binaries through the channel path, so deployment changes
the symlink rather than rewriting unit files. Environment files/state
paths remain outside the CI sandbox.

Runtime root is an accepted baseline where the project requires it;
moving to a dedicated runtime user is a separate hardening decision and
must not be conflated with CI deploy-user confinement.

## Edge naming

Use stable service-oriented nginx/vhost naming. Do not encode an
ephemeral artifact version into the public edge identity.

## Migration

When moving an existing service: 1. inventory current binaries, state,
secrets, units, users, ports, and rollback path; 2. create the
root-owned base and CI-writable `artifacts/` + `bin/`; 3. move mutable
state outside the CI tree; 4. place the current release into an
immutable version directory; 5. point the channel at it; 6. update
systemd to the channel path; 7. constrain CI permissions/sudo; 8. deploy
one new version through the new path; 9. readiness-check and prove
rollback; 10. remove the legacy writable layout only after verification.
