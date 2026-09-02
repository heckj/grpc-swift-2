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

import ArgumentParser
import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf
import TLSDemo

struct Greet: AsyncParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Sends a request to the greeter server")

  @Option(help: "The port to connect to")
  var port: Int = 31415

  @Option(help: "The person to greet")
  var name: String = ""

  @Option(help: "Whether to expect the server to also verify a client certificate")
  var mode: TransportMode = .tls

  @Option(
    help:
      "Directory to read the demo certificate authority's certificate (and, for mTLS, private key) from --- must match the directory `serve` wrote to"
  )
  var pkiDirectory: String = InMemoryPKIFiles.defaultDirectory.path

  @Option(
    help:
      "Workload identity to mint into a fresh client certificate's SAN for this request (mTLS only); the server reads this back and reports it"
  )
  var clientID: String = "demo-client"

  @Flag(
    help:
      "Sign the client certificate with a throwaway, untrusted CA instead of the real one, to demonstrate an mTLS trust failure (mTLS only)"
  )
  var untrustedCA: Bool = false

  func run() async throws {
    let directory = URL(fileURLWithPath: self.pkiDirectory)
    let authority = try InMemoryPKIFiles.loadCertificateAuthority(from: directory)

    let transportSecurity: HTTP2ClientTransport.Posix.TransportSecurity
    switch self.mode {
    case .tls:
      transportSecurity = .tls { config in
        config.trustRoots = .certificates([.bytes(authority.certificateDER, format: .der)])
      }

    case .mtls:
      let signingAuthority: InMemoryPKI.CertificateAuthority
      if self.untrustedCA {
        print("Signing client certificate with an untrusted CA (expect this to fail)...")
        signingAuthority = try InMemoryPKI.CertificateAuthority.makeDemoAuthority(
          commonName: "Untrusted Impostor CA"
        )
      } else {
        signingAuthority = authority
      }

      let identity = "spiffe://tls-hello-world.example/client/\(self.clientID)"
      let client = try signingAuthority.makeLeafCertificate(
        commonName: "Example Demo Client (\(self.clientID))",
        extendedKeyUsage: .clientAuth,
        subjectAlternativeNames: [.uniformResourceIdentifier(identity)]
      )

      transportSecurity = .mTLS(
        certificateChain: [.bytes(client.certificateDER, format: .der)],
        privateKey: .bytes(client.privateKeyDER, format: .der)
      ) { config in
        // The client still trusts the real server CA --- only the client's own certificate is
        // (optionally) signed by a CA the server doesn't recognize.
        config.trustRoots = .certificates([.bytes(authority.certificateDER, format: .der)])
      }
    }

    do {
      try await withGRPCClient(
        transport: .http2NIOPosix(
          target: .dns(host: "localhost", port: self.port),
          transportSecurity: transportSecurity
        )
      ) { client in
        let greeter = Helloworld_Greeter.Client(wrapping: client)
        let reply = try await greeter.sayHello(.with { $0.name = self.name })
        print(reply.message)
      }
    } catch {
      print("Request failed: \(error)")
    }
  }
}
