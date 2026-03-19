# Audience & Jobs to Be Done

## Audiences

| Audience | Role / context |
|---|---|
| Ken (solo developer) | Building and using the system personally. Technical, motivated by local AI exploration and genuine document chaos pain. |

## Jobs to Be Done

**Ken (solo user):**

- JTBD: "Stop losing documents — I need one place where I can actually find any record I own"
- JTBD: "Never wonder if a passport is expired or a bill is due — surface the metadata I've already paid to extract"
- JTBD: "Keep sensitive personal records (IDs, medical) under my own control — not in Google Drive or Evernote"
- JTBD: "Build and experiment with a real LLM-powered pipeline I understand end-to-end"

## Activities

| Activity | JTBD it serves | Capability depths |
|---|---|---|
| Ingest a document | Stop losing docs | upload → folder watch → API |
| Review / correct extraction | Trust the data | manual fill → diff view → confidence gating |
| Search for a document | Find anything | keyword FTS → semantic (v2) |
| Browse concern / type | Navigate the library | scaffold browse → filtered browse |
| Audit pipeline results | Improve over time | per-field provenance → accuracy metrics |
| Configure concerns | Shape the taxonomy | LLM-proposed → user-confirmed → custom |
| View upcoming metadata | Act on records | dashboard surface → alerts (v2+) |

## Story Map

```
[INGEST] → [REVIEW] → [SEARCH] → [BROWSE] → [AUDIT]

upload           manual fill      keyword FTS     scaffold view    per-field provenance
folder watch     diff view        filters         concern nav      LLM accuracy trends
API webhook      confidence gate  semantic (v2)   smart grouping   backfill triggers
```

## Release Plan

| Release | Ingest | Review | Search | Browse | Value delivered |
|---|---|---|---|---|---|
| **POC** | upload + folder watch + API | manual fill + diff view + confidence gate | keyword FTS | scaffold admin | Full pipeline proven on 10 real docs; find any ingested document by text query |
| **v1** | + email adapter | + bulk review | + filters | concern-based nav | Usable daily library with navigable structure and actionable metadata surfaced |
| **v2** | + camera/mobile | + backfill triggers | + semantic (pgvector) | smart grouping | Conceptual queries ("how much did I spend on healthcare last year") return correct answers |

**Current target release:** POC — full 6-stage ETL pipeline working end-to-end on real Government ID and Medical Record documents, searchable via full-text, with human review queue operational.
