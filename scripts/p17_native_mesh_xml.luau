--!strict
-- Host-only native RBXM decoder. Pinned Lune preserves engine-authored opaque
-- mesh payloads while exposing their serialized fields to the Python compiler.
-- Inputs/outputs are local paths; no engine, asset service or network is used.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local input, output = process.args[1], process.args[2]
assert(input and output and #process.args == 2, "expected native RBXM input and XML output paths")
local roots = roblox.deserializeModel(fs.readFile(input))
assert(#roots == 1 and roots[1]:IsA("Folder"), "native mesh capture requires one Folder root")
fs.writeFile(output, roblox.serializeModel(roots, true))
