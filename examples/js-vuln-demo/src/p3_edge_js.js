
const { exec } = require('child_process');

const BLACKLIST = ['rm', 'shutdown', 'del'];


function execCommand(input) {
    for (const bad of BLACKLIST) {
        if (input.includes(bad)) return 'blocked';
    }
    exec(input, (err, stdout) => {});  // shell=true 可绕过
}


function validateUrl(url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
        return fetch(url);  // 未校验 SSRF
    }
    throw new Error('Invalid URL');
}
