# Owner-action contract

When work requires an action the agent genuinely cannot perform, the
handoff is a runnable script, not a scattered checklist.

Examples: password-gated sudo, interactive login, protected-branch
action, license/payment action, physical access, unavailable credential,
or an irreversible action not already authorized.

Do not delegate work the agent can perform itself.

## Build the handoff while working

As soon as an owner-only action becomes likely, start the script and
append exact commands while context is fresh. Keep it in scratch space
while evolving; hand it over from a stable path such as
`/tmp/<task>-owner-actions.sh`.

If multiple scripts are required, provide one top-level caller so the
owner still runs one command.

## Script contract

The script must: 1. print what it will do and identify irreversible
actions; 2. ask for confirmation once, not once per step; 3. be
idempotent/resumable; 4. preflight host, tools, repository state, and
credentials before mutation; 5. prepare backup and rollback before the
first destructive action; 6. distinguish installation/action failure
from verification failure; 7. support `DRY=1` when it writes outside the
working tree; 8. finish by printing evidence of the resulting state.

For remote privileged work, stage the complete privileged procedure
securely and execute it in one TTY-backed sudo session rather than
issuing many independent sudo calls. Use restrictive permissions and
traps to remove staged secret-bearing files. Never place secrets in
argv.

A probe that lacks permission to determine state reports `unknown`; it
must not print a false healthy/success verdict.

## Owner-machine portability

A script handed to the owner runs on the owner's machine. Assume
macOS/Bash 3.2 constraints unless the script explicitly executes inside
a known Linux host. Avoid GNU-only local commands and shell features
unavailable there, or perform those operations remotely.

## Handoff

When asked what is blocked on the owner: - provide the one command to
run; - state what it changes and whether anything is irreversible; -
state what evidence the script prints on success.

Before declaring a task blocked, prepare the owner-action script
whenever the blocker can be made executable.
