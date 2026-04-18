# Batch Request Middleware

## What It Does

A Rack middleware that intercepts `POST /api/batch`, fans out the sub-requests
internally (same process, no network round trips), and returns aggregated responses
in a single HTTP response.

## Why It Exists

Clients that need data from multiple endpoints pay one HTTP round trip instead of N.
This matters for dashboards, initial page loads, and any UI that assembles data from
several API resources.

The alternative — a bespoke aggregation endpoint per use case — creates coupling
between frontend needs and backend routes. Batch middleware is generic: any
combination of existing endpoints can be batched without backend changes.

## Request Shape

```json
POST /api/batch
{
  "requests": [
    { "method": "GET", "url": "/api/documents?page=1" },
    { "method": "GET", "url": "/api/organizations/1" },
    { "method": "PATCH", "url": "/api/users/5", "body": { "name": "updated" } }
  ]
}
```

## Response Shape

```json
{
  "responses": [
    { "status": 200, "headers": { ... }, "body": { ... } },
    { "status": 200, "headers": { ... }, "body": { ... } },
    { "status": 422, "headers": { ... }, "body": { "errors": [...] } }
  ]
}
```

Responses are ordered — response[i] corresponds to request[i].

## Limits

- Maximum batch size (e.g., 100 requests). Exceeding it returns 422 with an error.
- Malformed JSON returns 422.
- Individual sub-request failures (404, 500) are captured in the response array —
  they don't fail the batch.

## Behavior

- Each sub-request runs through the full Rack stack (authentication, authorization,
  tenant resolution) — the batch middleware replays the request internally.
- Sub-requests share the same authentication context as the batch request itself.
- Sub-request errors are isolated — one failure doesn't abort the batch.
- The batch endpoint itself requires authentication (inherits from the outer request).

## When to Use

- Frontend needs data from multiple endpoints on a single page load
- Bulk operations (update many resources) where individual endpoints already exist
- Reducing HTTP overhead in high-latency environments

## When Not to Use

- When a dedicated endpoint with a single query would be more efficient
- When sub-requests have ordering dependencies (batch provides no ordering guarantees
  beyond response position)
