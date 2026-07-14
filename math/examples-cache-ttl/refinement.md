# Refinement: cache-ttl

## State

- pre: cache miss (no entry for key)
- post: cache hit (entry exists, age < TTL)

## Operation

On read, check entry timestamp. If age > TTL, refresh from
upstream. On explicit --cache-invalidate, evict the entry
immediately.

## Mapping

| spec state         | impl state                  |
|--------------------|------------------------------|
| cache hit          | dict.get(key) returns value  |
| cache miss         | dict.get(key) returns None   |
| expired entry      | age > TTL, refresh upstream  |
| invalidated entry  | dict.pop(key) (immediate)    |

## Invariant preservation

- Cache entries never served beyond TTL.
- Manual invalidation is immediate (no waiting for TTL).
- Idempotency: multiple invalidation calls have the same
  effect as one.

## Test obligation

tests/contract/test_cache_ttl.spec:
  - test_ttl_default_60s: write entry, sleep 61, read
    (expect upstream fetch)
  - test_ttl_configurable: set TTL=5s, sleep 6, read
    (expect upstream fetch)
  - test_invalidation_immediate: write entry, invalidate,
    read (expect miss)
  - test_invalidation_idempotent: invalidate twice, write,
    invalidate twice (expect same result as one call)

## Runtime check

Periodic log: "cache: N hits, M misses, K evictions" every
hour. Alerts if miss rate > 50%.