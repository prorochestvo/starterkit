---
name: common-contracts
description: Apply reusable engineering and operating contracts selectively based on the task, affected component, programming language, and deployment environment. Covers Go code (types, interfaces, packages, layout, tests), services, configuration and secrets, health checks (/ping and /health/check), Linux releases and deployment, documentation (README, docs, specs, comments, AGENTS.md), and owner-only actions (password, sudo, login, protected action, credential).
---

# Common contracts

Use progressive disclosure. Select contracts by applicability and task triggers. Never load all contracts by default.

## Naming convention

Contract filenames follow `[<type>-][<language>-]<subject>.md`. `src` means service, `app` means user-facing application. Include language only for language-dependent rules. Omit type or language for rules applying more broadly. Do not infer applicability from the original project.

## Contract map

| Scope | Contract | Load when |
|---|---|---|
| General | `references/security.md` | Handling secrets, credentials, redaction, or sensitive output |
| General | `references/documentation.md` | Writing or reviewing README files, `docs/`, specs under `.agents/specs/`, `AGENTS.md`, or code comments |
| General | `references/operator-actions.md` | Owner-only actions: a password, sudo, a login, a protected action, a credential, or anything else the agent genuinely cannot perform |
| General | `references/engineering.md` | Writing or reviewing operational limits, correctness guards, or shell pipelines |
| Application · Dart | `references/app-dart-comments.md` | Writing Dart comments |
| Go | `references/go-engineering.md` | Designing Go types, interfaces, packages, abstractions, dependencies, or tests |
| Go | `references/go-layout.md` | Organizing Go files, tests, composition roots, or transport layers; formatting call arguments |
| Service · Go | `references/src-go-engineering.md` | Writing or reviewing service-owned storage implementation in Go |
| Service | `references/src-configuration.md` | Working with service settings, startup validation, or shipped configuration |
| Service | `references/src-health-check.md` | Adding a new long-running service, or touching its health endpoints (`/ping`, `/health/check`) |
| Service · Linux release | `references/src-release-linux.md` | Using versioned-artifact, systemd, and release-channel deployment; CI deploy permissions, rollback, pruning, nginx naming |

Choosing a library for settings or logging in Go: R8 in `references/go-engineering.md`.

## Contract selection

1. Identify the affected component, type, language, runtime, and deployment environment.
2. Match both the contract scope and its task trigger.
3. Read only matching contracts; several may apply.
4. Apply each contract only to its affected component, not automatically to the whole repository.

A repository may contain services, applications, libraries, and tools. Do not create empty categories or placeholder contracts.

## Precedence

1. Explicit instructions for the current task.
2. Project-specific `AGENTS.md`, `CLAUDE.md`, ADRs, and documented contracts.
3. Applicable common contracts.
4. General conventions.

More specific rules win. Follow deliberate project overrides without flagging them; report uncertainty when an exception is ambiguous.

## Working principle

Contracts are constraints, not ceremony. Do not add compliance-only abstractions, files, comments, or process steps. Preserve existing `R#` rules and their meanings; never silently delete or weaken them.
