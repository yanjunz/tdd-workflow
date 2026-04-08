# Implementation Plan — {{FEATURE_NAME}}

> Created: {{DATE}}
> Status: in-progress

## Phase 2: Unit Tests + Implementation (TDD Main Loop)

- [ ] 2.1 {{module}}: Write failing test (RED)
  - Test file: `{{test dir}}/{{module}}/{{file}}.test.{{ext}}`
  - Covers: REQ-01 happy path
  - Command: `{{TEST_COMMAND}} {{file}}`
- [ ] 2.2 {{module}}: Write minimum implementation (GREEN)
  - Implementation file: `{{source dir}}/{{module}}/{{file}}.{{ext}}`
- [ ] 2.3 {{module}}: Refactor
- [ ] 2.4 {{module}}: Error scenario tests + implementation
- [ ] 2.5 Integration test: Write failing test
  - Test file: `{{test dir}}/integration/{{feature}}.test.{{ext}}`
- [ ] 2.6 Integration test: Implement and pass

## Phase 3: E2E Acceptance

- [ ] 3.1 E2E (if applicable)
  - Test file: `{{E2E test dir}}/{{feature}}.spec.{{ext}}`
  - Command: `{{E2E_COMMAND}}`

## Phase 4: Delivery

- [ ] 4.1 Full unit tests: `{{TEST_COMMAND}} --coverage`
- [ ] 4.2 Full regression (if project has regression scripts)
- [ ] 4.3 Issue tracking (if qualifying bugs found)
- [ ] 4.4 Feature docs updated (if project has usecases/docs directory)
- [ ] 4.5 Environment variable examples synced (if new env vars added)

## Status Tracking

| Task | Status | Notes |
|------|--------|-------|
| Phase 2 | In Progress | |
| Phase 3 | Pending | |
| Phase 4 | Pending | |

## Failure Log

| Test | Failure Count | Last Error | Resolution |
|------|--------------|------------|------------|
