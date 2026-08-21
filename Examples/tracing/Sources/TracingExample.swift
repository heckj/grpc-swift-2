/*
 * Copyright 2026, gRPC Authors All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import GRPCCore
import GRPCInProcessTransport
import GRPCOTelTracingInterceptors
import GRPCServiceLifecycle
import InMemoryTracing
import Logging
import ServiceLifecycle
import Tracing

@main
struct TracingExample {
  static func main() async throws {
    // Bootstrap a tracer once, at process start, before any spans are created. This example
    // uses `InMemoryTracer` so it runs standalone with no external services. Swap in
    // `OTel.bootstrap(configuration:)` from swift-otel to export real spans to Jaeger, Zipkin,
    // or Grafana Tempo instead -- the interceptors below, and every propagation pattern in
    // `GreetingService`, are unchanged either way, because they only depend on the `Tracer`
    // protocol from swift-distributed-tracing, not on OpenTelemetry export itself.
    let tracer = InMemoryTracer()
    InstrumentationSystem.bootstrap(tracer)

    let greetingService = GreetingService()
    let inProcess = InProcessTransport()

    // Adding the interceptors is the entire integration: no changes to 'GreetingService' or
    // to how the client is called are required to get a trace for every RPC.
    let server = GRPCServer(
      transport: inProcess.server,
      services: [greetingService],
      interceptors: [
        ServerOTelTracingInterceptor(
          serverHostname: "in-process",
          networkTransportMethod: "in-process"
        )
      ]
    )
    let client = GRPCClient(
      transport: inProcess.client,
      interceptors: [
        ClientOTelTracingInterceptor(
          serverHostname: "in-process",
          networkTransportMethod: "in-process"
        )
      ]
    )

    let serviceGroup = ServiceGroup(
      services: [server, client],
      logger: Logger(label: "io.grpc.examples.tracing")
    )

    try await withThrowingDiscardingTaskGroup { group in
      group.addTask {
        try await serviceGroup.run()
      }

      let greeter = Helloworld_Greeter.Client(wrapping: client)
      let reply = try await greeter.sayHello(.with { $0.name = "world" })
      print(reply.message)

      // The client interceptor started a root span for the call; the server interceptor
      // started a child of it; 'lookUpGreetingPrefix' inside 'GreetingService' started a
      // grandchild. Printing the recorded spans in completion order shows that chain, which
      // is the same chain a real trace viewer (Grafana, Jaeger, Zipkin) would render as nested
      // bars.
      print("\nRecorded spans (in completion order):")
      for span in tracer.finishedSpans {
        print("  \(span.operationName) [span: \(span.spanID), parent: \(span.parentSpanID ?? "none")]")
      }

      await serviceGroup.triggerGracefulShutdown()
    }
  }
}
