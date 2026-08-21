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

import Crypto
import Foundation
import SwiftASN1
import X509

/// A throwaway, in-memory certificate authority plus server and client leaf certificates, for
/// demonstrating TLS and mutual TLS without ever writing a certificate or private key to disk.
/// Generated fresh on every run using `swift-certificates`, the same approach
/// `grpc-swift-nio-transport`'s own test suite uses -- but, unlike that test utility, the server
/// and client certificates here are signed by a single shared CA, which is what a real mTLS
/// trust configuration needs on both sides.
struct DemoPKI {
  struct KeyPair {
    let certificateDER: [UInt8]
    let privateKeyDER: [UInt8]
  }

  let caCertificateDER: [UInt8]
  let server: KeyPair
  let client: KeyPair

  init() throws {
    let ca = try Self.makeCertificate(commonName: "Example Demo CA", issuer: nil, usage: .certificateAuthority)
    let server = try Self.makeCertificate(commonName: "Example Demo Server", issuer: ca, usage: .server)
    let client = try Self.makeCertificate(commonName: "Example Demo Client", issuer: ca, usage: .client)

    self.caCertificateDER = ca.certificateDER
    self.server = KeyPair(certificateDER: server.certificateDER, privateKeyDER: server.privateKeyDER)
    self.client = KeyPair(certificateDER: client.certificateDER, privateKeyDER: client.privateKeyDER)
  }

  private enum Usage {
    case certificateAuthority
    case server
    case client
  }

  private struct GeneratedCertificate {
    let certificate: Certificate
    let privateKey: Certificate.PrivateKey
    let certificateDER: [UInt8]
    let privateKeyDER: [UInt8]
  }

  private static func makeCertificate(
    commonName: String,
    issuer: GeneratedCertificate?,
    usage: Usage
  ) throws -> GeneratedCertificate {
    let privateKey = Certificate.PrivateKey(P256.Signing.PrivateKey())
    let subjectName = try DistinguishedName { CommonName(commonName) }
    let issuerName = issuer?.certificate.subject ?? subjectName
    let issuerPrivateKey = issuer?.privateKey ?? privateKey
    let now = Date()

    let extensions = try Certificate.Extensions {
      switch usage {
      case .certificateAuthority:
        Critical(BasicConstraints.isCertificateAuthority(maxPathLength: nil))
        Critical(KeyUsage(keyCertSign: true, cRLSign: true))

      case .server:
        Critical(BasicConstraints.notCertificateAuthority)
        Critical(KeyUsage(digitalSignature: true, keyEncipherment: true))
        Critical(try ExtendedKeyUsage([.serverAuth]))
        SubjectAlternativeNames([.dnsName("localhost")])

      case .client:
        Critical(BasicConstraints.notCertificateAuthority)
        Critical(KeyUsage(digitalSignature: true, keyEncipherment: true))
        Critical(try ExtendedKeyUsage([.clientAuth]))
      }
    }

    let certificate = try Certificate(
      version: .v3,
      serialNumber: Certificate.SerialNumber(),
      publicKey: privateKey.publicKey,
      notValidBefore: now.addingTimeInterval(-60 * 60),
      notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 365),
      issuer: issuerName,
      subject: subjectName,
      signatureAlgorithm: .ecdsaWithSHA256,
      extensions: extensions,
      issuerPrivateKey: issuerPrivateKey
    )

    var serializer = DER.Serializer()
    try serializer.serialize(certificate)

    return GeneratedCertificate(
      certificate: certificate,
      privateKey: privateKey,
      certificateDER: serializer.serializedBytes,
      privateKeyDER: try privateKey.serializeAsPEM().derBytes
    )
  }
}
