---@class Helpers
local Helpers = {}

function Helpers.tprint (tbl, height, indent)
	if not tbl then return end
	if not height then height = 0 end
	if not indent then indent = 0 end
	if indent > 10 then
		return
	end
	if type(tbl) ~= "table" then
		print(tbl)
		return
	end
	for k, v in pairs(tbl) do
		height = height+1
		local formatting = string.rep("  ", indent) .. tostring(k) .. ": "
		if type(v) == "table" then
			print(formatting, indent*8, 16*height)
			Helpers.tprint(v, height+1, indent+1)
		elseif type(v) == 'function' then
			print(formatting .. "function", indent*8, 16*height)
		else
			print(formatting .. tostring(v), indent*8, 16*height)
		end
	end
end

function Helpers.make_cookies(table)
	table = table or {}
	local res = ""
	for key, value in pairs(table) do
		res = ("%s%s=%s;"):format(res, tostring(key), tostring(value))
	end
	return res
end

---@generic V
---@generic R
---@generic K
---@param t table<`K`,`V`>
---@param f fun(k: K, v: V): R
---@return R[]
function table.map(t, f)
	local res = {}
	for key, value in pairs(t) do
		local r = f(key, value)
		if r ~= nil then
			table.insert(res, r)
		end
	end
	return res
end

function table.contains(col, item)
	return table.getIndex(col, item)
end

function table.getIndex(col, item)
	local fun = type(item) == "function"
	for index, value in ipairs(col) do
		if fun and item(value) or item == value then
			return index
		end
	end
	return 0
end

function table.removeItem(col, item)
    local i = table.getIndex(col, item)
    if i then
        table.remove(col, i)
    end
end

function table.removeall(t, n)
	local fun = type(n) == "function"
	local succ = false
	for k, value in pairs(t) do
		if (fun and n(value) == true) or (value == n) then
			succ = true
			t[k] = nil
		end
	end
	return succ
end

function table.clone(org)
	return {unpack(org)}
end

local char_to_hex = function(c)
	return string.format("%%%02X", string.byte(c))
end

function Helpers.urlencode(url)
	if url == nil then
		return
	end
	url = url:gsub("\n", "\r\n")
	url = url:gsub("([^%w ])", char_to_hex)
	url = url:gsub(" ", "%%20")
	return url
end

local function hex_to_char(x)
	return string.char(tonumber(x, 16))
end

function Helpers.urldecode(url)
	if url == nil then
		return
	end
	url = url:gsub("%%20", " ")
	url = url:gsub("%%(%x%x)", hex_to_char)
	return url
end

function Helpers.round(n)
	return math.floor(n + 0.5)
end

return Helpers