const express = require("express");
const router = express.Router();
const con = require("./database");

router.get("/:id", (req, res, next) => {
    con.query("select id, name, server, kristName, kristAddress from shop where id = ?;", [req.params.id], async (err, result) => {
        if (err) console.error(err);

        if (result.length === 0) return next();

        let shop = result[0];

        const items = await con.pquery("select item.name, item.nbt, item.displayName, item.price, item.meta, item.count, dictionary.displayName as dictionaryName from item left join dictionary on item.shop_id = dictionary.shop_id and item.name = dictionary.name and item.nbt = dictionary.nbt where item.shop_id = ?;", [shop.id]);

        let shops = global.sockets.filter(x => x.id.toLowerCase() === shop.id.toLowerCase());
        shop.status = "offline";
        
        shops.forEach(socket => {
            if (socket.timeSinceLastPing <= 15) {
                shop.status = "active";
            } else if (shop.status === "offline") {
                shop.status = "inactive";
            }
        });

        res.render("pages/shop", {
            shop: shop,
            items: items,
        });
    });
});

module.exports = router;