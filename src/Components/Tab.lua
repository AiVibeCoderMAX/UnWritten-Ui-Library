local import = ...
local Util = import("Core/Util")
local Theme = import("Core/Theme")
local Router = import("Core/Router")
local Animation = import("Core/Animation")
local Page = import("Components/Page")
local Container = import("Components/Container")
local Maid = import("Core/Maid")
local Signal = import("Core/Signal")

-- a tab is a sidebar entry with one page, or a set of sub-tabs with a chip bar above their pages.
-- Sub-tabs of sub-tabs are not supported; each sub-tab is a full page with the card API.
local Tab = {}
Tab.__index = Tab
Container.Apply(Tab)

function Tab.new(window, def)
    local self = setmetatable({}, Tab)
    Container.Setup(self)
    self.Kind = "Tab"
    self.Window = window
    self.Def = def
    self.Title = def.Title or def.Name or "Tab"
    self.Icon = def.Icon
    self.Id = def.Id or ("tab:" .. self.Title)
    self.Draggable = def.Draggable ~= false
    self.Columns = def.Columns or 2
    self.SubTabs = {}
    self.Selected = nil
    self.Visible = def.Visible ~= false
    self.Children = {}
    self.Changed = Signal.new()
    self.StateChanged = Signal.new()
    self.Maid = Maid.new()
    self.Page = Page.new(window, { Id = self.Id .. "/main", Columns = self.Columns })
    self.Page.ParentFrame = nil
    self.Page.Tab = self
    self.FavoritesAllowed = def.Favorites ~= false
    return self
end

-- the page shown right now
function Tab:CurrentPage()
    if self.Selected then return self.Selected.Page end
    return self.Page
end

function Tab:SubTab(def)
    local sub = setmetatable({}, Tab)
    Container.Setup(sub)
    sub.Kind = "SubTab"
    sub.Window = self.Window
    sub.Def = def
    sub.Title = def.Title or def.Name or "Sub-tab"
    sub.Icon = def.Icon
    sub.Id = def.Id or (self.Id .. "/sub:" .. sub.Title)
    sub.Draggable = def.Draggable ~= false
    sub.Columns = def.Columns or self.Columns
    sub.Visible = def.Visible ~= false
    sub.SubTabs = {}
    sub.Selected = nil
    sub.ParentTab = self
    sub.Children = {}
    sub.Changed = Signal.new()
    sub.StateChanged = Signal.new()
    sub.Maid = Maid.new()
    sub.Page = Page.new(self.Window, { Id = sub.Id, Columns = sub.Columns })
    sub.Page.Tab = self
    sub.Page.SubTab = sub
    sub.FavoritesAllowed = self.FavoritesAllowed
    -- the first sub-tab is shown by default
    table.insert(self.SubTabs, sub)
    if #self.SubTabs == 1 then self.Selected = sub end
    self.Window:_buildChips(self)
    return sub
end

function Tab:Module(def)
    if not self.Selected and #self.SubTabs > 0 then self.Selected = self.SubTabs[1] end
    return self:CurrentPage():Module(def)
end

function Tab:Elements()
    local out = self.Page:Elements()
    for _, sub in self.SubTabs do
        local subElements = sub.Page:Elements()
        for _, element in subElements do table.insert(out, element) end
    end
    return out
end

-- every module of the tab, including sub-tabs
function Tab:Modules()
    local out = {}
    for _, module in self.Page.Modules do table.insert(out, module) end
    for _, sub in self.SubTabs do
        for _, module in sub.Page.Modules do table.insert(out, module) end
    end
    return out
end

function Tab:SelectSub(name)
    for _, sub in self.SubTabs do
        if sub == name or sub.Title == name or sub.Id == name then
            self.Selected = sub
            self.Window:_showTab(self)
            return sub
        end
    end
    return nil
end

function Tab:Select()
    self.Window:SelectTab(self)
end

function Tab:SetVisible(visible)
    self.Visible = visible and true or false
    self.Window:_refreshSidebar()
end

function Tab:Matches(query)
    if self.Page:Matches(query) then return true end
    for _, sub in self.SubTabs do
        if sub.Page:Matches(query) then return true end
    end
    return false
end

-- which of this tab's pages match the query, with the matching modules
function Tab:Search(query)
    local result = {}
    local function scan(page, label)
        local hits = {}
        for _, module in page.Modules do
            if module:Matches(query) then table.insert(hits, module) end
        end
        if #hits > 0 then table.insert(result, { Page = page, Label = label, Hits = hits }) end
    end
    scan(self.Page, self.Title)
    for _, sub in self.SubTabs do
        scan(sub.Page, self.Title .. " · " .. sub.Title)
    end
    return result
end

return Tab
