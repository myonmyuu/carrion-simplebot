Logger = require "lib.log"

local helpers = require "lib.helpers"
local action = require "lib.event.action"

function love.load(arg)
	local startpath	= arg[1];
	local token		= arg[2];
	if not startpath then
		print("path to bot data required")
		love.event.quit(0);
	end
	if not token then
		print("bot token data required")
		love.event.quit(0);
	end

	package.path = package.path..";"
		..startpath.."?.lua;"
		..startpath.."?/init.lua"

	local botinit = require "botinit" ---@type fun(token:string, args:table)
	botinit(token, arg)
end

function love.update(dt)
	action.globalUpdate(dt)
end

function love.draw()
end
