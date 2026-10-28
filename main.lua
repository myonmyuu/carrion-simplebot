Logger = require "lib.log"
local rootlog = Logger:spec("simplebot-root")

local messages = {}	---@type [love.Text, LogLevel][]
local messagelimit	= 80
local messagewidth	= 600

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

require "lib.string"
local helpers	= require "lib.helpers"
local carrion	= require "lib.carrion"
local fs		= require "lib.fs"
local json		= require "lib.json"

UPDATE_TIME		= 0.2
HEARTBEAT_TIME	= 25
local update_elapsed	= 0
local heartbeat_elapsed	= 0

local built = fs.is_directory(love.filesystem.getSource())
rootlog:verbose("simplebot built:", built, love.filesystem.getSource())
BasePath = (built and love.filesystem.getWorkingDirectory() or love.filesystem.getSource())
carrion.BasePath = BasePath;

local messagex		= 20
local messagey		= -20
local messagegap	= 4

local cmdchannel	= "channel_cmd"
local cmdthread		---@type love.Thread

local addedpaths = {}


---@param path string
---@param file string
local function startbotat(path, file)
	if not table.contains(addedpaths, path) then
		table.insert(addedpaths, path)
		package.path = package.path..";"
			..path.."?.lua;"
			..path.."?/init.lua"
	end

	require(file) -- should run the bot without a distinct call
end

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

local function designatebot(session, chid, chname, botdesc)
	local cookies = carrion:makeusercookies(session)
	local response = carrion:request(
		carrion.Api.bots.designate,
		{
			headers	= carrion:makeheaders(cookies);
			data	= json.encode {
				character_id	= chid;
				character_name	= chname;
				bot_description	= botdesc;
			}
		}
	):getbodytable()

	helpers.tprint(response)
end

function GetToken(name)
	local filename = fs.parent(BasePath).."/tokens/"..name..".token"
	rootlog:verbose("token path: ", filename)
	local exists = fs.file_exists(filename)
	if not exists then
		return false, nil
	end
	local token = fs.read_to_string(filename)
	rootlog:verbose("token: ", token)
	return type(token) == "string", (token or ""):gsub("\n", "")
end

local function initcmdthread()
	rootlog:info("starting cmd thread")
	cmdthread = love.thread.newThread("readconsole.lua")
	cmdthread:start(cmdchannel)
	carrion.Events.update:register(cmdthread, function (dt)
		local cmdres = love.thread.getChannel(cmdchannel):pop()
		if cmdres then
			if cmdres == "q" then
				love.event.quit(0)
				return
			end
			carrion.Events.cmd(cmdres)
		end
	end)
end

---@param arg table
function love.load(arg)
	_G.arg = arg
	rootlog:verbose("save dir:", love.filesystem.getSaveDirectory())
	rootlog:verbose("source dir:", love.filesystem.getSource())
	rootlog:verbose("working dir:", love.filesystem.getWorkingDirectory())
	local action = arg[1]
	if not action then
		rootlog:verbose("Hello world!")
	elseif action == "designate" then
		designatebot(arg[2], arg[3], arg[4], arg[5])
	else
		initcmdthread()
		startbotat(arg[1], arg[2])
	end
end

local usercount = 0
local inchatcount = 0

---Löve event for a frame update
---@param dt number
function love.update(dt)
	local ok, res = pcall(Update, dt)
	if not ok then
		rootlog:errorF("error in update: '%s'", tostring(res))
	end
end

---Actual update function that's called protected
---@param dt number
function Update(dt)
	update_elapsed = update_elapsed + dt
	heartbeat_elapsed = heartbeat_elapsed + dt

	if update_elapsed > UPDATE_TIME then
		update_elapsed = update_elapsed - UPDATE_TIME
		carrion.Events.update(UPDATE_TIME)
	end

	if heartbeat_elapsed > HEARTBEAT_TIME then
		heartbeat_elapsed = heartbeat_elapsed - HEARTBEAT_TIME
		carrion.Events.heartbeat(HEARTBEAT_TIME)

		usercount = 0
		inchatcount = 0
		for _, user in pairs(carrion.Users) do
			usercount = usercount + 1
			inchatcount = inchatcount + (user.in_chat and {1} or {0})[1]
		end
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

	love.graphics.print(("Online users: %i.  In chat: %i."):format(usercount, inchatcount))
end

function love.quit()
	carrion.Events.shutdown()
end