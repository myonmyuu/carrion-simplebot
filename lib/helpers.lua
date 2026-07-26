---@class Helpers
local Helpers = {}

function Helpers.tprint (tbl, height, indent)
	if not tbl then return end
	if not height then height = 0 end
	if not indent then indent = 0 end
	if type(tbl) ~= "table" then
		print(tbl)
		return
	end
	for k, v in pairs(tbl) do
		height = height+1
		local formatting = string.rep("  ", indent) .. k .. ": "
		if type(v) == "table" then
			print(formatting, indent*8, 16*height)
			Helpers.tprint(v, height+1, indent+1)
		elseif type(v) == 'function' then
			print(formatting .. "function", indent*8, 16*height)
		elseif type(v) == 'boolean' then
			print(formatting .. tostring(v), indent*8, 16*height)
		else
			print(formatting .. v, indent*8, 16*height)
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

function table.clone(org)
	return {unpack(org)}
end


return Helpers