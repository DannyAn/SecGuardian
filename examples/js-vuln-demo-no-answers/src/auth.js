
const crypto = require('crypto');
const jwt = require('jsonwebtoken');






function badAdminRoute(req, res) {

    res.json({
        users: getAllUsers(),
        config: getAdminConfig(),
        secrets: getSecrets()
    });
}


function badVerifyToken(token, secret) {

    const decoded = jwt.decode(token);  
    return decoded;
}





const JWT_SECRET = 'mysecretkey123';

function badSignJWT(user) {

    const token = jwt.sign(
        { username: user.username, role: 'admin' },  
        'secret',  
        { algorithm: 'HS256' }
    );
    return token;
}


function badSignJWTNoExpiry(user) {

    return jwt.sign({ user: user.username, admin: true }, JWT_SECRET);
}





const API_KEY = 'sk-1234567890abcdef-production-key';
const DB_PASSWORD = 'admin123!@#';
const AWS_SECRET = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';

function badAuthenticate(token) {

    return token === 'supersecrettoken123';
}





function badUserProfile(req, res) {

    const userId = req.params.id;
    const userData = getUserById(userId);
    res.json({
        userId: userData.id,
        email: userData.email,
        ssn: userData.ssn,  
        creditCard: userData.cc
    });
}





function badLogin(req, res) {

    const { username, password } = req.body;
    const user = db.find(u => u.username === username);
    if (user && user.password === password) {
        return res.json({ token: badSignJWT(user) });
    }
    return res.status(401).json({ error: 'Invalid credentials' });
    
}





function goodAdminRoute(req, res) {
    
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
    
    return jwt.sign(
        { username: user.username, role: user.role },
        process.env.JWT_SECRET,
        { algorithm: 'HS256', expiresIn: '1h' }
    );
}

function goodAuthenticate(token) {
    const expected = process.env.API_TOKEN;
    if (!expected) return false;
    
    return crypto.timingSafeEqual(
        Buffer.from(token),
        Buffer.from(expected)
    );
}


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
            attempts.lockedUntil = Date.now() + 15 * 60 * 1000;  
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
