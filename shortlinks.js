const express = require("express");
const router = express.Router();

const redirects = {
    discord: "docs/discord-integration",
};

for (const sl in redirects) {
    router.get("/" + sl, (req, res) => {
        res.redirect(redirects[sl]);
    });
}

module.exports = router;