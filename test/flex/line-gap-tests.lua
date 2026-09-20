--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `lineGap` spaces wrapped lines apart, independent of `gap` between
-- children on the same line.
do
  local parent = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 100,
    height = 200,
    wrap = true,
    gap = 4,
    lineGap = 20,
    children = {
      { frame = a, width = 60, height = 10 },
      { frame = b, width = 60, height = 10 }, -- doesn't fit next to a, new line
      { frame = c, width = 60, height = 10 }, -- doesn't fit next to b, new line
    }
  }):Layout()

  assert(a._test.point.offsetY == 0)
  assert(b._test.point.offsetY == -30) -- -(10 + lineGap 20)
  assert(c._test.point.offsetY == -60) -- -(30 + 10 + lineGap 20)
end

-- Test: `lineGap` unset falls back to `gap`.
do
  local parent = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 60,
    height = 200,
    wrap = true,
    gap = 15,
    children = {
      { frame = a, width = 60, height = 10 },
      { frame = b, width = 60, height = 10 },
    }
  }):Layout()

  assert(b._test.point.offsetY == -25) -- -(10 + gap 15)
end

-- Test: cross-axis `"AUTO"` sums every line's own cross-size plus
-- `lineGap` between them, not `gap`.
do
  local parent = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 60,
    height = "AUTO",
    wrap = true,
    gap = 5,
    lineGap = 25,
    children = {
      { frame = a, width = 60, height = 10 },
      { frame = b, width = 60, height = 10 },
    }
  }):Layout()

  assert(parent._test.height == 45) -- 10 + lineGap 25 + 10
end

-- Test: `lineGap` works the same way on a COLUMN, spacing wrapped columns
-- apart sideways instead of down.
do
  local parent = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "COLUMN",
    width = 200,
    height = 30,
    wrap = true,
    gap = 3,
    lineGap = 40,
    children = {
      { frame = a, width = 10, height = 20 },
      { frame = b, width = 10, height = 20 }, -- doesn't fit under a, new column
    }
  }):Layout()

  assert(a._test.point.offsetX == 0)
  assert(b._test.point.offsetX == 50) -- 10 + lineGap 40
end

print("All assertions passed.")
