local inpath  = "UniversalTraits/media/lua/shared/Translate/EN/UI_EN.txt"
local outpath = "UniversalTraits/media/lua/shared/Translate/EN/UI.json"

local f = io.open(inpath, "r")
local content = f:read("*a")
f:close()

local entries = {}
for key, val in content:gmatch('(UI_UT_%w+)%s*=%s*"(.-)",') do
    table.insert(entries, {key=key, val=val})
end

local out = io.open(outpath, "w")
out:write("{\n")
for i, e in ipairs(entries) do
    local comma = i < #entries and "," or ""
    -- escape backslash then double-quote
    local v = e.val
    v = v:gsub([[\]], [[\\]])
    v = v:gsub('"', [[\\"]])
    out:write('    "' .. e.key .. '": "' .. v .. '"' .. comma .. "\n")
end
out:write("}\n")
out:close()
print("Wrote " .. #entries .. " entries to " .. outpath)
