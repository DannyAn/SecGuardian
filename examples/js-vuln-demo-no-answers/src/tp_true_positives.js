
const { exec } = require('child_process');


function vulnerableQuery(db, userId) {
    return db.query(`SELECT * FROM users WHERE id = ${userId}`);
}


function vulnerableExec(input) {
    exec(`ping ${input}`, (err, stdout) => {});
}
