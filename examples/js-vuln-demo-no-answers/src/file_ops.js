/**
 * file_ops.js — File operation & path traversal vulnerability examples (Node.js)
 *






 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// ═══════════════════════════════════════════

// ═══════════════════════════════════════════

function badReadFile(userFile) {

    const filePath = `/var/app/files/${userFile}`;
    return fs.readFileSync(filePath, 'utf8');
    // Attacker: userFile = '../../etc/passwd' → reads /etc/passwd
}

function badServeStatic(req, res) {

    const userPath = req.query.file;
    const fullPath = path.join('/var/www/uploads', userPath);
    // path.join normalizes BUT doesn't verify the result is within base dir!
    const content = fs.readFileSync(fullPath, 'utf8');
    res.end(content);
    // Attacker: ?file=../../etc/shadow
}

function badExtractZip(zipEntry) {

    const AdmZip = require('adm-zip');
    const zip = new AdmZip('upload.zip');
    const entries = zip.getEntries();

    entries.forEach(entry => {
        const outputPath = '/var/app/uploads/' + entry.entryName;
        // entry.entryName could be '../../../etc/cron.d/backdoor'!
        fs.writeFileSync(outputPath, entry.getData());
    });
}

// ═══════════════════════════════════════════

// ═══════════════════════════════════════════

function badFileUpload(req, res) {

    const file = req.files.upload;
    const uploadPath = '/var/app/uploads/' + file.name;
    // No MIME check, no extension whitelist, no size limit
    fs.writeFileSync(uploadPath, file.data);
    // Attacker uploads: shell.php, backdoor.jsp, malicious.exe
    res.json({ path: uploadPath });
}

// ═══════════════════════════════════════════

// ═══════════════════════════════════════════

function badUserInfoEndpoint(req, res) {

    const user = db.find({ id: req.params.id });
    res.json({
        ...user,          // Exposes password hash, SSN, internal IDs
        config: getConfig(),  // Exposes DB passwords, API keys
        serverInfo: {
            nodeVersion: process.version,
            platform: os.platform(),
            hostname: os.hostname(),
            uptime: os.uptime(),
            memory: process.memoryUsage(),
            env: process.env     // CRITICAL: exposes ALL environment variables!
        }
    });
}

// ═══════════════════════════════════════════

// ═══════════════════════════════════════════

function badErrorHandler(err, req, res, next) {

    res.status(500).json({
        error: err.message,
        stack: err.stack,           // Full stack trace leaked!
        code: err.code,              // Internal error codes
        syscall: err.syscall,       // System call info
        path: err.path,             // File path info
        module: module.filename,    // Module location
        nodeVersion: process.version // Node version for exploit targeting
    });
}

// ═══════════════════════════════════════════

// ═══════════════════════════════════════════

function badLogging(user, token, creditCard) {

    console.log('User login:', JSON.stringify(user));  // Has password hash!
    console.log('Session token:', token);              // JWT logged!
    console.log('Processing payment:', creditCard);    // Full credit card number!

    const logger = require('winston');
    logger.info('Payment processed', {
        card: creditCard.number,      // CC number in logs
        cvv: creditCard.cvv,          // CVV in logs!
        expiry: creditCard.expiry,
        amount: 100.00
    });
}

// ═══════════════════════════════════════════
// CORRECTED VERSIONS
// ═══════════════════════════════════════════

function goodReadFile(userFile) {
    const baseDir = '/var/app/files';
    // Resolve AND verify path stays within base directory
    const resolved = path.resolve(baseDir, userFile);
    if (!resolved.startsWith(baseDir + path.sep)) {
        throw new Error('Path traversal detected');
    }
    return fs.readFileSync(resolved, 'utf8');
}

function goodFileUpload(req, res) {
    const file = req.files.upload;
    const ALLOWED_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.pdf', '.docx']);
    const ALLOWED_MIMES = new Set(['image/jpeg', 'image/png', 'application/pdf']);
    const MAX_SIZE = 10 * 1024 * 1024;  // 10 MB

    const ext = path.extname(file.name).toLowerCase();
    if (!ALLOWED_EXTENSIONS.has(ext)) {
        return res.status(400).json({ error: 'File type not allowed' });
    }
    if (!ALLOWED_MIMES.has(file.mimetype)) {
        return res.status(400).json({ error: 'Invalid MIME type' });
    }
    if (file.size > MAX_SIZE) {
        return res.status(400).json({ error: 'File too large' });
    }

    // Generate safe filename (don't use user-supplied name)
    const safeName = require('crypto').randomBytes(16).toString('hex') + ext;
    fs.writeFileSync('/var/app/uploads/' + safeName, file.data);
    res.json({ id: safeName });
}

function goodErrorHandler(err, req, res, next) {
    // Log full error internally, return generic message to client
    console.error(`[${new Date().toISOString()}] ${req.method} ${req.path}:`, err);

    res.status(500).json({
        error: 'An internal error occurred',
        requestId: req.id  // Correlation ID for debugging, not internal details
    });
}

function goodLogging(user, action) {
    // Log only what's necessary — never sensitive data
    console.log(`User action: ${user.id} performed ${action}`);
    // Password hashes, tokens, credit cards — NEVER logged
}

module.exports = {
    badReadFile, badServeStatic, badExtractZip, badFileUpload,
    badUserInfoEndpoint, badErrorHandler, badLogging,
    goodReadFile, goodFileUpload, goodErrorHandler, goodLogging
};
