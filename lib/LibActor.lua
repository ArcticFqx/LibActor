 -- -- -- -- -- -- -- -- -- --
-- LibActor global reference --
 -- -- -- -- -- -- -- -- -- --

local libactor = {
    _VERSION = 'LibActor 0.4.4',
    GlobalData = libactor and libactor.GlobalData or {}
}

_G.libactor = libactor
_G.lax = libactor

-- Localize Lua functions that gets called fairly often
-- No point in doing that for C userdata and error
local lower = string.lower
local gsub = string.gsub
local unpack = unpack
local gfind = string.gfind
local loadfile = loadfile
local Debug = Debug
local Trace = Trace
local print = print
local getn = table.getn
local find = string.find
local sub = string.sub
local setmetatable = setmetatable
local pairs = pairs
local rawset,rawget = rawset, rawget

-- Initialize state/cache
local requireCache = {}
local actorCache = {}
local messageCache = {}
local sharedData = {}
local lastPath = ''
local devmode = false

libactor.Data = sharedData

local devErrorMsg

-- Require with a search path in your song directory, caches path hits and results
function libactor.Require(s, ...)
    local name = lower(s)

    -- First check if we have a cached pack
    if requireCache[name] then
        return unpack(requireCache[name])
    end

    local folder = gsub(lower(GAMESTATE:GetCurrentSong():GetSongDir()), '/songs', '')
    local file = gsub(name, '%.', '/') .. '.lua'
    local path, func, err
    local log = {}

    -- Then build search path
    local addSongs = lower(PREFSMAN:GetPreference('AdditionalSongFolders'))
    local addFolder = lower(PREFSMAN:GetPreference('AdditionalFolders'))
    local add = lastPath .. './songs,' .. addSongs .. ','
                .. gsub(addFolder, ',' ,'/songs,') .. '/songs'

    -- Try each path
    for w in gfind(add,'[^,]+') do
        path = w .. folder .. file
        func, err = loadfile(path)
        if func then
            Debug('[LibActor] Loading ' .. path)
            lastPath = w .. ','
            local oldarg = _G.arg
            _G.arg = arg
            requireCache[name] = {func()}
            _G.arg = oldarg
            return unpack(requireCache[name])
        end
        log[getn(log)+1] = err
    end

    -- Pick suitable error
    for i=1, getn(log) do
        if not find(log[i], 'cannot read') then
            error(log[i], devmode and 2 or 1)
        end
    end
    error(log[1])
end

-- Used internally for caching purposes
local function includeLua(key)
    local name = lower(key)
    if actorCache[name] then
        actorCache[key] = actorCache[name]
        return actorCache[name]
    end
    local pack = libactor.Require(name)
    if not pack then
        local err = '[LibActor] XML Error: Could not load package "' .. name .. '".'
        error(err, -1)
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
function libactor.ApplyCallback(actor, key, script, ...)
    local name = script or actor:GetName()
    local pack = actorCache[name] or includeLua(name)
    messageCache[key] = messageCache[key] or sub(key, 3)
    local fn = pack[messageCache[key]]
    if not fn then
        local err = '[LibActor] XML error: "' .. messageCache[key] ..
            '" on package "' .. name .. '" does not exist.'
        error(err, -1)
    end
    return fn(actor, unpack(arg))
end

-- For XML, redirection for actors to other files
libactor.On = {}
local function lbonError()
    devErrorMsg('[LibActor] XML error: Incomplete libactor.On. call.')
end
function libactor.On:__index(key)
    local onto = {}
    function onto:__index(script)
        messageCache[key] = key
        local ApplyCallback = libactor.ApplyCallback
        return function(actor, ...)
            return ApplyCallback(actor, key, script, unpack(arg))
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
function devErrorMsg(err)
    print() -- Spacer to make error easy to find
    SCREENMAN:SystemMessage('[LibActor] Lua error: Check log for details.')
    Debug(tostring(err))
    print() -- Spacer
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
    -- All access to OnSomething is assumed to come from XML
    if messageCache[key] or find(key, '^On%u') then
        local ApplyCallback = libactor.ApplyCallback
        return function(actor)
            return ApplyCallback(actor, key)
        end
    end
    -- Housekeeping
    if key == 'Refresh' then
        requireCache = {}
        lastPath = ''
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
