---@alias HttpsMethod
---|"GET"
---|"POST"
---|"DELETE"
---|"PUT"

---@class https.options
---@field data		string? application/x-www-form-urlencoded
---@field method	HttpsMethod?
---@field headers	table<string, string>

---@class SSEData : userdata

---@class love.https
---@field request fun(url:string, options:https.options):code:number, body:string, headers:table<string, string>
local https		= require "https"
---@class SSE
---@field sse_connect	fun(url:string, headers:table, method:string?):SSEData
---@field sse_read		fun(data:SSEData, f:fun(event:string, data:string))
---@field sse_check		fun(data:SSEData):boolean
local sse		= require "sse"
local helpers	= require "lib.helpers"
local event		= require "lib.event"
local action	= require "lib.event.action"

---@class Carrion
local Carrion = {
	url	= "https://carrion.chat";
	api	= {
		characters = {
			me = {"/api/v1/characters/me/", "GET"};
		};
		bots = {
			designate = {"/api/v1/bots/designate/", "POST"};
		};
		events = {
			subscribe = function (name)
				return {("/api/v1/events/subscribe/%s/"):format(name), "GET"}
			end;
		};
	};
	headers = {
		content	= "Content-Type";
		cookie	= "Cookie";
		agent	= "User-Agent";
		auth	= "Authorization";
	};
	content_types = {
		json	= "application/json";
	};
}

---@param api string
---@return string
function Carrion:getapiurl(api)
	return self.url..(api or "")
end

---@param sessionid string
---@return table
function Carrion:makeusercookies(sessionid)
	return {
		age_verified	= true;
		sessionid		= sessionid;
	}
end

function Carrion:makebotcookies()
---@diagnostic disable-next-line: param-type-mismatch
	return self:makeusercookies(nil)
end

---@param cookies table<string, any>
---@param ctype string?
---@param token string
---@return unknown
function Carrion:makebotheaders(cookies, token, ctype)
	local headers = self:makeheaders(cookies, ctype)
	headers[self.headers.auth]	= "Bearer "..token
	return headers
end

---@param cookies table<string, any>
---@param ctype string?
---@return table
function Carrion:makeheaders(cookies, ctype)
	cookies = cookies or {}
	return {
		[self.headers.agent]	= "application/lua";
		[self.headers.content]	= ctype or self.content_types.json;
		[self.headers.cookie]	= helpers.make_cookies(cookies);
	}
end

---@param api [string, string]
---@param options https.options
---@return number code, string body, table<string, string> headers
function Carrion:request(api, options)
	options.method = api[2]
	return https.request(
		self:getapiurl(api[1]),
		options
	)
end

---@class BotIdentity
local BotIdentity = {
	Api		= Carrion.api;

	name	= nil;	---@type string
	token	= nil;	---@type string
	carrion	= nil;	---@type Carrion
	log		= nil;	---@type SpecLogger

	sse_receiver	= nil;	---@type SSEData?
	sse_poll_task	= nil;	---@type Action?
}

---@param api [string, string]
---@param opt https.options?
---@param cookies table<string, any>?
---@return number code, string body, table<string, string> headers
function BotIdentity:request(api, opt, cookies)
	opt = opt or {}
	cookies = cookies or self.carrion:makebotcookies()
	opt.headers = opt.headers or self.carrion:makebotheaders(
		cookies or {},
		self.token
	)
	local rcode, rbody, rheaders = self.carrion:request(api, opt)
	self.log:debugF("received server response (%i): %s", rcode, rbody or "no body")
	return rcode, rbody, rheaders
end

function BotIdentity:login()
	self.log:debug("sending sse login...")
	self.sse_receiver = sse.sse_connect(
		self.carrion:getapiurl(self.Api.events.subscribe(self.name)[1]),
		self.carrion:makebotheaders(self.carrion:makebotcookies(), self.token)
	)

	self.sse_poll_task = action:fromFunc(function (act)
		self:poll(act)
	end):run()

	return self.sse_receiver
end

---@param act Action
function BotIdentity:poll(act)
	while true do
		if not sse.sse_check(self.sse_receiver) then
			act:delay(0.5)
			self.log:info("login expired, relogging...")
			self:login()
			return
		end

		sse.sse_read(self.sse_receiver, wraptfunc(self, self.event_received))

		act:delay(0.1)
	end
end

---@param event_name	string
---@param body_json		string
function BotIdentity:event_received(event_name, body_json)
	
end

do --- Events
	
end

function BotIdentity:register()
	self.log = Logger:spec(self.name)
end

---@param name	string
---@param token	string
---@return BotIdentity
function Carrion:createbotidentity(name, token)
	local bot = setmetatable({
		name	= name;
		token	= token;
		carrion	= self;
	}, { __index = BotIdentity })
	bot:register()
	return bot
end

return Carrion