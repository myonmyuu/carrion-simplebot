---@class love.https
---@field request fun(url:string, options:https.options):code:number, body:string, headers:table<string, string>
local https		= require "https"
---@type SSE
local sse		= require "sse"
---@class CarrionCrypta
---@field decrypt_carrion_message fun(privatekey: string, publickey: string, body: string)
---@field encrypt_carrion_message fun(privatekey: string, publickey: string, body: string)
local crypta	= require "carrion-crypta"
local helpers	= require "lib.helpers"
local event		= require "lib.event"
local json		= require "lib.json"
local fs		= require "lib.fs"

local log = Logger:spec("carrion")
local tprint = helpers.tprint
local topstring = helpers.topstring

local savedir = "save"
local keydir = fs.join(savedir, "keys")

local function getssechannel(name)
	return "channel_sse_"..name
end

local pkeycache = {}	---@type table<Carrion.CharID, Carrion.PublicKey>
local modcache = {}		---@type table<string, Carrion.CharID[]>

---@param channel string
---@return Carrion.CharName[]
local function ensurechannelmods(channel)
	local mods = modcache[channel]
	if not mods then
		mods = {}
		modcache[channel] = mods
	end
	return mods
end

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
		print("returning nil body for 404")
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
	name		= nil;	---@type string
	log			= nil;	---@type SpecLogger
	target		= nil;	---@type CarrionSSE?
	thread		= nil;	---@type love.Thread?
}

---@param l SpecLogger?
---@param ev CarrionSSEEvents?
---@param name string?
---@return CarrionSSE
function CarrionSSE:createfrom(l, ev, name)
	local csse = {} ---@type CarrionSSE
	csse.log = l or Logger:spec("csse")
	csse.events = ev or CarrionSSEEvents:new({
		log = csse.log;
	})
	csse.name = name or "NONAME"
	csse.thread = love.thread.newThread("ssethread.lua")
	return setmetatable(csse, { __index = self })
end

function CarrionSSE:poll()
	-- sse.sse_read(self.receiver, function (ev, data)
	-- 	self:event_received(ev, data)
	-- end)
	local channel = love.thread.getChannel(getssechannel(self.name))
	while channel:peek() do
		local ev, data = unpack(channel:pop())
		self:event_received(ev, data)
	end
end

---@param event_name	string
---@param body_json		string
function CarrionSSE:event_received(event_name, body_json)
	local ev = self.target[event_name]
	if type(ev) ~= "function" then
		self.log:debugF("invalid event '%s' received, falling back...", event_name)
		ev = CarrionSSEEvents.fallback
	end

	ev(self.target, json.decode(body_json), body_json)
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
		return {CarrionURL.."/api/v1"..(addr:format(tostring(v))), method}
	end
end
---@param addr string
---@param method HttpMethod
---@param ... string
---@return fun(v:string, ...:string):[string, HttpMethod]
local function makeendpointvq(addr, method, ...)
	local queries = {...}
	return function (v, ...)
		-- v = helpers.urlencode(v)
		local basepath = CarrionURL.."/api/v1"..(addr:format(tostring(v)))
		local fullpath = basepath
		local qvals = {...}

		for i = 1, #qvals do
			local val = qvals[i]
			if val then
				fullpath = fullpath..("%s%s=%s"):format(
					i == 1 and "?" or "&",
					tostring(queries[math.min(#queries, i)]),
					tostring(val)
				)
			end
		end
		return {fullpath, method}
	end
end

---@class Carrion.User
---@field id				Carrion.CharID
---@field name				Carrion.CharName
---@field presence_state	PresenceState
---@field badges			Badge[]?
---@field avatar			URL
---@field name_color		NameColor
---@field in_chat			boolean
---@field intent			Intent
---@field is_private		boolean?

---@class Carrion
local Carrion = {
	Users		= {};	---@type table<Carrion.CharID, Carrion.User>
	UserIDMap	= {};	---@type table<Carrion.CharName, Carrion.CharID>
	UserIDMapR	= {};	---@type table<Carrion.CharID, Carrion.CharName>
	BasePath	= nil;	---@type string
	Events = {
		update		= event:new();
		heartbeat	= event:new();
		shutdown	= event:new();
		cmd			= event:new();
	};
	Url	= "https://carrion.chat";
	Api	= {
		characters = {
			me			= makeendpoint("/characters/me/", "GET");
			byname		= makeendpointv("/characters/by-name/%s/", "GET");
			byident		= makeendpointv("/characters/%s/", "GET");
			bulk		= makeendpoint("/characters/bulk-profiles/", "POST"); --- send along "names": [ "a", "b"[, ...]]
		};
		bots = {
			designate	= makeendpoint("/bots/designate/", "POST");
		};
		keys = {
			publish		= makeendpoint("/keys/publish/", "POST"); --- "public_key": "string"
			genbotpair	= makeendpoint("/keys/bot/generate-keypair/", "POST");
			mykey		= makeendpoint("/keys/my-key/", "GET");
			keyfrom		= makeendpointv("/keys/%s/", "GET");
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
			disconnect	= makeendpoint("/presence/disconnect/", "POST");
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
		dm = {
			pendingrooms= makeendpoint("/dm/my-pending-rooms/", "GET");
			send		= makeendpoint("/dm/send-message/", "POST");
			pullcradle	= makeendpointv("/dm/cradle/%s/", "GET");
			deletecradle= makeendpointvq("/dm/cradle/%s/", "DELETE", "message_ids")
		}
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


do --- SSE Events
	function CarrionSSEEvents:fallback(data, raw)
		self.log:debug("MISSING EVENT!!! fallback;", topstring(data))
	end

	---@param data sse.EventData.connected
	function CarrionSSEEvents:connected(data)
		Carrion:filluserlist(data)

		-- print(topstring(data))
	end

	function CarrionSSEEvents:keepalive(data)
	end

	function CarrionSSEEvents:error(data)
		self.log:error("SSE error: ", topstring(data))
	end

	local function debugprintevent(o, data, t)
		o.log:debug("(debug)", data.type or t or "unknown", topstring(data))
	end

	do --- Messaging
		---@param data sse.EventData.channel_message
		function CarrionSSEEvents:channel_message(data)
		end

		---@param data sse.EventData.dm_message
		function CarrionSSEEvents:dm_message(data)
		end

		function CarrionSSEEvents:classified_response(data)
		end

		function CarrionSSEEvents:love_letter(data)
		end

		function CarrionSSEEvents:cross_character_notification(data)
			debugprintevent(self, data)
		end
	end

	do --- Presence
		---@param data sse.EventData.user_online
		function CarrionSSEEvents:user_online(data)
			data.name	= data.character
			data.id		= data.character_id
			log:verboseF("user %s (%i) logging in", data.character, data.character_id)
			Carrion.UserIDMap[data.name]	= data.id
			Carrion.UserIDMapR[data.id]		= data.name
			Carrion.Users[data.id]			= data --[[@as Carrion.User]]
		end

		---@param data sse.EventData.user_offline
		function CarrionSSEEvents:user_offline(data)
			log:verboseF("user %s (%i) logging out", data.character, data.character_id)
			Carrion.Users[data.character_id] = nil
			Carrion.UserIDMap[data.character] = nil
			Carrion.UserIDMapR[data.character_id] = nil
		end

		---@param data sse.EventData.intent_updated
		function CarrionSSEEvents:intent_changed(data)
			local user = Carrion.Users[data.character_id]
			if not user then
				log:warningF("got intent update for offline user '%s' (%i)", data.character, data.character_id)
				return
			end
			user.intent = data.intent
		end

		---@param data sse.EventData.presence_changed
		function CarrionSSEEvents:presence_changed(data)
			local user = Carrion.Users[data.character_id]
			if not user then
				log:warningF("got presence update for offline user '%s' (%i)", data.character, data.character_id)
				return
			end
			user.presence_state = data.presence_state
		end

		---@param data sse.EventData.in_chat_changed
		function CarrionSSEEvents:in_chat_changed(data)
			local user = Carrion.Users[data.character_id]
			if not user then
				--- update gets sent after logout
				-- log:warningF("got in chat update for offline user '%s' (%i)", data.character, data.character_id)
				return
			end
			user.in_chat = data.in_chat
		end

		---@param data sse.EventData.profile_updated
		function CarrionSSEEvents:profile_updated(data)
			debugprintevent(self, data)
		end
	end

	do --- Rooms
		---@param data sse.EventData.user_joined_room
		function CarrionSSEEvents:user_joined_room(data)
			self.log:info("joined;", topstring(data))
			if data.role then
				self:sawmod(data)
				local mods = ensurechannelmods(data.room)
---@diagnostic disable-next-line: undefined-field
				if self.request then
					local id = Carrion:getuserid(data.character, self--[[@as BotIdentity]])
					if not table.contains(mods, id) then
					table.insert(mods, id)
				end
				end
			end
		end

		---@param data sse.EventData.user_joined_room
		function CarrionSSEEvents:sawmod(data)
			self.log:verbose("saw mod fallback")
		end

		function CarrionSSEEvents:user_left_room(data)
			-- self.log:verbose("left;", topstring(data))
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
			debugprintevent(self, data)
		end

		function CarrionSSEEvents:mod_invite(data)
			debugprintevent(self, data)
		end

		function CarrionSSEEvents:mod_accepted(data)
			debugprintevent(self, data)
		end

		function CarrionSSEEvents:mod_granted(data)
			debugprintevent(self, data)
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
			debugprintevent(self, data)
		end

		function CarrionSSEEvents:blind_date_match(data)
		end

		function CarrionSSEEvents:vault_available(data)
		end

		function CarrionSSEEvents:evicted(data)
		end
	end
end


---@param data sse.EventData.connected
function Carrion:filluserlist(data)
	for name, id in pairs(data.ids) do
		---@type Carrion.User
		local user = {
			id				= id;
			name			= name;
			avatar			= data.avatars[name];
			badges			= data.badges[name];
			presence_state	= data.presence_states[name];
			in_chat			= data.in_chat[name] or false;
			name_color		= data.name_colors[name];
			intent			= data.intents[name];
		}

		self.UserIDMap[name] = id
		self.UserIDMapR[id] = name
		self.Users[id] = user
	end

end

---@param name Carrion.CharName
---@param bot BotIdentity
---@return Carrion.CharID
function Carrion:getuserid(name, bot)
	local cacheres = self.UserIDMap[name]
	if cacheres then
		return cacheres
	end
	local chreqt = bot:request(self.Api.characters.byname(name)):getbodytable()
	return chreqt and chreqt.id or error(("unable to get id for user '%s'"):format(name))
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
	if rcode ~= 200 then
		log:warningF(
			"received server response for address '%s:%s' (%i): %s",
			api[1],
			api[2],
			rcode,
			rbody or "no body"
		)
	end
	return HttpResponse:new(rcode, rbody, rheaders)
end

---@class BotIdentity
local BotIdentity = {
	name		= nil;	---@type Carrion.CharName
	id			= nil;	---@type Carrion.CharID
	token		= nil;	---@type string
	carrion		= nil;	---@type Carrion
	log			= nil;	---@type SpecLogger

	publickey	= nil;	---@type Carrion.PublicKey
	privatekey	= nil;	---@type string

	sse			= nil;	---@type CarrionSSE
	sse_ev		= nil;	---@type CarrionSSEEvents
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

	return setmetatable(o, {
		__index = self;
		__tostring = function (t)
			return ("(botidentity (%s))"):format(t.name)
		end;
	})
end

---@param room string
function BotIdentity:readcradle(room)
	self.log:verboseF("reading cradle '%s'", room)
	local mesrqt = self:request(Carrion.Api.dm.pullcradle(room)):getbodytable()
	if (not mesrqt) or mesrqt.count == 0 then
		self.log:warningF("tried to read from empty cradle in '%s'", room)
		return
	end
	local publickey ---@type Carrion.PublicKey?
	local function getpublickey(id)
		if not publickey then
			local ok, key = self:getpeerkey(id)
			publickey = ok and key or error(("unable to get key for %s"):format(tostring(id)))
		end
		return publickey
	end

	local ids = {}

	for _, value in pairs(mesrqt.messages) do
		--[[@cast value sse.EventData.dm_message]]
		table.insert(ids, value.message_id)
		local pkey = getpublickey(value.from_id).raw
		self.log:verboseF("message, from: %s (%i). Key: '%s': <%s>", value.from, value.from_id, pkey, value.body)

		local ok, decrypted_message = pcall(
			crypta.decrypt_carrion_message,
			self.privatekey,
			pkey,
			value.body
		)
		if ok then
			self:dm(
				decrypted_message,
				value
			)
		else
			self.log:errorF("error decrypting message: '%s'", tostring(decrypted_message))
		end
	end

	if #ids > 0 then
		-- self:request(Carrion.Api.dm.deletecradle(room, unpack(ids)))
	end
end

function BotIdentity:readdms()
	self.log:verbose("reading dms...")
	local dmreqt = self:request(Carrion.Api.dm.pendingrooms):getbodytable()
	if (not dmreqt) or dmreqt.count == 0 then
		return
	end
	for _, value in pairs(dmreqt.room_jids) do
		self:readcradle(value)
	end
end

---@param message string
---@param ev sse.EventData.dm_message
function BotIdentity:dm(message, ev)
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

---@param rawkey any
---@return Carrion.PublicKey
local function parsepkey(rawkey)
	local key = json.decode(rawkey)
	key.raw = rawkey
	return key
end

function BotIdentity:ensurekeys()
	self.log:info("getting keys...")
	fs.create_directory(keydir)
	local keyfile = fs.join(keydir, self.id)
	local haskey = fs.exists(keyfile)

	if haskey then
		self.log:info("reading stored private key")
		self.privatekey = fs.read(keyfile)
	else
		self.log:info("no saved key found, requesting new keypair")
		local req_t = self:request(Carrion.Api.keys.genbotpair):getbodytable()
		if not req_t or not req_t.success then
			self.log:error("unable to generate new keypair")
			return
		end

		self.privatekey = req_t.private_key_hex or error("error getting private key from http response")
		fs.write(keyfile, self.privatekey)
	end

	self.log:info("retrieving public key")
	local pubreq = self:request(Carrion.Api.keys.mykey):getbodytable()
	local rawkey = pubreq and pubreq.public_key or error("error getting public key from http response")
	self.publickey = parsepkey(rawkey)
	pkeycache[self.id] = self.publickey
	tprint(self.publickey)
	self.log:info("keys OK")
end

---@param id any
---@return boolean
---@return Carrion.PublicKey?
function BotIdentity:getpeerkey(id)
	local key = pkeycache[id]---@type Carrion.PublicKey
	if not key then
		local keyres = self:request(Carrion.Api.keys.keyfrom(id)):getbodytable()
		local rkey = keyres and keyres.public_key
		key = parsepkey(rkey)
	end
	return key ~= nil, key
end

function BotIdentity:login()
	self.log:debug("logging in!")
	local sub_addr = Carrion.Api.events.subscribe(self.name)[1]

	-- local sse_receiver = sse.sse_connect(
	-- 	sub_addr,
	-- 	Carrion:makebotheaders(Carrion:makebotcookies(), self.token)
	-- )
	local req = self:request(Carrion.Api.characters.byname(self.name))
	local req_t = req:getbodytable()
	if not req_t then
		return
	end
	self.id = req_t and req_t.id or error("unable to get bot id")
	self.sse = CarrionSSE:createfrom(self.log, nil, self.name)
	self.sse.target = setmetatable({}, {
		__index = function (_, k)
			return self[k] or self.sse[k] or self.sse_ev[k]
		end;
		__newindex = self;
	})

	self.sse.thread:start(
		getssechannel(self.name),
		sub_addr,
		Carrion:makebotheaders(Carrion:makebotcookies(), self.token)
	)

	Carrion.Events.update:register(self.sse, function (...)
		if not self.sse.thread:isRunning() then
			self.log:info("login expired, relogging...")

			self.log:debug("logging out & unregistering...")
			self:request(Carrion.Api.presence.disconnect)
			self:unregister()
			self.sse = nil

			while self.sse == nil do
				self:login()
				love.timer.sleep(3)
			end
			return
		end

		self:update(...)
		self.sse:poll()
	end)
	Carrion.Events.heartbeat:register(self.sse, function (...) self:heartbeat(...) end)
	Carrion.Events.shutdown:register(self.sse, function (...) self:_shutdown_int(...) end)

	self:ensurekeys()
	self:postlogin()

	-- self:heartbeat()
	return self.sse
end

function BotIdentity:postlogin()
end

function BotIdentity:unregister()
	Carrion.Events.update:unregister(self.sse)
	Carrion.Events.heartbeat:unregister(self.sse)
	Carrion.Events.shutdown:unregister(self.sse)
	if self.sse.thread and self.sse.thread:isRunning() then
		love.thread.getChannel(getssechannel(self.name).."k"):push(true)
		self.sse.thread:wait()
	end
end

do --- Event
	function BotIdentity:update(dt)
	end

	function BotIdentity:heartbeat(dt)
		if not self.sse then
			return
		end
		-- print(self, self.log)
		-- self.log:debug("heartbeating!")
		self:request(Carrion.Api.presence.heartbeat, Carrion:makehttpcontent {
			character_name	= self.name;
			is_active		= true;
		})
	end

	function BotIdentity:_shutdown_int(...)
		self:unregister()
		self:request(Carrion.Api.presence.disconnect)
		self:shutdown(...)
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