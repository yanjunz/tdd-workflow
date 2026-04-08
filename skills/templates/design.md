# Technical Design — {{FEATURE_NAME}}

> Created: {{DATE}}
> Status: draft

## Architecture Overview

{{Brief description of technical approach, 1-3 paragraphs}}

## Affected Modules

| Module | File Path | Change Type |
|--------|-----------|-------------|
| ... | ... | Add/Modify/Delete |

## Data Flow

```
{{ASCII diagram or mermaid describing request/data flow}}
```

## Interface Design

### New/Modified Interfaces

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| ... | ... | ... | ... |

**Request Body**:
```json
{}
```

**Response Body**:
```json
{}
```

## Database Changes

{{None if not applicable}}

## Test Strategy

| Layer | Framework | File Location | Focus |
|-------|-----------|---------------|-------|
| Unit | {{project test framework}} | `{{test dir}}/...` | Core logic, error handling |
| Integration | {{project test framework}} | `{{test dir}}/integration/...` | Cross-module chains |
| E2E | {{E2E framework}} | `{{E2E test dir}}/` | User operation flows |
