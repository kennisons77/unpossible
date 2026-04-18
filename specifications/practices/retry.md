# Retry Strategy

Loaded on demand when building gateway or external API integration code.

## When to Retry

Retry only **transient** failures — errors that might succeed on a subsequent attempt
without any change to the request. Never retry errors caused by bad input.

| Retryable | Not retryable |
|---|---|
| Network timeout | 400 Bad Request |
| Connection refused (service restarting) | 401 Unauthorized |
| 429 Too Many Requests | 403 Forbidden |
| 500 Internal Server Error | 404 Not Found |
| 502 Bad Gateway | 422 Unprocessable Entity |
| 503 Service Unavailable | Validation failures |
| 504 Gateway Timeout | Deserialization errors |

## Retryable Error Classification

The error itself should know whether it's retryable. This keeps retry logic in the
gateway, not scattered across callers.

```ruby
# The gateway returns a result that carries retry semantics
class ApiResult
  def retryable? = false
end

class TransientError < ApiResult
  def retryable? = true
end
```

Callers branch on the result (see structural-vocabulary: Result Branch). The retry
loop checks `retryable?` and stops immediately for non-retryable errors.

## Exponential Backoff with Jitter

Retry delays grow exponentially to avoid overwhelming a recovering service.
Jitter randomizes the delay to prevent thundering herd — multiple clients that
failed simultaneously retrying at the same instant.

```
delay = min(base_delay × (factor ^ attempt), max_delay)
jittered_delay = delay × (0.5 + rand(0..1))
```

### Defaults

| Parameter | Value | Rationale |
|---|---|---|
| Max attempts | 3 | Enough for transient blips, not enough to mask real outages |
| Base delay | 200ms | Fast first retry for brief hiccups |
| Max delay | 5s | Cap prevents absurd waits |
| Backoff factor | 2.0 | Standard doubling |
| Jitter | enabled | Prevents thundering herd |

### Progression (no jitter)

| Attempt | Delay |
|---|---|
| 1 | 200ms |
| 2 | 400ms |
| 3 | 800ms |

With jitter, each delay is randomized within ±50% of the calculated value.

## Implementation

Use a library rather than hand-rolling retry logic. The retry mechanism should be
configured per-gateway, not globally — different external services have different
tolerance for retry pressure.

## What Not to Retry

- **Idempotency-unsafe operations** without an idempotency key — retrying a
  non-idempotent POST may create duplicates
- **Auth failures** — retrying with the same expired token wastes time
- **Client errors (4xx)** — the request is wrong, not the service
- **Operations that already succeeded** — if the response was lost but the
  side-effect happened, retrying may duplicate it

## Logging

Log every retry with: attempt number, delay, error classification. Don't log the
full request payload (may contain secrets). On final failure, log at warn/error
level with the total attempt count.
