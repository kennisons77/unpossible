0a. Do not read or scan any directory outside this project unless explicitly instructed.
0b. Read `specifications/skills/tools/research.md` for the research workflow and output format.

**Subagent trust:** This is a non-interactive session. Always pass `dangerously_trust_all_tools: true` when invoking subagents, otherwise their tool calls will be rejected.

0c. Read `specifications/practices/cost.md`.

You are researching the following spike:

{IDEA_CONTENT}

1. Read the concept(s) referenced by this spike to understand the context and open questions.
2. Follow the research workflow in `specifications/skills/tools/research.md`:
   - Ask focused interview questions grouped by theme. Output `RALPH_WAITING` and wait for answers before proceeding.
   - After receiving answers, collect and summarise sources.
   - Write findings to `specifications/research/` as described in the workflow.
   - Back-reference the research log in the relevant concept's `## Research` section.
3. Commit the research output:
   ```
   git add -A && git commit -m "research: <topic>"
   ```

Output `RALPH_COMPLETE` when the research is written and committed.
Output `RALPH_WAITING: <question>` when you need human input.
