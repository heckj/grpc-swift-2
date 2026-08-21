# Tracing

Enable distributed tracing for a gRPC service and client with two interceptors and no changes
to your business logic.

<!--
Outline only -- fill in prose in your own voice. Notes in italics below each heading are what
that section needs to cover and which verified facts/APIs to draw on. Delete the notes once the
section is written.
-->

## Overview

_What distributed tracing buys you (latency, cross-service visibility, error correlation) in a
sentence or two. State up front that this is opt-in via `grpc-swift-extras`'
`GRPCOTelTracingInterceptors`, and that it requires zero changes to service or client business
logic -- it's entirely interceptor-based. Forward-reference <doc:Tracing-Context-Propagation>
for anything that crosses into non-gRPC code (a database call, an HTTP call, a message queue)._

## Add the dependency

_Package.swift snippet: add `grpc-swift-extras` (for `GRPCOTelTracingInterceptors`) and a
tracer implementation. Note that a tracer is required -- the interceptors call
`InstrumentationSystem.tracer` and do nothing useful with the default no-op tracer. For
production, that's `swift-otel`'s `OTel` product; see `Examples/tracing` in this repo for a
dependency-light alternative (`InMemoryTracing` from `swift-distributed-tracing`) if you just
want to see spans without standing up a collector._

## Enable tracing on the server

_Minimal snippet: `ServerOTelTracingInterceptor(serverHostname:networkTransportMethod:)` added
to `GRPCServer(interceptors:)`. One line each for what `serverHostname` and
`networkTransportMethod` become in span attributes (`server.address`, `network.transport`).
Point at `Examples/tracing/Sources/TracingExample.swift` for the full wiring, including where
the tracer gets bootstrapped (`InstrumentationSystem.bootstrap(_:)`, called once, before any
spans are created)._

## Enable tracing on the client

_Same shape, mirrored: `ClientOTelTracingInterceptor(serverHostname:networkTransportMethod:)`
added to `GRPCClient(interceptors:)`. Note explicitly that this is what makes the client's span
become the *parent* of the server's span -- covered in depth in
<doc:Tracing-Context-Propagation>, but worth one sentence here since it's the payoff of adding
both interceptors together._

## What you get automatically

_The standard span attribute table, verified against `SpanAttributes+GRPCTracingKeys.swift` and
the OTel semantic-convention links already cited in the interceptors' doc comments
(`rpc.method`, `rpc.service`, `rpc.system`, `server.address`, `network.transport`). Mention the
`traceEachMessage`, `includeRequestMetadata`, `includeResponseMetadata` initializer parameters
briefly -- what each buys you, and the security callout already in the source docs about
`includeRequestMetadata`/`includeResponseMetadata` (all string metadata values become span
attributes, so don't turn these on if metadata carries sensitive data). Show the resulting
client-span-parents-server-span nesting, either as the diagram style used in the workshop or
as the literal console output from `Examples/tracing`._

## Next steps

_Link to <doc:Tracing-Context-Propagation> for: reading the current span/context in a handler,
propagating into other libraries, and the client-side "I already have a context, how does it
reach the gRPC call" question. Optionally link out to `swift-otel`'s own docs for production
exporter configuration (OTLP, sampling, batching) since that's out of scope for this article._
