local vec = {}
local meta = {}

local len = table.getn
local unpack = unpack
local setmetatable = setmetatable
local sqrt = math.sqrt
local format = string.format

local function checkActor(a)
    return function()
        a:getaux()
    end
end

local function newvec(...)
    local new

    if len(arg) == 3 then
        new = {unpack(arg)}
    elseif len(arg) == 2 then
        new = {arg[1], arg[2], 0}
    elseif type(arg[1]) == "number" then
        new = {arg[1], arg[1], arg[1]}
    elseif pcall(checkActor(arg[1])) then
        new = {arg[1]:GetX(), arg[1]:GetY(), arg[1]:GetZ()}
    end

    if new then
        setmetatable(new, meta)
    end

    return new
end

function vec:x()
    return self[1]
end
function vec:y()
    return self[2]
end
function vec:z()
    return self[3]
end
function vec:xy()
    return self[1], self[2]
end
function vec:xyz()
    return unpack(self)
end

function meta:__add(rv)
    return newvec(self[1] + rv[1], self[2] + rv[2], self[3] + rv[3])
end
function meta:__sub(rv)
    return newvec(self[1] - rv[1], self[2] - rv[2], self[3] - rv[3])
end
function meta:__mul(rv)
    return newvec(self[1] * rv, self[2] * rv, self[3] * rv)
end
function meta:__div(rv)
    return newvec(self[1] / rv, self[2] / rv, self[3] / rv)
end

function vec:LengthSqr()
    return self[1] * self[1] + self[2] * self[2] + self[3] * self[3]
end
function vec:Length()
    return sqrt(self[1] * self[1] + self[2] * self[2] + self[3] * self[3])
end

function vec:Dot(rv)
    return self[1] * rv[1] + self[2] * rv[2] + self[3] * rv[3]
end
function vec:Cross(rv)
    return newvec(
        self[2] * rv[3] - self[3] * rv[2],
        self[3] * rv[1] - self[1] * rv[3],
        self[1] * rv[2] - self[2] * rv[1]
    )
end
function vec:GetNormalized()
    return self / self:Length()
end
function vec:Distance(rv)
    return (rv - self):Length()
end

meta.__index = vec
meta.__call = vec.xyz
function meta:__tostring()
    return format("vec(%f, %f, %f)", self[1], self[2], self[3])
end

return newvec
