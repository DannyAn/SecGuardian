
const { exec, execSync, spawn } = require('child_process');
const vm = require('vm');





function badExecShell(userInput) {

    const cmd = `ping -c 1 ${userInput}`;
    return execSync(cmd).toString();
    
}

function badExecOptions(userCmd) {

    const child = exec(userCmd, { shell: true }, (err, stdout, stderr) => {
        console.log(stdout);
    });
    
}

function badSpawnShell(userInput) {

    const parts = userInput.split(' ');
    const child = spawn(parts[0], parts.slice(1), { shell: true });
    return child;
}





function badEval(userExpr) {

    return eval(userExpr);
    
}

function badFunctionConstructor(userCode) {

    const fn = new Function('data', userCode);
    return fn({});
    
}

function badSetTimeout(userCode) {

    setTimeout(userCode, 1000);
    
}





function badVMRun(userCode) {

    const sandbox = { result: null };
    vm.createContext(sandbox);
    vm.runInContext(userCode, sandbox);
    
    return sandbox.result;
}





function badMerge(target, source) {

    for (const key in source) {
        if (typeof source[key] === 'object' && source[key] !== null) {
            if (!target[key]) target[key] = {};
            badMerge(target[key], source[key]);
        } else {
            target[key] = source[key];  
        }
    }
    return target;
}

function badSetNestedProperty(obj, path, value) {

    const parts = path.split('.');
    let current = obj;
    for (let i = 0; i < parts.length - 1; i++) {
        if (!current[parts[i]]) current[parts[i]] = {};
        current = current[parts[i]];
    }
    current[parts[parts.length - 1]] = value;
    
    return obj;
}





function badUpdateUser(id, userInput) {

    const updates = { ...userInput };
    return db.users.update({ id }, { $set: updates });
    
}

function badCreateUser(userInput) {

    const user = {
        username: userInput.username,
        password: userInput.password,
        role: userInput.role || 'user',       
        isAdmin: userInput.isAdmin || false,   
        credits: userInput.credits || 0        
    };
    return db.users.insert(user);
}





function goodExecPing(host) {
    
    const { execFileSync } = require('child_process');
    if (!/^[a-zA-Z0-9.-]+$/.test(host)) {
        throw new Error('Invalid host');
    }
    return execFileSync('ping', ['-c', '1', host]).toString();
}

function goodSafeEval(expression) {
    
    const allowed = /^[\d\s+\-*/().]+$/;
    if (!allowed.test(expression)) {
        throw new Error('Expression contains disallowed characters');
    }
    return Function('"use strict"; return (' + expression + ')')();
}

function goodMerge(target, source) {
    
    const blocked = ['__proto__', 'constructor', 'prototype'];
    for (const key in source) {
        if (blocked.includes(key)) continue;
        if (typeof source[key] === 'object' && source[key] !== null && !Array.isArray(source[key])) {
            if (!target[key] || typeof target[key] !== 'object') target[key] = {};
            goodMerge(target[key], source[key]);
        } else {
            target[key] = source[key];
        }
    }
    return target;
}

function goodCreateUser(userInput) {
    
    const user = {
        username: userInput.username,
        password: userInput.password,
        role: 'user',        
        isAdmin: false,       
        credits: 0            
    };
    return db.users.insert(user);
}

module.exports = {
    badExecShell, badExecOptions, badSpawnShell,
    badEval, badFunctionConstructor, badSetTimeout, badVMRun,
    badMerge, badSetNestedProperty, badUpdateUser, badCreateUser,
    goodExecPing, goodSafeEval, goodMerge, goodCreateUser
};
