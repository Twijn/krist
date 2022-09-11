// Load application config file 
const config = require("./config.json");

// SQL connection setup
const mysql      = require('mysql');
const connection = mysql.createConnection({
    host     : config.mysql.host,
    user     : config.mysql.user,
    password : config.mysql.password,
    database : config.mysql.database,
    charset: 'utf8mb4',
});

// Open a SQL connection
connection.connect();

// Perform a SQL query that returns a promise 
connection.pquery = (query, vars) => {
    return new Promise((res, rej) => {
        connection.query(query, vars, (err, result) => {
            if (err) {rej(err);return;}
            res(result);
        });
    });
}


const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
const charactersLength = characters.length;

connection.generateRandomString = (length = 10) => {
    let result = '';
    for ( var i = 0; i < length; i++ ) {
        result += characters.charAt(Math.floor(Math.random() * 
            charactersLength));
    }
    return result;
}


module.exports = connection;