// compiles every source file (wrapped as the bundler does) with luau-compile and reports failures
// usage: node build/check.mjs [path-to-luau-compile]
import { readFileSync, readdirSync, statSync, writeFileSync, mkdtempSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const srcDir = join(root, "src");
const compiler = process.argv[2] || process.env.LUAU_COMPILE || "luau-compile";

function walk(dir) {
    return readdirSync(dir).flatMap((name) => {
        const full = join(dir, name);
        return statSync(full).isDirectory() ? walk(full) : name.endsWith(".lua") ? [full] : [];
    });
}

let failed = 0;
const dir = mkdtempSync(join(tmpdir(), "uw-check-"));
for (const file of walk(srcDir).sort()) {
    const name = relative(root, file);
    const out = join(dir, "chunk.lua");
    writeFileSync(out, readFileSync(file, "utf8"));
    try {
        execFileSync(compiler, ["--binary", "-O2", out], { stdio: "pipe" });
    } catch (error) {
        failed += 1;
        console.log(`FAIL ${name}`);
        const text = (error.stderr || error.stdout || "").toString();
        for (const line of text.trim().split("\n").slice(0, 8)) console.log("  " + line);
    }
}
if (!failed) console.log("all source files compile");
process.exit(failed ? 1 : 0);
