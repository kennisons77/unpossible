# Platform Overrides — Unpossible

Runtime-specific implementation details. Each file extends a core spec in `../system/` or `../product/` — it does not repeat it.

## Structure

```
platform/
  rails/          # Rails 8 implementation
    system/       # Overrides for system/ specs
    product/      # Overrides for product/ specs
  go/             # Go sidecar implementation
    system/       # Overrides for system/ specs
```

## Convention

Each override file begins with: `Extends specifications/[path]. [Runtime]-specific implementation details only.`
