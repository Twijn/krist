const con = require("./database");

module.exports = {
    keepAlive: (msg, reply, socket) => {
        socket.timeSinceLastPing = 0;
    },
    shopInfo: (msg, reply, socket) => {
        if (msg.hasOwnProperty("name") &&
                msg.hasOwnProperty("server") &&
                msg.hasOwnProperty("kristName") &&
                msg.hasOwnProperty("kristAddress")) {
            if (msg.name.length > 64)
                reply({ok: false, error: "name length must be < 65 characters"});
            if (msg.server.length > 64)
                reply({ok: false, error: "server length must be < 65 characters"});
            if (msg.kristName.length > 64)
                reply({ok: false, error: "kristName length must be < 65 characters"});
            if (msg.kristAddress.length > 64)
                reply({ok: false, error: "kristAddress length must be < 65 characters"});

            con.query("update shop set name = ?, server = ?, kristName = ?, kristAddress = ? where id = ?;", [msg.name, msg.server, msg.kristName, msg.kristAddress, socket.id], err => {
                if (err) {
                    console.error(err)
                    reply({ok: false, error: "SQL error occurred"})
                    return;
                }

                reply({ok: true, info: {name: msg.name, server: msg.server, krist: {name: msg.kristName, address: msg.kristAddress}}})
            });
        } else {
            reply({ok: false, error: "Invalid parameters, expected [name, server, kristName, kristAddress]"})
        }
    },
    itemDictionary: (msg, reply, socket) => {
        if (msg.hasOwnProperty("items") && typeof(msg.items) == "object") {
            msg.items.forEach(item => {
                if (!item.hasOwnProperty("nbt")) item.nbt = "";
                if (item.hasOwnProperty("name") && item.hasOwnProperty("nbt") && item.hasOwnProperty("displayName")) {
                    con.query("insert into dictionary (shop_id, name, nbt, displayName) values (?, ?, ?, ?) on duplicate key update displayName = ?;", [socket.id, item.name, item.nbt, item.displayName, item.displayName], err => {
                        if (err) console.error(err);
                    });
                }
            });
            reply({ok: true});
        } else {
            reply({ok: false, error: "Invalid parameters, expected [items]"})
        }
    },
    itemsForSale: (msg, reply, socket) => {
        if (msg.hasOwnProperty("items") && typeof(msg.items) == "object") {
            con.query("delete from item where shop_id = ?;", [socket.id], err => {
                if (err) {
                    console.error(err);
                    reply({ok: false, error: "SQL error occurred"})
                    return;
                }
                
                msg.items.forEach(item => {
                    if (!item.hasOwnProperty("nbt")) item.nbt = "";
                    if (item.hasOwnProperty("name") && item.hasOwnProperty("nbt") && item.hasOwnProperty("displayName") && item.hasOwnProperty("price") && item.hasOwnProperty("meta") && item.hasOwnProperty("count")) {
                        con.query("insert into item (shop_id, name, nbt, displayName, price, meta, count) values (?, ?, ?, ?, ?, ?, ?);", [socket.id, item.name, item.nbt, item.displayName, item.price, item.meta, item.count], err => {
                            if (err) console.error(err);
                        });
                    }
                });
                reply({ok: true});
            });
        } else {
            reply({ok: false, error: "Invalid parameters, expected [items]"})
        }
    },
};