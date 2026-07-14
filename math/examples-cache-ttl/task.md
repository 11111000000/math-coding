# cache-ttl

## Problem

Stale data is served indefinitely after upstream changes
because the cache has no expiration policy.

## Desired outcome

Cache entries expire after a configurable TTL (default 60
seconds). Manual invalidation is available as a separate
endpoint for cases where freshness is critical.

## Constraints

- TTL must be configurable per cache type.
- Invalidation must be idempotent (safe to call multiple
  times).
- No code change for in-process cache: just a wrapper.