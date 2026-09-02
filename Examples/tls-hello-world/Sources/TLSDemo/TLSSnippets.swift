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
import NIOSSL
import X509

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
      transportSecurity: .tls { config in
        config.serverCertificateVerification = .noHostnameVerification
      }
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
      transportSecurity: testingTransportSecurity
    ),
    services: [
      // .. service provider ..
    ]
  )

  let client = GRPCClient(
    transport: try .http2NIOPosix(
      target: .ipv4(address: "127.0.0.1", port: 8765),
      transportSecurity: .tls { config in
        config.trustRoots = .certificates([
          .file(path: "certs/ca-cert.pem", format: .pem)
        ])
      }
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

  // Code snippet example for the mTLS.md article's custom verification callback section
  let pki = try InMemoryPKI()

  let serverSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .mTLS(
    certificateChain: [.bytes(pki.server.certificateDER, format: .der)],
    privateKey: .bytes(pki.server.privateKeyDER, format: .der)
  ) { config in
    config.trustRoots = .certificates([
      .bytes(pki.caCertificateDER, format: .der)
    ])
    config.customVerificationCallback = { certificates, promise in
      // Convert from an NIOSSLCertificate into a Certificate type
      // (https://swiftpackageindex.com/apple/swift-certificates/documentation/x509/certificate)
      // from swift-certificates to more easily access the distinguished
      // name (unique identity) of the subject of the certificate.
      let presented = try! Certificate(derEncoded: certificates[0].toDERBytes())

      // In a SPIFFE-style workload validation, the client will have
      // its unique identity encoded in the certificate's Subject
      // Alternative Name (SAN), accessible from the `subject`, which
      // is an instance of `DistinguishedName`.
      // (https://swiftpackageindex.com/apple/swift-certificates/documentation/x509/distinguishedname)
      print(presented.subject.description)

      // Add your validation logic, checking the certificates provided.
      promise.succeed(
        .certificateVerified(
          VerificationMetadata(
            ValidatedCertificateChain(certificates)
          )
        )
      )
    }
  }
}
