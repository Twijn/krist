let cart = {
    items: [],
};

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

function updateItem(name, nbt) {
    let itemRow = $(`#item-${name}-${nbt}`.replace(":","\\:"));
    let item = cart.items.find(x => x.shopId === shopId && x.name === name && x.nbt === nbt)

    if (item) {
        itemRow.find(".item-count").val(item.count);
    }

    if (item && item.count > 0) {
        itemRow.find(".add-item").hide();
        itemRow.find(".edit-item").show();
    } else {
        itemRow.find(".add-item").show();
        itemRow.find(".edit-item").hide();
    }
}

function removeFromCart(shopId, name, nbt, inc = 1) {
    let itemInCart = cart.items.find(x => x.shopId === shopId && x.name === name && x.nbt === nbt);
    if (!itemInCart) return;

    if (itemInCart.count > 1 && inc !== "all") {
        itemInCart.count -= inc;
    } else {
        cart.items = cart.items.filter(x => x.shopId !== shopId || x.name !== name || x.nbt !== nbt);
    }
    
    updateItem(name, nbt);
    saveCart();
}

function addToCart(shopId, name, nbt, displayName, stock, price, meta, inc = 1) {
    let itemInCart = cart.items.find(x => x.shopId === shopId && x.name === name && x.nbt === nbt);

    if (itemInCart) {
        itemInCart.count = Math.min(itemInCart.count + inc, stock);
    } else {
        if (inc === "all" || inc > stock) inc = stock;
        cart.items = [
            ...cart.items,
            {
                shopId: shopId,
                name: name,
                nbt: nbt,
                displayName: displayName,
                stock: stock,
                price: price,
                meta: meta,
                count: inc,
            }
        ];
    }

    updateItem(name, nbt);
    saveCart();
}

function setCount(shopId, name, nbt, displayName, stock, price, meta, count) {
    let itemInCart = cart.items.find(x => x.shopId === shopId && x.name === name && x.nbt === nbt);

    if (!itemInCart) {
        addToCart(shopId, name, nbt, displayName, stock, price, meta, count);
    } else {
        itemInCart.count = Math.min(Math.max(count, 0), stock);

        updateItem(name, nbt);
        saveCart();
    }
}

$(function() {
    cart.items.forEach(item => {
        let itemRow = $(`#item-${item.name}-${item.nbt}`.replace(":","\\:"));
        itemRow.find(".item-count").val(item.count);
        itemRow.find(".add-item").hide();
        itemRow.find(".edit-item").show();
    });
    
    $("button.item-add-cart").on("click", function() {
        let item = $(this).closest('tr[class="item"]');
        addToCart(shopId, item.attr("data-name"), item.attr("data-nbt"), item.attr("data-displayName"), Number(item.attr("data-stock")), Number(item.attr("data-price")), item.attr("data-meta"));
    });
    
    $("button.item-remove-cart").on("click", function() {
        let item = $(this).closest('tr[class="item"]');
        removeFromCart(shopId, item.attr("data-name"), item.attr("data-nbt"));
    });

    $("input.item-count").on("change", function() {
        let item = $(this).closest('tr[class="item"]');
        setCount(shopId, item.attr("data-name"), item.attr("data-nbt"), item.attr("data-displayName"), Number(item.attr("data-stock")), Number(item.attr("data-price")), item.attr("data-meta"), Number($(this).val()));
    });
});
