---
description: Добавить тесты для файла или модуля
agent: tester
subagent: true
---
Add tests for $ARGUMENTS.

Rules:
- Follow the project's existing test framework and style.
- If the project has no test framework (pytest, vitest, jest, go test), report that and stop. Do not install dependencies.
- Do not change production code. If a test exposes a real bug, report it instead of fixing the code.
- Run the tests and report the result.
