local KRIST_DOMAIN = "krist.dev"

local RETRY_INTERVAL = 3
local MAX_RETRIES = 3
local nextId = 1

--[[
    krist.lua by Twijn
]]

local KristAPI = {
    version="1.0.0",
    author="Twijn"
}

local sha256 = require("sha256")
local ue = textutils.urlEncode

local function kassert(parameters, expected)
    for i,v in pairs(parameters) do
        if not expected[i] then
            error("missing expected rules for parameter " .. i)
        end
        if expected[i].type and type(v) ~= expected[i].type then
            error("unexpected type for '"..expected[i].name.."' ("..i.."): expected "..expected[i].type..", got " ..type(v))
        end
    end
end

local function get(_, uri)
    local resp,err = http.get("https://".._.domain.."/"..uri)
    if not resp then error(err) end
    local json = textutils.unserializeJSON(resp.readAll())
    return json
end

local function post(_, uri, body)
    print(body)
    local resp,err = http.post("https://".._.domain.."/"..uri, body)
    if not resp then error(err) end
    local json = textutils.unserializeJSON(resp.readAll())
    return json
end

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
        os.queueEvent("k_ready")

        return arg
    else
        if retryCount < maxRetries then
            os.queueEvent("k_retry")
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
                        os.queueEvent("k_websocket_reply", json.id, json)
                    end
                end
            elseif e == "websocket_closed" then
                os.queueEvent("k_closed")
                
                _.ws = _:connect()
            end
        end
    end
end

-- This handles events registered by #.on()
local function relay(_)
    while true do
        local e, arg1, arg2, arg3, arg4, arg5, arg6, arg7 = os.pullEvent()

        e = e:gsub("k_", "")

        if _.listeners[e] then
            for i,v in pairs(_.listeners[e]) do
                local status, err = pcall(function() v(arg1, arg2, arg3, arg4, arg5, arg6, arg7) end)
                if not status then error(err) end --  handle errors better than this later
            end
        end
    end
end

function KristAPI.new(domain)
    local _ = {
        privateKey = nil,
        domain = domain or KRIST_DOMAIN,
        listeners = {}
    }
    
    _.address = {
        get = function(address, fetchNames)
            fetchNames = fetchNames or false
            kassert({address, fetchNames}, {{name="address", type="string"}, {name="fetchNames", type="boolean"}})
            if fetchNames then fetchNames = "?fetchNames" else fetchNames = "" end
            local resp = get(_, "addresses/"..ue(address)..fetchNames)
            return resp
        end,
        list = function(limit, offset)
            limit = limit or 50
            offset = offset or 0
            kassert({limit, offset}, {{name="limit", type="number"}, {name="offset", type="number"}})
            local resp = get(_, "addresses?limit="..tostring(limit).."&offset="..tostring(offset))
            return resp
        end,
        listRich = function(limit, offset)
            limit = limit or 50
            offset = offset or 0
            kassert({limit, offset}, {{name="limit", type="number"}, {name="offset", type="number"}})
            local resp = get(_, "addresses/rich?limit="..tostring(limit).."&offset="..tostring(offset))
            return resp
        end,
        names = function(address, limit, offset)
            limit = limit or 50
            offset = offset or 0
            kassert({address, limit, offset}, {{name="address", type="string"}, {name="limit", type="number"}, {name="offset", type="number"}})
            local resp = get(_, "addresses/"..textutils.urlEncode(address).."/names?limit="..tostring(limit).."&offset="..tostring(offset))
            return resp
        end,
    }
    
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
            e, r_id, msg = os.pullEvent("k_websocket_reply")
        until msg.id == r_id

        return msg
    end

    function _.login(privateKey, kristWallet)
        kristWallet = kristWallet or true
        if not _.ws then
            return false, "Not connected to websocket"
        end
        if kristWallet then
            privateKey = sha256("KRISTWALLET" .. privateKey) .. "-000"
        end
        _.privateKey = privateKey
        local reply = _.send("login", {privatekey = privateKey})
        if reply.ok and reply.address then _.loggedIn = reply.address end
        return reply.ok, reply
    end

    function _.me()
        if not _.ws then
            return false, "Not connected to websocket"
        end
        local reply = _.send("me")
        return reply.ok, reply
    end

    function _.subscribe(event)
        if not _.ws then
            return false, "Not connected to websocket"
        end
        local reply = _.send("subscribe", {event = event})
        return reply.ok, reply
    end

    function _.unsubscribe(event)
        if not _.ws then
            return false, "Not connected to websocket"
        end
        local reply = _.send("unsubscribe", {event = event})
        return reply.ok, reply
    end

    function _.connect(...)
        local url = nil

        local req = post(_, "ws/start", textutils.serializeJSON({privatekey = _.privateKey}))
        if req.ok then
            url = req.url
        else
            error("connection error: " ..req.error)
        end
        _.uri = url

        local args = {...}
        _.ws = connect(table.unpack(args))
    end

    function _.on(event, func)
        event = event:gsub("k_", "")
        if not _.listeners[event] then _.listeners[event] = {} end
        table.insert(_.listeners[event], func)
    end

    function _.listen()
        parallel.waitForAny(function() listen(_)end, function() relay(_)end)
    end

    return _
end

return KristAPI
