# Security Notice

## About This Software

SecGuardian is an **enterprise white-box security audit tool** — it analyzes source code for security vulnerabilities. It is NOT malware, an exploit kit, or an attack tool.

## Why Your Security Software May Flag This Package

This package contains:

1. **Unsigned native binaries** (`secguardian-index`) — Go-compiled code indexer for AST parsing. Currently ad-hoc signed (linker-signed). We are working on obtaining a code signing certificate.

2. **Security vulnerability descriptions** (`knowledge/guard-rules/*.md`) — These are educational documents describing known vulnerability patterns (CWE Top 25, OWASP Top 10) for detection purposes. They describe what vulnerabilities look like so AI agents can find them — they do NOT contain functional exploit code.

3. **Shell/PowerShell wrapper scripts** — Cross-platform launchers that detect the OS/architecture and invoke the appropriate binary.

## Verification

All packages on Gitee Releases include SHA-256 checksums. Verify your download:

```bash
shasum -a 256 -c secguardian-0.5.1-claude-code.zip.sha256
```

## Source Code

This is fully open-source software. The complete source code is available at:
https://gitee.com/jonyan/secguardian

## Whitelisting

If your corporate Endpoint Protection blocks this package, provide this document to your security team along with the Gitee release URL for verification.

---

SecGuardian Team | https://gitee.com/jonyan/secguardian
