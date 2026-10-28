local returnchannel, sub_addr, headers = ...

---@type SSE
local sse = require "sse"

local sse_receiver = sse.sse_connect(
	sub_addr,
	headers
)

while true do
	if love.thread.getChannel(returnchannel.."k"):pop() then
		return
	end
	sse.sse_read(sse_receiver, function (event, data)
		love.thread.getChannel(returnchannel):push({ event, data })
	end)
	love.timer.sleep(0.1)
end