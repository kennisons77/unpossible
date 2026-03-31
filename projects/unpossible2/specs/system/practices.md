# Practices

Practices files live in `practices/` and are loaded selectively per loop iteration based on task type. Not every file is loaded every iteration — that wastes context budget.

## File Map

| File | Loaded when |
|---|---|
| `practices/general/coding.md` | Every build iteration |
| `practices/general/planning.md` | Every plan iteration |
| `practices/general/verification.md` | Before running tests |
| `practices/general/cost.md` | Every iteration |
| `practices/general/prompting.md` | When editing PROMPT_*.md files |
| `practices/general/security.md` | Every build iteration |
| `practices/general/reflect.md` | Every reflect iteration |
| `practices/lang/ruby.md` | When language is Ruby |
| `practices/lang/go.md` | When language is Go |
| `practices/framework/rails.md` | When framework is Rails |

In unpossible2, prompt caching and effort parameters are applied automatically by `Agents::ProviderAdapter` — prompt authors do not add `cache_control` annotations manually.
