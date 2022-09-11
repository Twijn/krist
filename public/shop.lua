
-- KRIST_DOMAIN, APP_DOMAIN, ID, and KEY should prefill above
-- If it hasn't, get a new shop file from https://krist.store/shop.lua

local appHTTP = "https://"
local appWS = "wss://"

local config = {
    shop = {
        name = "Krist.Store Shopfront",
        server = "Singleplayer",
    },
    krist = {
        privateKey = "<krist priv key>",
        kristWallet = true,
        address = "",
        name = "",
    },
    monitor = {
        scale = 0.9,
        columns = {
            {
                name = "displayName",
                displayName = "Name",
                minWidth = 10,
                maxWidth = 30,
                align = "left",
            },
            {
                name = "count",
                displayName = "Stock",
                minWidth = 5,
                maxWidth = 10,
                align = "right",
                rowSuffix = "x",
            },
            {
                name = "price",
                displayName = "Price",
                minWidth = 8,
                maxWidth = 15,
                align = "right",
                rowSuffix = "kst/ea",
            },
            {
                name = "meta",
                displayName = "Address",
                minWidth = 10,
                maxWidth = 30,
                align = "right",
                rowSuffix = "@{{name}}",
            }
        },
    },
    discord = {
        key = "<join https://cc-d.twijn.dev/discord and use /token create>",
        admin = "<user ID>",
    },
    forSale = {},
    reserved = {
        chests = {},
        items = {},
    },
}
local items = {}


local configName = "shop.conf"
local itemsName = ".items"
local function saveConfig()
    local f = fs.open(configName, "w")
    f.write(textutils.serialize(config))
    f.close()
end

local function saveItems()
    local f = fs.open(itemsName, "w")
    f.write(textutils.serialize(items))
    f.close()
end

if not (KRIST_DOMAIN and APP_DOMAIN and ID and KEY) then
    error("missing required prefill. please reinstall from https://krist.twijn.dev/shop.lua")
end

if fs.exists(configName) then
    local f = fs.open(configName,"r")
    config = textutils.unserialize(f.readAll())
    f.close()
else
    saveConfig()
end

if fs.exists(itemsName) then
    local f = fs.open(itemsName,"r")
    items = textutils.unserialize(f.readAll())
    f.close()
end

if APP_DOMAIN:find("localhost") or APP_DOMAIN:find("127.0.0.1") then
    appHTTP = "http://"
    appWS = "ws://"
end

if not fs.exists("sha256.lua") then
    shell.run("wget", appHTTP..APP_DOMAIN.."/sha256.lua")
end

if not fs.exists("krist.lua") then
    shell.run("wget", appHTTP..APP_DOMAIN.."/krist.lua")
end

if not fs.exists("kstore.lua") then
    shell.run("wget", appHTTP..APP_DOMAIN.."/kstore.lua")
end

local function drawCenter(text)
    local w,h = term.getSize()
    local curX, curY = term.getCursorPos()
    term.setCursorPos(math.max(1, math.floor((w/2) - (#text/2))), curY)
    term.write(text)
end

local function middle(offset)
    offset = offset or 0
    local w,h = term.getSize()
    term.setCursorPos(1,math.floor(h/2) + offset)
end

function table.contains(table, element)
    for i,v in pairs(table) do
        if v == element then return true end
    end
    return false
end

local formValidate = {
    snowflake = {
        name = "snowflake",
        allowedChars = {"0","1","2","3","4","5","6","7","8","9"},
        error = "snowflake required",
        func = function(x)
            return type(x) == "string" and not (x == "" or x:find("%D"))
        end
    },
    positiveInteger = {
        name = "+integer",
        allowedChars = {"0","1","2","3","4","5","6","7","8","9"},
        error = "positive integer required",
        func = function(x)
            return type(x) == "string" and not (x == "" or x:find("%D")) and tonumber(x) > 0
        end
    },
    integer = {
        name = "integer",
        allowedChars = {"-","0","1","2","3","4","5","6","7","8","9"},
        error = "integer required",
        func = function(x)
            return type(x) == "string" and not (x == "" or x:find("%D"))
        end,
    },
    positiveNumber = {
        name = "+number",
        allowedChars = {".","0","1","2","3","4","5","6","7","8","9"},
        error = "positive number required",
        func = function(x)
            return type(x) == "string" and  tonumber(x) ~= nil and tonumber(x) > 0
        end,
    },
    number = {
        name = "number",
        allowedChars = {".","-","0","1","2","3","4","5","6","7","8","9"},
        error = "number required",
        func = function(x)
            return type(x) == "string" and  tonumber(x) ~= nil
        end,
    },
    required = {
        name = "required",
        error = "value required",
        func = function(x)
            return type(x) == "string" and #x > 0
        end
    },
    boolean = {
        name = "boolean",
        error = "boolean required",
        func = function(x)
            return x:lower() == "true" or x:lower() == "false"
        end
    },
    exactLength = function(length)
        return {
            name = "exactlength-"..length,
            error = length.." chars required",
            func = function(x)
                return #x == length
            end
        }
    end,
    rangeLength = function(min,max)
        return {
            name = "range-"..min.."-"..max,
            error = min.."-"..max.." chars",
            func = function(x)
                return #x >= min and #x <= max
            end
        }
    end,
    meta = {
        name = "meta",
        error = "unique meta required",
        func = function(x)
            for i,v in pairs(config.forSale)do
                if v.meta == x then return false end
            end
            return true
        end
    },
}

--[[
    layout example
    {
        label = "Display Label",
        name = "internalName",
        validate = validate option from above,
        default = "optional default value",
    }
]]
local function form(layout, title)
    local w,h = term.getSize()
    local selected = 1
    local data = {}
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    term.setCursorBlink(true)

    for i,v in pairs(layout) do
        if v.default then
            data[v.name] = v.default
        end
    end

    while true do
        local lineNum = 1
        local offset = 0
        if title then offset = offset + 1 end
        for i,v in pairs(layout) do
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.setCursorPos(2,((lineNum - 1) * 3) + offset + 2)
            term.clearLine()
            term.write(v.label)
            if v.showError then
                term.setTextColor(colors.red)
                term.write(" "..v.validate.error)
                v.showError = false
            end
            term.setBackgroundColor(colors.white)
            term.setTextColor(colors.black)
            term.setCursorPos(2,((lineNum - 1) * 3) + offset + 3)
            if data[layout[lineNum].name] then
                term.write(data[layout[lineNum].name] .. string.rep(" ", w-2-#data[layout[lineNum].name]))
            else
                term.write(string.rep(" ", w-2))
            end
            lineNum = lineNum + 1
        end
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)

        term.setCursorPos(1,h)
        term.clearLine()
        term.write("Use up/down to move, enter to continue")

        if title then
            term.setCursorPos(1,1)
            term.clearLine()
            drawCenter(title)
        end

        term.setBackgroundColor(colors.lightGray)
        term.setTextColor(colors.black)
        term.setCursorBlink(true)
        local selectedX = 2
        if data[layout[selected].name] then
            selectedX = selectedX + #data[layout[selected].name]
        end
        term.setCursorPos(selectedX, ((selected - 1) * 3) + offset + 3)

        while true do
            local e,key = os.pullEvent()
            
            if e == "key" then
                if key == keys.up then
                    selected = math.max(selected - 1, 1)
                    break
                elseif key == keys.down or key == keys.tab then
                    selected = math.min(selected + 1, #layout)
                    break
                elseif key == keys.enter then
                    local success = true
                    for i,v in pairs(layout) do
                        if v.validate and not v.validate.func(data[v.name]) then
                            v.showError = true
                            success = false
                        end
                    end
                    if success then
                        for i,v in pairs(layout) do
                            if v.validate and (v.validate.name == "number" or v.validate.name == "+number" or v.validate.name == "integer" or v.validate.name == "+integer") then
                                data[v.name] = tonumber(data[v.name])
                            end
                        end
                        term.setBackgroundColor(colors.black)
                        term.setTextColor(colors.white)
                        term.clear()
                        term.setCursorPos(1,1)
                        term.setCursorBlink(false)
                        return data
                    else break end
                elseif key == keys.backspace then
                    if not data[layout[selected].name] then data[layout[selected].name] = "" end
                    if #data[layout[selected].name] > 0 then
                        data[layout[selected].name] = data[layout[selected].name]:sub(1,#data[layout[selected].name]-1)
                
                        term.setBackgroundColor(colors.white)
                        term.setTextColor(colors.black)
                        term.setCursorPos(2,((selected - 1) * 3) + offset + 3)
                        term.write(data[layout[selected].name] .. string.rep(" ", w-2-#data[layout[selected].name]))
                        term.setCursorPos(2+#data[layout[selected].name],((selected - 1) * 3) + offset + 3)
                    end
                end
            elseif e == "char" then
                if not layout[selected].validate or not layout[selected].validate.allowedChars or table.contains(layout[selected].validate.allowedChars, key) then
                    if not data[layout[selected].name] then data[layout[selected].name] = "" end
                    data[layout[selected].name] = data[layout[selected].name]..key
                    
                    term.setBackgroundColor(colors.white)
                    term.setTextColor(colors.black)
                    term.setCursorPos(2,((selected - 1) * 3) + offset + 3)
                    term.write(data[layout[selected].name] .. string.rep(" ", w-2-#data[layout[selected].name]))
                    term.setCursorPos(2+#data[layout[selected].name],((selected - 1) * 3) + offset + 3)
                end
            end
        end
    end
end

local function selectMenu(list, title)
    local w,h = term.getSize()
    local selected = 1
    local currentlySelected = nil
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    while true do
        local lineNum = 1
        local offset = 0
        if #list > h - 2 and selected > math.floor(h/2) then
            offset = math.max(math.floor(h/2) - selected, h-#list-1)
        end
        if title then offset = offset + 1 end
        for i,v in pairs(list) do
            if lineNum == selected then
                currentlySelected = v
                term.setBackgroundColor(colors.lightGray)
                term.setTextColor(colors.black)
            else
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.white)
            end
            term.setCursorPos(2,lineNum + offset)
            term.clearLine()
            if type(v) == "table" then
                term.write(v.name)
                if v.alignRight then
                    term.setCursorPos(w - #v.alignRight - 1, lineNum + offset)
                    term.write(v.alignRight)
                end
            else
                term.write(v)
            end
            lineNum = lineNum + 1
        end
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)

        term.setCursorPos(1,h)
        term.clearLine()
        term.write("Use up/down to move, enter to select")

        if title then
            term.setCursorPos(1,1)
            term.clearLine()
            drawCenter(title)
        end

        local e,key = os.pullEvent("key")
        
        if key == keys.up then
            selected = math.max(selected - 1, 1)
        elseif key == keys.down then
            selected = math.min(selected + 1, #list)
        elseif key == keys.enter then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.clear()
            term.setCursorPos(1,1)
            if type(currentlySelected) == "table" then
                return currentlySelected.value
            else
                return currentlySelected
            end
        end
    end
end

local function itemScan()
    local scan = {}
    for i,v in pairs(items) do
        v.count = 0
        scan[i] = v
    end
    for _, per in pairs(peripheral.getNames())do
        local types = {peripheral.getType(per)}
        
        if table.contains(types, "inventory") then
            local inventory = peripheral.wrap(per)
            for slot,item in pairs(inventory.list())do
                local id = item.name
                if item.nbt then
                    id = id .. "-" .. item.nbt
                end
                if scan[id] then
                    scan[id].count = scan[id].count + item.count
                else
                    scan[id] = inventory.getItemDetail(slot)
                end
            end
        end
    end
    items = scan
    return scan
end

-- Monitor methods

-- Thanks to http://lua-users.org/wiki/CopyTable for this code!
local function deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
            end
            setmetatable(copy, deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local ITEM_TABLE_OFFSET = {
    x = 2,
    y = 5,
}

local hasMonitor = false
local monitors = {}
local mon = {
    setCursorPosMiddle = function(offset)
        offset = offset or 0
        for i, cmon in pairs(monitors) do
            local w,h = cmon.getSize()
            cmon.setCursorPos(1, math.floor(h/2) + offset)
        end
    end,
    setCursorPosLastLine = function(offset)
        offset = offset or 0
        for i, cmon in pairs(monitors) do
            local w,h = cmon.getSize()
            cmon.setCursorPos(1, h + offset)
        end
    end,
    setCursorPosLastChar = function(offset)
        offset = offset or 0
        for i,cmon in pairs(monitors) do
            local w,h = cmon.getSize()
            local curX, curY = cmon.getCursorPos()
            cmon.setCursorPos(w + offset, curY)
        end
    end,
    center = function(text)
        for i, cmon in pairs(monitors) do
            local w,h = cmon.getSize()
            local curX, curY = cmon.getCursorPos()
            cmon.setCursorPos(math.max(1, math.floor((w/2)-(#text/2))), curY)
            cmon.write(text)
        end
    end,
    loading = function(mon, textColor, backgroundColor, text)
        if hasMonitor then
            mon.setTextScale(config.monitor.scale)
            mon.setTextColor(textColor)
            mon.setBackgroundColor(backgroundColor)
            mon.clear()
            mon.setCursorPosMiddle(-1)
            mon.center(text)
        end
    end,
    updateLoading = function(mon, text)
        if hasMonitor then
            mon.setCursorPosMiddle(1)
            mon.clearLine()
            mon.center(text)
        end
    end,
    firstDraw = function()
        for i, cmon in pairs(monitors) do
            local w,h = cmon.getSize()
            cmon.setBackgroundColor(colors.lightGray)
            for i = 4, h - 1 do
                cmon.setCursorPos(1,i)
                cmon.clearLine()
            end
        end
    end,
    drawHeader = function(mon)
        if not hasMonitor then return end

        mon.setTextColor(colors.white)
        mon.setBackgroundColor(colors.blue)
        for i = 1,3 do
            mon.setCursorPos(1,i)
            mon.clearLine()
        end
        mon.setCursorPos(1,2)
        mon.center(config.shop.name)
    end,
    drawFooter = function(mon)
        if not hasMonitor then return end

        mon.setTextColor(colors.white)
        mon.setBackgroundColor(colors.blue)
        mon.setCursorPosLastLine()
        mon.clearLine()
        mon.center(appHTTP .. APP_DOMAIN .. "/" .. ID:lower())
    end,
    drawItems = function()
        if not hasMonitor then return end

        local columns = deepcopy(config.monitor.columns)

        -- generate initial width values based on header, min & max widths
        for colNum, col in pairs(columns) do
            col.width = #col.displayName
            if col.minWidth then col.width = math.max(col.width, col.minWidth) end
            if col.maxWidth then col.width = math.min(col.width, col.maxWidth) end
        end

        -- recognize each column width based on row data & form basic rows table
        local rows = {}
        for i,saleItem in pairs(config.forSale)do
            local row = {}
            for colNum, col in pairs(columns)do
                local value = saleItem[col.name]
                if not value then value = items[i][col.name] end
                value = tostring(value)
                if col.rowSuffix then
                    value = value .. col.rowSuffix:gsub("{{name}}", config.krist.name)
                end
                if value then
                    if #value > col.width then
                        col.width = #value
                        if col.minWidth then col.width = math.max(col.width, col.minWidth) end
                        if col.maxWidth then col.width = math.min(col.width, col.maxWidth) end
                    end
                end
                table.insert(row, value)
            end
            table.insert(rows, row)
        end

        local initialTableWidth = #columns + 1
        for colNum, col in pairs(columns) do initialTableWidth = initialTableWidth + col.width end

        for i, mon in pairs(monitors) do
            -- Generate new columns table to create specific widths for each monitor
            local monitorColumns = deepcopy(columns)

            local x,y = mon.getSize()

            local maxTableWidth = x - 2

            if x < 50 then
                -- TODO: actually do something for monitors < 50
                mon.setCursorPos(1,1)
                mon.clear()
                mon.write("no")
            else
                for colNum, col in pairs(monitorColumns) do
                    -- this creates a ratio comparing initial table width to the maximum table width
                    col.width = math.floor(col.width / initialTableWidth * maxTableWidth)
                    
                    -- ensure min and maxes are still recognized
                    if col.minWidth then col.width = math.max(col.width, col.minWidth) end
                    if col.maxWidth then col.width = math.min(col.width, col.maxWidth) end
                end
                
                mon.setBackgroundColor(colors.gray)
                mon.setTextColor(colors.white)
                mon.setCursorPos(ITEM_TABLE_OFFSET.x,ITEM_TABLE_OFFSET.y)
                
                -- determine table length
                local tableWidth = #monitorColumns + 1
                for colNum, col in pairs(monitorColumns) do tableWidth = tableWidth + col.width end
    
                -- determine max & current table width difference and apply to first column
                local diff = maxTableWidth - tableWidth
                monitorColumns[1].width = monitorColumns[1].width + diff
                tableWidth = tableWidth + diff
        
                mon.write(string.rep(" ", tableWidth))
                
                mon.setCursorPos(ITEM_TABLE_OFFSET.x,ITEM_TABLE_OFFSET.y + 1)
                for colNum, col in pairs(monitorColumns) do
                    col.displayName = col.displayName:sub(1, col.width)
                    if col.align and col.align == "right" then
                        mon.write(string.rep(" ", col.width - #col.displayName + 1) .. col.displayName)
                    else
                        mon.write(" " .. col.displayName .. string.rep(" ", col.width - #col.displayName))
                    end
                end
                mon.write(" ")
                mon.setCursorPos(ITEM_TABLE_OFFSET.x,ITEM_TABLE_OFFSET.y + 2)
                mon.write(string.rep(" ", tableWidth))
                mon.setBackgroundColor(colors.white)
                mon.setTextColor(colors.black)
                for rowNum, rowColumns in pairs(rows)do
                    mon.setCursorPos(ITEM_TABLE_OFFSET.x,ITEM_TABLE_OFFSET.y + 2 + rowNum)
                    for colNum, value in pairs(rowColumns) do
                        local col = monitorColumns[colNum]
                        value = value:sub(1, col.width)
                        if col.align and col.align == "right" then
                            mon.write(string.rep(" ", col.width - #value + 1) .. value)
                        else
                            mon.write(" " .. value .. string.rep(" ", col.width - #value))
                        end
                    end
                    mon.write(" ")
                end
    
                local curX, curY = mon.getCursorPos()
                for i = curX, y do
                    mon.setCursorPos(1,i)
                    mon.clearLine()
                end
            end
        end
    end,
}

for i,v in pairs(peripheral.getNames()) do
    if peripheral.getType(v) == "monitor" then
        hasMonitor = true
        monitors[v] = peripheral.wrap(v)

        for _i, method in pairs(peripheral.getMethods(v)) do
            mon[method] = function(...)
                local args = {...}
                for __i, cmon in pairs(monitors) do
                    cmon[method](table.unpack(args))
                end
            end
        end
    end
end

mon:loading(colors.white, colors.blue, config.shop.name.." is starting up...")

local function waitForTransaction()
    while true do
        print(os.pullEvent("event"))
    end
end

local krist = require("krist")
local kstore = require("kstore")
local ccd -- CC-D is ONLY initialized if requested

local PRIVATE_KEY = config.krist.privateKey
if PRIVATE_KEY == "<krist priv key>" or #PRIVATE_KEY == 0 then PRIVATE_KEY = nil end

local k = krist.new(KRIST_DOMAIN)
local e = kstore.new(KEY, APP_DOMAIN, appWS)
local d

local function sendAdminNotification(message)
    if d then
        if type(config.discord.admin) == "string" then
            d.users.send(config.discord.admin, message)
        elseif type(config.discord.admin) == "table" and config.discord.admin.channel and config.discord.admin.guild then
            d.channels.send(config.discord.admin.guild, config.discord.admin.channel, message)
        end
    end
end

local listenFunctions = {function() while true do itemScan() saveItems() sleep(30) end end, function() k:connect() k.listen() end, function() sleep(2)e:connect()e.listen() end, waitForTransaction}

local kstoreReady = false
local kristReady = false
local ccdReady = false

local function updateItems()
    local itemsForSale = {}
    local itemDictionary = {}
    for i, item in pairs(config.forSale) do
        table.insert(itemsForSale, {
            name = items[i].name,
            nbt = items[i].nbt,
            displayName = item.displayName,
            price = item.price,
            meta = item.meta,
            count = items[i].count,
        })
    end

    for i, item in pairs(items) do
        table.insert(itemDictionary, {
            name = item.name,
            nbt = item.nbt,
            displayName = item.displayName,
        })
    end

    local succ, obj = e.updateForSaleItems(itemsForSale)
    if not succ then print(obj.error) sleep(3) end
    succ, obj = e.updateItemDictionary(itemDictionary)
    if not succ then print(obj.error) sleep(3) end
end

k.on("e_ready", function()
    print("kStore API ready")

    local success, obj = e.updateShopInfo(config.shop.name, config.shop.server, config.krist.name, config.krist.address)

    if not success then print(obj.error) sleep(3) end

    kstoreReady = true

    mon:updateLoading("Connection made to kStore API!")
end)

k.on("k_ready", function()
    local ok, me, err
    print("Krist API ready")
    if PRIVATE_KEY then
        print("Logging in to Krist")
        mon:updateLoading("Logging in to Krist")
        ok, me = k.login(PRIVATE_KEY, config.krist.kristWallet)
        if not ok then error("error retrieving self: " .. me) end
        print("Got Krist host account data!")
        if me.isGuest then
            mon:updateLoading("Logged in as a guest")
            print("Logged in as GUEST")
        else
            mon:updateLoading("Logged in as "..me.address.address)
            print("Logged in as " .. me.address.address .. " ("..me.address.balance..")")
            config.krist.address = me.address.address
            saveConfig()
        end
    else
        print("Logged in as GUEST")
    end
    if not config.krist.address or #config.krist.address == 0 then
        error("no Krist address was provided, and a private key was missing or failed. please provide a private key or Krist address in "..configName)
    end
    if not config.krist.name or #config.krist.name == 0 then
        local names = k.address.names(config.krist.address)
        if not names.ok then error("failed when retrieving names: " ..names.error) end

        local selectList = {}
        for i, name in pairs(names.names)do
            table.insert(selectList, name.name..".kst")
        end
        local name = selectMenu(selectList, "Select the krist domain to use")
        print("Selected " .. name .. " for shop use")
        config.krist.name = name
        saveConfig()
    end
    print("Subscribing to all transactions")
    ok, err = k.subscribe("transactions")
    if not ok then error("error subscribing to transactions: " .. err) end
    print("Subscribed!")
    kristReady = true

    mon:updateLoading("Connection made to Krist!")
end)
k.on("ccd_ready", function()
    print("CC:D API ready")
    ccdReady = true

    mon:updateLoading("Connection made to CC:D!")
end)

local function monitorRefresh()
    print("Waiting for all connections before starting monitor draw...")
    repeat sleep(0.25) until kstoreReady and kristReady and ((not d) or ccdReady)
    
    mon:firstDraw()
    mon:drawHeader()
    mon:drawFooter()

    itemScan()
    updateItems()

    while true do
        itemScan()
        mon:drawItems()
        sleep(10)
    end
end

local formLayouts = {
    newItem = function(displayName, name)
        local find = name:find(":")
        local meta = name:sub(find + 1):sub(1,3)
        return {
            {
                label = "Display Name",
                name = "displayName",
                validate = formValidate.required,
                default = displayName,
            },
            {
                label = "Meta Name",
                name = "meta",
                validate = formValidate.meta,
                default = meta,
            },
            {
                label = "Krist Price (per item)",
                name = "price",
                validate = formValidate.positiveNumber,
            },
        }
    end,
    editItem = function(displayName, meta, price)
        return {
            {
                label = "Display Name",
                name = "displayName",
                validate = formValidate.required,
                default = displayName,
            },
            {
                label = "Meta Name",
                name = "meta",
                validate = formValidate.meta,
                default = meta,
            },
            {
                label = "Krist Price (per item)",
                name = "price",
                validate = formValidate.positiveNumber,
                default = price,
            },
        }
    end,
    settings = {
        shopData = function(name, server)
            return {
                {
                    label = "Shop Name",
                    name = "name",
                    validate = formValidate.required,
                    default = name,
                },
                {
                    label = "Server Name",
                    name = "server",
                    validate = formValidate.required,
                    default = server,
                },
            }
        end,
        kristData = function(address, name, kristWallet)
            return {
                {
                    label = "Private Key (blank = no change)",
                    name = "privateKey",
                },
                {
                    label = "Address",
                    name = "address",
                    validate = formValidate.required,
                    default = address,
                },
                {
                    label = "Name",
                    name = "name",
                    validate = formValidate.required,
                    default = name,
                },
            }
        end,
        discord = {
            token = function()
                return {
                    {
                        label = "CC:D Token",
                        name = "key",
                    },
                }
            end,
            channel = function(guild, channel)
                return {
                    {
                        label = "Discord Guild ID",
                        name = "guild",
                        validate = formValidate.snowflake,
                        default = guild,
                    },
                    {
                        label = "Discord Channel ID",
                        name = "channel",
                        validate = formValidate.snowflake,
                        default = channel,
                    },
                }
            end,
            user = function(user)
                return {
                    {
                        label = "Discord User ID",
                        name = "admin",
                        validate = formValidate.snowflake,
                        default = user,
                    },
                }
            end,
        },
    },
}

local function confirmChange(setting)
    local selectMenu
    if setting then
        selectMenu = selectMenu({"Yes", "No"}, "Vital setting '".. setting .."' changed. Reboot?")
    else
        selectMenu = selectMenu({"Yes", "No"}, "Vital setting changed. Reboot?")
    end
    return selectMenu == "Yes"
end

local actions = {
    addItem = function()
        itemScan()
        local unknownItems = {"Cancel"}
        for meta,item in pairs(items)do
            if not config.forSale[meta] then
                table.insert(unknownItems, {
                    name = item.displayName,
                    value = meta,
                    alignRight = "[" .. item.count .. "]",
                })
            end
        end

        local itemName = selectMenu(unknownItems, "Select an item to add")
        if itemName ~= "Cancel" then
            local item = items[itemName]
            local info = form(formLayouts.newItem(item.displayName, item.name), "Adding new item: " .. item.displayName .. " ["..item.count.."]")
            config.forSale[itemName] = info
            saveConfig()
            term.clear()
            middle()
            drawCenter("Added " ..info.displayName)
            middle(1)
            drawCenter(info.meta .. "@" .. config.krist.name .. " at " .. info.price .. " kst/ea.")
            sleep(1)
            mon:drawItems()
            updateItems()
        end
    end,
    editItem = function()
        local currentItems = {"Cancel"}
        for meta,item in pairs(config.forSale)do
            if items[meta] then
                table.insert(currentItems, {
                    name = item.displayName,
                    value = meta,
                    alignRight = items[meta].count .. " @ " ..item.price .." kst/ea",
                })
            end
        end

        local itemName = selectMenu(currentItems, "Select an item to edit")
        if itemName ~= "Cancel" then
            local item = items[itemName]
            local saleItem = config.forSale[itemName]
            local oldMeta = saleItem.meta
            saleItem.meta = "__invalid"
            local info = form(formLayouts.editItem(saleItem.displayName, oldMeta, tostring(saleItem.price)), "Editing item: " .. item.displayName .. " ["..item.count.."]")
            config.forSale[itemName] = info
            saveConfig()
            term.clear()
            middle()
            drawCenter("Edited " ..info.displayName)
            middle(1)
            drawCenter(info.meta .. "@" .. config.krist.name .. " at " .. info.price .. " kst/ea.")
            sleep(1)
            mon:drawItems()
            updateItems()
        end
    end,
    removeItem = function()
        local currentItems = {"Cancel"}
        for meta,item in pairs(config.forSale)do
            if items[meta] then
                table.insert(currentItems, {
                    name = item.displayName,
                    value = meta,
                    alignRight = items[meta].count .. " @ " ..item.price .." kst/ea",
                })
            end
        end

        local itemName = selectMenu(currentItems, "Select an item to remove")
        if itemName ~= "Cancel" then
            local item = items[itemName]
            config.forSale[itemName] = nil
            saveConfig()
            term.clear()
            middle()
            drawCenter("Deleted " ..item.displayName)
            sleep(1)
            mon:drawItems()
            updateItems()
        end
    end,
    editSettings = function()
        local settings = {"Back", "Shop Settings", "Krist Settings", "CC:D Settings"}
        while true do
            local setting = selectMenu(settings, "Select a setting group to modify")

            if setting == "Shop Settings" then
                local formData = form(formLayouts.settings.shopData(config.shop.name, config.shop.server), "Edit Shop Data")
                config.shop.name = formData.name
                config.shop.server = formData.server
                saveConfig()
                local s, obj = e.updateShopInfo(config.shop.name, config.shop.server, config.krist.name, config.krist.address)
                if not s then
                    term.clear()
                    middle(-1)
                    drawCenter("Error occurred while posting shop data")
                    middle(1)
                    drawCenter(obj.error)
                end
                mon:drawHeader()
            elseif setting == "Krist Settings" then
                local formData = form(formLayouts.settings.kristData(config.krist.address, config.krist.name, config.krist.kristWallet), "Edit Krist Data")
                config.krist.address = formData.address
                config.krist.name = formData.name
                if formData.privateKey and #formData.privateKey > 0 then
                    local selectMenu = selectMenu({"Yes", "No"}, "Vital setting changed. Reboot?")
                    if selectMenu == "Yes" then
                        config.krist.privateKey = formData.privateKey
                        saveConfig()
                        os.reboot()
                    end
                end
                saveConfig()
                mon:drawHeader()
            elseif setting == "CC:D Settings" then
                local discordOptions = {"Back", "Edit CC:D Token", "Set Discord admin user", "Set Discord admin channel"}
                while true do
                    local discordOption = selectMenu(discordOptions, "Select a discord setting group")

                    if discordOption == "Edit CC:D Token" then
                        local token = form(formLayouts.settings.discord.token(), "Insert new CC:D Token")
                        if #token.key > 0 and token.key ~= config.discord.key then
                            if confirmChange("cc:d token") then
                                config.discord.key = token.key
                                saveConfig()
                                os.reboot()
                            end
                        end
                    elseif discordOption == "Set Discord admin user" then
                        local user = ""
                        if type(config.discord.admin) == "string" then user = config.discord.admin end

                        local user = form(formLayouts.settings.discord.user(user), "Insert Discord user ID")
                        if #user.admin > 0 and user.admin ~= config.discord.admin then
                            config.discord.admin = user.admin
                            saveConfig()
                        end
                    elseif discordOption == "Set Discord admin channel" then
                        local guild = ""
                        local channel = ""
                        if type(config.discord.admin) == "table" then
                            if config.discord.admin.guild then guild = config.discord.admin.guild end
                            if config.discord.admin.channel then channel = config.discord.admin.channel end
                        end

                        local user = form(formLayouts.settings.discord.channel(guild, channel), "Insert Discord channel ID & guild ID")
                        if #user.admin > 0 and user.admin ~= config.discord.admin then
                            config.discord.admin = user.admin
                            saveConfig()
                        end
                    else
                        break
                    end
                end
            else
                break
            end
        end
    end,
    refreshCache = function(reset)
        term.clear()
        middle()
        if reset then
            drawCenter("Resetting item cache...")
            items = {}
        else
            drawCenter("Refreshing item cache...")
        end
        itemScan()
        saveItems()
        mon:drawItems()
        term.clear()
        if reset then
            drawCenter("Reset item cache!")
        else
            drawCenter("Refreshed item cache!")
        end
        sleep(1)
        mon:drawItems()
    end,
}

local function terminalRefresh()
    print("Waiting for all connections before starting terminal draw...")
    repeat sleep(.25) until kstoreReady and kristReady and ((not d) or ccdReady)
    
    while true do
        local selection = selectMenu({
            "Add an Item",
            "Edit an Item",
            "Remove an Item",
            "Edit Settings",
            "Refresh Item Cache",
            "Reset Item Cache",
        }, config.shop.name .. " : Admin Panel")

        if selection == "Add an Item" then
            actions.addItem()
        elseif selection == "Edit an Item" then
            actions.editItem()
        elseif selection == "Remove an Item" then
            actions.removeItem()
        elseif selection == "Edit Settings" then
            actions.editSettings()
        elseif selection == "Refresh Item Cache" then
            actions.refreshCache(false)
        elseif selection == "Reset Item Cache" then
            actions.refreshCache(true)
        end
    end
end

if config.discord.key and config.discord.admin and #config.discord.key == 64 and ((type(config.discord.admin) == "string" and #config.discord.admin > 10) or (type(config.discord.admin) == "table" and config.discord.admin.channel and config.discord.admin.guild)) then
    mon:updateLoading("Installing CC:Discord Wrapper")
    if not fs.exists("cc-d.lua") then
        shell.run("wget https://cc-d.twijn.dev/lua/cc-d.lua cc-d.lua")
    end
    ccd = require("cc-d")
    d = ccd.new(config.discord.key)
    table.insert(listenFunctions, function() sleep(2)d:connect()d.listen() end)
end

mon:updateLoading("Making connections to required APIs")

if hasMonitor then
    table.insert(listenFunctions, monitorRefresh)
end
table.insert(listenFunctions, terminalRefresh)

parallel.waitForAll(table.unpack(listenFunctions))
