--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Shared setup for most cases below: a 300-wide row, three fixed 50-wide
-- children (150 total), nothing flexible, 150 leftover to distribute.
local function ThreeFixedChildren(justify)
  local parent = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 300,
    height = 50,
    justify = justify,
    children = {
      { frame = a, width = 50 },
      { frame = b, width = 50 },
      { frame = c, width = 50 },
    }
  }):Layout()

  return a, b, c
end

-- Test: `justify = "START"` (also the default) packs children against the
-- start.
do
  local a, b, c = ThreeFixedChildren("START")
  assert(a._test.point.offsetX == 0)
  assert(b._test.point.offsetX == 50)
  assert(c._test.point.offsetX == 100)
end

-- Test: `justify = "END"` packs children against the far end instead.
do
  local a, b, c = ThreeFixedChildren("END")
  assert(a._test.point.offsetX == 150)
  assert(b._test.point.offsetX == 200)
  assert(c._test.point.offsetX == 250) -- ends flush at 300
end

-- Test: `justify = "CENTER"` centers the whole packed group.
do
  local a, b, c = ThreeFixedChildren("CENTER")
  assert(a._test.point.offsetX == 75)  -- 150 leftover / 2
  assert(b._test.point.offsetX == 125)
  assert(c._test.point.offsetX == 175)
end

-- Test: `justify = "SPACE_BETWEEN"` puts all leftover space between
-- children, none before the first or after the last.
do
  local a, b, c = ThreeFixedChildren("SPACE_BETWEEN")
  assert(a._test.point.offsetX == 0)
  assert(b._test.point.offsetX == 125) -- 50 + 150/2
  assert(c._test.point.offsetX == 250) -- ends flush at 300
end

-- Test: `justify = "SPACE_AROUND"` gives every child an equal share, but
-- the edges only get half a share.
do
  local a, b, c = ThreeFixedChildren("SPACE_AROUND")
  assert(a._test.point.offsetX == 25)  -- half of (150/3)
  assert(b._test.point.offsetX == 125) -- 25 + 50 + 50
  assert(c._test.point.offsetX == 225) -- 125 + 50 + 50
end

-- Test: `justify = "SPACE_EVENLY"` gives every gap, edges included, the
-- exact same share.
do
  local a, b, c = ThreeFixedChildren("SPACE_EVENLY")
  assert(a._test.point.offsetX == 37.5)  -- 150 / 4
  assert(b._test.point.offsetX == 125)   -- 37.5 + 50 + 37.5
  assert(c._test.point.offsetX == 212.5) -- 125 + 50 + 37.5
end

-- Test: `justify` has nothing to distribute, and is skipped entirely, once
-- any child is flexible, the flexible child already consumes all of the
-- leftover space itself.
do
  local parent = Mocks:CreateFrame()
  local fixed1, flex, fixed2 = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 300,
    height = 50,
    justify = "CENTER",
    children = {
      { frame = fixed1, width = 50 },
      { frame = flex },
      { frame = fixed2, width = 50 },
    }
  }):Layout()

  assert(fixed1._test.point.offsetX == 0)
  assert(flex._test.width == 200) -- absorbed all 200 leftover, none left for `justify`
  assert(flex._test.point.offsetX == 50)
  assert(fixed2._test.point.offsetX == 250)
end

-- Test: `SPACE_BETWEEN` with only one visible child has nothing to put
-- "between", falls back to the same placement as `START`.
do
  local parent = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 300,
    height = 50,
    justify = "SPACE_BETWEEN",
    children = { { frame = a, width = 50 } }
  }):Layout()

  assert(a._test.point.offsetX == 0)
end

-- Test: `justify` distributes along whichever axis is the main one: for
-- COLUMN, that's height (Y), not width (X).
do
  local parent = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "COLUMN",
    width = 50,
    height = 200,
    justify = "CENTER",
    children = {
      { frame = a, height = 40 },
      { frame = b, height = 40 },
    }
  }):Layout()

  -- leftover = 200 - 80 = 120, centered offset = 60
  assert(a._test.point.offsetY == -60)
  assert(b._test.point.offsetY == -100) -- 60 + 40
end

print("All assertions passed.")
