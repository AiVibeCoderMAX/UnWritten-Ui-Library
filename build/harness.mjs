// writes dist/Harness.lua: the bundle and examples/Example.lua in one file, so the example can be
// run in a real executor without hosting anything. Errors land in getgenv().UnWrittenTestErr.
// usage: node build/harness.mjs [out]
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const out = process.argv[2] ? resolve(process.argv[2]) : join(root, "dist/Harness.lua");

const bundle = readFileSync(join(root, "dist/UnWrittenUI.lua"), "utf8");
let example = readFileSync(join(root, "examples/Example.lua"), "utf8");

// the example downloads the library; in the harness it is already inline
const loaderPattern = /^local UnWrittenUI = loadstring\(game:HttpGet\([^\n]*\)\)\(\)$/m;
if (!loaderPattern.test(example)) {
    console.error("harness: examples/Example.lua no longer starts with the loadstring(game:HttpGet(...)) loader");
    process.exit(1);
}
example = example.replace(loaderPattern, "local UnWrittenUI = __UnWrittenUI");

const file = [
    "-- UnWrittenUI harness: library + examples/Example.lua in one file. Generated, do not edit.",
    "getgenv().UnWrittenTestErr = \"running\"",
    "getgenv().UnWrittenWarns = {}",
    "local __warn = warn",
    "warn = function(...)",
    "    local parts = {}",
    "    for index = 1, select(\"#\", ...) do parts[index] = tostring(select(index, ...)) end",
    "    table.insert(getgenv().UnWrittenWarns, table.concat(parts, \" \"))",
    "    __warn(...)",
    "end",
    "local ok, err = xpcall(function()",
    "    local __UnWrittenUI = (function()",
    bundle,
    "    end)()",
    "    getgenv().UnWrittenUI_Dev = __UnWrittenUI",
    example,
    "end, debug.traceback)",
    "getgenv().UnWrittenTestErr = ok and \"ok\" or tostring(err)",
    "print(\"[UnWrittenUI] \" .. getgenv().UnWrittenTestErr)",
    "for _, message in getgenv().UnWrittenWarns do print(\"[warn] \" .. message) end",
].join("\n");

writeFileSync(out, file);
console.log(`wrote ${out} (${(file.length / 1024).toFixed(1)} KiB)`);

// smoke the example against the headless mock so a broken example fails the build
const mockPath = join(root, "build/mock.luau");
const mock = readFileSync(mockPath, "utf8").slice(0, readFileSync(mockPath, "utf8").lastIndexOf("return M"));
const check = [
    "local Mock = (function()",
    mock,
    "return M",
    "end)()",
    "Mock.errors = {}",
    "Mock.warnings = {}",
    "Mock.time = 0",
    `local example = [====[${example}]====]`,
    `local bundle = [====[${bundle}]====]`,
    "local env = Mock.newEnv()",
    "local chunk = assert(loadstring(bundle, '@UnWrittenUI'))",
    "setfenv(chunk, env)",
    "local ok, library = pcall(chunk)",
    "if not ok then print('FAILED: bundle: ' .. tostring(library)) os.exit(1) end",
    "env.UnWrittenUI = library",
    "env.__UnWrittenUI = library",
    "env.Mock = Mock",
    "env.setclipboard = function() end",
    "local exampleChunk = assert(loadstring(example, '@example'))",
    "setfenv(exampleChunk, env)",
    "local ran, err = pcall(exampleChunk)",
    "Mock.Flush(120)",
    "if not ran then print('FAILED: example: ' .. tostring(err)) os.exit(1) end",
    "-- assertions: the example must actually produce a usable window",
    "local window = library.Window",
    "assert(window, 'no window')",
    "assert(#window.Tabs >= 5, 'expected 5+ tabs, got ' .. #window.Tabs)",
    "assert(#window:Modules() >= 10, 'expected 10+ modules, got ' .. #window:Modules())",
    "local combat",
    "for _, tab in window.Tabs do if tab.Title == 'Combat' then combat = tab end end",
    "assert(combat, 'missing Combat tab')",
    "assert(#combat:Modules() >= 3, 'Combat has too few modules')",
    "assert(window.Interface and window.Interface.ToggleKey, 'no toggle key')",
    "assert(window.SearchBox, 'no search box')",
    "assert(#window.Panels >= 1, 'no floating panel')",
    "assert(#window.ScreenButtons >= 1, 'no screen button')",
    "assert(library:GetFlag('AimEnabled') == false, 'flag default wrong')",
    "library:SetFlag('AimEnabled', true)",
    "assert(library:GetFlag('AimEnabled') == true, 'SetFlag failed')",
    "library:SetFlag('WalkSpeed', 120)",
    "assert(library:GetFlag('WalkSpeed') == 120, 'WalkSpeed flag failed')",
    "local okSave, saveErr = window.Config:Save('harness')",
    "assert(okSave, 'config save failed: ' .. tostring(saveErr))",
    "library:SetFlag('AimEnabled', false)",
    "local okLoad, loadErr = window.Config:Load('harness')",
    "assert(okLoad, 'config load failed: ' .. tostring(loadErr))",
    "assert(library:GetFlag('AimEnabled') == true, 'config did not restore AimEnabled')",
    "local settingsTab = window:OpenSettings('Theme')",
    "assert(settingsTab, 'OpenSettings returned nothing')",
    "assert(window.SelectedTab == settingsTab, 'OpenSettings did not select the tab')",
    "window:SetWatermark('harness v1')",
    "assert(window.Overlays and window.Overlays.WatermarkFrame, 'watermark not built')",
    "window.Overlays:SetKeybindList(true)",
    "assert(window.Overlays.Binds, 'keybind list did not open')",
    "window.Overlays:SetKeybindList(false)",
    "local code = window.Config:ShareCode()",
    "assert(type(code) == 'string' and #code > 10, 'share code empty')",
    "window:SelectTab(window.Tabs[2])",
    "window:SetMinimized(true) Mock.Flush(3) window:SetMinimized(false)",
    "library:Unload()",
    "Mock.Flush(20)",
    "for _, message in Mock.errors do print('runtime: ' .. message) end",
    "print(('example: %d modules, %d tabs, %d runtime errors, %d warnings'):format(#library.Window:Modules(), #library.Window.Tabs, #Mock.errors, #Mock.warnings))",
    "for _, message in Mock.warnings do print('warning: ' .. message) end",
    "if #Mock.errors > 0 then os.exit(1) end",
].join("\n");
const checkPath = join(root, "build/_harness_check.luau");
writeFileSync(checkPath, check);
