---@class LogLevel
---@field name string
---@field level integer

---@param name string
---@param l integer
---@param clr? string
---@return LogLevel
local function makeLevel(name, l, clr)
    return {
        name = name,
        level = l,
        colorHtml = clr
    }
end

---@class Logger
local log = {
    levels = {
        off = makeLevel("off", 0),
        verbose = makeLevel("verbose", 5, "#919191"),
        debug = makeLevel("debug", 10),
        info = makeLevel("info", 15, "#85eddf"),
        warning = makeLevel("warn", 20, "#fcba03"),
        error = makeLevel("err", 25, "#fa2e00"),
    },
    handlers = {}
}
table.insert(log.handlers, function(mes, l)
    print(mes)
end)
log.level = log.levels.verbose

---@param l LogLevel
---@param s string
---@param ... any
function log:log(l, s, ...)
	if self.level == log.levels.off or l.level < self.level.level then
		return
	end
    local arg = {...}
    local mes = ""
    for _, value in ipairs(arg) do
        mes = mes .. "\t" .. tostring(value)
    end
    self:pushMessage(("<%s|%s> %s"):format(s, l.name, mes), l)
end

function log:pushMessage(mes, l)
    for _, value in ipairs(self.handlers) do
        value(mes, l)
    end
end

function log:verbose(s, ...)
    self:log(self.levels.verbose, s or "root", ...)
end
function log:debug(s, ...)
    self:log(self.levels.debug, s or "root", ...)
end
function log:info(s, ...)
    self:log(self.levels.info, s or "root", ...)
end
function log:warning(s, ...)
    self:log(self.levels.warning, s or "root", ...)
end
function log:error(s, ...)
    self:log(self.levels.error, s or "root", ...)
end
function log:fatal(s, ...)
    self:log(self.levels.error, "FATAL: "..(s or "root"), ...)
    error(tostring(...))
end

Logger = log
---@class SpecLogger : Logger
local SpecLogger = setmetatable({
	---@type string?
	sawmill = nil
}, { __index = Logger })

function SpecLogger:debug(l, ...) 		Logger:debug(self.sawmill, l, ...) end
function SpecLogger:error(l, ...) 		Logger:error(self.sawmill, l, ...) end
function SpecLogger:fatal(l, ...) 		Logger:fatal(self.sawmill, l, ...) end
function SpecLogger:info(l, ...) 		Logger:info(self.sawmill, l, ...) end
function SpecLogger:verbose(l, ...) 	Logger:verbose(self.sawmill, l, ...) end
function SpecLogger:warning(l, ...) 	Logger:warning(self.sawmill, l, ...) end

function SpecLogger:debugF(l, ...) 		Logger:debug(self.sawmill, string.format( l, ...)) end
function SpecLogger:errorF(l, ...) 		Logger:error(self.sawmill, string.format( l, ...)) end
function SpecLogger:fatalF(l, ...) 		Logger:fatal(self.sawmill, string.format( l, ...)) end
function SpecLogger:infoF(l, ...) 		Logger:info(self.sawmill, string.format( l, ...)) end
function SpecLogger:verboseF(l, ...) 	Logger:verbose(self.sawmill, string.format( l, ...)) end
function SpecLogger:warningF(l, ...) 	Logger:warning(self.sawmill, string.format( l, ...)) end

---@param o SpecLogger
---@return SpecLogger
function SpecLogger:create(o)
	return setmetatable(o or {}, { __index = self })
end

function log:spec(s)
	return SpecLogger:create({ sawmill = s })
end

log.SpecLogger = SpecLogger
log = setmetatable(log, { __call = function(_, s)
	return log:spec(s)
end })
return log