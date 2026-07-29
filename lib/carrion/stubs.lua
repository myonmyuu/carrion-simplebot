--- HTML

---@class URL : string

---@alias HttpMethod : string
---|"GET"
---|"POST"
---|"DELETE"
---|"PUT"

---@class https.options
---@field data		string? application/x-www-form-urlencoded
---@field method	HttpMethod?
---@field headers	table<string, string>

--- SSE

---@class SSEReceiver		: userdata
---@class Carrion.CharName	: string
---@class Carrion.CharID	: integer

---@alias PresenceState : string
---|"online"
---|"lurking"
---|"away"
---|"absent"

---@alias Intent : string
---|"none"
---|"looking_rp"
---|"introduce"
---|"lewd_dms"
---|"open_pitches"
---|"dnd"
---|"friends_only"

---@alias Badge : string
---|"alpha"
---|"janitor"
---|"admin"
---|"bot"
---|"pre-alpha"
---|"subscsriber"
---|"beta"

---@alias NameColor : string
---|"black"
---|"dull_teal"

---@class sse.EventData

---@class sse.TypedEventData : sse.EventData
---@field type string

---@class sse.TimedEventData : sse.EventData
---@field timestamp string

---@class channeluser
---@field id		integer
---@field name		string
---@field badges	string[]
---@field avatar	string

---@class sse.EventData.channel_message : sse.TypedEventData, sse.TimedEventData
---@field room_jid		string
---@field tab_id		string
---@field sender		channeluser
---@field message_id	string
---@field body			string

---@class sse.EventData.connected : sse.EventData
---@field server_version	string
---@field presence_states	table<Carrion.CharName, PresenceState>
---@field in_chat			table<Carrion.CharName, boolean>
---@field badges			table<Carrion.CharName, Badge[]>
---@field ids				table<Carrion.CharName, Carrion.CharID>
---@field online_characters	Carrion.CharName[]
---@field avatars			table<Carrion.CharName, URL>
---@field name_colors		table<Carrion.CharName, NameColor>
---@field intents			table<Carrion.CharName, Intent>

---@class sse.IDEventData : sse.EventData
---@field character			Carrion.CharName
---@field character_id		Carrion.CharID

---@class sse.EventData.user_online : sse.TypedEventData, sse.IDEventData
---@field badges			Badge[]
---@field in_chat			boolean
---@field name_color		NameColor
---@field intent			Intent
---@field presence_state	PresenceState
---@field avatar			URL

---@class sse.EventData.user_offline : sse.TypedEventData, sse.IDEventData

---@class sse.EventData.presence_changed : sse.TypedEventData, sse.IDEventData
---@field presence_state	PresenceState

---@class sse.EventData.in_chat_changed : sse.TypedEventData, sse.IDEventData
---@field in_chat			boolean

---@class sse.EventData.profile_updated : sse.TypedEventData, sse.IDEventData
---@field avatar			URL?
---@field name_color		NameColor?

---@class sse.EventData.intent_updated : sse.TypedEventData, sse.IDEventData
---@field intent			Intent
