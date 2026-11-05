---@class Helpers
local Helpers = {}
table.unpack = unpack

function Helpers.topstring(tbl, height, indent)
	if not tbl then return "nil" end
	if not height then height = 1 end
	if not indent then indent = 1 end
	if indent > 10 then
		return
	end
	if type(tbl) ~= "table" then
		return tostring(tbl)
	end
	local ret = "{\n"
	for k, v in pairs(tbl) do
		height = height+1
		local nextval
		if type(v) == "table" then
			nextval = Helpers.topstring(v, height + 1, indent + 1)
		elseif type(v) == 'function' then
			nextval = "function"
		else
			nextval = tostring(v)
				:gsub("%%20", " ")
		end
		ret = ("%s%s %s: %s;\n")
			:format(ret, string.rep("\t", indent), tostring(k), "%s")
			:format(tostring(nextval))
	end

	ret = ("%s%s}"):format(ret, string.rep("\t", math.max(0, indent - 1)))
	return ret
end
function Helpers.tprint (tbl)
	print(Helpers.topstring(tbl))
end

function Helpers.make_cookies(table)
	table = table or {}
	local res = ""
	for key, value in pairs(table) do
		res = ("%s%s=%s;"):format(res, tostring(key), tostring(value))
	end
	return res
end

---@param x number
---@param y number
---@param alpha number
---@return number
function math.lerp(x, y, alpha)
    if x == y then return x end
    if alpha == 0 then return x end
    if alpha == 1 then return y end

    return x + (y - x) * alpha
end

---@param min integer
---@param max integer
---@param n integer
---@return integer
function math.wrap(min, max, n)
	n = n - min
	n = n % (max - min + 1)
	return n + min
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

---@generic Key
---@generic Val
---@generic RKey
---@generic RVal
---@param t table<Key,Val>
---@param f fun(k: Key, v: Val): RKey, RVal
---@return { [RKey]: RVal }
function table.mapk(t, f)
	local res = {}
	for key, value in pairs(t) do
		local k, v = f(key, value)
		if k ~= nil then
			res[k] = v
		end
	end
	return res
end

---@generic V
---@generic R
---@generic K
---@param t table<`K`,`V`>
---@param f fun(k: K, v: V): boolean
---@return boolean
function table.any(t, f)
	for key, value in pairs(t) do
		local r = f(key, value)
		if r then
			return true
		end
	end
	return false
end

---@generic K
---@generic V
---@param t table<`K`,`V`>
---@param wf? fun(v:V):number
---@return K
function table.weightedrandom(t, wf)
	local totalWeight = 0

    for _, item in pairs(t) do
        totalWeight = totalWeight + (wf and wf(item)) or item.weight
    end

    local roll = math.random() * totalWeight

    for name, item in pairs(t) do
        roll = roll - (wf and wf(item)) or item.weight

        if roll <= 0 then
            return name
        end
    end
	return nil
end

---comment
---@param col any
---@param item any
---@return boolean
function table.contains(col, item)
	return table.getIndex(col, item) ~= 0
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
	elseif type(url) ~= "string" then
		url = tostring(url)
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