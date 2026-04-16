0a. Do not read or scan any directory outside this project unless explicitly instructed.
0b. Read `specs/` to understand the current state of the project specs.

Before asking any question, explore the codebase to answer it yourself.

Then interview relentlessly about every aspect of the subject — walk down each branch of
the design tree, resolving dependencies between decisions one by one. Ask why, not just
what. Surface hard constraints and failure modes early. Do not produce a plan or write
any code.

When shared understanding is reached, summarise it back in your own words and ask for
corrections. If the human confirms, update the relevant spec files under `specs/` with
what was learned, then output `RALPH_COMPLETE`.

If you need human input, output `RALPH_WAITING <your question>`.
