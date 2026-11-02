Redis lens. Cache, lock, queue and session code on Redis — Sentinel or Cluster, from Java (Jedis, Lettuce, Redisson, Spring Data Redis) or Rust (redis-rs). The server's failure modes are the same from every client; the client section below covers what differs.

HARD GATE: for every finding, name the interleaving or failure that triggers it — a second client between two commands, a failover, a crash between two writes, an eviction, a slow command blocking the server — and the consequence: a partial or stale value served, a lost write, a key that never expires, a lock held by two owners, a blocked event loop. "Should use SCAN" / "should set a TTL" with no production path and no consequence is not a finding.

Where to look first (non-exhaustive — reason beyond this list):
- Check-then-act across commands: `GET` then `SET`, `EXISTS` then `SET` — a second client wins the gap. Locks need `SET key token NX PX ttl`, and unlock must compare the token (a Lua compare-and-delete); a plain `DEL` releases someone else's lock after expiry.
- A set, hash or list replaced in several steps (`DEL` then `SADD`/`HSET`…) — readers see an empty or partial collection in between. Build under a temp key and `RENAME`, or wrap in `MULTI`/`EXEC` (no rollback: one failing command does not undo the others).
- TTL lost: `SET` then a separate `EXPIRE` (a crash leaves no TTL — use `SET … EX`); a plain `SET` on an existing key clears its TTL unless `KEEPTTL`; `INCR` + `EXPIRE` rate limits that never expire if the second call is lost.
- Cluster: multi-key commands, `MULTI` and Lua scripts across hash slots fail (CROSSSLOT) unless the keys share a `{hashtag}`; Lua must name its keys in `KEYS`.
- Server-blocking calls on production paths: `KEYS`, `SMEMBERS`/`HGETALL`/`LRANGE 0 -1` on unbounded collections, `DEL` of a huge key (use `UNLINK`), long Lua scripts.
- Sentinel/replication is asynchronous: an acknowledged write can vanish on failover; reads from replicas are stale. The client must find the master through Sentinel, not a fixed host — a hard-coded master address breaks at the first failover.
- Messaging: Pub/Sub is at-most-once (a disconnected subscriber loses messages); Streams without `XACK` grow the pending list, and a dead consumer's messages need `XAUTOCLAIM`.
- Cache-aside races: invalidate-then-repopulate lets a slow reader write the old DB value back after the delete; mass expiry at one moment stampedes the DB; `maxmemory-policy` evicting keys of data that only lives in Redis.
- Serialization: Spring `RedisTemplate`'s default JDK serializer (class changes break reads; untrusted bytes are a deserialization risk); two writers with different key serializers write different keys for the same name.

Client specifics:
- Jedis: a `Jedis` instance is not thread-safe — borrow from `JedisPool` (or `JedisSentinelPool`) per use, return it (try-with-resources).
- Lettuce (Spring Boot's default): one connection is shared by all threads, so a blocking Redis COMMAND (`BLPOP`, `XREAD BLOCK`) or a `MULTI` on it stalls or corrupts everyone else's — use a dedicated connection; Cluster topology refresh is off by default (stale topology after failover); `ReadFrom.REPLICA*` reads stale data.
- Reactor `.block()` is a different thing: it parks the CALLING thread until the reply, and other commands keep flowing on the shared connection. It is a bug only on a thread that must not wait — a Netty event loop or a Reactor non-blocking scheduler (it throws there, or stalls that loop). On a startup (`@PostConstruct`), scheduler or plain worker thread it is fine.
- Spring Data Redis: `multi()`/`exec()` on `RedisTemplate` outside a `SessionCallback` run on different connections — not a transaction; `RedisCacheManager` entries have no TTL unless configured.
- Redisson: `lock(leaseTime, …)` disables the watchdog — the lock expires mid-work; `RLock` is owned by a thread, so locking in one reactive/async callback and unlocking in another fails.
- redis-rs (Rust): a blocking command on a shared `MultiplexedConnection` stalls every task using it; a plain `Connection` does not reconnect (use `ConnectionManager`); a pipeline is a transaction only with `.atomic()`.

Not bugs:
- `KEYS`, `FLUSHALL` or no TTL in tests and one-off admin scripts; no TTL on keys that are meant to persist (the code or config says so).
- A non-atomic read-modify-write on a Redis key with a single writer, when the code shows there is only one — counting every writer: listener and request threads, scheduled jobs, startup, and every other instance of the service (a scheduled job runs on all of them unless a distributed lock says otherwise).
