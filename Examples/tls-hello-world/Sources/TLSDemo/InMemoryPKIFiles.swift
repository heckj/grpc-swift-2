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

import Foundation
import SwiftASN1
import X509

/// Persists a ``InMemoryPKI/CertificateAuthority`` to disk as PEM files, and loads it back.
///
/// `serve` and `greet` are separate `swift run` invocations, so mTLS needs a shared trust
/// anchor between them: `serve` writes the demo CA here on startup, and `greet` reads it back
/// to both trust the server and (for mTLS) mint a fresh, CA-signed client certificate.
///
/// Writing the CA's private key to disk only makes sense for a short-lived, throwaway demo
/// certificate authority like `InMemoryPKI` generates --- a real certificate authority's private
/// key should never leave the CA.
package enum InMemoryPKIFiles {
  /// The directory `serve` and `greet` agree on when no directory is given explicitly, so the
  /// demo works end-to-end with zero flags.
  package static var defaultDirectory: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      "tls-hello-world-demo-pki",
      isDirectory: true
    )
  }

  private static func caCertificatePath(in directory: URL) -> URL {
    directory.appendingPathComponent("ca-cert.pem")
  }

  private static func caPrivateKeyPath(in directory: URL) -> URL {
    directory.appendingPathComponent("ca-key.pem")
  }

  /// Writes `authority`'s certificate and private key to `directory` as PEM files.
  package static func write(_ authority: InMemoryPKI.CertificateAuthority, to directory: URL) throws
  {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let certificate = try Certificate(derEncoded: authority.certificateDER)
    let certificatePEM = try certificate.serializeAsPEM().pemString
    try Data(certificatePEM.utf8).write(to: caCertificatePath(in: directory))

    let privateKey = try Certificate.PrivateKey(derBytes: authority.privateKeyDER)
    let privateKeyPEM = try privateKey.serializeAsPEM().pemString
    try Data(privateKeyPEM.utf8).write(to: caPrivateKeyPath(in: directory))
  }

  /// Loads a demo certificate authority previously written by ``write(_:to:)``.
  package static func loadCertificateAuthority(
    from directory: URL
  ) throws -> InMemoryPKI.CertificateAuthority {
    let certificatePEMData = try Data(contentsOf: caCertificatePath(in: directory))
    let privateKeyPEMData = try Data(contentsOf: caPrivateKeyPath(in: directory))

    let certificate = try Certificate(
      pemEncoded: String(decoding: certificatePEMData, as: UTF8.self)
    )
    let privateKey = try Certificate.PrivateKey(
      pemEncoded: String(decoding: privateKeyPEMData, as: UTF8.self)
    )

    var serializer = DER.Serializer()
    try serializer.serialize(certificate)

    return try InMemoryPKI.CertificateAuthority(
      certificateDER: serializer.serializedBytes,
      privateKeyDER: privateKey.serializeAsPEM().derBytes
    )
  }
}
