/**
 * crypto.c — Cryptographic vulnerability examples
 *
 * VULNERABILITIES:
 *   - CWE-798: Hardcoded secret (line 17)
 *   - CWE-338: Weak random (line 33)
 *   - CWE-327: Weak crypto algorithm (line 48)
 *   - CWE-326: Insufficient key length (line 65)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <openssl/rand.h>
#include <openssl/evp.h>
#include <openssl/aes.h>
#include <openssl/des.h>
#include <time.h>

/* ── CWE-798: Hardcoded Credentials ────────────────────────── */
static const char *g_api_key = "sk-abcdef1234567890abcdef1234567890";

void authenticate_user() {
    // VULNERABILITY [CWE-798]: Hardcoded secret in source
    // API key directly in code — git history exposes it forever
    const char *password = "SuperSecretPassw0rd!";
    const char *token = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0";

    if (strcmp(getenv("USER_TOKEN"), token) == 0) {
        printf("Authenticated with hardcoded token\n");
    }
}

/* ── CWE-338: Weak Random ─────────────────────────────────── */
int generate_token_weak() {
    // VULNERABILITY [CWE-338]: Weak PRNG for security-sensitive purpose
    // rand() is predictable — seed can be brute-forced
    srand(time(NULL));         // BAD: predictable seed
    int token = rand();         // BAD: predictable value
    return token;
}

int generate_token_strong() {
    // GOOD: use cryptographic RNG
    unsigned char buf[32];
    RAND_bytes(buf, sizeof(buf));
    return buf[0];
}

/* ── CWE-327: Weak Crypto Algorithm ───────────────────────── */
void encrypt_data_weak(const char *plaintext) {
    // VULNERABILITY [CWE-327]: Use of broken/weak crypto algorithm
    // DES is deprecated and can be brute-forced in <24 hours
    DES_cblock key;
    DES_key_schedule schedule;

    // BAD: DES with 56-bit key
    DES_set_key_unchecked(&key, &schedule);

    unsigned char output[64];
    DES_ecb_encrypt((const_DES_cblock *)plaintext,
                    (DES_cblock *)output, &schedule, DES_ENCRYPT);
    printf("Encrypted with DES (broken)\n");
}

void encrypt_data_good(const char *plaintext) {
    // GOOD: use AEAD (AES-256-GCM)
    unsigned char key[32];  // 256-bit
    RAND_bytes(key, sizeof(key));
    // Use EVP_EncryptInit_ex with EVP_aes_256_gcm()
    printf("Encrypted with AES-256-GCM (secure)\n");
}

/* ── CWE-326: Insufficient Key Length ─────────────────────── */
void setup_encryption_weak() {
    // VULNERABILITY [CWE-326]: Key length too short
    // AES-56 (not a real mode — simulating short key)
    unsigned char key[7];    // BAD: 56 bits — bruteforceable
    RAND_bytes(key, 7);

    // RC4 with variable key (already broken, but short key makes it worse)
    // VULNERABILITY [CWE-326]: RC4 uses variable key, 40-bit variant exists
    printf("Using 56-bit key (should be 256-bit minimum)\n");
}

void setup_encryption_strong() {
    // GOOD: 256-bit key
    unsigned char key[32];
    RAND_bytes(key, sizeof(key));
    printf("Using 256-bit key\n");
}

/* ── Main ─────────────────────────────────────────────────── */
int main() {
    printf("Crypto vulnerability demo\n");
    authenticate_user();
    generate_token_weak();
    encrypt_data_weak("sensitive data");
    setup_encryption_weak();
    return 0;
}
