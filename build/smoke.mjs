// builds build/_smoke.luau: the mock, the bundle and the smoke body in one runnable file.
// usage: node build/smoke.mjs && luau build/_smoke.luau
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
let mock = readFileSync(join(root, "build/mock.luau"), "utf8");
const body = readFileSync(join(root, "build/smoke_body.luau"), "utf8");
const bundle = readFileSync(join(root, "dist/UnWrittenUI.lua"), "utf8");

const exportIndex = mock.lastIndexOf("return M");
mock = mock.slice(0, exportIndex);

const out = [
    "local Mock = (function()",
    mock,
    "return M",
    "end)()",
    "Mock.errors = {}",
    "Mock.warnings = {}",
    "Mock.time = 0",
    "local __bundle = [====[",
    bundle,
    "]====]",
    "local __body = [====[",
    body,
    "]====]",
    "local function main()",
    "    local env = Mock.newEnv()",
    "    local chunk = assert(loadstring(__bundle, '@UnWrittenUI'))",
    "    setfenv(chunk, env)",
    "    local ok, library = pcall(chunk)",
    "    if not ok then error('bundle failed: ' .. tostring(library), 0) end",
    "    env.UnWrittenUI = library",
    "    env.Mock = Mock",
    "    local bodyChunk = assert(loadstring(__body, '@smoke'))",
    "    setfenv(bodyChunk, env)",
    "    local bodyOk, bodyErr = pcall(bodyChunk)",
    "    if not bodyOk then error('body failed: ' .. tostring(bodyErr), 0) end",
    "    for index = 1, 300 do Mock.Frame() end",
    "    return env",
    "end",
    "local ok, result = pcall(main)",
    "if not ok then",
    "    print('FAILED: ' .. tostring(result))",
    "else",
    "    if result.__result then print('smoke: ' .. result.__result) end",
    "end",
    "print(('runtime errors: %d, warnings: %d'):format(#Mock.errors, #Mock.warnings))",
    "for index, message in Mock.errors do print(('  error %d: %s'):format(index, message)) end",
    "for index, message in Mock.warnings do print(('  warning %d: %s'):format(index, message)) end",
    "if ok and #Mock.errors == 0 and result.__result == 'all steps ok' then print('PASS') else print('FAIL') end",
].join("\n");
writeFileSync(join(root, "build/_smoke.luau"), out);
console.log("build/_smoke.luau written");
