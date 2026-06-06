/**
 * auth.js — Authentication & Authorization vulnerability examples (Node.js)
 *
 * VULNERABILITIES:
 *   - CWE-287: Authentication bypass — no auth check on admin routes
 *   - CWE-347: JWT misuse — weak HMAC secret, no signature verification
 *   - CWE-798: Hardcoded credentials — API keys & secrets in source
 *   - CWE-306: Missing authentication — public access to protected resources
 *   - CWE-307: Brute force — no rate limiting on login
 */

const crypto = require('crypto');
const jwt = require('jsonwebtoken');

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-287]: Authentication Bypass
// ═══════════════════════════════════════════

// BadAdminRoute — admin endpoint without any auth check
function badAdminRoute(req, res) {
    // VULNERABILITY [CWE-287]: No authentication check on admin endpoint
    res.json({
        users: getAllUsers(),
        config: getAdminConfig(),
        secrets: getSecrets()
    });
}

// BadVerifyToken — token verification that doesn't check signature
function badVerifyToken(token, secret) {
    // VULNERABILITY [CWE-347]: JWT decode without verify
    const decoded = jwt.decode(token);  // decode() does NOT verify signature!
    return decoded;
}

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-347]: JWT Weak Secret
// ═══════════════════════════════════════════

const JWT_SECRET = 'mysecretkey123';  // VULNERABILITY [CWE-798]: hardcoded JWT secret

function badSignJWT(user) {
    // VULNERABILITY [CWE-347]: weak secret + admin claim from user input
    const token = jwt.sign(
        { username: user.username, role: 'admin' },  // role from client input!
        'secret',  // literally "secret" as signing key
        { algorithm: 'HS256' }
    );
    return token;
}

// BadJWTNoExpiry — JWT without expiration
function badSignJWTNoExpiry(user) {
    // VULNERABILITY [CWE-347]: No expiration — token valid forever
    return jwt.sign({ user: user.username, admin: true }, JWT_SECRET);
}

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-798]: Hardcoded Secrets
// ═══════════════════════════════════════════

const API_KEY = 'sk-1234567890abcdef-production-key';  // VULNERABILITY [CWE-798]
const DB_PASSWORD = 'admin123!@#';  // VULNERABILITY [CWE-798]
const AWS_SECRET = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';  // VULNERABILITY [CWE-798]

function badAuthenticate(token) {
    // VULNERABILITY [CWE-798]: token compared against hardcoded value
    return token === 'supersecrettoken123';
}

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-306]: Missing Authentication
// ═══════════════════════════════════════════

function badUserProfile(req, res) {
    // VULNERABILITY [CWE-306]: No auth check — anyone can access
    const userId = req.params.id;
    const userData = getUserById(userId);
    res.json({
        userId: userData.id,
        email: userData.email,
        ssn: userData.ssn,  // SSN exposed without auth!
        creditCard: userData.cc
    });
}

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-307]: No Rate Limiting
// ═══════════════════════════════════════════

function badLogin(req, res) {
    // VULNERABILITY [CWE-307]: No brute force protection
    const { username, password } = req.body;
    const user = db.find(u => u.username === username);
    if (user && user.password === password) {
        return res.json({ token: badSignJWT(user) });
    }
    return res.status(401).json({ error: 'Invalid credentials' });
    // Attacker can try unlimited passwords — no rate limiting, no account lockout
}

// ═══════════════════════════════════════════
// CORRECTED VERSIONS
// ═══════════════════════════════════════════

function goodAdminRoute(req, res) {
    // Verify auth token first
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ error: 'Unauthorized' });

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        if (decoded.role !== 'admin') {
            return res.status(403).json({ error: 'Forbidden' });
        }
        res.json({ users: getAllUsers() });
    } catch (err) {
        return res.status(401).json({ error: 'Invalid token' });
    }
}

function goodSignJWT(user) {
    // Never set admin from user input; use env for secret; set expiry
    return jwt.sign(
        { username: user.username, role: user.role },
        process.env.JWT_SECRET,
        { algorithm: 'HS256', expiresIn: '1h' }
    );
}

function goodAuthenticate(token) {
    const expected = process.env.API_TOKEN;
    if (!expected) return false;
    // Use timing-safe comparison
    return crypto.timingSafeEqual(
        Buffer.from(token),
        Buffer.from(expected)
    );
}

// Rate limiter middleware (conceptual)
const loginAttempts = new Map();
function goodLogin(req, res) {
    const ip = req.ip;
    const attempts = loginAttempts.get(ip) || { count: 0, lockedUntil: 0 };

    if (Date.now() < attempts.lockedUntil) {
        return res.status(429).json({ error: 'Too many attempts. Try again later.' });
    }

    const { username, password } = req.body;
    const user = db.find(u => u.username === username);

    if (!user || user.password !== password) {
        attempts.count++;
        if (attempts.count >= 5) {
            attempts.lockedUntil = Date.now() + 15 * 60 * 1000;  // 15 min lockout
        }
        loginAttempts.set(ip, attempts);
        return res.status(401).json({ error: 'Invalid credentials' });
    }

    loginAttempts.delete(ip);
    return res.json({ token: goodSignJWT(user) });
}

module.exports = {
    badAdminRoute, badVerifyToken, badSignJWT, badSignJWTNoExpiry,
    badAuthenticate, badUserProfile, badLogin,
    goodAdminRoute, goodSignJWT, goodAuthenticate, goodLogin
};
