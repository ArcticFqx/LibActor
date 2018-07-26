 -- -- -- -- -- -- -- -- -- --
-- LibActor global reference --
 -- -- -- -- -- -- -- -- -- --

_G.libactor = {_VERSION = "LibActor 0.1"}


-- -- -- -- -- - - -- -- -- -- --
-- First lets add some utility --
-- -- -- -- -- - - -- -- -- -- --

-- Redefine global require
-- As far as I know, this is the first ever script using it, so it *should* be safe
local oldrequire = _G.require
function _G.require(s, ...)
    local file =
        table.concat {
        string.sub(GAMESTATE:GetCurrentSong():GetSongDir(), 2),
        string.gsub(s, "%.", "/"),
        ".lua"
    }
    _LOADED[file] = false
    Trace("[LibActor] Loading " .. file)
    return oldrequire(file)
end

-- Why not?
_G.math.huge = 1 / 0

-- From Lua 5.1
function _G.string.match(s, pattern, init)
    local a, b = string.find(s, pattern, init)
    if a then
        return string.sub(s, a, b)
    end
end

-- Internal utility function
local actorCache = {}
local function includeLua(name, intent, actor, typeOveride)
    name = string.lower(name)
    if actorCache[name] then
        return actorCache[name]
    end
    local succ, ret = pcall(require, name)
    if succ then
        actorCache[name] = ret
        return ret
    else
        local type = typeOveride or string.match(tostring(actor), "^%w+")
        local msg = table.concat {
            "XML error: Failed to load Lua file\n\tfrom Actor/Condition '",
            name, "' of type '", type, "' on attribute/callback '", intent,
            "'\n\nYou should take a closer look at '",
            string.sub(GAMESTATE:GetCurrentSong():GetSongDir(), 2),
            "lua/", string.gsub(name, "%.", "/"), ".lua'\n\n",
            tostring(ret)
        }
        error(msg, 3)
    end
end


-- -- -- -- -- -- -- -- --
-- LibActor starts here --
-- -- -- -- -- -- -- -- --

local messageCache = {}
local sharedData = {}

-- Feel free to use me as you see fit
libactor.GlobalData = {}

-- Loads and runs InitCommand, will enable Update if defined
function libactor.Init(actor)
    local name = actor:GetName()
    local pack = includeLua(name, "InitCommand", actor)
    if pack.Update then
        pack.UpdateRate = pack.UpdateRate or 60
        actor:sleep(1 / pack.UpdateRate)
        actor:queuecommand("Update")
    end
    return pack.Init(actor)
end

-- Keeps it updating
function libactor.Update(actor)
    local name = string.lower(actor:GetName())
    local pack = actorCache[name] or includeLua(name, "UpdateCommand", actor)
    local ret = pack.Update(actor)
    if ret ~= false then
        actor:sleep(1 / pack.UpdateRate)
        actor:queuecommand("Update")
    end
    return ret
end

-- Used for Messages and custom Commands
function libactor.ApplyCallback(actor, key)
    local name = string.lower(actor:GetName())
    local pack = actorCache[name] or includeLua(name, key, actor)
    messageCache[key] = messageCache[key] or string.sub(key, 3)
    return pack[messageCache[key]](actor)
end

-- For Condition, name can be any available script, will run its Check function
function libactor.Check(key)
    local name = string.lower(key)
    local pack = actorCache[name] or includeLua(name, "Condition", nil, "Function")
    return pack.Check and pack.Check() or false
end

-- Sleep forever
function libactor:__call(actor)
    actor:hidden(1)
    actor:sleep(math.huge)
end

-- Creates a special case for On-commands
function libactor:__index(key)
    -- Just return like normal if a key exist
    if rawget(self, key) ~= nil then
        return v
    end
    -- All access to OnSomething is assumed to come from XML
    if string.find(key, "^On%u") then
        return function(actor)
            return libactor.ApplyCallback(actor, key)
        end
    end
    -- Will always return the latest sharedData
    if key == "Data" then
        return sharedData
    end
    -- Housekeeping
    if key == "Refresh" then
        actorCache = {}
        messageCache = {}
        sharedData = {}
        Trace "[LibActor] Cache and shared data cleanup complete"
        return true
    end
    -- Else just return something from sharedData, shortcuts are nice
    return sharedData[key]
end

-- Shortcut to set shared data
function libactor:__newindex(key, value)
    if rawget(self, key) ~= nil then
        return
    end
    sharedData[key] = value
end

-- And we are done!
setmetatable(libactor, libactor)

Trace "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
Trace "[LibActor] initialized!"
Trace("[LibActor] We are on version '" .. libactor._VERSION .. "'")
Trace "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
