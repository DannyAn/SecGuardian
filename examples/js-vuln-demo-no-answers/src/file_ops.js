
const fs = require('fs');
const path = require('path');
const os = require('os');





function badReadFile(userFile) {

    const filePath = `/var/app/files/${userFile}`;
    return fs.readFileSync(filePath, 'utf8');
    
}

function badServeStatic(req, res) {

    const userPath = req.query.file;
    const fullPath = path.join('/var/www/uploads', userPath);
    
    const content = fs.readFileSync(fullPath, 'utf8');
    res.end(content);
    
}

function badExtractZip(zipEntry) {

    const AdmZip = require('adm-zip');
    const zip = new AdmZip('upload.zip');
    const entries = zip.getEntries();

    entries.forEach(entry => {
        const outputPath = '/var/app/uploads/' + entry.entryName;
        
        fs.writeFileSync(outputPath, entry.getData());
    });
}





function badFileUpload(req, res) {

    const file = req.files.upload;
    const uploadPath = '/var/app/uploads/' + file.name;
    
    fs.writeFileSync(uploadPath, file.data);
    
    res.json({ path: uploadPath });
}





function badUserInfoEndpoint(req, res) {

    const user = db.find({ id: req.params.id });
    res.json({
        ...user,          
        config: getConfig(),  
        serverInfo: {
            nodeVersion: process.version,
            platform: os.platform(),
            hostname: os.hostname(),
            uptime: os.uptime(),
            memory: process.memoryUsage(),
            env: process.env     
        }
    });
}





function badErrorHandler(err, req, res, next) {

    res.status(500).json({
        error: err.message,
        stack: err.stack,           
        code: err.code,              
        syscall: err.syscall,       
        path: err.path,             
        module: module.filename,    
        nodeVersion: process.version 
    });
}





function badLogging(user, token, creditCard) {

    console.log('User login:', JSON.stringify(user));  
    console.log('Session token:', token);              
    console.log('Processing payment:', creditCard);    

    const logger = require('winston');
    logger.info('Payment processed', {
        card: creditCard.number,      
        cvv: creditCard.cvv,          
        expiry: creditCard.expiry,
        amount: 100.00
    });
}





function goodReadFile(userFile) {
    const baseDir = '/var/app/files';
    
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
    const MAX_SIZE = 10 * 1024 * 1024;  

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

    
    const safeName = require('crypto').randomBytes(16).toString('hex') + ext;
    fs.writeFileSync('/var/app/uploads/' + safeName, file.data);
    res.json({ id: safeName });
}

function goodErrorHandler(err, req, res, next) {
    
    console.error(`[${new Date().toISOString()}] ${req.method} ${req.path}:`, err);

    res.status(500).json({
        error: 'An internal error occurred',
        requestId: req.id  
    });
}

function goodLogging(user, action) {
    
    console.log(`User action: ${user.id} performed ${action}`);
    
}

module.exports = {
    badReadFile, badServeStatic, badExtractZip, badFileUpload,
    badUserInfoEndpoint, badErrorHandler, badLogging,
    goodReadFile, goodFileUpload, goodErrorHandler, goodLogging
};
