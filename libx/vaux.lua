--[[
Virtual aux by ArcticFqx

No need for an actor if you're just tweening values
Just supply a list of values you want to tween (list will be sorted automatically)

Example vaux object:

local v = vaux { 0,  {                    -- Initial value is 0
        { 40, 10, 1, vaux.Linear },       -- Tween to 40, start at beat 10, lasts for 1 second, use Linear
        { 20, 32, 2, vaux.Spring, true }  -- Tween to 20 (from 40), start at beat 32, lasts for 2 beats, use Spring, bool duration is beats
    } 
}
print(v()) -- prints tweened value at game time
print(v(11)) -- prints tweened value at beat 11
print(v(62, true)) -- prints tweened value at 62 seconds

You can also supply your own ease function, function signature is:
    function ease( start value, end value, percentage into tween (0-1) )

Be careful, start and end value is not guaranteed to be numbers, 
keep numerical functions only on the percentage and only use operators on the values

Included easing functions are exactly the same as found on actors + random:
    vaux.Linear
    vaux.Accelerate
    vaux.Decelerate
    vaux.BounceBegin
    vaux.BounceEnd
    vaux.Spring
    vaux.Sleep
    vaux.Random

]]
local getn = table.getn
local sort = table.sort
local unpack = unpack
local setmetatable = setmetatable
local sin = math.sin
local pi = math.pi
local pc = pi * 2.5

local function timeFromBeat(v)
    return GAMESTATE:GetCurrentSong():GetElapsedTimeFromBeat(v)
end

local vobj = {}
function vobj:__call(beat, isSec, _index)
    if beat then
        self.index = _index or 1
    end

    local i = self.index
    local from = self[2][i - 1]
    local to = self[2][i]
    local val = from[1] or self[1]

    if not to then
        return val
    end

    local goal, start, duration, func = unpack(to)

    local t
    if beat then
        t = isSec and beat or timeFromBeat(beat)
    else
        t = GAMESTATE:GetSongTime()
    end

    local p = (start + duration - t) / duration
    p = p == p and p or 1 -- nan guard

    if p <= 0 then
        return val
    end
    if p >= 1 then
        self.index = i + 1
        return self(beat, isSec, self.index)
    end

    return func(val, goal, p)
end

--[[
function vobj:Run(val, duration, func, isBeat)
    if type(val) == "table" then
        val, duration, func, isBeat = unpack(val)
    end
    local v = self()
    local p = self[2][self.index] or self[2][self.index-1]
    p[1] = v
    local t = {val, GAMESTATE:GetSongTime(), duration, func, isBeat}
    table.insert(self[2], self.index+1,  )
end
]]
vobj.__index = vobj

local vaux = {}

function vaux.Sleep(val, goal, percent)
    return percent < 1 and val or goal
end

function vaux.Linear(val, goal, percent)
    return val + (goal - val) * percent
end

function vaux.Accelerate(val, goal, percent)
    return vaux.Linear(val, goal, percent * percent)
end

function vaux.Decelerate(val, goal, percent)
    local dec = 1 - (1 - percent) * (1 - percent)
    return vaux.Linear(val, goal, dec)
end

function vaux.BounceBegin(val, goal, percent)
    local p = 1 - sin(1.1 + percent * (pi - 1.1)) / 0.89
    return vaux.Linear(val, goal, p)
end

function vaux.BounceEnd(val, goal, percent)
    local p = sin(1.1 + (1 - percent) * (pi - 1.1)) / 0.89
    return vaux.Linear(val, goal, p)
end

function vaux.Spring(val, goal, percent)
    local p = 1 - sin(percent * pc) / (1 + percent * 3)
    return vaux.Linear(val, goal, p)
end

local random = math.random

function vaux.Random(val, goal)
    return vaux.Linear(val, goal, random())
end

function vaux:__call(t)
    local von = {t[1], {}}
    for i = 1, getn(t[2]) do
        von[2][i] = {unpack(t[2][i])}
        if von[2][i][5] then
            von[2][i][3] = timeFromBeat(von[2][i][2] + von[2][i][3])
        end
        von[2][i][2] = timeFromBeat(von[2][i][2])
    end
    sort(
        von[2],
        function(a, b)
            return a[1] < b[1]
        end
    )

    von.index = 1
    von.from = v[1]

    setmetatable(von, vobj)

    return von
end
setmetatable(vaux, vaux)

return vaux
