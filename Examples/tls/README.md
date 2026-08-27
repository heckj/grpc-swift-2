# TLS

This example demonstrates enabling TLS and mutual TLS (mTLS) on a gRPC service using
a `TransportSecurity` configuration from the `grpc-swift-nio-transport` package, and showing
another test setup that uses `GRPCInProcessTransport`, which supports testing business logic
without touching the network.

## Overview

`DemoPKI` generates a throwaway certificate authority plus a server and client leaf certificate
entirely in memory (via `swift-certificates` --- nothing is written to disk), fresh on every test
run. `Greeter` is a minimal `Helloworld_Greeter` implementation shared by both test suites below.

## What's tested

### `Tests/TLSHandshakeTests`

Real TLS over a real socket (`HTTP2ServerTransport.Posix`/`HTTP2ClientTransport.Posix`, bound to
an ephemeral `127.0.0.1` port), using the in-memory certificates from `DemoPKI`:

1. **TLS**: the server presents a certificate signed by the demo CA; the client trusts that CA
   and fully verifies the server, including its hostname.
2. **mTLS**: the server also requires and verifies a client certificate; the client presents
   one. Both certificates are signed by the same CA, so a single `trustRoots` value on each side
   verifies the other.

### `Tests/InProcessGreeterTests`

The same `Greeter` service, wired up with `GRPCInProcessTransport`'s `InProcessTransport()`
instead. There's no socket and no TLS handshake --- the client and server talk to each other
entirely in memory within the test process. Reach for this pattern when a test needs to exercise
service logic, not the transport it will eventually run over.

## Usage

```console
$ swift test
```
