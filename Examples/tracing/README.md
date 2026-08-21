# Tracing

This example demonstrates enabling distributed tracing for a gRPC service using the
interceptors from `GRPCOTelTracingInterceptors`, and shows the patterns for propagating a
trace context to code that isn't itself a gRPC interceptor.

## Overview

A `tracing` command line tool that starts an in-process `Greeter` client and server (as in the
`service-lifecycle` example), adds `ServerOTelTracingInterceptor` and
`ClientOTelTracingInterceptor` to them, and makes one RPC. `GreetingService` additionally shows,
inside the RPC handler:

- **Ambient propagation** (`lookUpGreetingPrefix`): starting a child span for a call to a
  downstream dependency that's itself built on `swift-distributed-tracing` (for example, an
  instrumented database client, or `AsyncHTTPClient`). No context is passed explicitly --
  `ServiceContext.current` is already the RPC's context because the server interceptor made it
  ambient.
- **Manual propagation** (`notifyAuditLog`): injecting the current trace context into a
  `[String: String]` carrier, standing in for the header dictionary of a downstream call that
  _isn't_ tracing-aware.

This example bootstraps `InMemoryTracer` from `swift-distributed-tracing`, rather than a real
OpenTelemetry exporter, so it runs standalone with no external services. The interceptors and
every propagation pattern shown here are identical if you bootstrap `OTel.bootstrap(configuration:)`
from [swift-otel](https://github.com/swift-otel/swift-otel) instead -- they only depend on the
`Tracer` protocol, not on OpenTelemetry export.

## Usage

```console
$ swift run tracing
  (audit-log headers would carry: ["in-memory-span-id": "span-2", "in-memory-trace-id": "trace-1", "content-type": "application/json"])
Hello, world!

Recorded spans (in completion order):
  db.lookup [span: span-3, parent: span-2]
  helloworld.Greeter/SayHello [span: span-2, parent: span-1]
  helloworld.Greeter/SayHello [span: span-1, parent: none]
```

The parent/child chain above is the same chain a trace viewer (Grafana, Jaeger, Zipkin) would
render as nested bars: the client's span (`span-1`) is the root with no parent, the server's
span (`span-2`) is its child, and the simulated database lookup (`span-3`) is a grandchild —
all without any code passing a context parameter between them. The audit-log line shows the
other case: a plain `[String: String]` carrier populated by hand from the same ambient context,
for a downstream call that isn't tracing-aware.
