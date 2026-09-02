# TLS Hello World

This example demonstrates TLS and mutual TLS (mTLS) on a gRPC service. It uses the same core
logic as the [Hello World example](../hello-world), secured with either a TLS or mTLS connection, with certificates 
backed by an in-memory demo certificate authority generated with the package `swift-certificates`.

## Overview

`InMemoryPKI.CertificateAuthority` generates a throwaway certificate authority (using the package
`swift-certificates`) and can create and sign new leaf (server or client) certificates on demand.
`Greeter` is the `Helloworld_Greeter` implementation: when it's talking to a client over mTLS, it reads
the client certificate's Subject Alternative Name from `ServerContext.transportSpecific` and
reports it back --- both in the RPC reply and to its console output.

## Usage

Start the server in one terminal. `serve` generates a new Certificate Authority (CA) and server certificate,
writes the CA's certificate (and, for this demo only, its private key) to a temporary
directory, and prints where:

```console
$ swift run tls-hello-world serve --mode tls
Demo CA written to /var/folders/.../tls-hello-world-demo-pki
Greeter listening on [ipv4]127.0.0.1:31415 (tls)
```

In another terminal, connect to it. 

### TLS

With plain `--mode tls`, the client secures the connection and only verifies the
server --- there's no client identity to report:

```console
$ swift run tls-hello-world greet --mode tls
Hello, stranger! This connection was verified.
```

### mTLS

In the first terminal, restart `serve` and use `--mode mtls` to also require a client certificate. 
Each time the client `greet` is run, it generates a new client certificate signed by the CA, and 
embeds a SPIFFE-style identity into the Subject Alternative Name (SAN) using the client option of `--client-id`.
The server reads that identity back off the peer certificate chain and includes it in its reply:

```console
$ swift run tls-hello-world serve --mode mtls
Demo CA written to /var/folders/.../tls-hello-world-demo-pki
Greeter listening on [ipv4]127.0.0.1:31415 (mtls)

$ swift run tls-hello-world greet --mode mtls --client-id alice
Hello, stranger! Verified client identity: spiffe://tls-hello-world.example/client/alice.

$ swift run tls-hello-world greet --mode mtls --client-id bob
Hello, stranger! Verified client identity: spiffe://tls-hello-world.example/client/bob.
```

`serve` and `greet` agree on the CA's location by default, so no flags are needed to share it
across the two invocations; pass `--pki-dir` to both if you want to point them somewhere else.

> Warning: `serve` writes the demo CA's private key to disk so `greet` can mint client
> certificates signed by it. This is not appropriate secure behavior, and is set up only to support
> illustrating the code for how this works. A real CA's private key should never leave the CA.

### Forcing mTLS failure: use an untrusted client CA

To see what an mTLS trust failure looks like, pass `--untrusted-ca` to `greet`. Rather than
signing the client certificate with the known CA, it creates a new CA 
(that the server has no knowledge of) and signs the client certificate with it.
Everything else about the connection is unchanged:

```console
$ swift run tls-hello-world greet --mode mtls --client-id alice --untrusted-ca
Signing client certificate with an untrusted CA (expect this to fail)...
Request failed: unavailable: "The server accepted the TCP connection but closed the connection
before completing the HTTP/2 connection preface." (cause: "sslError([Error: ... SSL routines:
OPENSSL_internal:TLSV1_ALERT_UNKNOWN_CA ...])")
```

The TCP connection and TLS handshake both start, and the server rejects the client's certificate
mid-handshake because its issuer isn't in the server's `trustRoots.` 
The underlying `TLSV1_ALERT_UNKNOWN_CA` is the standard TLS alert for that failure: mTLS validates 
the whole certificate chain, not just whether a certificate was presented.

## Example Tests

### `Tests/TLSHandshakeTests`

Real TLS over a real socket, using in-memory certificates from `InMemoryPKI`:

1. **TLS**: the server presents a certificate signed by the demo CA; the client trusts that CA
   and fully verifies the server, including its hostname.
2. **mTLS**: the server also requires and verifies a client certificate; the client presents
   one. Both certificates are signed by the same CA, so a single `trustRoots` value on each side
   verifies the other.
3. **mTLS with an on-demand client identity**: the same on-demand certificate `greet`
   uses, exercised end-to-end --- a fresh client certificate with a SPIFFE-style SAN, and an
   assertion that the server reads that exact identity back off the peer certificate chain.
4. **mTLS rejects a client certificate signed by an untrusted CA**: the same failure `greet
   --untrusted-ca` demonstrates, exercised end-to-end --- the handshake itself fails, so the
   request never reaches `Greeter`.

### `Tests/InProcessGreeterTests`

The Hello World `Greeter` service, wired up with `InProcessTransport` so that you can validate 
business logic of the client or server without requiring a network interface. The client and server
talk to each other in memory within the test process.

```console
$ swift test
```
