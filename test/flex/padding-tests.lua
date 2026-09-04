--- @diagnostic disable: undefined-field

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `paddingLeft`/`paddingRight` override `padding` on the main axis
-- of a ROW container, independently of each other.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    paddingLeft = 10,
    paddingRight = 30,
    children = { { frame = a } }
  }):Layout()

  assert(a._test.width == 160) -- 200 - 10 - 30
  assert(a._test.point.offsetX == 10)
end

-- Test: `paddingTop`/`paddingBottom` do the same on a COLUMN container,
-- main axis there is vertical instead.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "COLUMN",
    width = 50,
    height = 200,
    paddingTop = 20,
    paddingBottom = 40,
    children = { { frame = a } }
  }):Layout()

  assert(a._test.height == 140) -- 200 - 20 - 40
  assert(a._test.point.offsetY == -20)
end

-- Test: cross-axis padding (`paddingTop`/`paddingBottom` on a ROW) clamps
-- a `STRETCH`-ed child's cross size and offsets it, same as the main axis.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 100,
    paddingTop = 10,
    paddingBottom = 30,
    children = { { frame = a } }
  }):Layout()

  assert(a._test.height == 60) -- 100 - 10 - 30
  assert(a._test.point.offsetY == -10)
  assert(a._test.width == 200) -- unaffected, no left/right padding given
  assert(a._test.point.offsetX == 0)
end

-- Test: a per-side value overrides `padding` for that side only, the
-- other three sides still fall back to it.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    padding = 10,
    paddingLeft = 25,
    children = { { frame = a } }
  }):Layout()

  assert(a._test.width == 265) -- 300 - 25 (paddingLeft) - 10 (padding, right)
  assert(a._test.point.offsetX == 25)
  assert(a._test.height == 30) -- 50 - 10 - 10 (padding, top and bottom)
  assert(a._test.point.offsetY == -10)
end

-- Test: `"AUTO"` on the main axis sums in `paddingLeft`/`paddingRight`
-- instead of one uniform `padding` on both ends.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = "AUTO",
    height = 50,
    paddingLeft = 5,
    paddingRight = 15,
    children = { { frame = a, width = 100 } }
  }):Layout()

  assert(root._test.width == 120) -- 100 + 5 + 15
end

-- Test: `"AUTO"` on the cross axis does the same with `paddingTop`/`paddingBottom`.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = "AUTO",
    paddingTop = 5,
    paddingBottom = 25,
    children = { { frame = a, height = 30 } }
  }):Layout()

  assert(root._test.height == 60) -- 30 + 5 + 25
end

-- Test: under `wrap`, every line starts at the same main-axis leading
-- padding, cross-axis leading padding only offsets the first line.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 100,
    height = 200,
    wrap = true,
    paddingLeft = 10,
    paddingTop = 5,
    children = {
      { frame = a, width = 50, height = 20 },
      { frame = b, width = 50, height = 30 }, -- doesn't fit alongside a, starts line 2
    }
  }):Layout()

  assert(a._test.point.offsetX == 10)
  assert(a._test.point.offsetY == -5)  -- crossLeading, line 1
  assert(b._test.point.offsetX == 10)  -- same leading padding, line 2
  assert(b._test.point.offsetY == -25) -- crossLeading (5) + line 1's own cross-size (20)
end

print("All assertions passed.")
