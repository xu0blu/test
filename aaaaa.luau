local SynVersion = 'Synapse X ' .. (type(_VERSION) == 'string' and _VERSION or 'unknown')

local Configs = getgenv().SynDecompilerConfigs or {
    DecompilerTimeout = 5,
    RemoveSemicolon = false,
    GetHighestIndex = function() return 0 end,
    IsDefined = function(tbl, v) 
        for _, x in ipairs(tbl) do 
            if x == v then return true end 
        end 
        return false 
    end,
}

local SynDecompile = assert(getgenv().decompile, "Orijinal 'decompile' bulunamadı.")

getgenv().decompile = function(Path, ...)
    if typeof(Path) ~= "Instance" or not Path.ClassName:find("Script") then
        return "--[[ INVALID SCRIPT INSTANCE ]]--"
    end

    local Output
    local args = {...}

    spawn(function()
        Output = SynDecompile(Path, unpack(args))
    end)

    local Tick = 0
    repeat
        task.wait(1)
        Tick = Tick + 1
    until Output or Tick >= Configs.DecompilerTimeout

    if not Output then
        if Tick >= Configs.DecompilerTimeout then
            return "--" .. SynVersion .. "\n--Exceeded decompiler timeout."
        else
            return "--" .. SynVersion .. "\n--No bytecode was found (this script most likely contains an anti-decompiler)."
        end
    end

    if #Output == 0 then
        return "--" .. SynVersion .. "\n--No bytecode was found (empty script)."
    end

    -- Temizleme ve düzenleme
    Output = Output:gsub("Synapse X Luau", SynVersion)
    Output = Output:gsub("\r\n", "\n")
    Output = Output:gsub("\n\n+", "\n")
    Output = Output:gsub("-- Decompiled by Krnl", "")
    Output = Output:gsub("-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw", "")

    -- __set_list ve yorum satırlarını sil
    Output = table.concat(table.pack((function()
        local lines = {}
        for line in Output:gmatch("([^\n]*)\n?") do
            if not line:match("%b()__set_list%b()") and not line:match("^%s*%-%-") and not line:match("^%s*goto%s+") and not line:match("^%s*::.*::$") then
                table.insert(lines, line)
            end
        end
        return table.unpack(lines)
    end)()), "\n")

    -- local değişkenleri v1, v2, v3... olarak değiştir, function satırları bozulmasın
    local counter = 0
    local renameMap = {}
    Output = Output:gsub("local%s+([%w_]+)%s*=", function(name)
        counter = counter + 1
        local newName = "v" .. counter
        renameMap[name] = newName
        return "local " .. newName .. " ="
    end)
    -- referansları güncelle
    for oldName, newName in pairs(renameMap) do
        Output = Output:gsub("%f[%w_]" .. oldName .. "%f[%W]", newName)
    end

    -- semicolon ekleme
   Output = Output:gsub("([^\n]+)\n", function(line)
    if line:match("^%s*::.*::$") or
       line:match("^%s*goto%s+") or
       line:match("^%s*if%s") or
       line:match("^%s*for%s") or
       line:match("^%s*while%s") or
       line:match("^%s*function%s*%b()") or  -- function(...) atla
       line:match("^%s*repeat%s") or
       line:match("^%s*else%s") or
       line:match("^%s*elseif%s") or
       line:match("^%s*do%s") then
        return line .. "\n"
    else
        return line .. ";\n"
    end
end)
end)

    -- variable/constant header
    local DefinedVariables = {}
    local DefinedConstants = {}
    local highest = 0
    if type(Configs.GetHighestIndex) == "function" then
        highest = tonumber(Configs.GetHighestIndex(Output)) or 0
    end
    for i = 1, highest do
        local varName = "Variable_" .. i
        local constName = "Constant_" .. i
        if Output:find("local%s+" .. varName) and not Configs.IsDefined(DefinedVariables, "local " .. varName) then
            table.insert(DefinedVariables, varName .. " = nil")
        end
        if Output:find("local%s+" .. constName) and not Configs.IsDefined(DefinedConstants, "local " .. constName) then
            table.insert(DefinedConstants, constName .. " = nil")
        end
    end
    local header = "-- Decompiled with the " .. SynVersion .. " decompiler.\n\n"
    local bodySplit = Output:match("%-%- Decompiled with the .-\n\n(.*)") or Output
    if #DefinedVariables > 0 then
        local varHeader = "-- [[ Variables ]] --\n"
        for _, v in ipairs(DefinedVariables) do varHeader = varHeader .. v .. "\n" end
        Output = header .. varHeader .. "\n" .. bodySplit
        bodySplit = Output
    end
    if #DefinedConstants > 0 then
        local constHeader = "-- [[ Constants ]] --\n"
        for _, c in ipairs(DefinedConstants) do constHeader = constHeader .. c .. "\n" end
        Output = header .. constHeader .. "\n" .. bodySplit
    end

    if Output:lower():find("bytecode") then
        return "--" .. SynVersion .. "\n--No bytecode was found (most likely a Synapse X generated script or empty script)."
    end

    -- 2. satıra blu decompiler mesajı ekle
    local lines = {}
    for line in Output:gmatch("([^\n]*)\n?") do table.insert(lines, line) end
    table.insert(lines, 2, "-- decompiled with blu's decompiler xd")
    Output = table.concat(lines, "\n")

    return Output
end

decompile = getgenv().decompile
