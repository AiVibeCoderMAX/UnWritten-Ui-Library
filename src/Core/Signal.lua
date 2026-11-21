local _ = ...

-- synchronous signal; handlers run in connect order, errors are reported and do not stop the rest
local Signal = {}
Signal.__index = Signal

local function report(err)
    warn("[UnWrittenUI] signal handler: " .. tostring(err))
end

function Signal.new()
    return setmetatable({ _handlers = {}, _firing = 0 }, Signal)
end

function Signal:Connect(fn)
    local handler = { fn = fn, live = true }
    table.insert(self._handlers, handler)
    local handlers = self._handlers
    local connection = { Connected = true }
    function connection:Disconnect()
        if not handler.live then return end
        handler.live = false
        self.Connected = false
        if handlers._firing == nil or handlers._firing == 0 then
            local index = table.find(handlers, handler)
            if index then table.remove(handlers, index) end
        else
            -- removed on the next fire so iterating handlers stays safe
            handler.dead = true
        end
    end
    return connection
end

function Signal:Once(fn)
    local connection
    connection = self:Connect(function(...)
        connection:Disconnect()
        fn(...)
    end)
    return connection
end

function Signal:Fire(...)
    local handlers = self._handlers
    for _, handler in handlers do
        if handler.live then
            local ok, err = pcall(handler.fn, ...)
            if not ok then report(err) end
        end
    end
    if self._firing > 0 then return end
    -- sweep dead handlers once the outermost fire is done
    for index = #handlers, 1, -1 do
        if handlers[index].dead then table.remove(handlers, index) end
    end
end

function Signal:DisconnectAll()
    for _, handler in self._handlers do handler.live = false end
    table.clear(self._handlers)
end

Signal.Destroy = Signal.DisconnectAll

return Signal
