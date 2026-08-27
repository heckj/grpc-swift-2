# Mutual TLS

Authenticate the client as well as the server, using a private certificate authority instead of
a public trust store.

## Overview

Mutual TLS (mTLS) extends the idea of TLS to validate the client, in addition to validating the server.
mTLS is commonly used to ensure that the network connection is both from and to an expected client.
Its used as an alterantive, or alongside, token-based authentication systems, often for service to service authentication.

Using mTLS requires more logistical overhead. 
Every client authenticating with mTLS requires it's own certificate and key, issued by a certificate authority (CA) that both the client and server trust.
To maintain a good secruity posture, keys and certificates need to be rotated on a regular basis and handled securely.

## Configure transport security using mTLS-specific API

The available transports both offer `.mTLS` options to configure transport security.

Like `.tls`, the types for client and server transport security are distinct, but intentionally aligned:
- client [.mTLS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix/grpcniotransportcore/http2clienttransport/posix/transportsecurity/mtls(certificatechain:privatekey:configure:))
- server [.mTLS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix/grpcniotransportcore/http2servertransport/posix/transportsecurity/mtls(certificatechain:privatekey:configure:))

The Transport Services client and server has equivalent mTLS configuration types and factory methods: 

- transport services client [.mTLS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2transportservices/grpcniotransportcore/http2clienttransport/transportservices/transportsecurity/mtls(identityprovider:configure:))
- transport services server [.mTLS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2transportservices/grpcniotransportcore/http2servertransport/transportservices/transportsecurity/mtls(identityprovider:configure:))

> Tip: the transport services configuration API expects CA certificates to be encoded with `.der` encoding.

### Ensure you use the same certificate authority for both client and server

In addition to providing the certificate and private key, ensure that you provide the certificate authority in the TLS configuration to both the client and server configuration.

For example, from the tls example code

```swift
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
```

and in the matching client code:

```swift
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
```

> TIP: The default verification for TLS within the .mTLS configuration uses [noHostnameVerification](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransportcore/tlsconfig/certificateverification/nohostnameverification),
> because common use of mTLS identifies services, not DNS entries.

## Certificate rotation

In mTLS, both client and server must prove their identity cryptographically.
Certificate rotation strengthens security because it limits the lifespan of a credential.
Shorter periods reduce the time an attacker can use a compromised key.

If a client certificate leaks, an attacker can impersonate a legitimate user.
If a server certificate leaks, an attacker can intercept and decrypt private traffic.
Rotating both credentials ensures that a stolen identity does not grant permanent access.
Use code to regularly update both client and server certificates and keys to maintain security.

The POSIX transport offers an mTLS configuration that uses a type that conforms to [CertificateReloader](https://swiftpackageindex.com/apple/swift-nio-extras/documentation/niocertificatereloading/certificatereloader), from [swift-nio-extras](https://github.com/apple/swift-nio-extras).
The swift-nio-extras package provides a [TimedCertificateReloader](https://swiftpackageindex.com/apple/swift-nio-extras/documentation/niocertificatereloading/timedcertificatereloader) that reloads certificates on a configuraable, regular basis.

> Note: if you create a TimedCertificateReloader, ensure you start with an existing valid certificate.

The mTLS factory methods, for the Posix transport, that you can use with a `CertificateReloader`:
- client [.mTLS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix/grpcniotransportcore/http2clienttransport/posix/transportsecurity/mtls(certificatereloader:configure:))
- server [.mTLS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix/grpcniotransportcore/http2servertransport/posix/transportsecurity/mtls(certificatereloader:configure:))

## Building a private CA for mTLS testing

The [tls example code](https://github.com/grpc/grpc-swift-2/tree/main/Examples/tls) in the grpc-swift repository
includes an example of setting up short-lived CA and the relevant client and server credentials to test business logic working with mTLS.

It builds that information in memory, and allows your test code validate that the client and server certificates
are signed by the same certificate authority.

## Custom mTLS verification

If your mTLS infrastructure supports a workload identity, using a mechanism such as [SPIFEE](https://spiffe.io),
then you may want to validate the identity with an external service.
You can configure custom client annd server verification callbacks that gRPC invokes when validating the TLS connection.

To use a the custom verification callback that the gRPC-swift transport provides,
set `customVerificationCallback` when you configure the transport.
The following example illustrates providing a custom callback:

```swift
let serverSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .mTLS(
  certificateChain: [.bytes(pki.server.certificateDER, format: .der)],
  privateKey: .bytes(pki.server.privateKeyDER, format: .der)
) { config in
  config.trustRoots = .certificates([.bytes(pki.caCertificateDER, format: .der)])
  config.customVerificationCallback = { certificates, promise in
    // Convert from an NIOSSLCertificate into a swift-certificates Certificate
    // (https://swiftpackageindex.com/apple/swift-certificates/documentation/x509/certificate)
    // to more easily access the distinguished name (unique identity) of the subject of the certificate.
    let presented = try! Certificate(derEncoded: certificates[0].toDERBytes())

    // In a SPIFEE-style workload validation, the client will have its unique identity
    // encoded in the certificates Subject Alterantive Name (SAN), accessible
    // from the `subject`, which is an instance of DistinguishedName
    // (https://swiftpackageindex.com/apple/swift-certificates/documentation/x509/distinguishedname)
    print(presented.subject.description)

    promise.succeed(
      .certificateVerified(VerificationMetadata(ValidatedCertificateChain(certificates)))
    )
  }
}
```

The callback receives a list of [NIOSSLCertificate](https://swiftpackageindex.com/apple/swift-nio-ssl/documentation/niossl/niosslcertificate)
that you can then process to extra the workload identity and validate it.
Ensure that you call `promise.succeed()` or `promise.fail()` to complete the callback after the verification.
