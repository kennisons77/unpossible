---
name: openai
kind: provider
description: Best practices for OpenAI as an actor
---

## Context Window

Enforce 75% utilisation cap. Do not fill the context window — leave headroom for the
response.

## Structured Output

Use structured output format for tasks that require structured responses (plan parsing,
gap analysis reports).

## Caching

No native prompt caching. Relies on `prompt_sha256` dedup in the agent runner.
