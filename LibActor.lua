 -- -- -- -- -- -- -- -- -- --
-- LibActor global reference --
 -- -- -- -- -- -- -- -- -- --

_G.libactor = {
    _VERSION = 'LibActor 0.3',
    GlobalData = libactor and libactor.GlobalData or {}
}

-- require with a search path only in your song directory
local requireCache = {}
local function requireLua(s, ...)
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

libactor.require = requireLua

local actorCache = {}
local function includeLua(key)
    local name = string.lower(key)
    if actorCache[name] then
        actorCache[key] = actorCache[name]
        return actorCache[name]
    end
    actorCache[name] = requireLua(name)
    actorCache[key] = actorCache[name]
    return actorCache[name]
end

local messageCache = {}
local sharedData = {}

-- Loads and runs InitCommand, will enable Update if defined
function libactor.Init(actor)
    local name = actor:GetName()
    local pack = includeLua(name)
    if pack.Update then
        pack.UpdateRate = pack.UpdateRate or 60
        actor:sleep(1 / pack.UpdateRate)
        actor:queuecommand('Update')
    end
    return pack.Init(actor)
end

-- Keeps it updating
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

-- Used for Messages and custom Commands
function libactor.ApplyCallback(actor, key)
    local name = actor:GetName()
    local pack = actorCache[name] or includeLua(name, key, actor)
    messageCache[key] = messageCache[key] or string.sub(key, 3)
    return pack[messageCache[key]](actor)
end

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

local devmode
local function enableDevmode()
    devmode = {}

    local function errorMsg(err)
        Debug(tostring(err))
        SCREENMAN:SystemMessage('Lua error, check log for details.')
    end

    local function protect(fn)
        return function(...)
            local ret
            local succ =
                xpcall(
                function()
                    ret = {fn(unpack(arg))}
                end,
                errorMsg
            )
            return succ and unpack(ret) or nil
        end
    end

    local function applyProtection(name)
        devmode[name] = rawget(libactor, name)
        rawset(libactor, name, protect(devmode[name]))
    end

    applyProtection('Init')
    applyProtection('Update')
    applyProtection('ApplyCallback')
    applyProtection('Check')
    applyProtection('__call')
    applyProtection('__index')
    applyProtection('require')

    Trace '[LibActor] DevMode enabled'
    return true
end

-- Creates a special case for On-commands
function libactor:__index(key)
    -- Just return like normal if a key exist
    if rawget(self, key) ~= nil then
        return v
    end
    -- All access to OnSomething is assumed to come from XML
    if messageCache[key] or string.find(key, '^On%u') then
        return function(actor)
            return libactor.ApplyCallback(actor, key)
        end
    end
    -- Will always return the latest sharedData
    if key == 'Data' then
        return sharedData
    end
    -- Housekeeping
    if key == 'Refresh' then
        requireCache = {}
        actorCache = {}
        messageCache = {}
        sharedData = {}
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

    if key == 'DevMode' then
        if devmode then
            return true
        end
        return enableDevmode()
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

Trace ' '
Trace '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
Trace '[LibActor] initialized!'
Trace('[LibActor] We are on version \'' .. libactor._VERSION .. '\'')
Trace '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
Trace ' '
