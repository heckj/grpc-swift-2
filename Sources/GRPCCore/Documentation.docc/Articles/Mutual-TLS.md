# Mutual TLS

Authenticate the client as well as the server, using a private certificate authority instead of
the public trust store.

<!--
Outline only -- fill in prose in your own voice. Notes in italics below each heading are what
that section needs to cover and which verified facts/APIs to draw on. Delete the notes once the
section is written. This article assumes the reader has already been through <doc:TLS>.
-->

## Overview

_What mTLS buys you beyond server-only TLS: the client also presents a certificate, so the
server can authenticate *who is calling*, not just encrypt the channel. This is the common
pattern for service-to-service auth inside a private network, as an alternative to (or alongside)
token/metadata-based auth. State the operational cost plainly too: every client now needs a
certificate and key, issued by a CA both sides trust, which is a real distribution and rotation
burden the workshop's "consider mTLS" one-liner (`06-Production-Readiness/01-SecurityWithTLS.md`)
doesn't get into._

## The mTLS-specific API

_`.mTLS(certificateChain:privateKey:configure:)` exists as its own factory on both
`HTTP2ServerTransport.Posix.TransportSecurity` and `HTTP2ClientTransport.Posix.TransportSecurity`
(verified in `Config+TLS.swift`) -- it isn't just `.tls(...)` with extra steps. Show its
different defaults versus plain `.tls(...)`:_

_- Server: `clientCertificateVerification` defaults to `.noHostnameVerification` (not
`.noVerification` as with plain `.tls`) -- because presenting a client cert at all is the point
of mTLS, defaulting to "don't verify it" would defeat the purpose._
_- Client: `serverCertificateVerification` still defaults to `.fullVerification`, same as plain
`.tls`._

_Explain briefly why hostname verification is typically skipped for the client cert specifically:
client certificates usually identify a service/workload, not a DNS name, so there's no hostname
to match against in the first place._

## Trust roots for mTLS

_Both sides default `trustRoots` to `.systemDefault` (the public trust store), which is almost
never right for mTLS -- your client certs aren't signed by a public CA. Show
`trustRoots: .certificates([.file(path:format:)])` pointed at your private CA on **both** the
server config (to verify incoming client certs) and the client config (to verify the server
cert, if it's also issued by the private CA rather than a public one). This is the detail most
likely to be missed by someone adapting a plain-TLS example into an mTLS one._

## Building a private CA for mTLS testing

_Extends the self-signed pattern from <doc:TLS>, but with a twist worth flagging precisely:
`grpc-swift-nio-transport`'s own test utility
(`Tests/GRPCNIOTransportHTTP2Tests/Test Utilities/SelfSignedCertificateKeyPairs.swift`) generates
a server cert and a client cert that are each **independently self-signed** -- there's no shared
CA chaining them together. That's sufficient for that test suite's purposes, but a proper mTLS
setup usually wants one private CA that signs both the server and client leaf certs, so a single
`trustRoots` value on each side can verify the other. Don't assume the existing test utility
already does this; verify before reusing it, and extend it (or use the `openssl` three-certificate
CA/server/client chain shown in the workshop's demo) if it doesn't._

## Certificate rotation

_`CertificateReloader` (from `NIOCertificateReloading`) and the `.mTLS(certificateReloader:)` /
`.tls(certificateReloader:)` throwing variants (verified in `Config+TLS.swift`) -- this is a
real, shipped feature, not just the workshop's "consider certificate rotation" bullet. Explain
why it matters more for mTLS than plain TLS: with mTLS, the *client's* identity also needs
rotating, not just the server's, doubling the operational surface. Note the reloader must be
"primed" with an initial certificate chain and private key before use, or the throwing
initializer fails with an `RPCError`._

## Custom verification callbacks

_`customVerificationCallback` on both server (`clientCertificateVerification`-gated, available
2.2+) and client (`serverCertificateVerification`-gated, available 2.3+) TLS configs -- for
verification logic beyond the three built-in modes, e.g. checking a custom certificate extension
or a workload identity format (SPIFFE-style) instead of a hostname. Note precisely: the doc
comments in `Config+TLS.swift` state this callback is only invoked when the corresponding
verification mode is *not* `.noVerification` -- worth calling out since it's a easy-to-miss
gotcha if someone sets `.noVerification` expecting their custom callback to still run._

## Backend differences for mTLS

_TransportServices: `.mTLS(identityProvider:configure:)`, same `SecIdentity`-based model as plain
TLS. Repeat the PEM/DER precision note from <doc:TLS> here explicitly -- it bites harder for
mTLS, since a private CA trust root is now mandatory on both sides, not just an optional
customization._

## Reference documentation

_Plain markdown links to SwiftPackageIndex for `CertificateReloader`/`NIOCertificateReloading`,
and back-links to the specific `.mTLS(...)` overloads on each backend's `TransportSecurity` type
already linked from <doc:TLS>._
