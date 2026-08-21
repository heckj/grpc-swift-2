# TLS

Encrypt gRPC connections and authenticate the server (and, with mutual TLS, the client) using
the transport's TLS configuration.

<!--
Outline only -- fill in prose in your own voice. Notes in italics below each heading are what
that section needs to cover and which verified facts/APIs to draw on. Delete the notes once the
section is written.
-->

## Overview

_State up front: TLS is not a `GRPCCore` concept. `GRPCCore` only defines the transport
protocols (`ClientTransport`/`ServerTransport`); TLS is configured on the concrete transport
you choose from `grpc-swift-nio-transport`, via the `transportSecurity:` parameter passed to
`.http2NIOPosix`/`.http2NIOTS`. Say this explicitly and early -- it's the single most common
point of confusion (a reader searching `GRPCCore` for "TLS" finds nothing, because there is
nothing there to find). State the three-way choice every transport exposes up front:
`.plaintext`, `.tls(...)`, `.mTLS(...)` -- covered in <doc:Mutual-TLS> instead of here._

## Add the dependency

_Package.swift snippet: `grpc-swift-nio-transport`, either the umbrella `GRPCNIOTransportHTTP2`
product or the platform-specific `GRPCNIOTransportHTTP2Posix`/`GRPCNIOTransportHTTP2TransportServices`
directly. Reuse the existing snippet already in `Documentation.md`'s package-structure overview
rather than inventing a new one -- stay consistent with what's already there._

## Choosing a transport security mode

_`.plaintext`, `.tls(...)`, `.mTLS(...)` as the three cases on `TransportSecurity` (verified in
`Config+TLS.swift` for both `HTTP2ServerTransport.Posix` and `HTTP2ClientTransport.Posix`).
Footnote `.customSecure` (2.8+) as an escape hatch for injecting your own security handlers via
`channelDebuggingCallbacks.onCreateTCPConnection` -- out of scope here, link to the API reference
only._

_Precision note, state clearly and early: `HTTP2ServerTransport.Posix.TransportSecurity` and
`HTTP2ServerTransport.TransportServices.TransportSecurity` are different types with different
initializers, despite sharing case names and this article's examples. Structure every code
example below so the Posix and TransportServices versions are visually adjacent, not interleaved
in prose._

## Basic secure setup with real certificates

_Posix: `.tls(certificateChain:privateKey:configure:)`, using
`TLSConfig.CertificateSource.file(path:format:)`/`TLSConfig.PrivateKeySource.file(path:format:)`.
Call out explicitly that `format:` is a required parameter -- the equivalent snippet in the
workshop (`grpc-swift-workshop`'s `01-SecurityWithTLS.md`) omits it and won't compile against
the current API. Show the resulting defaults (`clientCertificateVerification: .noVerification`,
`trustRoots: .systemDefault`, `requireALPN: false`) from `TLS.defaults(...)`._

_TransportServices: `.tls(identityProvider:configure:)`, taking a
`@Sendable () throws -> SecIdentity` instead of file paths. Flag plainly that this is a
different acquisition model entirely (Keychain/`Security` framework, not files on disk) and
that teaching Keychain identity management is out of scope -- link to Apple's `SecIdentity`
documentation instead of attempting to replicate it here._

## Self-signed certificates for local testing

_Two real paths, not the workshop's `openssl`-only approach:_

_1. **`openssl` CLI** (what the workshop shows, still valid): generate a CA, a server cert
signed by it, done. Quick, no extra Swift dependencies, produces PEM. Cite the workshop's
commands as a starting point but verify they still produce output the current API accepts._

_2. **In-Swift generation**, for no-shell-dependency / CI-friendly cases: cite the verified,
already-shipping pattern in `grpc-swift-nio-transport`'s own test suite
(`Tests/GRPCNIOTransportHTTP2Tests/Test Utilities/SelfSignedCertificateKeyPairs.swift`), which
uses `swift-certificates` (`X509`), `swift-crypto` (`Crypto`), and `swift-asn1` (`SwiftASN1`) to
build a `Certificate` and serialize it directly -- no shelling out. Note the added dependencies
this pulls in versus option 1, so a reader can make an informed choice._

_Then: how you actually get a client to trust a self-signed cert --
`trustRoots: .certificates([.file(path:format:)])` pointed at the self-signed cert, plus either
`.noHostnameVerification` (chain still validated, hostname match skipped -- reasonable for local
testing against `localhost`) or `.noVerification` (nothing validated at all). State plainly that
`.noVerification` should not ship to production; it's a "make it connect while I'm debugging
something else" escape hatch, not a testing pattern to standardize on._

## PEM vs. DER: a backend-specific gotcha

_Verified in `GRPCNIOTransportHTTP2TransportServices/Config+TLS.swift`: on the TransportServices
backend, custom trust-root certificates **must** be DER-encoded -- the code path for
`.file`/`.bytes` with `format: .pem` hits a `fatalError`, not a thrown error, not a graceful
fallback. Posix accepts either PEM or DER. This means a trust-root snippet copy-pasted from a
Posix example (PEM, the common default from `openssl`) crashes at runtime on Apple platforms
using `.http2NIOTS`. Give the one-line fix: `openssl x509 -in ca-cert.pem -outform der -out
ca-cert.der`. This is worth its own heading, not a footnote -- it's the kind of thing that only
surfaces once someone actually runs the "obvious" snippet on the other backend._

## Reference documentation

_Plain markdown links (not DocC symbol links -- `GRPCCore` has no dependency on
`grpc-swift-nio-transport`, so symbol-link syntax can't resolve here regardless of visibility
annotations) to the SwiftPackageIndex-hosted pages for:_

_- `TLSConfig` and its nested types (`CertificateSource`, `PrivateKeySource`, `TrustRootsSource`,
`CertificateVerification`) -- `GRPCNIOTransportCore`._
_- `HTTP2ServerTransport.Posix.TransportSecurity`/`.TLS` and the `HTTP2ClientTransport` equivalents
-- `GRPCNIOTransportHTTP2Posix`._
_- The TransportServices equivalents -- `GRPCNIOTransportHTTP2TransportServices`._
_- `swift-certificates`' `X509` module, for the in-Swift self-signed path._

## Next step

_Link to <doc:Mutual-TLS> for client authentication, private CA trust roots, certificate
rotation, and custom verification callbacks._
