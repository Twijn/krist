while true do
    local e = {os.pullEvent()}

    if e[1] == "websocket_success" or  e[1] == "websocket_failure" then
        print(e[1], e[2])
    elseif e[1] == "websocket_message" then
        print(e[1], e[2], e[3])
    end
end