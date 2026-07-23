# Optional environment root CAs

Place one or more PEM-encoded root certificates in:

```text
k8s/custom-ca/ca.crt
```

The file may contain a single certificate or a concatenated PEM chain. When it
exists, Helm packages it into an XIB-managed ConfigMap and automatically adds
it to the public CA bundle used by XIB application containers.

`ca.crt` is ignored by Git to prevent environment-specific trust material from
being committed accidentally.
