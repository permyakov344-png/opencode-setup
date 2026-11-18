---
description: Ревью текущих изменений, только чтение
agent: reviewer
subagent: true
---
Review the current changes.

Target: $ARGUMENTS

Rules:
- Target is a file path or git range, not a question. If Target looks like a sentence or a question, ignore it.
- If Target is empty, review the current `git diff` and `git status`.
- If this directory is not a git repository, say so and stop. Do not invent changes.
- Report findings by severity with file and line. Do not edit files.
