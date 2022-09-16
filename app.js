const express = require("express");
const ws = require("ws");
const fs = require("fs")
const path = require("path")
const cookieParser = require("cookie-parser");

const con = require("./database");

const app = express();

app.set("view engine", "ejs");
app.use(cookieParser());

const config = require("./config.json")

const wsServer = new ws.Server({noServer: true});
const wsRoutes = require("./wsRoutes");

let nextSocketId = 1;
global.sockets = [];

wsServer.on("connection", socket => {
    socket.internalId = nextSocketId++;
    socket.timeSinceLastPing = 0;
    global.sockets = [
        ...global.sockets,
        socket
    ];
    socket.on("message", message => {
        socket.timeSinceLastPing = 0;
        try {
            let msg = JSON.parse(message.toString());

            if (msg.hasOwnProperty("type") && wsRoutes.hasOwnProperty(msg.type)) {
                wsRoutes[msg.type](msg, replyMessage => {
                    if (msg.hasOwnProperty("id")) replyMessage.id = msg.id;
                    socket.send(JSON.stringify(replyMessage));
                }, socket);
            }
        } catch (err) {
            console.error(err);
            console.error(message.toString());
        }
    });

    socket.on("close", () => {
        global.sockets = global.sockets.filter(x => x.internalId !== socket.internalId);
    });
});

setInterval(() => {
    global.sockets.forEach(socket => {
        socket.timeSinceLastPing++;
        if (socket.timeSinceLastPing > 30) {
            socket.close();
        }
    });
}, 1000);

app.get("/shop.lua", (req, res) => {
    fs.readFile(path.join(__dirname, 'public', 'shop.lua'), "utf8", function(err, data) {
        if (err) {
            res.sendStatus(404);
        } else {
            let kristDomain = config.domains.krist;
            let appDomain = config.domains.app;

            if (req.query.hasOwnProperty("kristDomain")) {
                kristDomain = req.query.kristDomain;
            }
            if (req.query.hasOwnProperty("appDomain")) {
                appDomain = req.query.appDomain;
            }
            
            const genKey = (retryNum = 0) => {
                if (retryNum >= 3) {
                    res.status(500);
                    res.send("too many tries generating token")
                    return;
                }
                let id = con.generateRandomString(8).toUpperCase();
                let key = con.generateRandomString(64);
                con.query("select id from shop where `id` = ? or `key` = ?;", [id, key], (err, result) => {
                    if (err || result.length > 0) {
                        console.error(err);
                        genKey(retryNum + 1)
                        return;
                    }
                    con.query("insert into shop (`id`, `key`) values (?, ?);", [id, key], err => {
                        if (err) {
                            console.error(err);
                            res.status(500);
                            res.send("unable to add token")
                        } else {
                            res.setHeader("content-type", "text/plain");
                            res.cookie("key", key);
                            data = 
                                `local KRIST_DOMAIN = "${kristDomain}"\nlocal APP_DOMAIN = "${appDomain}"\nlocal ID = "${id}"\nlocal KEY = "${key}"\n`
                                + data;
                            res.send(data);
                        }
                    });
                });
            }
            
            if (req.cookies?.key || req.query?.key) {
                let key;
                if (req.cookies?.key) {
                    key = req.cookies.key;
                } else {
                    key = req.query.key;
                }
                
                con.query("select id from shop where `key` = ?;", [key], (err, result) => {
                    if (!err && result.length > 0) {
                        res.setHeader("content-type", "text/plain");
                        data = 
                            `local KRIST_DOMAIN = "${kristDomain}"\nlocal APP_DOMAIN = "${appDomain}"\nlocal ID = "${result[0].id}"\nlocal KEY = "${key}"\n`
                            + data;
                        res.send(data);
                        return;
                    }
                    genKey();
                });
            } else {
                genKey();
            }
        }
    });
})

app.use("/", require("./shortlinks"));
app.use("/", require("./shop"));
require("./controllers/")(app);

app.use(express.static(__dirname + "/node_modules/bootstrap/dist"));
app.use("/js", express.static(__dirname + "/node_modules/jquery/dist"));
app.use(express.static("public", {extensions: ["html"]}));

const server = app.listen(config.port);

server.on("upgrade", (request, socket, head) => {
    let key = request.url;

    const failAuth = () => {
        socket.write('HTTP/1.1 401 Web Socket Protocol Handshake\r\n' +
                     'Upgrade: WebSocket\r\n' +
                     'Connection: Upgrade\r\n' +
                     '\r\n');
        socket.destroy();
    }

    if (key) {
        key = key.replace("/", "");
        con.query("select * from shop where `key` = ?;", [key], (err, result) => {
            if (err) {
                console.error(err)
                failAuth();
                return;
            }
    
            if (result.length > 0) {
                wsServer.handleUpgrade(request, socket, head, socket => {
                    socket.id = result[0].id;
                    socket.key = result[0].key;

                    con.query("update shop set used = now() where id = ?;", [socket.id], err => err ? console.error(err) : "");
                
                    wsServer.emit("connection", socket, request);
                });
            } else failAuth();
        });
    } else failAuth();
});

require("./removeOldKeys");

console.log("Started Express webserver on " + config.port);