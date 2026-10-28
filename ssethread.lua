require "love.timer"

local logger = require "lib.log"

local returnchannel, sub_addr, headers = ...
local log = logger:spec(returnchannel)

---@type SSE
local sse = require "sse"

log:infoF("sending sse login... (%s)", sub_addr)
local sse_receiver = sse.sse_connect(
	sub_addr,
	headers
)

while sse.sse_check(sse_receiver) do
	if love.thread.getChannel(returnchannel.."k"):pop() then
		log:info(returnchannel, "SSE shutdown requested")
		sse.sse_close(sse_receiver)
		return
	end
	sse.sse_read(sse_receiver, function (event, data)
		love.thread.getChannel(returnchannel):push({ event, data })
	end)
	love.timer.sleep(0.1)
end

log:info(returnchannel, "SSE dead")