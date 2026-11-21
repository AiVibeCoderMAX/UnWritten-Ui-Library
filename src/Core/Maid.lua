local _ = ...

-- collects connections, instances, functions and objects; Clean releases them newest first
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(item)
    if item == nil then return item end
    table.insert(self._tasks, item)
    return item
end

local function release(item)
    local kind = typeof(item)
    if kind == "RBXScriptConnection" then
        item:Disconnect()
    elseif kind == "Instance" then
        item:Destroy()
    elseif kind == "function" then
        item()
    elseif kind == "thread" then
        pcall(task.cancel, item)
    elseif kind == "table" then
        if type(item.Disconnect) == "function" then
            item:Disconnect()
        elseif type(item.Clean) == "function" then
            item:Clean()
        elseif type(item.Destroy) == "function" then
            item:Destroy()
        end
    end
end

function Maid:Clean()
    local tasks = self._tasks
    self._tasks = {}
    for index = #tasks, 1, -1 do
        local ok, err = pcall(release, tasks[index])
        if not ok then warn("[UnWrittenUI] cleanup: " .. tostring(err)) end
    end
end

Maid.Destroy = Maid.Clean

return Maid
