 -- -- -- -- -- -- -- -- -- --
-- LibActor global reference --
 -- -- -- -- -- -- -- -- -- --

_G.libactor = {
    _VERSION = 'LibActor 0.4',
    GlobalData = libactor and libactor.GlobalData or {}
}

local requireCache = {}
local actorCache = {}
local messageCache = {}
local sharedData = {}
local devmode = false

libactor.Data = sharedData

-- require with a search path only in your song directory
function libactor.Require(s, ...)
    local name = string.lower(s)
    if requireCache[name] then
        return unpack(requireCache[name])
    end
    local file =
        table.concat {
        string.sub(GAMESTATE:GetCurrentSong():GetSongDir(), 2),
        string.gsub(name, '%.', '/'), '.lua'
    }
    Trace('[LibActor] Loading ' .. file)
    local ret = {assert(loadfile(file))(unpack(arg))}
    requireCache[name] = ret
    return unpack(requireCache[name])
end

-- Used internally for caching purposes
local function includeLua(key)
    local name = string.lower(key)
    if actorCache[name] then
        actorCache[key] = actorCache[name]
        return actorCache[name]
    end
    local pack = libactor.Require(name)
    if not pack then
        local err = 'XML Error: Package "' .. name .. '" does not exist.'
        SCREENMAN:SystemMessage(err) 
        error('\n[LibActor] ' .. err )
    end
    actorCache[name] = pack
    actorCache[key] = pack
    return actorCache[name]
end

-- Convenience for InitCommand
-- Will enable Update if defined and returned value is not false
function libactor.Init(actor)
    local name = actor:GetName()
    local pack = actorCache[name] or includeLua(name)
    local ret = pack.Init(actor)
    if ret ~= false and pack.Update then
        pack.UpdateRate = pack.UpdateRate or 60
        actor:sleep(1 / pack.UpdateRate)
        actor:queuecommand('Update')
    end
    return ret
end

-- Convenience for UpdateCommand
-- Keeps it updating, return false to stop it
function libactor.Update(actor)
    local name = actor:GetName()
    local pack = actorCache[name] or includeLua(name)
    local ret = pack.Update(actor)
    if ret ~= false then
        pack.UpdateRate = pack.UpdateRate or 60
        actor:sleep(1 / pack.UpdateRate)
        actor:queuecommand('Update')
    end
    return ret
end

-- Used for Messages and custom Commands, usually only in XML
function libactor.ApplyCallback(actor, key, script)
    local name = script or actor:GetName()
    local pack = actorCache[name] or includeLua(name)
    messageCache[key] = messageCache[key] or string.sub(key, 3)
    local fn = pack[messageCache[key]]
    if not fn then
        local err = 'XML error: "' .. messageCache[key] .. 
            '" on package "' .. name .. '" does not exist.'
        SCREENMAN:SystemMessage(err) 
        error('\n[LibActor] ' .. err)
    end
    return fn(actor)
end

-- For XML, redirection for actors to other files
libactor.On = {}
local function lbonError()
    local err = 'XML error: Incomplete libactor.On. call.'
    SCREENMAN:SystemMessage(err) 
    Debug('\n[LibActor] ' .. err)
end
function libactor.On:__index(key)
    local onto = {}
    function onto:__index(script)
        messageCache[key] = key
        local ApplyCallback = libactor.ApplyCallback
        return function(actor)
            return ApplyCallback(actor, key, script)
        end
    end
    onto.__call = lbonError
    setmetatable(onto,onto)
    return onto
end
libactor.On.__call = lbonError
setmetatable(libactor.On,libactor.On)

-- For Condition, name can be any available script, will run its Check function
function libactor.Check(key)
    local pack = actorCache[key] or includeLua(key)
    return pack.Check and pack.Check() or false
end

-- Sleep forever
function libactor:__call(actor)
    actor:hidden(1)
    actor:sleep(1 / 0)
end

-- DevMode
-- It self modifies itself by wrapping itself in xpcalls
-- Enable by reading out libactor.DevMode, preferably in a Condition
-- Disable by reading out libactor.Refresh
local function devErrorMsg(err)
    SCREENMAN:SystemMessage('Lua error, check log for details.')
    Debug(tostring(err))
end

local function devProtect(fn)
    return function(...)
        local ret
        local success =
            xpcall(
            function()
                ret = {fn(unpack(arg))}
            end,
            devErrorMsg
        )
        return success and unpack(ret) or nil
    end
end

local function devApplyProtection(name)
    devmode[name] = rawget(libactor, name)
    rawset(libactor, name, devProtect(devmode[name]))
end

local function devEnable()
    devmode = {}

    devApplyProtection('Init')
    devApplyProtection('Update')
    devApplyProtection('ApplyCallback')
    devApplyProtection('Check')
    devApplyProtection('Require')

    Trace '[LibActor] DevMode enabled'
    return true
end

-- Indexing operations, will  check sharedData if there is no match
function libactor:__index(key)
    -- Just return like normal if a key exist
    if rawget(self, key) ~= nil then
        return v
    end
    -- All access to OnSomething is assumed to come from XML
    if messageCache[key] or string.find(key, '^On%u') then
        local ApplyCallback = libactor.ApplyCallback
        return function(actor)
            return ApplyCallback(actor, key)
        end
    end
    -- Housekeeping
    if key == 'Refresh' then
        requireCache = {}
        actorCache = {}
        messageCache = {}
        sharedData = {}
        libactor.Data = sharedData
        if devmode then
            for k, v in pairs(devmode) do
                rawset(libactor, k, v)
            end
            devmode = false
            Trace '[LibActor] DevMode disabled'
        end
        Trace '[LibActor] Cache and shared data cleanup complete'
        return true
    end
    -- Enables DevMode, will always return true
    if key == 'DevMode' then
        if devmode then
            return true
        end
        return devEnable()
    end

    -- Else just return something from sharedData, shortcuts are nice
    return sharedData[key]
end

-- Shortcut to set shared data
function libactor:__newindex(key, value)
    if rawget(self, key) == nil then
        sharedData[key] = value
    end
end

-- And we are done!
setmetatable(libactor, libactor)

Trace '[LibActor] Initialized!'
Trace('[LibActor] We are on version "' .. libactor._VERSION .. '"')
