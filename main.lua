Logger = require "lib.log"

require "lib.string"
local helpers	= require "lib.helpers"
local carrion	= require "lib.carrion"
local fs		= require "lib.fs"

UPDATE_TIME		= 0.05
HEARTBEAT_TIME	= 25
local update_elapsed	= 0
local heartbeat_elapsed	= 0

local built = fs.is_directory(love.filesystem.getSource())
BasePath = (built and love.filesystem.getWorkingDirectory() or love.filesystem.getSource())
carrion.BasePath = BasePath;

local messagelimit	= 40
local messagex		= 20
local messagey		= -20
local messagegap	= 4
local messagewidth	= 600

local messages = {}	---@type [love.Text, LogLevel][]
---@param m string
---@param l LogLevel
table.insert(Logger.handlers, function (m, l)
	local message = love.graphics.newText(love.graphics.getFont())
	message:setf(m, messagewidth, "left")
	table.insert(messages, {message, l})

	if #messages > messagelimit then
		table.remove(messages, 1)
	end
end)

local function startbot(arg)
	local startpath	= arg[1]
	local token		= arg[2]
	if not startpath then
		print("path to bot data required")
		love.event.quit(0)
	end
	if not token then
		print("bot token data required")
		love.event.quit(0)
	end

	package.path = package.path..";"
		..startpath.."?.lua;"
		..startpath.."?/init.lua"

	local botinit = require "botinit" ---@type fun(token:string, args:table)
	botinit(token, arg)
end

---@param arg table
function love.load(arg)

	startbot(arg)
end

function love.update(dt)
	update_elapsed = update_elapsed + dt
	heartbeat_elapsed = heartbeat_elapsed + dt

	if update_elapsed > UPDATE_TIME then
		update_elapsed = update_elapsed - UPDATE_TIME
		carrion.Events.update(UPDATE_TIME)
	end

	if heartbeat_elapsed > HEARTBEAT_TIME then
		heartbeat_elapsed = heartbeat_elapsed - HEARTBEAT_TIME
		carrion.Events.heartbeat(HEARTBEAT_TIME)
	end
end

function love.draw()
	local y = love.graphics.getHeight() + messagey
	for i = #messages, 1, -1 do
		local mes, _l = unpack(messages[i])
		y = y - mes:getHeight() - 4
		love.graphics.setColor(love.math.colorFromBytes(_l.color[1], _l.color[2], _l.color[3]))
		love.graphics.draw(mes, messagex, y)
		love.graphics.setColor(1, 1, 1, 1)
	end
end

function love.quit()
	carrion.Events.shutdown()
end