--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: fixed children that overflow the line shrink proportionally to
-- fit, weighted by size as well as `shrink`: two equally-weighted
-- (default `shrink`) children still give up different absolute amounts,
-- since they aren't the same size to begin with.
do
  local root, a, b = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = a, width = 150 },
      { frame = b, width = 100 },
    }
  }):Layout()

  assert(a._test.width == 120)
  assert(b._test.width == 80)
end

-- Test: `shrink = 0` opts a child out entirely, the rest absorb the
-- whole deficit instead.
do
  local root, a, b = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = a, width = 150, shrink = 0 },
      { frame = b, width = 100 },
    }
  }):Layout()

  assert(a._test.width == 150)
  assert(b._test.width == 50)
end

-- Test: a higher `shrink` weight gives up proportionally more, same
-- size otherwise.
do
  local root, a, b = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 90,
    height = 50,
    children = {
      { frame = a, width = 90, shrink = 2 },
      { frame = b, width = 90, shrink = 1 },
    }
  }):Layout()

  assert(a._test.width == 30)
  assert(b._test.width == 60)
end

-- Test: `minWidth` floors how far a child shrinks; whatever it can't
-- give up redistributes to still-shrinkable siblings.
do
  local root, a, b = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 140,
    height = 50,
    children = {
      { frame = a, width = 100, minWidth = 90 },
      { frame = b, width = 100 },
    }
  }):Layout()

  assert(a._test.width == 90) -- floors at its own minWidth
  assert(b._test.width == 50) -- absorbs what a couldn't give up
end

-- Test: `maxWidth` has no effect on shrinking, a child only ever shrinks
-- down from its own stated size, never up past it.
do
  local root, a, b = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 150,
    height = 50,
    children = {
      { frame = a, width = 100, maxWidth = 80 },
      { frame = b, width = 100 },
    }
  }):Layout()

  assert(a._test.width == 75)
  assert(b._test.width == 75)
end

-- Test: a percentage width resolves first, then shrinks like any other
-- fixed size.
do
  local root, a, b = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 90,
    height = 50,
    children = {
      { frame = a, width = "50%" }, -- 45, then shrinks like a fixed 45 would
      { frame = b, width = 55 },
    }
  }):Layout()

  assert(a._test.width == 40.5)
  assert(b._test.width == 49.5)
end

-- Test: `shrink` works the same way on a COLUMN, main axis is height.
do
  local root, a, b = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "COLUMN",
    width = 50,
    height = 200,
    children = {
      { frame = a, height = 150 },
      { frame = b, height = 100 },
    }
  }):Layout()

  assert(a._test.height == 120)
  assert(b._test.height == 80)
end

-- Test: no deficit at all leaves existing fixed/flexible sizing
-- untouched, shrink only ever engages once something actually overflows.
do
  local root, a, b = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 100 },
      { frame = b },
    }
  }):Layout()

  assert(a._test.width == 100)
  assert(b._test.width == 200)
end

print("All assertions passed.")
