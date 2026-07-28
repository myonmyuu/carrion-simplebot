---@alias HttpMethod : string
---|"GET"
---|"POST"
---|"DELETE"
---|"PUT"

---@class sse.Event
---@field type string
---@field timestamp string

---@class channeluser
---@field id		integer
---@field name		string
---@field badges	string[]
---@field avatar	string

---@class sse.Event.channel_message : sse.Event
---@field room_jid		string
---@field tab_id		string
---@field sender		channeluser
---@field message_id	string
---@field body			string

---@class https.options
---@field data		string? application/x-www-form-urlencoded
---@field method	HttpMethod?
---@field headers	table<string, string>

---@class SSEReceiver : userdata

---@class love.https
---@field request fun(url:string, options:https.options):code:number, body:string, headers:table<string, string>
local https		= require "https"
---@class SSE
---@field sse_connect	fun(url:string, headers:table, method:string?):SSEReceiver
---@field sse_read		fun(data:SSEReceiver, f:fun(event:string, data:string))
---@field sse_check		fun(data:SSEReceiver):boolean
local sse		= require "sse"
local helpers	= require "lib.helpers"
local event		= require "lib.event"
local json		= require "lib.json"

local log = Logger:spec("carrion")

---@class HttpResponse
local HttpResponse = {
	code	= 0;
	body	= nil;	---@type string
	headers = nil;	---@type table<string, string>
}
---@param c number
---@param b string
---@param h table<string, string>
---@return HttpResponse
function HttpResponse:new(c, b, h)
	return setmetatable({
		code = c;
		body = b;
		headers = h;
	}, { __index = self })
end


---@return table?
function HttpResponse:getbodytable()
	if self.code == 404 then
		return nil
	end
	return json.decode(self.body)
end

---@class CarrionSSEEvents
local CarrionSSEEvents = {
	log			= nil;	---@type SpecLogger
}

---@param o CarrionSSEEvents|table
---@return CarrionSSEEvents
function CarrionSSEEvents:new(o)
	o = o or {}
	o.log = o.log or Logger:spec("sse events")
	return setmetatable(o, {
		__index = self;
		__tostring = function (t)
			return ("(carrion sse events)")
		end
	})
end

---@class CarrionSSE
local CarrionSSE = {
	receiver	= nil;	---@type SSEReceiver
	log			= nil;	---@type SpecLogger
	target		= nil;	---@type CarrionSSE?
}

---@param receiver SSEReceiver
---@param l SpecLogger?
---@param ev CarrionSSEEvents?
---@return CarrionSSE
function CarrionSSE:createfrom(receiver, l, ev)
	local csse = {} ---@type CarrionSSE
	csse.receiver = receiver
	csse.log = l or Logger:spec("csse")
	csse.events = ev or CarrionSSEEvents:new({
		log = csse.log;
	})
	return setmetatable(csse, { __index = self })
end

function CarrionSSE:poll()
	sse.sse_read(self.receiver, function (ev, data)
		self:event_received(ev, data)
	end)
end

---@param event_name	string
---@param body_json		string
function CarrionSSE:event_received(event_name, body_json)
	local ev = self.target[event_name]
	if type(ev) ~= "function" then
		self.log:debugF("invalid event '%s' received, falling back...", event_name)
		ev = CarrionSSEEvents.fallback
	end

	ev(self.target, json.decode(body_json))
end

do --- Events
	function CarrionSSEEvents:fallback(data)
		self.log:debugF("MISSING EVENT!!! fallback;")
		helpers.tprint(data)
	end

	---@param data table
	function CarrionSSEEvents:connected(data)
	end

	do --- Messaging
		function CarrionSSEEvents:channel_message(data)
		end

		function CarrionSSEEvents:dm_message(data)
		end

		function CarrionSSEEvents:classified_response(data)
		end

		function CarrionSSEEvents:love_letter(data)
		end

		function CarrionSSEEvents:cross_character_notification(data)
		end
	end

	do --- Presence
		function CarrionSSEEvents:user_online(data)
		end

		function CarrionSSEEvents:user_offline(data)
		end

		function CarrionSSEEvents:intent_changed(data)
		end

		function CarrionSSEEvents:presence_changed(data)
		end

		function CarrionSSEEvents:in_chat_changed(data)
		end

		function CarrionSSEEvents:profile_updated(data)
		end
	end

	do --- Rooms
		function CarrionSSEEvents:user_joined_room(data)
		end

		function CarrionSSEEvents:user_left_room(data)
		end

		function CarrionSSEEvents:topic_changed(data)
		end
	end

	do --- Moderation
		function CarrionSSEEvents:you_were_kicked(data)
		end

		function CarrionSSEEvents:you_were_banned(data)
		end

		function CarrionSSEEvents:you_were_muted(data)
		end

		function CarrionSSEEvents:you_were_unmuted(data)
		end

		function CarrionSSEEvents:user_kicked(data)
		end

		function CarrionSSEEvents:user_banned(data)
		end

		function CarrionSSEEvents:user_muted(data)
		end

		function CarrionSSEEvents:moderation_action(data)
		end
	end

	do --- Ownership
		function CarrionSSEEvents:claim_granted(data)
		end

		function CarrionSSEEvents:mod_invite(data)
		end

		function CarrionSSEEvents:mod_accepted(data)
		end

		function CarrionSSEEvents:mod_granted(data)
		end

		function CarrionSSEEvents:mod_revoked(data)
		end

		function CarrionSSEEvents:transfer_invite(data)
		end

		function CarrionSSEEvents:ownership_granted(data)
		end
	end

	do --- Other
		function CarrionSSEEvents:broadcast(data)
		end

		function CarrionSSEEvents:blind_date_match(data)
		end

		function CarrionSSEEvents:vault_available(data)
		end

		function CarrionSSEEvents:evicted(data)
		end
	end
end

local CarrionURL = "https://carrion.chat";

---@param addr string
---@param method HttpMethod
local function makeendpoint(addr, method)
	return {CarrionURL.."/api/v1"..addr, method}
end
---@param addr string
---@param method HttpMethod
---@return fun(v:string):[string, HttpMethod]
local function makeendpointv(addr, method)
	return function (v)
		v = helpers.urlencode(v)
		return {CarrionURL.."/api/v1"..(addr:format(v)), method}
	end
end
---@class Carrion
local Carrion = {
	BasePath = nil; ---@type string
	Events = {
		update		= event:new();
		heartbeat	= event:new();
		shutdown	= event:new();
	};
	Url	= "https://carrion.chat";
	Api	= {
		characters = {
			me			= makeendpoint("/characters/me/", "GET");
			byname		= makeendpointv("/characters/by-name/%s/", "GET");
			byident		= makeendpointv("/characters/{%s}/", "GET");
		};
		bots = {
			designate	= makeendpoint("/bots/designate/", "POST");
		};
		room = {
			join		= makeendpoint("/presence/join-room/", "POST");
			leave		= makeendpoint("/presence/leave-room/", "POST");
			disconnect	= makeendpoint("/presence/disconnect/", "POST");
			defaults	= makeendpoint("/presence/default-rooms/", "GET");
			getusers	= makeendpointv("/presence/room/%s/", "GET");
		};
		presence = {
			subscribe	= makeendpoint("/presence/subscribe-rooms/", "POST");
			heartbeat	= makeendpoint("/presence/heartbeat/", "POST");
		};
		events = {
			subscribe	= makeendpointv("/events/subscribe/%s/", "GET");
		};
		channels = {
			ownercommand= makeendpoint("/channels/owner-command/", "POST");
			directory	= makeendpoint("/channels/directory", "GET");
			send		= makeendpointv("/channels/%s/send/", "POST");
			gettabs		= makeendpointv("/channels/tabs/%s", "GET");
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

-- ---@param api string
-- ---@return string
-- function Carrion:getapiurl(api)
-- 	return self.url..(api or "")
-- end

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

---@param t table
---@return https.options
function Carrion:makehttpcontent(t)
	return {
		data = json.encode(t);
	}
end

---@param api [string, string]
---@param options https.options
---@return HttpResponse
function Carrion:request(api, options)
	options.method = api[2]
	local rcode, rbody, rheaders = https.request(api[1], options)
	log:verboseF(
		"received server response for address '%s:%s' (%i): %s",
		api[1],
		api[2],
		rcode,
		rbody or "no body"
	)
	return HttpResponse:new(rcode, rbody, rheaders)
end

---@class BotIdentity
local BotIdentity = {
	name	= nil;	---@type string
	token	= nil;	---@type string
	carrion	= nil;	---@type Carrion
	log		= nil;	---@type SpecLogger

	sse		= nil;	---@type CarrionSSE
	sse_ev	= nil;	---@type CarrionSSEEvents
}
Carrion.BotIdentity = BotIdentity

---@generic T
---@param name string
---@param token string
---@param carrion Carrion
---@param o T?
---@return T
function BotIdentity:create(name, token, carrion, o)
	o = o or {}
	o.name	= name
	o.token	= token
	o.carrion = carrion
	o.log = Logger:spec(o.name)
	o.sse_ev = CarrionSSEEvents:new(setmetatable({}, { __index = o }))

	return setmetatable(
		o, {
			__index = self;
			__tostring = function (t)
				return ("(botidentity (%s))"):format(t.name)
			end;
		})
end

---@param api [string, string]
---@param opt https.options?
---@param cookies table<string, any>?
---@return HttpResponse
function BotIdentity:request(api, opt, cookies)
	opt = opt or {}
	cookies = cookies or self.carrion:makebotcookies()
	opt.headers = opt.headers or self.carrion:makebotheaders(
		cookies or {},
		self.token
	)
	return self.carrion:request(api, opt)
end

function BotIdentity:login()
	local sub_addr = self.carrion.Api.events.subscribe(self.name)[1]
	self.log:debugF("sending sse login... (%s)", sub_addr)
	local sse_receiver = sse.sse_connect(
		sub_addr,
		self.carrion:makebotheaders(self.carrion:makebotcookies(), self.token)
	)
	self.sse = CarrionSSE:createfrom(sse_receiver, self.log)
	self.sse.target = setmetatable({}, {
		__index = function (_, k)
			return self[k] or self.sse[k] or self.sse_ev[k]
		end;
		__newindex = self;
	})

	Carrion.Events.update:register(self.sse, function (...)
		if not sse.sse_check(self.sse.receiver) then
			self.log:info("login expired, relogging...")
			self:unregister()
			self:login()
			return
		end

		self:update(...)
		self.sse:poll()
	end)
	Carrion.Events.heartbeat:register(self.sse, function (...) self:heartbeat(...) end)
	Carrion.Events.shutdown:register(self.sse, function (...) self:shutdown(...) end)
	-- self.sse_poll_task = action:fromFunc(function (act)
	-- 	local login_attempts = 0
	-- 	print("asd")
	-- 	act:delay(0.1)
	-- 	while not sse.sse_check(self.sse.receiver) do
	-- 		self.log:debug("waiting for login...")
	-- 		login_attempts = login_attempts + 1
	-- 		if login_attempts > 20 then
	-- 			self.log:debug("unable to log in, aborting")
	-- 			return
	-- 		end
	-- 		act:delay(0.5)
	-- 	end
	-- 	print("asd 2")
	-- 	while true do
	-- 		local ok, pollres, err = xpcall(self.poll, debug.traceback, self, act)
	-- 		print("POLL RES", ok, pollres, err)
	-- 		if not pollres then
	-- 			-- break
	-- 		end
	-- 		act:delay(0.1)
	-- 	end
	-- 	print("asd 3")
	-- end):run()

	return self.sse
end

function BotIdentity:unregister()
	Carrion.Events.update:unregister(self)
	Carrion.Events.update:unregister(self.sse)
	Carrion.Events.heartbeat:unregister(self)
	Carrion.Events.heartbeat:unregister(self.sse)
	Carrion.Events.shutdown:unregister(self)
	Carrion.Events.shutdown:unregister(self.sse)
end

do --- Event
	function BotIdentity:update(dt)
	end

	function BotIdentity:heartbeat(dt)
		-- print(self, self.log)
		self.log:debug("heartbeating!")
		self:request(Carrion.Api.presence.heartbeat, Carrion:makehttpcontent {
			character_name	= self.name;
			is_active		= true;
		})
	end

	function BotIdentity:shutdown(...)
		
	end
end

---@param name	string
---@param token	string
---@param class BotIdentity?
---@return BotIdentity
function Carrion:createbotidentity(name, token, class)
	class = class or BotIdentity
	return class:create(name, token, self)
end

return Carrion