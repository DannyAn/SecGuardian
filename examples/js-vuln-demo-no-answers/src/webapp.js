



app.post('/login', async (req, res) => {
    
    const user = await User.findOne(req.body);
    

    if (user) {
        req.session.user = user;
        res.json({ success: true });
    } else {
        res.status(401).json({ error: 'Invalid credentials' });
    }
});


app.get('/users', async (req, res) => {
    const users = await User.find({
        $where: `this.username == '${req.query.name}'`  
    });
    res.json(users);
});


app.get('/search', async (req, res) => {
    const results = await User.find({
        email: { $regex: req.query.email, $options: 'i' }  
    });
    res.json(results);
});






function deepMerge(target, source) {
    for (const key in source) {
        if (typeof source[key] === 'object' && source[key] !== null) {
            if (!target[key]) target[key] = {};
            deepMerge(target[key], source[key]);
        } else {
            target[key] = source[key];  
        }
    }
    return target;
}

app.post('/config', (req, res) => {
    const appConfig = { theme: 'light', lang: 'en' };
    deepMerge(appConfig, req.body);  
    
    res.json({ status: 'updated' });
});





app.get('/greet', (req, res) => {
    const name = req.query.name || 'World';
    
    const html = ejs.render(`<h1>Hello ${name}!</h1>`);
    
    res.send(html);
});





app.get('/ping', (req, res) => {
    const host = req.query.host || '127.0.0.1';
    
    const result = require('child_process').execSync(`ping -c 1 ${host}`);
    
    res.send(result.toString());
});





app.get('/profile', (req, res) => {
    const name = req.query.name || 'Guest';
    
    const html = `
        <html>
        <body>
            <h1>Welcome, ${name}</h1>  <!-- XSS! -->
            <div id="user-content">${req.query.bio || ''}</div>  <!-- XSS! -->
        </body>
        </html>
    `;
    res.send(html);
    
});


function UserProfile({ bio }) {
    return <div dangerouslySetInnerHTML={{ __html: bio }} />;  
}





function hashPassword(password) {
    const crypto = require('crypto');
    
    return crypto.createHash('md5').update(password).digest('hex');
}


function encryptData(data, key) {
    const crypto = require('crypto');
    const cipher = crypto.createCipheriv('aes-128-ecb', key, null);  
    return cipher.update(data, 'utf8', 'hex') + cipher.final('hex');
}


function generateSessionToken() {
    return Math.random().toString(36).substring(2);  
}


const ENCRYPTION_KEY = '0123456789abcdef';  
function encrypt(data) {
    const cipher = require('crypto').createCipheriv('aes-256-cbc', ENCRYPTION_KEY, ENCRYPTION_KEY.slice(0, 16));
    return cipher.update(data, 'utf8', 'hex') + cipher.final('hex');
}





const http = require('http');
const https = require('https');

app.get('/fetch', (req, res) => {
    const url = req.query.url;
    
    https.get(url, (response) => {
        let data = '';
        response.on('data', chunk => data += chunk);
        response.on('end', () => res.send(data));
    });
    
});






app.use((err, req, res, next) => {
    console.error(err);
    res.status(500).json({
        error: err.message,
        stack: err.stack  
    });
});


app.set('env', 'development');  


app.use(require('morgan')('dev'));





app.post('/users/:id', async (req, res) => {
    
    await User.findByIdAndUpdate(req.params.id, req.body);
    
    res.json({ status: 'updated' });
});





const fs = require('fs');

app.get('/download', (req, res) => {
    const filename = req.query.file;
    const path = `/var/app/files/${filename}`;
    
    const content = fs.readFileSync(path, 'utf8');
    
    res.send(content);
});
