local _, ns = ...
-- luacheck: globals unpack table CopyTable floor AbbreviateNumbers gsub strsub strmatch strupper strfind

-- table: setn, insert, getn, foreachi, maxn, foreach, concat, create, removemulti, sort, wipe, remove
-- string: split, match, gmatch, upper, gsub, format, lower, sub, gfind, rep, char, rtgsub, join, reverse, byte, trim, len, find
-- math: log, acos, ldexp, huge, pi, pow, tanh, deg, tan, cosh, cos, random, sinh, frexp, ceil, floor, rad, abs, sqrt, modf, asin, min, max, fmod, log10, atan2, exp, sin, atan

-- wow api
-- AbbreviateNumbers Interface/AddOns/Blizzard_SharedXMLBase/TableUtil.lua

ns.lua = {
  -- return a function that transforms a table by selecting the provided key
  Select = function(k) return function(t) return t[k] end end,
}
