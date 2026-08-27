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
import GRPCNIOTransportHTTP2

func snippetCode() async throws {

  // Code snippet examples for the TLS.md article

  let reply = try await withGRPCClient(
    transport: .http2NIOPosix(
      target: .dns(host: "your-gRPC-service.com"),
      transportSecurity: .tls
    )
  ) { client in
    // Create a service endpoint client by wrapping the gRPC client
    let greeter = Helloworld_Greeter.Client(wrapping: client)
    // and make a request
    return try await greeter.sayHello(.with { $0.name = "TLS client" })
  }

  #if canImport(Network)
  let tsReply = try await withGRPCClient(
    transport: .http2NIOTS(
      target: .dns(host: "your-gRPC-service.com"),
      transportSecurity: .tls
    )
  ) { client in
    // Create a service endpoint client by wrapping the gRPC client
    let greeter = Helloworld_Greeter.Client(wrapping: client)
    // and make a request
    return try await greeter.sayHello(.with { $0.name = "TLS client" })
  }
  #endif

  let noHostnameVerificationReply = try await withGRPCClient(
    transport: .http2NIOPosix(
      target: .dns(host: "your-gRPC-service.com"),
      transportSecurity: .tls(configure: { config in
        config.serverCertificateVerification = .noHostnameVerification
      })
    )
  ) { client in
    let greeter = Helloworld_Greeter.Client(wrapping: client)
    return try await greeter.sayHello(.with { $0.name = "TLS client" })
  }

  let testingTransportSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .tls(
    certificateChain: [.file(path: "path/to/server-cert.pem", format: .pem)],
    privateKey: .file(path: "path/to/server-key.pem", format: .pem)
  )

  let server = GRPCServer(
    transport: .http2NIOPosix(
      address: .ipv4(host: "0.0.0.0", port: 0),
      transportSecurity: .tls(
        certificateChain: [
          .file(path: "path/to/server-cert.pem", format: .pem)
        ],
        privateKey: .file(path: "path/to/server-key.pem", format: .pem)
      )
    ),
    services: [
      // .. service provider ..
    ]
  )

  let client = GRPCClient(
    transport: try .http2NIOPosix(
      target: .ipv4(address: "127.0.0.1", port: 8765),
      transportSecurity: .tls(configure: { config in
        config.trustRoots = .certificates([
          .file(path: "certs/ca-cert.pem", format: .pem)
        ])
      })
    )
  )

  // Code snippet examples for the mTLS.md article

  let mTLSServerSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .mTLS(
    certificateChain: [
      .file(path: "path/to/server-cert.pem", format: .pem)
    ],
    privateKey: .file(path: "path/to/server-key.pem", format: .pem)
  ) { config in
    config.trustRoots = .certificates([
      .file(path: "path/to/ca-cert.pem", format: .pem)
    ])
  }

  let mTLSClientSecurity: HTTP2ClientTransport.Posix.TransportSecurity = .mTLS(
    certificateChain: [
      .file(path: "path/to/client-cert.pem", format: .pem)
    ],
    privateKey: .file(path: "path/to/client-key.pem", format: .pem)
  ) { config in
    config.trustRoots = .certificates([
      .file(path: "path/to/ca-cert.pem", format: .pem)
    ])
  }
}
