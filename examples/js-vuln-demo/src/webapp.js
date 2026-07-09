/**
 * JS Vulnerability Demo — 8 security anti-patterns for detector validation
 *
 * Run: node src/webapp.js
 * Each vulnerability has a // VULN comment
 */

// ============================================

// ============================================
app.post('/login', async (req, res) => {
    // VULN: body directly as query → operation injection
    const user = await User.findOne(req.body);
    // Attacker: {"username": {"$ne": ""}, "password": {"$ne": ""}} → bypass auth

    if (user) {
        req.session.user = user;
        res.json({ success: true });
    } else {
        res.status(401).json({ error: 'Invalid credentials' });
    }
});

// VULN: $where JS code injection
app.get('/users', async (req, res) => {
    const users = await User.find({
        $where: `this.username == '${req.query.name}'`  // JS code injection!
    });
    res.json(users);
});

// VULN: $regex without input validation
app.get('/search', async (req, res) => {
    const results = await User.find({
        email: { $regex: req.query.email, $options: 'i' }  // NoSQL injection!
    });
    res.json(results);
});


// ============================================

// ============================================
// VULN: recursive merge without __proto__ filtering
function deepMerge(target, source) {
    for (const key in source) {
        if (typeof source[key] === 'object' && source[key] !== null) {
            if (!target[key]) target[key] = {};
            deepMerge(target[key], source[key]);
        } else {
            target[key] = source[key];  // __proto__ can be set!
        }
    }
    return target;
}

app.post('/config', (req, res) => {
    const appConfig = { theme: 'light', lang: 'en' };
    deepMerge(appConfig, req.body);  // VULN: prototype pollution
    // Attacker: {"__proto__": {"isAdmin": true}} → all objects inherit isAdmin!
    res.json({ status: 'updated' });
});


// ============================================

// ============================================
app.get('/greet', (req, res) => {
    const name = req.query.name || 'World';
    // VULN: user input rendered as template (not variable)
    const html = ejs.render(`<h1>Hello ${name}!</h1>`);
    // Attacker: ?name=<%= process.mainModule.require('child_process').execSync('id') %>
    res.send(html);
});


// ============================================

// ============================================
app.get('/ping', (req, res) => {
    const host = req.query.host || '127.0.0.1';
    // VULN: user input concatenated to shell command
    const result = require('child_process').execSync(`ping -c 1 ${host}`);
    // Attacker: ?host=8.8.8.8; cat /etc/passwd
    res.send(result.toString());
});


// ============================================

// ============================================
app.get('/profile', (req, res) => {
    const name = req.query.name || 'Guest';
    // VULN: innerHTML with unescaped user input
    const html = `
        <html>
        <body>
            <h1>Welcome, ${name}</h1>  <!-- XSS! -->
            <div id="user-content">${req.query.bio || ''}</div>  <!-- XSS! -->
        </body>
        </html>
    `;
    res.send(html);
    // Attacker: ?name=<script>alert(document.cookie)</script>
});

// VULN: React dangerouslySetInnerHTML
function UserProfile({ bio }) {
    return <div dangerouslySetInnerHTML={{ __html: bio }} />;  // XSS!
}


// ============================================

// ============================================
function hashPassword(password) {
    const crypto = require('crypto');
    // VULN: MD5 for password storage
    return crypto.createHash('md5').update(password).digest('hex');
}

// VULN: AES-ECB mode
function encryptData(data, key) {
    const crypto = require('crypto');
    const cipher = crypto.createCipheriv('aes-128-ecb', key, null);  // ECB!
    return cipher.update(data, 'utf8', 'hex') + cipher.final('hex');
}

// VULN: Math.random() for security-sensitive use
function generateSessionToken() {
    return Math.random().toString(36).substring(2);  // NOT crypto secure!
}

// VULN: hardcoded encryption key
const ENCRYPTION_KEY = '0123456789abcdef';  // Hardcoded key!
function encrypt(data) {
    const cipher = require('crypto').createCipheriv('aes-256-cbc', ENCRYPTION_KEY, ENCRYPTION_KEY.slice(0, 16));
    return cipher.update(data, 'utf8', 'hex') + cipher.final('hex');
}


// ============================================

// ============================================
const http = require('http');
const https = require('https');

app.get('/fetch', (req, res) => {
    const url = req.query.url;
    // VULN: user-controlled URL → SSRF
    https.get(url, (response) => {
        let data = '';
        response.on('data', chunk => data += chunk);
        response.on('end', () => res.send(data));
    });
    // Attacker: ?url=http://169.254.169.254/latest/meta-data/ (AWS metadata)
});


// ============================================
// 8. Error Handling Issues — Stack Trace Leak + Debug Mode
// ============================================
// VULN: stack trace returned to client
app.use((err, req, res, next) => {
    console.error(err);
    res.status(500).json({
        error: err.message,
        stack: err.stack  // Full stack trace exposed!
    });
});

// VULN: Express development mode in production
app.set('env', 'development');  // Should be 'production'

// VULN: debug middleware in production
app.use(require('morgan')('dev'));


// ============================================

// ============================================
app.post('/users/:id', async (req, res) => {
    // VULN: entire req.body used for update
    await User.findByIdAndUpdate(req.params.id, req.body);
    // Attacker: {"role": "admin", "isAdmin": true}
    res.json({ status: 'updated' });
});


// ============================================

// ============================================
const fs = require('fs');

app.get('/download', (req, res) => {
    const filename = req.query.file;
    const path = `/var/app/files/${filename}`;
    // VULN: no path normalization
    const content = fs.readFileSync(path, 'utf8');
    // Attacker: ?file=../../etc/passwd
    res.send(content);
});
