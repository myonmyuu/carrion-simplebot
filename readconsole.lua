local ret_channel = ...

while true do
	local cmdin = io.read("*l")
	if cmdin then
		love.thread.getChannel(ret_channel):push(cmdin)
		if cmdin == "q" then
			break
		end
	end
end

print("closing cmd thread")