local EMBEDDED_DOMAIN = "krist.store"

local RETRY_INTERVAL = 3
local MAX_RETRIES = 3

local nextId = 1

--[[
    kstore.lua by Twijn
]]

local KStore = {
    version="1.0.0",
    author="Twijn"
}

local function connect(_, retryCount)
    local retryInterval = _.retryInterval or RETRY_INTERVAL
    local maxRetries = _.maxRetries or MAX_RETRIES
    retryCount = retryCount or 0

    local uri = _.uri

    http.websocketAsync(uri)

    local e, url, arg
    repeat
        e, url, arg = os.pullEvent()
    until url == uri and (e == "websocket_success" or e == "websocket_failure")

    if e == "websocket_success" then
        os.queueEvent("e_ready")

        return arg
    else
        if retryCount < maxRetries then
            os.queueEvent("e_retry")
            sleep(retryInterval)
            return connect(_, retryCount + 1)
        else
            error(arg)
        end
    end
end

local function listen(_)
    while true do
        local e, url, msg = os.pullEvent()
        
        if url == _.uri then
            if e == "websocket_message" then
                local json = textutils.unserializeJSON(msg)
                if json ~= nil then
                    if json.id then
                        os.queueEvent("e_websocket_reply", json.id, json)
                    end
                end
            elseif e == "websocket_closed" then
                os.queueEvent("e_closed")
                print("reconnecting")
                _.ws = _:connect()
            end
        end
    end
end

-- This handles events registered by #.on()
local function relay(_)
    while true do
        local e, arg1, arg2, arg3, arg4, arg5, arg6, arg7 = os.pullEvent()

        e = e:gsub("e_", "")

        if _.listeners[e] then
            for i,v in pairs(_.listeners[e]) do
                local status, err = pcall(function() v(arg1, arg2, arg3, arg4, arg5, arg6, arg7) end)
                if not status then error(err) end --  handle errors better than this later
            end
        end
    end
end

local function keepAlive(_)
    local json = textutils.serializeJSON({type="keepAlive"})
    while true do
        if not _.ws then repeat sleep(1) until _.ws end
        _.ws.send(json)
        sleep(15)
    end
end

function KStore.new(privateKey, domain, protocol)
    protocol = protocol or "wss://"
    local _ = {
        privateKey = privateKey or nil,
        domain = domain or EMBEDDED_DOMAIN,
        listeners = {}
    }
    _.uri = protocol.._.domain.."/"..privateKey

    function _.connect(...)
        local args = {...}
        _.ws = connect(table.unpack(args))
    end

    function _.on(event, func)
        event = event:gsub("e_", "")
        if not _.listeners[event] then _.listeners[event] = {} end
        table.insert(_.listeners[event], func)
    end
    
    function _.send(msgType, msg)
        msg = msg or {}
        if not _.ws then
            repeat sleep(1) until _.ws
        end

        msg.type = msgType
        msg.id = nextId
        nextId = nextId + 1

        _.ws.send(textutils.serializeJSON(msg))

        local e, r_id, msg
        repeat
            e, r_id, msg = os.pullEvent("e_websocket_reply")
        until msg.id == r_id

        return msg
    end

    function _.listen()
        parallel.waitForAny(function() listen(_)end, function() relay(_)end, function() keepAlive(_)end)
    end

    function _.updateShopInfo(name, server, kristName, kristAddress, map, x, y, z)
        -- If one set of values is invalid, disregard all of them
        if x == nil or y == nil or z == nil then
            map = nil
            x = nil
            y = nil
            z = nil
        end
        local resp = _.send("shopInfo", {name = name, server = server, kristName = kristName, kristAddress = kristAddress, map = map, x = x, y = y, z = z})
        return resp.ok, resp
    end

    function _.updateItemDictionary(items)
        local resp = _.send("itemDictionary", {items = items})
        return resp.ok, resp
    end

    function _.updateForSaleItems(items)
        local resp = _.send("itemsForSale", {items = items})
        return resp.ok, resp
    end

    return _
end

return KStore
