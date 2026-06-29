# concurrency-test

A lightweight CLI tool for validating API concurrency behaviour: race conditions, optimistic locking, idempotency, and deadlocks.

Not a generic load tester. Purpose-built for running a single scenario with controlled concurrency and reading the results immediately.

---

## Requirements

- Elixir 1.15+
- [`zig`](https://ziglang.org/) and `xz` (required by Burrito to package the binary)

```bash
brew install zig xz   # macOS
```

---

## Build

### Escript (recommended for local dev)

Produces a single self-contained file. Requires Erlang/Elixir on the machine running it — which every developer using this tool already has.

```bash
mix deps.get
mix escript.build
mv concurrency_test concurrency-test
chmod +x concurrency-test
./concurrency-test transfer.yml
```

### Burrito (cross-platform binary, no runtime required)

Burrito 1.5.0 requires **Zig 0.15.2** exactly. Homebrew installs a newer Zig, and 0.15.2 does not support macOS Tahoe (macOS 26). Until Burrito ships support for Zig 0.16+, Burrito builds work on Linux and older macOS versions.

On a compatible machine:

```bash
mix deps.get
MIX_ENV=prod mix release
```

> Burrito 1.x uses `mix release` (the Burrito wrap step is configured in `releases/0`), not `mix burrito.build`.

The binary lands in `burrito_out/`. Rename it:

```bash
# macOS Apple Silicon
mv burrito_out/concurrency_test_macos_arm ./concurrency-test

# macOS Intel
mv burrito_out/concurrency_test_macos ./concurrency-test

# Linux x86_64
mv burrito_out/concurrency_test_linux ./concurrency-test
```

---

## Usage

```bash
./concurrency-test <scenario.yml>
```

Print usage:

```bash
./concurrency-test
```

---

## Scenario file

Everything lives in a single YAML file.

```yaml
name: Transfer API

run:
  requests: 10000      # total number of requests to send
  concurrency: 500     # max in-flight requests at once
  timeout: 5000        # per-request timeout in milliseconds

request:
  method: POST
  url: http://localhost:8000/transfers

headers:
  Authorization: Bearer token
  Content-Type: application/json
  Idempotency-Key: "{{uuid}}"   # generates a fresh UUID per request

body:
  sourceAccount: ACC001
  destinationAccount: ACC002
  amount: 1000
  currency: EUR
```

### Template tokens

| Token      | Behaviour                                      |
|------------|------------------------------------------------|
| `{{uuid}}` | Replaced with a unique UUID v4 per occurrence  |

Every placeholder is evaluated independently — three `{{uuid}}` tokens in one request produce three different UUIDs.

---

## Example output

```
Transfer API

Requests:      10000
Concurrency:   500

Success:       9998
Failure:       2

Status Codes

200 : 9998
409 : 2

Average : 31 ms
Min     : 8 ms
Max     : 241 ms
P95     : 84 ms
P99     : 130 ms

RPS     : 2380
```

---

## Use cases

### Race condition detection

Send the same mutating request from many concurrent workers. If your API lacks proper locking, you'll see duplicate successes where only one should succeed.

```yaml
name: Race condition — withdraw
run:
  requests: 100
  concurrency: 100     # all fire at the same instant
  timeout: 5000
request:
  method: POST
  url: http://localhost:8000/accounts/ACC001/withdraw
body:
  amount: 1000
```

A correctly locked endpoint returns exactly one `200` and 99 `409`/`400` responses.

---

### Idempotency key validation

Verify that your API deduplicates requests with the same idempotency key. Use a **fixed** key (no `{{uuid}}`) so every request looks identical.

```yaml
name: Idempotency — fixed key
run:
  requests: 50
  concurrency: 50
  timeout: 5000
request:
  method: POST
  url: http://localhost:8000/payments
headers:
  Idempotency-Key: test-key-abc123
body:
  amount: 500
  currency: USD
```

Expect one `201` and 49 deduplicated `200` (or `409`) responses.

To test that **different** keys each create a new resource, swap in `{{uuid}}`:

```yaml
headers:
  Idempotency-Key: "{{uuid}}"
```

---

### Optimistic locking / version conflicts

Hit a versioned resource simultaneously to provoke `409 Conflict` responses from optimistic locking.

```yaml
name: Optimistic lock — update profile
run:
  requests: 200
  concurrency: 50
  timeout: 3000
request:
  method: PUT
  url: http://localhost:8000/users/42
body:
  version: 7
  name: Alice
```

Only one writer should succeed per version. If more than one `200` comes back, the locking is broken.

---

### Deadlock / timeout stress

Push high concurrency against endpoints that hold locks or do long transactions to expose deadlocks or connection exhaustion.

```yaml
name: Deadlock probe — transfer both ways
run:
  requests: 1000
  concurrency: 200
  timeout: 10000
request:
  method: POST
  url: http://localhost:8000/transfers
body:
  sourceAccount: ACC001
  destinationAccount: ACC002
  amount: 1
```

Watch for a spike in errors or latency at the tail (P99). A healthy endpoint keeps P99 close to average under load.

---

### Throughput baseline

Measure raw RPS and latency distribution before and after a change.

```yaml
name: Throughput baseline — list orders
run:
  requests: 5000
  concurrency: 100
  timeout: 2000
request:
  method: GET
  url: http://localhost:8000/orders
```

---

## Development

```bash
mix deps.get
mix test
mix compile
```

Tests cover YAML parsing, template rendering, percentile calculation, and report formatting.
