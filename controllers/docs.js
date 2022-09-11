const express = require("express");
const router = express.Router();

router.get("/discord-integration", (req, res) => {
    res.render("pages/docs/discord-integration")
});

module.exports = router;