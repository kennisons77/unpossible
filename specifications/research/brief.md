### Unpossible Design Breakdown

## Goals

To create a evolving exosystem to handle the develoment, distrubution and support of software products using llm clients to fetch data, build boilerplate and analyse state.

To enable local development while still maintaining safe and robust deployment to production environments

To take the best of what was learned during unpossible 1.0 development and make it more modular, support more kinds of back pressure and cover more of the sdlc

To create modular feature sets that can be run in a monorepo, or spearately or adapted to/replaced with a 3rd party implementation. I.E. we create our own instrumentation but provide a sane way to use StatsD/datadog on a project (only once neccesary)

To leverage something like cargo to drive said modularity

To expodse an auththenticated task management and tracking api + UI to track agent conversations/show results and eventually add interaction

To emphasize adapatability and simplicity over the latest and greatest architecture

To be vigilint about security, limitingthe attack surfact of products, follwoing access best prectices never exposing secrets or PII to LLMS or the world at large

To reduce the risk of agentic development but using existing best practices and norms to "pin" concrete patterns and implementations that are reliable and reduce llm halucination and randomness.

To be adaptable in the tools it uses. We want to leverage mutiple LLMs, exparemant with different databases

To store agent I/O arrays for resumation or analysis, tracking them to the changes they drive.

To emphasize the creation of backpressure through out the SDLC be it code linters and robust, agent adapted tests to conceptual backpressure of developing ideas through research and feedback.

To reinforce backrpessure with analytics that cover LLM, Product, Server and Development metrics and analysis. 

To create and test hypotosis' thorough feature flags and analytics/log analysis. 

To automatically recover from failure using a rollback stragegy. 

To keep data avaialble backed up and secure

To use Agents to develop deterministic software and not just to rely on black box results from products we don't control. In this sense we store results to lear from them and void calls in the future. To not ask what we already know. 

To efficiently and effectively use agent ralph loops to generate high quality code while keeping costs low.

Adherence to the Star software development process
