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
import Tracing

/// Implements the "Hello World" gRPC service and, on every call, demonstrates the two ways a
/// trace context reaches code that isn't a gRPC interceptor:
///
/// 1. `lookUpGreetingPrefix` shows *ambient* propagation: any code running underneath the
///    server interceptor already sees the RPC's `ServiceContext` as `ServiceContext.current`,
///    so a child span just needs `withSpan` — no explicit context parameter to thread through.
/// 2. `notifyAuditLog` shows *manual* propagation: for a downstream call that isn't itself
///    built on `swift-distributed-tracing` (here, a stand-in for a plain HTTP request), you
///    inject the current trace context into whatever carrier that call uses yourself.
final class GreetingService: Sendable {
  private let greetings: [String: String] = [
    "en": "Hello",
    "fr": "Bonjour",
    "es": "Hola",
  ]

  /// Simulates a call to a downstream dependency that already participates in
  /// `swift-distributed-tracing` (for example, an instrumented database client or
  /// `AsyncHTTPClient`). No context is passed explicitly: starting a span here picks up
  /// `ServiceContext.current` by default, so it's automatically a child of the RPC span.
  private func lookUpGreetingPrefix(languageCode: String) -> String {
    withSpan("db.lookup", ofKind: .client) { span in
      span.attributes["db.statement"] = "SELECT prefix FROM greetings WHERE lang = ?"
      return self.greetings[languageCode] ?? self.greetings["en"]!
    }
  }

  /// Simulates a call to a downstream dependency that _isn't_ tracing-aware (for example, a
  /// plain HTTP request made without an instrumented client). There's no ambient propagation
  /// to rely on, so the current trace context is injected into the carrier the call actually
  /// uses -- here, a `[String: String]` stand-in for HTTP headers.
  private func notifyAuditLog(message: String) -> [String: String] {
    var headers: [String: String] = ["content-type": "application/json"]
    InstrumentationSystem.tracer.inject(
      ServiceContext.current ?? .topLevel,
      into: &headers,
      using: HTTPHeaderInjector()
    )
    return headers
  }

  func sayHello(
    request: Helloworld_HelloRequest,
    context: ServerContext
  ) async throws -> Helloworld_HelloReply {
    let prefix = self.lookUpGreetingPrefix(languageCode: "en")
    let headers = self.notifyAuditLog(message: "greeted \(request.name)")
    print("  (audit-log headers would carry: \(headers))")

    return .with {
      $0.message = "\(prefix), \(request.name)!"
    }
  }
}

extension GreetingService: Helloworld_Greeter.SimpleServiceProtocol {}

/// An `Injector` that writes trace context key-value pairs into a plain `[String: String]`
/// carrier, standing in for the header dictionary a non-tracing-aware HTTP client would expose.
struct HTTPHeaderInjector: Instrumentation.Injector {
  typealias Carrier = [String: String]

  func inject(_ value: String, forKey key: String, into carrier: inout Carrier) {
    carrier[key] = value
  }
}
