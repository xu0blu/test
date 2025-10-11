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

	-- local v_u_ veya u_ değişkenlerini v1,v2,v3... yap
	local vcount = 1
	local renameMap = {}

	for var in Output:gmatch("local%s+(v_u_%w+)%s*=") do
		if not renameMap[var] then
			renameMap[var] = "v" .. vcount
			vcount += 1
		end
	end
	for var in Output:gmatch("local%s+(u_%w+)%s*=") do
		if not renameMap[var] then
			renameMap[var] = "v" .. vcount
			vcount += 1
		end
	end

	for old, new in pairs(renameMap) do
		Output = Output:gsub("(%f[%w_])" .. old .. "(%f[%W])", "%1" .. new .. "%2")
	end

	-- kalan v_u_ veya u_ referanslarını da düzelt
	for ref in Output:gmatch("v_u_%w+") do
		if not renameMap[ref] then
			renameMap[ref] = "v" .. vcount
			Output = Output:gsub(ref, renameMap[ref])
			vcount += 1
		end
	end
	for ref in Output:gmatch("u_%w+") do
		if not renameMap[ref] then
			renameMap[ref] = "v" .. vcount
			Output = Output:gsub(ref, renameMap[ref])
			vcount += 1
		end
	end

	-- tabloları dokunmadan bırak (self referans kaldırıldı)

	-- "end" sonlarına ";" ekle
	if Output:find("(%f[%w_]end)(%s*)") then
		Output = Output:gsub("(%f[%w_]end)(%s*)", "end;%2")
	end
	if Output:find("(%f[%w_]end))(%s*)") then
		Output = Output:gsub("(%f[%w_]end))(%s*)", "end);%2")
	end

	-- başlığa sadece blu etiketi koy
	local lns = {}
	for line in Output:gmatch("([^\n]*)\n?") do
		table.insert(lns, line)
	end
	if not lns[1]:match("decompiled with blu") then
		table.insert(lns, 1, "-- decompiled with blu's decompiler xd")
	end
	Output = table.concat(lns, "\n")

	return Output
end

decompile = getgenv().decompile
