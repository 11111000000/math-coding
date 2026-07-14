# cache-ttl

## Thesis

Cache entries expire after 60 seconds. Manual invalidation
is a separate endpoint.

## Antithesis

Users may need to invalidate cache immediately when upstream
data changes. A fixed TTL forces them to wait up to 60 seconds
for the next refresh.

## Synthesis

Two paths, independent:
  1. TTL: cache entries auto-expire after 60 seconds.
  2. Invalidation: explicit `--cache-invalidate` endpoint
     forces immediate eviction.

The TTL is configurable per cache type. The invalidation
is idempotent (multiple calls have the same effect as one).

## Surface impact

touches: CLI --cache-invalidate [FROZEN], Cache API [FLUID]

## Proof

tests/contract/test_cache_ttl.spec:
  - test_ttl_default_60s
  - test_ttl_configurable
  - test_invalidation_immediate
  - test_invalidation_idempotent