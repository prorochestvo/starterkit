# Cloudflare operations

## Commands that need approval

Every command that creates, updates, deletes, uploads, deploys, or restores remote
state needs the exact-command approval set in `SKILL.md`. The common ones:

- `wrangler deploy`, `wrangler delete`, `wrangler versions upload|deploy`,
  `wrangler rollback`, `wrangler triggers deploy`, `wrangler pages deploy`
- `wrangler secret put|delete|bulk`, `wrangler versions secret put|delete|bulk`
- `wrangler kv key put|delete`, `wrangler kv bulk put|delete`,
  `wrangler kv namespace create|delete`
- `wrangler r2 object put|delete`, `wrangler r2 bucket create|delete`
- `wrangler d1 create|delete`, `wrangler d1 execute --remote` unless the SQL is
  read-only, `wrangler d1 migrations apply --remote`, `wrangler d1 time-travel restore`
- `wrangler queues create|delete`
- `wrangler dev --remote`

Any other `create`, `delete`, `put`, `upload`, `deploy`, `apply`, `restore`,
`rename`, or `update` subcommand is covered too.

## Before and after a change

Name the target account, resource, and environment, then inspect its remote state
read-only. Before a destructive change, state the recovery path in the approval
request: `wrangler rollback` for a Worker, `wrangler d1 time-travel info <db>` for
a D1 restore point; KV, R2, and secret deletes cannot be undone. Touch nothing
outside the named target. After an approved change, inspect the resulting remote
state and report what it shows, not the exit status.
