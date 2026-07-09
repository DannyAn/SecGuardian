
const https = require('https');
const { execSync } = require('child_process');
const fs = require('fs');





function badDownloadAndRun(url) {

    https.get(url, (res) => {
        let script = '';
        res.on('data', chunk => script += chunk);
        res.on('end', () => {
            eval(script);  
        });
    });
    
}

function badInstallScript() {

    
    
    execSync('curl https://some-cdn.com/setup.sh | bash');
    
}








function badLodashUsage(data) {
    const _ = require('lodash');

    _.set({}, data.path, data.value);  
}


function badExpressRedirect(req, res) {

    res.redirect(req.query.url);  
}


function badMarkedRender(userInput) {
    const marked = require('marked');

    return marked.parse(userInput);
}


function badAxiosRequest(userURL) {
    const axios = require('axios');

    return axios.get(userURL);
}






const VULNERABLE_DEPENDENCIES = [
    { name: 'request', version: '2.88.2', status: 'DEPRECATED', risk: 'No security updates' },
    { name: 'cryptiles', version: '3.1.2', status: 'DEPRECATED', risk: 'Known crypto vulnerabilities' },
    { name: 'hoek', version: '4.2.1', status: 'DEPRECATED', risk: 'Prototype pollution (CVE-2020-36604)' },
    { name: 'deep-extend', version: '0.4.2', status: 'UNMAINTAINED', risk: 'Prototype pollution' },
    { name: 'left-pad', version: '1.3.0', status: 'UNPUBLISHED', risk: 'Supply chain breakage' }
];





function badNpmInstallUntrusted() {

    
    execSync('npm install untrusted-package');
    
}

function badRequireDynamicPath(userPath) {

    const resolved = require.resolve(userPath);
    return require(resolved);
    
}





function badImportFromCDN() {

    
    
    const html = `
        <script src="https://cdn.untrusted-example.com/jquery.min.js"></script>
        <script src="https://cdn.untrusted-example.com/react.production.min.js"></script>
    `;
    return html;
    
}





function goodDownloadAndRun(url, expectedHash) {
    const crypto = require('crypto');

    return new Promise((resolve, reject) => {
        https.get(url, (res) => {
            const chunks = [];
            res.on('data', chunk => chunks.push(chunk));
            res.on('end', () => {
                const buffer = Buffer.concat(chunks);
                const hash = crypto.createHash('sha256').update(buffer).digest('hex');

                if (hash !== expectedHash) {
                    reject(new Error(`Integrity check failed! Expected ${expectedHash}, got ${hash}`));
                    return;
                }

                
                const script = buffer.toString();
                const module = { exports: {} };
                const fn = new Function('module', 'exports', script);
                fn(module, module.exports);
                resolve(module.exports);
            });
        });
    });
}

function goodHTMLWithSRI() {
    
    return `
        <script
            src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js"
            integrity="sha256-/JqT3SQfawRcv/BIHPThkBvs0OEvtFFmqPF/lYI/Cxo="
            crossorigin="anonymous">
        </script>
    `;
    
}

const ALLOWED_MODULES = new Set(['lodash', 'validator', 'axios']);
function goodNpmInstallSafely() {
    
    execSync('npm install lodash@4.17.21 --ignore-scripts --lockfile-version 2');
    
    execSync('npm audit --audit-level=high');
}

module.exports = {
    badDownloadAndRun, badInstallScript, badLodashUsage,
    badExpressRedirect, badMarkedRender, badAxiosRequest,
    badNpmInstallUntrusted, badRequireDynamicPath, badImportFromCDN,
    VULNERABLE_DEPENDENCIES,
    goodDownloadAndRun, goodHTMLWithSRI, goodNpmInstallSafely
};
