
const { exec } = require('child_process');

const BLACKLIST = ['rm', 'shutdown', 'del'];


function execCommand(input) {
    for (const bad of BLACKLIST) {
        if (input.includes(bad)) return 'blocked';
    }
    exec(input, (err, stdout) => {});  
}


function validateUrl(url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
        return fetch(url);  
    }
    throw new Error('Invalid URL');
}
