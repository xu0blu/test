local SynDecompile = getgenv().decompile

-- decompiled with blu's decompiler xd
getgenv().decompile = function(Path, ...)
	if typeof(Path) ~= "Instance" or not Path.ClassName:find("Script") then
		return "--[[ INVALID SCRIPT INSTANCE ]]--"
	end

	local args = {...}
	local Output = SynDecompile(Path, unpack(args))
	if not Output or #Output == 0 then
		return "-- failed to decompile script"
	end

	-- Gereksiz satırları sil
	local lines = {}
	for line in Output:gmatch("([^\n]*)\n?") do
		if not line:match("^%s*goto%s+") and not line:match("^%s*::.*::$") and not line:match("__set_list") then
			table.insert(lines, line)
		end
	end
	Output = table.concat(lines, "\n")

	-- Service adlarını l_Service_0 olarak düzenle
	Output = Output:gsub(
		"local%s+[%w_]+%s*=%s*game:GetService%([\"']([%w_]+)[\"']%)",
		function(service)
			return "local l_" .. service .. "_0 = game:GetService(\"" .. service .. "\")"
		end
	)

	-- v_u_ veya u_ değişkenleri v1,v2... şeklinde sırala
	local vcount = 1
	local renameMap = {}
	for var in Output:gmatch("local%s+(v_u_%w+)%s*=") do
		renameMap[var] = "v" .. vcount
		vcount += 1
	end
	for var in Output:gmatch("local%s+(u_%w+)%s*=") do
		if not renameMap[var] then
			renameMap[var] = "v" .. vcount
			vcount += 1
		end
	end

	for old, new in pairs(renameMap) do
		Output = Output:gsub("%f[%w_]" .. old .. "%f[%W]", new)
	end

	-- Table self referans düzeltmesi
	Output = Output:gsub("local%s+(%w+)%s*=%s*{(.-)}", function(tbl, body)
		local assigns = {}
		for k, v in body:gmatch("([%w_]+)%s*=%s*([%w_%.]+)") do
			table.insert(assigns, tbl .. "." .. k .. " = " .. v)
		end
		return "local " .. tbl .. " = {}\n" .. table.concat(assigns, "\n")
	end)

	-- İkinci satıra blu etiketi ekle
	local lns = {}
	for line in Output:gmatch("([^\n]*)\n?") do
		table.insert(lns, line)
	end
	if not lns[2] or not lns[2]:match("decompiled with blu") then
		table.insert(lns, 2, "-- decompiled with blu's decompiler xd")
	end
	Output = table.concat(lns, "\n")

	return Output
end

decompile = getgenv().decompile
