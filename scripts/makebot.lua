--- Requires lua-https: https://github.com/love2d/lua-https
--- 

---@class love.https
---@field request fun(url:string, options:https.options):code:number, body:string, headers:table<string, string>
local https		= require "https"
local json		= require "lib.json"
local helpers	= require "lib.helpers"
local carrion	= require "lib.carrion"

local
	session,
	ch_id,
	ch_name,
	bot_desc
	= ...

print("running bot setup...")

local req_data = json.encode {
	character_id	= ch_id;
	character_name	= ch_name;
	bot_description	= bot_desc;
}

local cookies = carrion:makeusercookies(session)

local res_code, res_body, res_headers
--[[
do
	res_code, res_body, res_headers = https.request(
		carrion:getapiurl(carrion.api.characters.me),
		{
			method	= "GET";
			headers = {
				--[headers.content]	= content_types.json;
				[headers.cookie] = helpers.make_cookies(cookies);
				[headers.agent]	= "application/lua";
			};
			--data = req_data;
		}
	)
end
]]

do
	res_code, res_body, res_headers = carrion:request(
		carrion.Api.bots.designate,
		{
			headers = carrion:makeheaders(cookies);
			data	= req_data;
		}
	)
end



print()
helpers.tprint(res_code)
print()
helpers.tprint(res_body)
print()
helpers.tprint(res_headers)
