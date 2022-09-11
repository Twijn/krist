const con = require("./database");

setInterval(() => {
    con.query("delete from shop where used is null and date_add(created, interval 30 minute) < now();", err => {
        if (err) console.error(err);
    });
}, 30000)