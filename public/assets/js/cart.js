let cart = {};

if (!localStorage) {
    alert("Local storage is required. You will experience bugs. Use a different browser if possible");
}

function saveCart() {
    localStorage.setItem("cart", JSON.stringify(cart))
}

let stringCart = localStorage.getItem("cart");
if (stringCart) {
    try {
        cart = JSON.parse(stringCart);
    } catch(err) {
        saveCart();
    }
} else {
    saveCart();
}


