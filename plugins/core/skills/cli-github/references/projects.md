# GitHub Projects v2 delivery board

These settings apply only to the defined issue delivery workflow, not every GitHub repository.

- User-level GitHub Projects v2 board: the configured board.
- Statuses: `Todo`, `In Progress`, `Blocked`, `Done`.
- Repository issues are actual issues attached to the board, not board-only drafts.
- `Blocked` means the next action belongs to the owner: a decision or PR review/merge.
- `Done` is a consequence of completion, not an optimistic manual status. Require local tests/linters, green PR CI, completed issue subtasks, owner merge, and issue closure through `Closes #N`.
