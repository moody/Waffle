--- @type Waffle
local Waffle = require("test/waffle")

-- =============================================================================
-- Setup
-- =============================================================================

--- The most memory a steady-state `Layout()` pass may allocate, in bytes. The
--- measured cost is a few bytes, and the smallest regression, one new table
--- per pass, is about 40, so this sits between the two.
local MAX_BYTES_PER_LAYOUT = 16

--- Returns a frame whose methods allocate nothing, unlike the recording mock
--- frames, so only Waffle's own allocations are measured.
--- @return WaffleFrame
local function CreateFrame()
  return {
    SetWidth = function() end,
    SetHeight = function() end,
    SetPoint = function() end,
    ClearAllPoints = function() end,
    SetParent = function() end,
    Show = function() end,
    Hide = function() end
  }
end

--- Returns `count` fixed-size icon nodes.
--- @param count integer
--- @return WaffleFlexNode[]
local function CreateIcons(count)
  local icons = {}
  for i = 1, count do icons[i] = { frame = CreateFrame(), width = 32, height = 32 } end
  return icons
end

--- @class AllocationTestSpec
--- @field description string What the tree exercises.
--- @field node WaffleFlexNode A root node with a numeric `width` of `200`.

--- Each tree exercises paths the others do not.
--- @type AllocationTestSpec[]
local SPECS = {
  {
    description = "flexible, constrained, shrinking, wrapping, and AUTO children",
    node = {
      frame = CreateFrame(),
      direction = "COLUMN",
      width = 200,
      height = 400,
      padding = 4,
      gap = 4,
      children = {
        {
          frame = CreateFrame(),
          direction = "ROW",
          height = 30,
          children = {
            { frame = CreateFrame(), grow = 1,   minWidth = 20, maxWidth = 60 },
            { frame = CreateFrame(), grow = 2 },
            { frame = CreateFrame(), width = 50, shrink = 1,    minWidth = 10 },
          }
        },
        { frame = CreateFrame(), direction = "ROW", wrap = true, height = "AUTO", gap = 2, lineGap = 2, children = CreateIcons(12) },
        {
          frame = CreateFrame(),
          direction = "COLUMN",
          height = "AUTO",
          children = { { frame = CreateFrame(), height = 10 }, { frame = CreateFrame(), height = 12 } }
        },
        { frame = CreateFrame() },
      }
    }
  },
  {
    description = "reversed directions, wrapping lines, and every justify value",
    node = {
      frame = CreateFrame(),
      direction = "COLUMN_REVERSE",
      justify = "SPACE_AROUND",
      width = 200,
      height = 400,
      children = {
        { frame = CreateFrame(), direction = "ROW_REVERSE", justify = "SPACE_BETWEEN", height = 30, children = CreateIcons(3) },
        { frame = CreateFrame(), direction = "ROW_REVERSE", justify = "END",           wrap = true, height = 70,              children = CreateIcons(8) },
        { frame = CreateFrame(), direction = "ROW",         justify = "CENTER",        height = 30, children = CreateIcons(2) },
        { frame = CreateFrame(), direction = "ROW",         justify = "SPACE_EVENLY",  height = 30, children = CreateIcons(2) },
      }
    }
  },
  {
    description = "alignment, margins, and percentage sizes",
    node = {
      frame = CreateFrame(),
      direction = "ROW",
      align = "CENTER",
      width = 200,
      height = 100,
      padding = 2,
      children = {
        { frame = CreateFrame(), width = "25%", height = 40,    margin = 3 },
        { frame = CreateFrame(), width = 50,    height = 30,    alignSelf = "END",  marginLeft = 2 },
        { frame = CreateFrame(), width = 40,    height = "50%", alignSelf = "START" },
        { frame = CreateFrame(), grow = 1,      height = 20,    minWidth = 10 },
      }
    }
  },
  {
    description = "order, INVISIBLE, GONE, and onLayout",
    node = {
      frame = CreateFrame(),
      direction = "COLUMN",
      width = 200,
      height = 300,
      onLayout = function() end,
      children = {
        { frame = CreateFrame(), height = 20, order = 3,                onLayout = function() end },
        { frame = CreateFrame(), height = 20, order = 1,                visibility = "INVISIBLE" },
        { frame = CreateFrame(), height = 20, order = 2,                visibility = "GONE" },
        { frame = CreateFrame(), order = 0,   children = CreateIcons(2) },
      }
    }
  },
}

-- =============================================================================
-- Tests
-- =============================================================================

-- Test: a repeated `Layout()` pass allocates no memory once the scratch pool
-- is warm.
for _, spec in ipairs(SPECS) do
  local root = Waffle:Flex(spec.node)

  -- Changes the root's width each call so every `Layout()` does real work
  local width = 200
  local function Relayout()
    width = width == 200 and 210 or 200
    root:SetWidth(width)
    root:Layout()
  end

  -- Fill the scratch pool, whose first passes allocate once
  for _ = 1, 50 do Relayout() end

  -- Measure with the collector stopped, so only new allocations raise the count
  collectgarbage()
  collectgarbage("stop")
  local before = collectgarbage("count")
  local passes = 1000
  for _ = 1, passes do Relayout() end
  local bytesPerLayout = (collectgarbage("count") - before) * 1024 / passes
  collectgarbage("restart")

  assert(bytesPerLayout <= MAX_BYTES_PER_LAYOUT, spec.description .. ": " .. bytesPerLayout .. " bytes per layout")
end

print("All assertions passed.")
