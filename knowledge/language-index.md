# 语言规则索引（自动生成 — 请勿手工编辑）

## cpp
guard-rules/concurrency-data-race, guard-rules/concurrency-deadlock, guard-rules/concurrency-race-condition, guard-rules/concurrency-thread-unsafe-signal, guard-rules/crypto-aes-ecb-mode
guard-rules/crypto-custom-crypto, guard-rules/crypto-hardcoded-iv, guard-rules/crypto-hardcoded-secrets, guard-rules/crypto-insufficient-key-length, guard-rules/crypto-tls-version
guard-rules/crypto-weak-crypto-algorithm, guard-rules/crypto-weak-random, guard-rules/error-debug-mode-production, guard-rules/error-exception-swallow, guard-rules/error-log-sensitive-data
guard-rules/error-stack-trace-leak, guard-rules/memory-bad-cast, guard-rules/memory-buffer-overflow, guard-rules/memory-double-free, guard-rules/memory-format-string
guard-rules/memory-heap-buffer-overflow, guard-rules/memory-integer-overflow, guard-rules/memory-memory-leak, guard-rules/memory-mismatched-free, guard-rules/memory-null-dereference
guard-rules/memory-off-by-one, guard-rules/memory-oob-read, guard-rules/memory-uninitialized-memory, guard-rules/memory-use-after-free, guard-rules/resource-file-double-close
guard-rules/resource-file-leak, guard-rules/resource-file-use-after-close, guard-rules/resource-lock-misuse, guard-rules/resource-refcount-misuse, guard-rules/resource-socket-leak
guard-rules/system-command-injection, guard-rules/system-insecure-permissions, guard-rules/system-insecure-temp-file, guard-rules/system-path-traversal, guard-rules/system-privilege-escalation
guard-rules/system-secrets-detection, guard-rules/system-symlink-attack, guard-rules/system-toctou, guard-rules/web-input-validation, guard-rules/web-resource-exhaustion
guard-rules/web-sql-injection, audit-rules/auth-and-session, audit-rules/authorization, audit-rules/cryptography, audit-rules/data-protection
audit-rules/dependency-security, audit-rules/http-security-headers, audit-rules/information-exposure, audit-rules/infra-hardening, audit-rules/input-validation
audit-rules/logging-and-monitoring, audit-rules/output-encoding, audit-rules/secrets-management, audit-rules/secure-transport, review-rules/cpp

## python
guard-rules/crypto-aes-ecb-mode, guard-rules/crypto-custom-crypto, guard-rules/crypto-hardcoded-iv, guard-rules/crypto-hardcoded-secrets, guard-rules/crypto-insufficient-key-length
guard-rules/crypto-password-storage, guard-rules/crypto-tls-version, guard-rules/crypto-weak-crypto-algorithm, guard-rules/crypto-weak-random, guard-rules/error-debug-mode-production
guard-rules/error-exception-swallow, guard-rules/error-log-sensitive-data, guard-rules/error-stack-trace-leak, guard-rules/error-unified-error-format, guard-rules/system-command-injection
guard-rules/system-insecure-permissions, guard-rules/system-path-traversal, guard-rules/system-secrets-detection, guard-rules/web-auth-bypass, guard-rules/web-code-injection
guard-rules/web-csrf, guard-rules/web-excessive-data-exposure, guard-rules/web-idor, guard-rules/web-input-validation, guard-rules/web-jwt-misuse
guard-rules/web-mass-assignment, guard-rules/web-missing-authentication, guard-rules/web-missing-authorization, guard-rules/web-open-redirect, guard-rules/web-resource-exhaustion
guard-rules/web-ssrf, guard-rules/web-ssti, guard-rules/web-unrestricted-upload, guard-rules/web-xss, guard-rules/web-xxe
audit-rules/auth-and-session, audit-rules/authorization, audit-rules/cryptography, audit-rules/data-protection, audit-rules/dependency-security
audit-rules/http-security-headers, audit-rules/information-exposure, audit-rules/infra-hardening, audit-rules/input-validation, audit-rules/logging-and-monitoring
audit-rules/output-encoding, audit-rules/secrets-management, audit-rules/secure-transport, review-rules/python

## java
guard-rules/crypto-aes-ecb-mode, guard-rules/crypto-custom-crypto, guard-rules/crypto-hardcoded-iv, guard-rules/crypto-hardcoded-secrets, guard-rules/crypto-insufficient-key-length
guard-rules/crypto-password-storage, guard-rules/crypto-tls-version, guard-rules/crypto-weak-crypto-algorithm, guard-rules/crypto-weak-random, guard-rules/error-debug-mode-production
guard-rules/error-exception-swallow, guard-rules/error-log-sensitive-data, guard-rules/error-stack-trace-leak, guard-rules/error-unified-error-format, guard-rules/system-command-injection
guard-rules/system-insecure-permissions, guard-rules/system-path-traversal, guard-rules/system-secrets-detection, guard-rules/web-auth-bypass, guard-rules/web-csrf
guard-rules/web-deserialization, guard-rules/web-excessive-data-exposure, guard-rules/web-idor, guard-rules/web-input-validation, guard-rules/web-jwt-misuse
guard-rules/web-mass-assignment, guard-rules/web-missing-authentication, guard-rules/web-missing-authorization, guard-rules/web-open-redirect, guard-rules/web-resource-exhaustion
guard-rules/web-sql-injection, guard-rules/web-ssrf, guard-rules/web-ssti, guard-rules/web-unrestricted-upload, guard-rules/web-xss
guard-rules/web-xxe, audit-rules/auth-and-session, audit-rules/authorization, audit-rules/cryptography, audit-rules/data-protection
audit-rules/dependency-security, audit-rules/http-security-headers, audit-rules/information-exposure, audit-rules/infra-hardening, audit-rules/input-validation
audit-rules/logging-and-monitoring, audit-rules/output-encoding, audit-rules/secrets-management, audit-rules/secure-transport, review-rules/java

## go
guard-rules/crypto-aes-ecb-mode, guard-rules/crypto-custom-crypto, guard-rules/crypto-hardcoded-iv, guard-rules/crypto-hardcoded-secrets, guard-rules/crypto-insufficient-key-length
guard-rules/crypto-password-storage, guard-rules/crypto-tls-version, guard-rules/crypto-weak-crypto-algorithm, guard-rules/crypto-weak-random, guard-rules/error-debug-mode-production
guard-rules/error-exception-swallow, guard-rules/error-log-sensitive-data, guard-rules/error-panic-to-client, guard-rules/error-stack-trace-leak, guard-rules/error-unified-error-format
guard-rules/system-command-injection, guard-rules/system-insecure-permissions, guard-rules/system-path-traversal, guard-rules/system-secrets-detection, guard-rules/web-auth-bypass
guard-rules/web-csrf, guard-rules/web-excessive-data-exposure, guard-rules/web-idor, guard-rules/web-input-validation, guard-rules/web-jwt-misuse
guard-rules/web-mass-assignment, guard-rules/web-missing-authentication, guard-rules/web-missing-authorization, guard-rules/web-open-redirect, guard-rules/web-resource-exhaustion
guard-rules/web-sql-injection, guard-rules/web-ssrf, guard-rules/web-ssti, guard-rules/web-unrestricted-upload, guard-rules/web-xss
guard-rules/web-xxe, audit-rules/auth-and-session, audit-rules/authorization, audit-rules/cryptography, audit-rules/data-protection
audit-rules/dependency-security, audit-rules/http-security-headers, audit-rules/information-exposure, audit-rules/infra-hardening, audit-rules/input-validation
audit-rules/logging-and-monitoring, audit-rules/output-encoding, audit-rules/secrets-management, audit-rules/secure-transport, review-rules/go

## javascript
guard-rules/system-secrets-detection, audit-rules/auth-and-session, audit-rules/authorization, audit-rules/cryptography, audit-rules/data-protection
audit-rules/dependency-security, audit-rules/http-security-headers, audit-rules/information-exposure, audit-rules/infra-hardening, audit-rules/input-validation
audit-rules/logging-and-monitoring, audit-rules/output-encoding, audit-rules/secrets-management, audit-rules/secure-transport, review-rules/javascript

