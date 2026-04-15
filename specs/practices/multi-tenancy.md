# Multi-Tenancy

Loaded on demand during plan and build when the work touches tenant isolation,
data scoping, or per-organization configuration.

## Principles

1. **Tenant isolation is a correctness property, not a feature** — a query that
   leaks data across tenants is a security bug, not a missing filter.
2. **Default-deny scoping** — every query is tenant-scoped unless explicitly
   opted out. Opting out requires a named reason (e.g., cross-tenant admin view).
3. **Tenant resolution happens once, early** — resolved at the request boundary
   (middleware), not re-derived in every model or service call.

## Schema-Per-Tenant (PostgreSQL)

The strongest isolation model for relational data. Each tenant gets its own
PostgreSQL schema. Shared tables (users, organizations, sessions) live in the
public schema.

When to use: multi-tenant SaaS where tenants must not see each other's data and
you want schema-level guarantees rather than relying on `WHERE tenant_id = ?` in
every query.

Trade-offs:
- Migrations run per-schema — slow at scale (hundreds of tenants)
- Connection pooling is more complex (schema search path per connection)
- Cross-tenant queries require explicit schema switching

### Tenant Elevator

A middleware that resolves the current tenant from the request — typically from
the subdomain, a header, or a JWT claim. Runs early in the middleware stack so
all downstream code operates in the correct tenant context.

The elevator must handle unknown tenants gracefully (404 or redirect, not a crash).

### Excluded Models

Some models are inherently cross-tenant: the organization table itself, session
storage, background job queues. These are excluded from tenant schemas and live
in the public schema.

Rule: if a model must be queryable without knowing which tenant you're in, it
belongs in the public schema.

## Row-Level Tenancy

Simpler model: all tenants share one schema, every table has a `tenant_id` (or
`org_id`) column, every query includes a tenant filter.

When to use: simpler deployments, fewer tenants, or when schema-per-tenant
overhead isn't justified.

Trade-offs:
- One missed `WHERE` clause leaks data — requires default scopes or query
  middleware to enforce
- Simpler migrations (run once, not per-tenant)
- Cross-tenant queries are trivial (just drop the filter)

## Middleware Ordering

Tenant resolution must happen before any middleware that depends on tenant context.
Common ordering issues:
- Rate limiting that checks per-tenant config must run after tenant resolution
- Authentication that loads tenant-specific settings must run after tenant resolution
- Health checks should run before tenant resolution (they don't need tenant context)

## Provisioning

Creating a new tenant is a multi-step operation: create the record, create the
schema (if schema-per-tenant), seed default data, create the first user. This
should be transactional where possible and idempotent — re-running provisioning
on an existing tenant should be a no-op, not a crash.

## Testing

Multi-tenant tests must:
- Set up tenant context before each test (switch to tenant schema or set tenant_id)
- Verify that queries in one tenant context don't return data from another
- Test the tenant elevator with valid, invalid, and missing tenant identifiers
- Test excluded/shared models are accessible without tenant context
