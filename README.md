# UnWrittenUI

A modular, heavily animated interface library for Roblox, written in Luau for executor environments.
Windows, tabs and sub-tabs, module cards in two rearrangeable columns, 20+ element types, floating
panels, configs, a theme editor — all in one file you can `loadstring` and run.

```
dist/UnWrittenUI.lua   the whole library, one file
examples/Example.lua   a showcase script that uses every feature
src/                   the source tree (build/bundle.mjs concatenates it)
```

## Install

```lua
local UnWrittenUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/AiVibeCoderMAX/UnWritten-Ui-Library/main/dist/UnWrittenUI.lua"))()
```

`loadstring` + `game:HttpGet` needs an executor. Everything degrades gracefully where an API is
missing: without `writefile` configs stay in memory, without `gethui` the gui lives in `CoreGui`,
without `setclipboard` the share button still shows the code.

## Quick start

```lua
local Window = UnWrittenUI:CreateWindow({
    Title = "UnWritten",
    Subtitle = "v" .. UnWrittenUI.Version,
    Icon = "sparkles",
    Folder = "MyScript",          -- config + ui.json live in <Folder>/
    Theme = "Sapphire",           -- preset name, see Themes below
    ToggleKey = "RightShift",
})

local Tab = Window:Tab({ Title = "Combat", Icon = "swords" })
local Aim = Tab:Module({
    Title = "Aim assist",
    Description = "Smoothly tracks the nearest target",
    Icon = "crosshair",
    Flag = "Aim",                 -- the card itself becomes an on/off module
    Keybind = { Key = "Q" },
})

Aim:Toggle({ Title = "Enabled", Flag = "AimEnabled", Default = false, Callback = function(on)
    print("aim assist", on)
end })
Aim:Slider({ Title = "Smoothing", Min = 0.05, Max = 1, Step = 0.05, Default = 0.35, Flag = "AimSmooth" })
Aim:Dropdown({ Title = "Hit part", Values = { "Head", "Torso" }, Flag = "AimPart" })
```

`Flag` is the key used by configs and by `UnWrittenUI:GetFlag("AimSmooth")`. Any element with a
flag is saved and restored; elements without one are ephemeral.

## Window

```lua
UnWrittenUI:CreateWindow({
    Title, Subtitle, Icon, Folder,
    Size = UDim2.fromOffset(780, 520),
    MinSize = Vector2.new(560, 380),
    SidebarWidth = 164,
    Theme = "Midnight",          -- preset name
    ThemeOverrides = { Accent = Color3.fromRGB(120, 170, 255), Radius = 10 },
    Tags = { { Title = "Beta", Color = Color3.fromRGB(120, 170, 255) }, { Title = "v1" } },
    ToggleKey = "RightShift",    -- menu key, any Enum.KeyCode name
    Search = true,               -- search box in the sidebar
    Settings = true,             -- built-in Settings tab (themes, configs, keybinds, overlays)
    AutoLoad = true, AutoSave = true,
    Resizable = true, Draggable = true,
    CloseAction = "Hide",        -- or "Unload"
    User = true,                 -- name + avatar in the sidebar
    Visible = true,
})
```

| Method | Does |
| --- | --- |
| `Window:Tab(def)` / `Window:SubTab` on a tab | sidebar tab, or a chip row of sub-tabs |
| `Window:TabSection(text)` / `Window:Divider()` | captions between sidebar entries |
| `Window:SelectTab(tab \| name \| index)` | show a tab |
| `Window:SelectFavorites()` / `Window:_search(query)` | favorites and search pages |
| `Window:Modules()` | every module in the window |
| `Window:SetVisible / Toggle / SetMinimized / SetCompact` | visibility and shape |
| `Window:SetScale(n)` / `SetFitScreen(on)` | manual scale or fit-to-viewport |
| `Window:SetSize(UDim2)` / `Center()` | geometry |
| `Window:SetTitle / SetSubtitle / SetUser` | header |
| `Window:SetWatermark(text \| nil)` | small watermark under the menu |
| `Window:Panel(def)` / `ScreenButton(def)` | floating panel, touch pill |
| `Window:Dialog(def)` / `Menu(items)` / `Notify(def)` | modal, context menu, toast |
| `Window:SaveState()` / `LoadAutoload()` | persist ui state, load the autoloaded config |
| `Window:Destroy()` | tear everything down |

## Tabs and modules

```lua
local Tab = Window:Tab({ Title = "Movement", Icon = "move", Columns = 2, Caption = "Group name" })
local Sub = Tab:SubTab({ Title = "Extras" })          -- chips above the page
local Card = Sub:Module({
    Title = "Speed", Icon = "gauge", Description = "Walk speed",
    Side = "Left",              -- or "Right": the page has two independent columns
    Opened = true,              -- unfold the settings by default
    Toggle = true,              -- shows the module switch (false for a plain card)
    Flag = "Speed", Keybind = { Key = "X", Mode = "Toggle" },
    Locked = false, Visible = true,
})
```

Modules are cards: a header (icon, title, description, switch, keybind pill, ⋮ menu) and a body of
elements that folds out when the module is enabled. The ⋮ menu has *Expand*, *Favorite*, *Keybind*,
*Reset*, *Lock* and *Destroy*. Drag the grip on the card header to move a card inside its column,
across columns, or to another tab. `SetEnabled(on)`, `SetExpanded(on)`, `SetFavorite(on)`,
`SetLocked(on)`, `SetVisible(on)`, `SetTitle(text)`, `SetDescription(text)`, `Reset()`,
`Destroy()`, `OnChanged(fn)` and `Binding` round it out.

## Elements

Every element takes `Title`, `Description`, `Tooltip`, `Flag`, `Locked`, `Visible`, `DependsOn`
(a table of `{ Flag = value }` that locks the element until the dependency matches), `Callback`
and `NoSave`.

| Call | Values | Extras |
| --- | --- | --- |
| `:Toggle{ Default, Style = "Switch" \| "Checkbox", Field, Color, Keybind }` | boolean | `Get/Set/ToggleEnabled/Binding`, `Field` adds an inline value box |
| `:Slider{ Min, Max, Default, Step, Format, Prefix, Suffix, Buttons, Input, Icons }` | number | `Set/SetMin/SetMax/Display/Reset` |
| `:Range{ Min, Max, Default = {lo, hi}, Step, MinGap }` | `{lo, hi}` | `Set/GetLow/GetHigh` |
| `:Dropdown{ Values, Default, Multi, Search, AllowNone, MaxVisible, Placeholder }` | value or list | `Values` entries can be `{ Title, Value, Icon }`; `Get/Set/Add/Remove/Toggle/IsSelected` |
| `:Input{ Default, Placeholder, Numeric, Multiline, Height, MaxLength, ClearOnFocus, Validate }` | string or number | `Set/Submit` |
| `:Keybind{ Default = "F", Mode = "Toggle" \| "Hold" \| "Always" }` | key name | `GetKey/SetKey/SetMode/IsDown` |
| `:ColorPicker{ Default, Alpha, Rainbow }` | Color3 | `Get/Set/GetAlpha/SetAlpha/SetRainbow` |
| `:Segmented{ Values, Default }` | value | `Get/Set/Values` — radio row or tabs |
| `:Button{ Title, Icon, Style, Confirm, Callback }` | — | `Press()`, `SetButtonTitle` |
| `:Buttons{ { Title, Icon, Callback }, ... }` | — | `Press(index)`, `SetButtonTitle(i, text)`, `SetButtonLocked(i, on)` |
| `:Group{ Title, Icon, Opened }` | — | a foldable container with its own element API; `SetOpened/Get/Set` |
| `:Label{ Text, Value, ValueColor }` | — | right-aligned value column |
| `:Paragraph{ Title, Content }` | — | rich text: `<b>`, `<i>`, `<font color='#rgb'>` |
| `:Divider{ Text }` / `:Spacer{ Height }` | — | layout helpers |
| `:ProgressBar{ Default, Max, Suffix, Format }` | number | `Set/SetMax` |
| `:Image{ Image, Height, Caption, ScaleType, Radius, AspectRatio }` | — | accepts an asset id number |
| `:Log{ Height, MaxLines, Timestamps }` | — | `Add(text, color)/AddColored/Clear` |
| `:Code{ Code, Lines, Editable }` | string | `Get/Set/Open` — click to copy or edit in a dialog |

Containers also expose the flag-first aliases `AddToggle`, `AddSlider`, `AddDropdown`, `AddInput`,
`AddKeybind`, `AddButton`, `AddColorPicker`, `AddLabel`, `AddParagraph`, `AddDivider`,
`AddProgressBar`, `AddGroup` and the short spellings `Checkbox`, `Textbox`, `Tabs`, `Progress`,
`Section`, `Space`.

## Animations

Motion is the point of the library, not a garnish:

- windows slide, scale and fade in and out, minimise into a compact bar, and blur the game behind them;
- cards spring open and closed, hover states cross-fade, and switches, sliders and segmented controls
  animate their fills, knobs and selection pills;
- dropdowns, context menus and tooltips grow from the pointer with a short scale/fade;
- notifications slide in from the edge, stack, and slide out on close, with progress bars;
- panels and screen buttons scale on press and snap while dragged;
- icons and text colours tween on hover and on theme changes.

`Theme.Current.AnimSpeed` is the global multiplier (`0` disables all motion and makes every
transition instant). Every window gets an **Animation speed** slider in *Settings → Style*, and
`Window:SetCompact(true)` and `SetMinimized(true)` are animated too. Internally each animation is
named (`"Press"`, `"Hover"`, `"Fade"`, `"Slide"`, `"Toggle"`, …); asking for the same name on the same
instance replays from the current value rather than stacking, so fast input never judders.

## Themes

Ten presets: `Sapphire`, `Obsidian`, `Midnight`, `Ocean`, `Emerald`, `Amber`, `Crimson`, `Rose`,
`Paper`, `Violet`.

```lua
UnWrittenUI:SetTheme("Ocean")
UnWrittenUI:SetAccent(Color3.fromRGB(120, 170, 255))
UnWrittenUI:SetBackgroundBlur(true)
Window:OpenSettings("Theme")            -- jump to the built-in editor
```

Palette tokens: `Accent`, `AccentAlt`, `Background`, `BackgroundAlt`, `Surface`, `SurfaceHover`,
`Elevated`, `ElevatedHover`, `Stroke`, `Divider`, `Text`, `TextDim`, `TextMuted`, `OnAccent`,
`Success`, `Warning`, `Danger`, `Info`. Style tokens: `WindowTransparency`, `SurfaceTransparency`,
`ElevatedTransparency`, `StrokeTransparency`, `Radius`, `ElementRadius`, `Font`, `AnimSpeed`,
`Gradient`, `GradientRotation`, `AnimatedTitle`.

Themes round-trip: `UnWrittenUI.Theme.Export()` returns a table and `Theme.Import(data)` applies it,
which is how window state and share codes persist your look. The editor lives in the Settings tab.

## Configs

Configs are json files in `<Folder>/configs`.

```lua
Window.Config:Save("pvp")            -- writes every flagged element
Window.Config:Load("pvp")
Window.Config:List()                 -- names, sorted
Window.Config:Rename("pvp", "duel")
Window.Config:Delete("pvp")
Window.Config:SetAutoload("pvp")     -- loaded on the next run when AutoLoad is on
Window.Config:GetAutoload()

local code = Window.Config:ShareCode()   -- json string of the current state
Window.Config:Import(code)               -- apply a shared setup
```

`Window.Config.AutoSave = true` (or `AutoSave = true` on the window) writes changes into the loaded
config as you toggle things. The built-in *Settings → Configs* module has buttons for all of it,
including copy-to-clipboard share codes.

## Overlays

```lua
local Hud = Window:Panel({
    Title = "Stats", Icon = "activity",
    Size = Vector2.new(200, 160), Position = UDim2.fromOffset(20, 20),
    Hud = true,                  -- survives the menu being hidden
    Collapsible = true, Closable = false, Resizable = true, AutoSize = false,
})
Hud:Toggle({ Title = "Show FPS", Default = true })
Hud:Label({ Text = "Ping", Value = "42 ms" })
Hud:Show()

Window:ScreenButton({
    Title = "Aim", Icon = "crosshair",
    Color = Color3.fromRGB(120, 170, 255),
    Active = function() return UnWrittenUI:GetFlag("AimEnabled") end,
    Press = function() end,
})

local toast = UnWrittenUI:Notify({
    Title = "Loaded", Content = "43 modules", Type = "Success",
    Icon = "check", Duration = 4,
})
toast:Update({ Content = "still here" })
toast:Close()

Window:Dialog({
    Title = "Confirm", Content = "Reset everything?",
    Buttons = { { Title = "Cancel" }, { Title = "Reset", Style = "Primary", Callback = reset } },
})

Window:Dialog({
    Title = "Name it", Input = { Placeholder = "config name" },
    Buttons = { { Title = "Save", Style = "Primary", Callback = function(handle)
        Window.Config:Save(handle.Value)
    end } },
})
```

Panels and screen buttons remember where you dragged them. `Window:Menu(items)` opens a context
menu at the pointer; right-clicking a module header does the same.

## Keybinds

`Keybind` elements and `Keybind = {}` on modules or toggles create pills you click to rebind.
Combos with up to three modifiers are supported; right-click a pill to pick *Hold*, *Toggle* or
*Always*. `UnWrittenUI:IsCapturing()` tells you whether a rebind is in progress, and the built-in
*Settings → Keybinds* page lists every bind with its mode and lets you clear them.

## Input and touch

Clicks, right-clicks, drags, long presses, double clicks and touch taps all go through one router
with a single global press registry, so a drag that leaves an element keeps tracking, and only one
menu or popup is open at a time. Text boxes that are focused swallow game keys. On touch devices the
screen buttons and the menu's compact mode take over, and the `ToggleKey` bind is ignored while
typing.

## Icons

The bundle ships no image assets: `Icon = "swords"` maps to a built-in set of ~170 shapes and falls
back to a circle when the name is unknown, so nothing ever renders blank. Register your own ids once:

```lua
UnWrittenUI:AddIcons({
    aim    = "rbxassetid://1234567890",
    swords = "rbxassetid://0987654321",
})
```

Any `Icon` can also be an asset id number or a full `rbxassetid://` / `http(s)://` string.

## Lifecycle

```lua
UnWrittenUI:OnUnload(function() print("bye") end)
UnWrittenUI:Unload()
```

Re-executing a script unloads the previous instance automatically (`getgenv().UnWrittenUI_Instance`),
so menus never stack. `Window:Destroy()` closes one window; `Unload()` closes everything and clears
connections, tweens, loops and the notifications.

## Building from source

```
npm run build      # dist/UnWrittenUI.lua from src/
npm run check      # parse every source file
npm run harness    # dist/Harness.lua: library + example in one file, for a real executor
npm run smoke      # bundle + headless Roblox mock + full API smoke test
```

`build/mock.luau` is a small virtual Roblox: instances with properties, signals, a real layout pass,
`task` scheduling on coroutines, a tween service and a json codec. It exists so the whole library can
be exercised without the game; `node build/smoke.mjs && luau build/_smoke.luau` runs 40+ steps that
build a window, every element, click, drag and type into things, save and load a config, change theme
and unload.

## Layout

```
src/
  init.lua                 library entry, CreateWindow, shared instance guard
  Core/                    Services, Signal, Maid, Storage, Animation, Theme, Icons, Util,
                           Router, Keybinds, Binding, Config
  Components/              Layer, Popup, Menu, Tooltip, Widgets, Container, Module, Page, Tab,
                           Window, Dialog, Notification, Panel, ScreenButton, Overlays, Acrylic
  Elements/                Base plus one file per element
  Addons/Settings.lua      the built-in Settings tab
  Themes/Presets.lua       the ten palettes
examples/Example.lua       showcase
build/                     bundler, icon table, checks, headless mock, smoke test, harness
```

MIT licensed.
