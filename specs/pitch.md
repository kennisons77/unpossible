## Pitch Document
Storing, understanding & securing important personal and professional documents, official correspondance, government documents, medical bills, membership agreements, receipt and bills are all can make modern consumer life complex, stressful and down right burdensome. This solution will create a simple to use and understand sovergn, controlled framework for storing and managing files outside of the domain of insecure and corrupted tech corporations. Users can use a service built on the framework to store files and notes about them in a local NAS array or, encrypted in the cloud. The freameowrk should not, when possible expose their PIO to LLMs or other unsafe sources. The framework and user interface should be developed at a constrained pace, not throwing everyhthing at the wall at once, but working to get things right before moving on.

## Overview
Generated from this prompt: As project planner red the information in the specs/pitch.md file and use the AskUserQuestionTool to interview me about literally anything relating to the project, technical implementation, ui/ux, concerns, tradeoffs, etc but make sure the questions are not obvious be very in depth and continue interviewing me until its complete then write the results to the spec files

The Sovereign Library a self-hosted "Personal Repo" that moves beyond simple note-taking (like Evernote) toward Data Governance. It functions as a private ETL (Extract, Transform, Load) pipeline that ingests fragmented digital/physical records—IDs, bills, and family history—and converts them into a high-fidelity, searchable knowledge base.Core Value PropositionsStructured Records vs. Loose Notes: Every document is mapped to a specific schema (e.g., a "Passport" object with expiration logic rather than just a "Note" containing a photo).Privacy-First AI: Routing sensitive documents to local LLMs (Ollama) to ensure identity data never leaves the home server.Actionable Metadata: Not just storage, but concluding. (e.g., "Amount: $80, Due: Oct 15").The 6-Stage ETL PipelineTo build this iteratively, the system follows these modular stages:StageProcessOutcome1. AcquisitionPluggable adapters (Upload, API, Scraper, Camera).Raw Blob + Source Metadata.2. CategorizationLLM-based routing into "Concerns" (Financial, Legal, etc.).Document Type & Priority assigned.3. IdentificationSHA-256 Hashing & Fuzzy Metadata matching.De-duplication & Versioning.4. NormalizationMarkdown conversion with YAML Front Matter.Human-readable "Source of Truth" file.5. StorageHybrid: Encrypted Blobs + Postgres + Vector Store.Semantic and Keyword searchability.6. EnrichmentAutomated triggers and manual annotations.Actionable insights (reminders, summaries).Technical Architecture (The Rails 8 Stack)The project utilizes the "One Person Framework" philosophy to maintain high velocity and low maintenance.Framework: Rails 8 using Solid Queue for background ETL processing.Database: Postgres with pgvector for hybrid semantic search.AI Orchestration: Ollama (Local LLM) for sensitive data; Langchainrb for chain management.Storage: MinIO (S3-compatible local Docker container) via Active Storage.Infrastructure: Kamal for Docker-based deployment; Tailscale for secure remote access without open ports.Data Model Example: The Normalized RecordThe system's goal is to produce a file that looks like this:YAML---
doc_id: "uuid-123"
concern: "financial"
category: "utility_bill"
entity: "Comcast"
amount: 84.50
due_date: 2026-03-25
tags: ["internet", "recurring"]
summary: "Monthly service bill; $5 increase noted."

# OCR / Extracted Content
[Full text of the document...]
Success Metrics for Planning PhaseSovereignty: Can the system classify a "Personal ID" using a local model without an internet connection?Portability: Is the library stored in a format (Markdown/YAML) that remains useful if the Rails app is turned off?Discovery: Can I find a document using a conceptual query (e.g., "How much did I spend on pet health last year?")?

## Goals

- Flexibility and human-in-the-loop review to allow the system to continuously improve
- Favor manual input over automated classification — LLM proposes, human confirms
- Privacy-first: PII redacted before any LLM call; designed for eventual local LLM migration (Ollama)
- Portable records: Markdown+YAML files in a git-tracked library; blobs in MinIO (never in git)
- Aid for understanding. Summaries derived about documents should focus on letting the user know how they are usefull to them, how they should an d should not be sstored and transmitted and what other information might complimnet them

## Key Decisions (from planning interviews)

- **LLM:** Claude Haiku (remote, cheap) for POC; Ollama migration path deferred until pipeline is proven
- **PII handling:** Rule-based regex redaction before any LLM call; no raw PII sent to cloud
- **Review UX:** Confidence-gated — low-confidence extractions pause for human diff-view review
- **Multi-concern:** Primary concern owns the record; secondary concerns are tags
- **Versioning:** Hash conflict triggers human review to decide version vs. duplicate
- **Storage:** Immutable blobs in MinIO + mutable Markdown in git (Rails auto-commits on every write)
- **Search v1:** Postgres full-text search; pgvector column ready for semantic search in v2
- **Provenance:** Per-field tracking (LLM / OCR / human) with source enum
- **Concern taxonomy:** LLM-derived, user-confirmed — not hardcoded
- **Frontend:** Tailwind + shadcn-style components + Hotwire; Rails scaffold for POC
- **Auth:** Rails 8 built-in (has_secure_password); single user now, owner FK for future multi-user
- **OCR:** pdftotext first (digital PDFs) → Tesseract fallback (image/scan)
- **Ingest adapters (POC):** File upload, folder watcher, API webhook
- **Deployment:** Docker Compose on dev machine → Kamal when pipeline proven on real docs

## Technical Requirements

- Rails 8 (Solid Queue + Solid Cache)
- PostgreSQL with pgvector extension
- MinIO (S3-compatible, local Docker)
- Claude Haiku via Anthropic API
- Tesseract + pdftotext for OCR
- Tailscale for remote access

## POC Success

Run 10 real documents (Government IDs + Medical Records) through all 6 pipeline stages. Qualitative: outputs feel useful and accurate.
