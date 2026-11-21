local import = ...
local Services = import("Core/Services")

-- executor file api; everything degrades to no-ops when it is missing
local Storage = {}

Storage.Available = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
    and type(makefolder) == "function" and type(isfolder) == "function"

local writefile = writefile
local readfile = readfile
local isfile = isfile
local isfolder = isfolder
local makefolder = makefolder
local delfile = delfile
local listfiles = listfiles

function Storage.Ensure(path)
    if not Storage.Available then return false end
    if path == "" or path == nil then return true end
    local built = ""
    for part in tostring(path):gmatch("[^/]+") do
        built = built == "" and part or (built .. "/" .. part)
        if not isfolder(built) then pcall(makefolder, built) end
    end
    return true
end

function Storage.Read(path)
    if not Storage.Available then return nil end
    local ok, exists = pcall(isfile, path)
    if not ok or not exists then return nil end
    local read, content = pcall(readfile, path)
    if read and type(content) == "string" then return content end
    return nil
end

function Storage.Write(path, content)
    if not Storage.Available then return false end
    local folder = path:match("^(.*)/[^/]+$")
    if folder then Storage.Ensure(folder) end
    local ok, err = pcall(writefile, path, content)
    if not ok then warn("[UnWrittenUI] write " .. path .. ": " .. tostring(err)) end
    return ok
end

function Storage.Delete(path)
    if not Storage.Available or type(delfile) ~= "function" then return false end
    return (pcall(delfile, path))
end

function Storage.Exists(path)
    if not Storage.Available then return false end
    local ok, exists = pcall(isfile, path)
    return ok and exists
end

function Storage.IsFolder(path)
    if not Storage.Available then return false end
    local ok, exists = pcall(isfolder, path)
    return ok and exists
end

-- file names in folder with extension, without the extension
function Storage.List(folder, extension)
    if not Storage.Available or type(listfiles) ~= "function" then return {} end
    local ok, files = pcall(listfiles, folder)
    if not ok or type(files) ~= "table" then return {} end
    local out = {}
    for _, file in files do
        local name = tostring(file):gsub("\\", "/"):match("([^/]+)%." .. (extension or "json") .. "$")
        if name then table.insert(out, name) end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

function Storage.Encode(data)
    local ok, content = pcall(function() return Services.HttpService:JSONEncode(data) end)
    return ok and content or nil
end

function Storage.Decode(content)
    if type(content) ~= "string" then return nil end
    local ok, data = pcall(function() return Services.HttpService:JSONDecode(content) end)
    return ok and data or nil
end

function Storage.ReadJSON(path)
    local content = Storage.Read(path)
    if not content then return nil end
    return Storage.Decode(content)
end

function Storage.WriteJSON(path, data)
    local content = Storage.Encode(data)
    if not content then
        warn("[UnWrittenUI] could not encode " .. tostring(path))
        return false
    end
    return Storage.Write(path, content)
end

-- reads a file with the executor's `readfile`, or HttpGet for a url
function Storage.Fetch(source)
    if type(source) == "string" and source:match("^https?://") then
        if type(game.HttpGet) == "function" then
            local ok, body = pcall(function() return game:HttpGet(source) end)
            return ok and body or nil
        end
        return nil
    end
    return Storage.Read(source)
end

return Storage
