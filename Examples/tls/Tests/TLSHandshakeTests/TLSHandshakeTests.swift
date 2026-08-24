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
import GRPCNIOTransportHTTP2Posix
import TLSDemo
import Testing

@Suite("TLS and mTLS handshakes")
struct TLSHandshakeTests {
  /// Server-authenticated TLS: the server presents a certificate signed by the demo CA; the
  /// client trusts that CA and fully verifies the server's certificate, including its hostname
  /// (the certificate's SAN is 'localhost', matching where the client connects).
  @Test("Server-authenticated TLS")
  func tls() async throws {
    let pki = try DemoPKI()

    let serverSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .tls(
      certificateChain: [.bytes(pki.server.certificateDER, format: .der)],
      privateKey: .bytes(pki.server.privateKeyDER, format: .der)
    )

    try await withGRPCServer(
      transport: .http2NIOPosix(
        address: .ipv4(host: "127.0.0.1", port: 0),
        transportSecurity: serverSecurity
      ),
      services: [Greeter()]
    ) { server in
      let port = try #require(await server.listeningAddress?.ipv4?.port)

      let clientSecurity: HTTP2ClientTransport.Posix.TransportSecurity = .tls {
        $0.trustRoots = .certificates([.bytes(pki.caCertificateDER, format: .der)])
      }

      let reply = try await withGRPCClient(
        transport: .http2NIOPosix(
          target: .dns(host: "localhost", port: port),
          transportSecurity: clientSecurity
        )
      ) { client in
        let greeter = Helloworld_Greeter.Client(wrapping: client)
        return try await greeter.sayHello(.with { $0.name = "TLS client" })
      }

      #expect(reply.message == "Hello, TLS client! This connection was verified.")
    }
  }

  /// Mutual TLS: the server also requires and verifies a client certificate, and the client
  /// presents one -- both signed by the same demo CA, so a single 'trustRoots' value on each
  /// side is enough to verify the other.
  @Test("Mutual TLS")
  func mtls() async throws {
    let pki = try DemoPKI()

    let serverSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .mTLS(
      certificateChain: [.bytes(pki.server.certificateDER, format: .der)],
      privateKey: .bytes(pki.server.privateKeyDER, format: .der)
    ) { config in
      config.trustRoots = .certificates([.bytes(pki.caCertificateDER, format: .der)])
    }

    try await withGRPCServer(
      transport: .http2NIOPosix(
        address: .ipv4(host: "127.0.0.1", port: 0),
        transportSecurity: serverSecurity
      ),
      services: [Greeter()]
    ) { server in
      let port = try #require(await server.listeningAddress?.ipv4?.port)

      let clientSecurity: HTTP2ClientTransport.Posix.TransportSecurity = .mTLS(
        certificateChain: [.bytes(pki.client.certificateDER, format: .der)],
        privateKey: .bytes(pki.client.privateKeyDER, format: .der)
      ) { config in
        config.trustRoots = .certificates([.bytes(pki.caCertificateDER, format: .der)])
      }

      let reply = try await withGRPCClient(
        transport: .http2NIOPosix(
          target: .dns(host: "localhost", port: port),
          transportSecurity: clientSecurity
        )
      ) { client in
        let greeter = Helloworld_Greeter.Client(wrapping: client)
        return try await greeter.sayHello(.with { $0.name = "mTLS client" })
      }

      #expect(reply.message == "Hello, mTLS client! This connection was verified.")
    }
  }
}
