# TLS

This example demonstrates enabling TLS and mutual TLS (mTLS) on a gRPC service using
`grpc-swift-nio-transport`'s `TransportSecurity` configuration.

## Overview

A `tls` command line tool that, on every run, generates a throwaway certificate authority plus
a server and client leaf certificate entirely in memory (via `swift-certificates` -- nothing is
written to disk), then runs two scenarios back to back:

1. **TLS**: the server presents a certificate signed by the demo CA; the client trusts that CA
   and fully verifies the server, including its hostname.
2. **mTLS**: the server also requires and verifies a client certificate; the client presents
   one. Both certificates are signed by the same CA, so a single `trustRoots` value on each side
   verifies the other -- unlike `grpc-swift-nio-transport`'s own test utility
   (`SelfSignedCertificateKeyPairs`), which generates two *independently* self-signed
   certificates with no shared CA.

## Usage

```console
$ swift run tls
--- TLS (server-authenticated) ---
  Hello, TLS client! This connection was verified.
--- mTLS (server- and client-authenticated) ---
  Hello, mTLS client! This connection was verified.
```

Both scenarios bind to an ephemeral port (`port: 0`) and read back the assigned port from
`server.listeningAddress`, so they don't collide with anything else running locally.
