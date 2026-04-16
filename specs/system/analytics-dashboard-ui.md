# Analytics Dashboard UI

<!-- status: proposed -->

## Problem

LLM cost, token usage, and loop success/failure rates are only accessible via API.
There is no visual overview of spend or loop health.

## Views

### Dashboard — `GET /analytics`
- Summary cards: total cost this week, total runs, failure rate
- Cost by provider/model (table or simple bar)
- Recent runs with status (last 20)

### LLM Metrics — `GET /analytics/llm`
- Cost and token breakdown by provider and model
- Filterable by date range

## Constraints

- Server-rendered HTML (ERB), no JS framework
- Depends on Analytics::LlmMetric and Agents::AgentRun models
- Auth follows the same pattern as LedgerController
