# GitHub issue delivery

Use only when the work is tracked as GitHub issues under the configured delivery workflow.

- Repository: current project's `origin`.
- Owner/assignee: the configured owner account.
- Pick highest-priority open `Todo` issue (`priority:high` > `priority:medium` > `priority:low`; tie: lowest issue number). Skip drafts and issues assigned to another person. Work one issue at a time.
- Assign it to the configured owner account and move to `In Progress`.
- Read the full issue, including attachments. Post implementation plan as an issue comment; do not commit plan files. Post material plan changes as follow-up comments.
- If a decision is required, post the question to the issue and move to `Blocked`. Resume when the owner responds.
- GitHub artifacts are English unless the task explicitly requires another language.
- Do not invent background polling in an agent session. Use a supported scheduled check only when requested; otherwise leave the issue blocked.
