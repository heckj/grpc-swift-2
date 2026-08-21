# Tracing Context Propagation

Carry a trace context from an incoming RPC into the other calls your handler makes, and from
an existing trace context into an outgoing RPC.

<!--
Outline only -- fill in prose in your own voice. Notes in italics below each heading are what
that section needs to cover and which verified facts/APIs to draw on. Delete the notes once the
section is written. This article assumes the reader has already been through <doc:Tracing>.
-->

## How context flows through gRPC Swift

_The mechanism, stated precisely (verified against `ServerOTelTracingInterceptor.swift` and
`ClientOTelTracingInterceptor.swift` in grpc-swift-extras):_

_- Server side: the interceptor extracts trace headers from the incoming request into a
`ServiceContext`, starts a span with that context as parent, then runs your handler inside
`ServiceContext.$current.withValue(span.context) { ... }`. Inside any RPC handler,
`ServiceContext.current` is already populated -- there's no context parameter to fetch or
thread through by hand._

_- Client side: `Tracer.startSpan`/`withSpan` (from `swift-distributed-tracing`) default their
`context:` parameter to `.current ?? .topLevel`. So the client interceptor's span automatically
becomes a child of whatever `ServiceContext.current` already is at the call site. If nothing
set it, it's a new root span._

_- Net effect: propagation across an RPC boundary is ambient, via Swift's task-local storage,
not an explicit parameter you pass. This is the one concept the whole article hangs on --
spend real space on it._

## Reading the current context in a handler

_`ServiceContext.current`, and `withSpan("operation") { span in ... }` for wrapping internal
work in a child span. Note `withSpan` also defaults to the ambient context, so nesting is
"just call it" -- no context threading. Point at
`Examples/tracing/Sources/GreetingService.swift`'s `lookUpGreetingPrefix` for a verified,
runnable version of this exact pattern, plus the console output in that example's `README.md`
showing the resulting span parent/child chain (client span -> server span -> lookup span)._

## Propagating into tracing-aware libraries

_The "it just works" case: any library already built on `swift-distributed-tracing` (for
example `AsyncHTTPClient`, which wraps requests in `tracer.withSpan` internally -- see
`AsyncHTTPClient/AsyncAwait/HTTPClient+tracing.swift` if you want to cite the mechanism) reads
the same `ServiceContext.current` task-local your handler is running under. Zero propagation
code needed on your part; the payoff of the ambient-context design from the first section._

## Propagating into non-tracing-aware libraries

_The manual case, for a dependency with no `swift-distributed-tracing` support (verified: as of
this writing, `postgres-nio` has none). Two sub-cases worth distinguishing:_

_- No network boundary (a DB driver call in the same process): just wrap the call in
`withSpan("db.query") { ... }` for a child span. There's nothing to inject -- the call doesn't
carry headers -- so this is purely about getting a nested span for observability._

_- Crosses a network boundary but the client library doesn't support `ServiceContext` (a raw
HTTP call, a queue message): inject the context into whatever carrier that call uses, via a
custom `Injector`. Show the exact pattern gRPC's own client interceptor uses internally
(`ClientRequestInjector` in `ClientOTelTracingInterceptor.swift`) adapted to a plain
`[String: String]` header carrier -- verified, compiling version in
`Examples/tracing/Sources/GreetingService.swift`'s `HTTPHeaderInjector`/`notifyAuditLog`. For
interop with non-Swift services, mention `swift-otel`'s `OTelW3CPropagator` (W3C
`traceparent`/`tracestate` headers) as the standard wire format instead of hand-rolling one._

## Client-side: making an outbound call from an existing context

_The mirror image of the server case, and the one developers most often ask about: "I'm behind
some middleware (Vapor, Hummingbird, a job queue) that already set a trace context from an
inbound HTTP request -- how do I get that into my outgoing gRPC call?" Answer, precisely: you
don't do anything extra. If `ServiceContext.current` is already set when you call the gRPC
client method, `ClientOTelTracingInterceptor` picks it up as the parent automatically (same
default-parameter mechanism as the first section)._

_Precision note: be explicit that this pickup is not something `GRPCOTelTracingInterceptors`
implements. It falls out of a `swift-distributed-tracing` default: `Tracer.startSpan`/`withSpan`
default their `context:` parameter to `.current ?? .topLevel`, and the client interceptor calls
`tracer.startSpan(...)` without overriding that parameter. So the "ambient context" behavior is
a property of `swift-distributed-tracing` itself, which gRPC's interceptor simply inherits by
not doing anything special -- worth saying plainly so readers don't go looking for propagation
logic inside the interceptor that isn't there, and so they know the same "just call it under an
ambient context" pattern applies uniformly to any `Tracer`-based library, not just gRPC's._

_Show a concrete before/after: calling the
gRPC client from plain top-level code (new root span) versus calling it from inside
`ServiceContext.$current.withValue(inboundContext) { ... }` (child of the inbound request)._

## Testing your own propagation code

_Point at `InMemoryTracer` from `swift-distributed-tracing`'s `InMemoryTracing` module --
`InstrumentationSystem.bootstrap(InMemoryTracer())`, then assert on `tracer.finishedSpans`
(operation name, `parentSpanID`, attributes). `Examples/tracing` bootstraps exactly this way for
the same reason: it's the only externally-usable way to inspect what the interceptors actually
did, since their `tracerOverride:` initializer parameter is package-internal to
grpc-swift-extras._
