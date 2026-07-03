/**
 * crypto_utils.js — Cryptographic vulnerability examples (Node.js)
 *
 * VULNERABILITIES:
 *   - CWE-327: Weak cryptography — MD5 for password hashing, AES-ECB mode
 *   - CWE-338: Weak random — Math.random() for security tokens
 *   - CWE-798: Hardcoded encryption keys & IVs
 *   - CWE-329: Static IV in CBC mode
 */

const crypto = require('crypto');

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-327]: MD5 for Password Hashing
// ═══════════════════════════════════════════

function badHashPassword(password) {
    // VULNERABILITY [CWE-327]: MD5 is cryptographically broken
    return crypto.createHash('md5').update(password).digest('hex');
    // Trivially reversed via rainbow tables. No salt.
}

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-327]: AES-ECB Mode
// ═══════════════════════════════════════════

function badEncryptECB(plaintext, key) {
    // VULNERABILITY [CWE-327]: ECB mode reveals data patterns
    const cipher = crypto.createCipheriv('aes-128-ecb', key, null);
    let encrypted = cipher.update(plaintext, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    return encrypted;
    // Identical plaintext blocks → identical ciphertext blocks
}

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-329]: Static/Hardcoded IV
// ═══════════════════════════════════════════

const HARDCODED_IV = '0123456789abcdef';  // VULNERABILITY [CWE-329]: static IV

function badEncryptStaticIV(plaintext, key) {
    // VULNERABILITY [CWE-329]: Same IV for every encryption
    const cipher = crypto.createCipheriv('aes-256-cbc', key, HARDCODED_IV);
    let encrypted = cipher.update(plaintext, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    return encrypted;
    // Reusing IV with same key → attacker can derive plaintext relationships
}

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-798]: Hardcoded Encryption Key
// ═══════════════════════════════════════════

const MASTER_KEY = 'abcdef1234567890abcdef1234567890';  // VULNERABILITY [CWE-798]

function badEncryptWithHardcodedKey(data) {
    // VULNERABILITY [CWE-798]: Key embedded in source code
    const cipher = crypto.createCipheriv('aes-256-cbc', MASTER_KEY, MASTER_KEY.slice(0, 16));
    return cipher.update(data, 'utf8', 'hex') + cipher.final('hex');
}

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-338]: Weak Random (Math.random)
// ═══════════════════════════════════════════

function badGenerateToken() {
    // VULNERABILITY [CWE-338]: Math.random() is NOT cryptographically secure
    return Math.random().toString(36).substring(2) +
           Math.random().toString(36).substring(2);
    // Predictable with ~2^48 effort. Observable via V8 PRNG state.
}

function badGenerateResetToken() {
    // VULNERABILITY [CWE-338]: weak random for password reset
    return Math.floor(Math.random() * 1000000).toString().padStart(6, '0');
    // 6-digit predictable code → brute-forceable in minutes
}

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-326]: Insufficient Key Length
// ═══════════════════════════════════════════

function badEncryptWeakKey(plaintext, password) {
    // VULNERABILITY [CWE-326]: Derives 128-bit key from weak password
    const key = crypto.createHash('sha256').update(password).digest().slice(0, 16);
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv('aes-128-cbc', key, iv);
    return Buffer.concat([iv, cipher.update(plaintext), cipher.final()]);
    // Weak password → weak key. No PBKDF2/bcrypt key derivation.
}

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-310]: Custom Crypto (XOR Cipher)
// ═══════════════════════════════════════════

function badXOREncrypt(data, key) {
    // VULNERABILITY [CWE-310]: Custom XOR "encryption" — trivially breakable
    let result = '';
    for (let i = 0; i < data.length; i++) {
        result += String.fromCharCode(data.charCodeAt(i) ^ key.charCodeAt(i % key.length));
    }
    return result;
    // Repeating-key XOR cracked by frequency analysis in seconds
}

// ═══════════════════════════════════════════
// CORRECTED VERSIONS
// ═══════════════════════════════════════════

const { scryptSync, randomBytes, createCipheriv, createHash, timingSafeEqual } = require('crypto');

function goodHashPassword(password) {
    // Use scrypt with random salt (or bcrypt in production)
    const salt = randomBytes(16).toString('hex');
    const hash = scryptSync(password, salt, 64).toString('hex');
    return `${salt}:${hash}`;
}

function goodVerifyPassword(password, stored) {
    const [salt, originalHash] = stored.split(':');
    const hash = scryptSync(password, salt, 64).toString('hex');
    return timingSafeEqual(Buffer.from(hash), Buffer.from(originalHash));
}

function goodEncrypt(plaintext, key) {
    // AES-256-GCM with random IV (authenticated encryption)
    const iv = randomBytes(12);  // GCM recommended IV length
    const cipher = createCipheriv('aes-256-gcm', key, iv);
    const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const authTag = cipher.getAuthTag();
    return Buffer.concat([iv, authTag, encrypted]).toString('base64');
}

function goodGenerateToken() {
    // crypto.randomBytes is cryptographically secure
    return randomBytes(32).toString('hex');
}

function goodEncryptDerivedKey(plaintext, password) {
    // Use PBKDF2 for key derivation
    const salt = randomBytes(16);
    const key = crypto.pbkdf2Sync(password, salt, 100000, 32, 'sha256');
    const iv = randomBytes(16);
    const cipher = createCipheriv('aes-256-cbc', key, iv);
    return Buffer.concat([salt, iv, cipher.update(plaintext), cipher.final()]);
}

module.exports = {
    badHashPassword, badEncryptECB, badEncryptStaticIV, badEncryptWithHardcodedKey,
    badGenerateToken, badGenerateResetToken, badEncryptWeakKey, badXOREncrypt,
    goodHashPassword, goodVerifyPassword, goodEncrypt, goodGenerateToken, goodEncryptDerivedKey
};
