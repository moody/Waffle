local Addon = {}
local waffle = assert(loadfile("src/waffle.lua"))

waffle("Waffle", Addon)

return assert(Addon.Waffle)
