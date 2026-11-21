local import = ...
local Storage = import("Core/Storage")
local Signal = import("Core/Signal")

-- flag registry + named config files under <Folder>/configs. Import / export also work with a plain
-- json string, so a setup can be shared between users.
local Config = {}
Config.__index = Config

local INVALID = '[\\/:%*%?"<>|]'

function Config.new(folder)
    local self = setmetatable({
        Folder = folder,
        Dir = folder .. "/configs",
        Flags = {},
        Current = nil,
        AutoSave = false,
        Changed = Signal.new(),
        Loaded = Signal.new(),
        _loading = false,
        _saveQueued = false,
        _pending = {},
    }, Config)
    Storage.Ensure(self.Dir)
    return self
end

function Config.ValidName(name)
    if type(name) ~= "string" then return false, "Enter a name." end
    name = name:match("^%s*(.-)%s*$")
    if name == "" then return false, "Enter a name." end
    if #name > 48 then return false, "Name is too long." end
    if name:find(INVALID) then return false, "Name contains invalid characters." end
    return true, name
end

function Config:Register(flag, element)
    if self.Flags[flag] and self.Flags[flag] ~= element then
        warn("[UnWrittenUI] duplicate flag '" .. flag .. "', the newer element wins")
    end
    self.Flags[flag] = element
    -- a config was loaded before this element existed: apply its value now
    local value = self._pending[flag]
    if value ~= nil then
        self._loading = true
        pcall(element.Load, element, value)
        self._loading = false
        self._pending[flag] = nil
    end
end

function Config:Unregister(flag, element)
    if self.Flags[flag] == element then self.Flags[flag] = nil end
end

function Config:Snapshot()
    local flags = {}
    for flag, element in self.Flags do
        if not element.NoSave then
            local ok, value = pcall(element.Save, element)
            if ok and value ~= nil then
                flags[flag] = value
            elseif not ok then
                warn("[UnWrittenUI] save " .. flag .. ": " .. tostring(value))
            end
        end
    end
    return { Version = 1, Flags = flags }
end

function Config:Apply(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.Flags) ~= "table" then return false, "Invalid config data." end
    self._loading = true
    self._pending = {}
    for flag, value in snapshot.Flags do
        local element = self.Flags[flag]
        if element and not element.NoSave then
            local ok, err = pcall(element.Load, element, value)
            if not ok then warn("[UnWrittenUI] load " .. flag .. ": " .. tostring(err)) end
        else
            -- elements are often added after the config loads; keep the value for them
            self._pending[flag] = value
        end
    end
    self._loading = false
    self.Loaded:Fire(snapshot)
    return true
end

function Config:Path(name)
    return self.Dir .. "/" .. name .. ".json"
end

function Config:List()
    return Storage.List(self.Dir, "json")
end

function Config:Exists(name)
    return Storage.Exists(self:Path(name))
end

function Config:Save(name)
    local ok, clean = Config.ValidName(name or self.Current)
    if not ok then return false, clean end
    if not Storage.Available then return false, "File access is not supported by this executor." end
    if not Storage.WriteJSON(self:Path(clean), self:Snapshot()) then return false, "Could not write the file." end
    self.Current = clean
    self.Changed:Fire()
    return true, clean
end

function Config:Load(name)
    local ok, clean = Config.ValidName(name)
    if not ok then return false, clean end
    local data = Storage.ReadJSON(self:Path(clean))
    if not data then return false, "Config not found." end
    local applied, err = self:Apply(data)
    if not applied then return false, err end
    self.Current = clean
    self.Changed:Fire("load")
    return true, clean
end

function Config:Delete(name)
    local ok, clean = Config.ValidName(name)
    if not ok then return false, clean end
    if not self:Exists(clean) then return false, "Config not found." end
    Storage.Delete(self:Path(clean))
    if self.Current == clean then self.Current = nil end
    if self:GetAutoload() == clean then self:SetAutoload(nil) end
    self.Changed:Fire()
    return true, clean
end

function Config:Rename(old, new)
    local okOld, from = Config.ValidName(old)
    if not okOld then return false, from end
    local okNew, to = Config.ValidName(new)
    if not okNew then return false, to end
    if from == to then return true, to end
    local content = Storage.Read(self:Path(from))
    if not content then return false, "Config not found." end
    if self:Exists(to) then return false, "A config with that name exists." end
    if not Storage.Write(self:Path(to), content) then return false, "Could not write the file." end
    Storage.Delete(self:Path(from))
    if self.Current == from then self.Current = to end
    if self:GetAutoload() == from then self:SetAutoload(to) end
    self.Changed:Fire()
    return true, to
end

function Config:GetAutoload()
    local name = Storage.Read(self.Dir .. "/autoload.txt")
    if name and name ~= "" and self:Exists(name) then return name end
    return nil
end

function Config:SetAutoload(name)
    if name then
        Storage.Write(self.Dir .. "/autoload.txt", name)
    else
        Storage.Delete(self.Dir .. "/autoload.txt")
    end
    self.Changed:Fire()
end

function Config:LoadAutoload()
    local name = self:GetAutoload()
    if name then return self:Load(name) end
    return false, "No autoload config."
end

-- json text of everything with a flag, ready to paste somewhere else
function Config:Export()
    return Storage.Encode(self:Snapshot())
end

function Config:Import(text)
    local data = type(text) == "string" and Storage.Decode(text)
    if not data then return false, "Not a valid config." end
    return self:Apply(data)
end

function Config:ExportConfig(name)
    local ok, clean = Config.ValidName(name)
    if not ok then return nil, clean end
    local data = Storage.ReadJSON(self:Path(clean))
    if not data then return nil, "Config not found." end
    return Storage.Encode(data)
end

-- the text a hub shows when a user shares a config; paste it into an import box
function Config:ShareCode(name)
    local json, err = self:ExportConfig(name or self.Current)
    if not json then return nil, err end
    return "-- UnWrittenUI config: " .. (name or self.Current or "shared") .. "\n" .. json
end

-- called by elements on every change; debounced save into the current config
function Config:Touch()
    if self._loading or not self.AutoSave or not self.Current or self._saveQueued then return end
    self._saveQueued = true
    task.delay(1, function()
        self._saveQueued = false
        if self.AutoSave and self.Current then self:Save(self.Current) end
    end)
end

return Config
