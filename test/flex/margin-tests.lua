--- @diagnostic disable: undefined-field

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: a fixed child's own `marginLeft`/`marginRight` add to the space
-- it consumes on the main axis, reducing what's left for a flexible
-- sibling.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 50, marginLeft = 10, marginRight = 20 },
      { frame = b },
    }
  }):Layout()

  assert(a._test.width == 50)
  assert(a._test.point.offsetX == 10)
  assert(b._test.width == 220) -- 300 - 10 - 50 - 20
  assert(b._test.point.offsetX == 80) -- right after a's own margin
end

-- Test: a flexible child's own margin still reduces the shared pool,
-- even though its own size isn't known until that pool is split.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, marginRight = 20 },
      { frame = b },
    }
  }):Layout()

  assert(a._test.width == 140) -- (300 - 20) / 2
  assert(a._test.point.offsetX == 0)
  assert(b._test.width == 140)
  assert(b._test.point.offsetX == 160) -- right after a's own width and margin
end

-- Test: `marginTop`/`marginBottom` inset a `STRETCH`-ed child from both
-- ends of the cross axis, the same relationship `padding` has to the
-- whole container.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 100,
    children = {
      { frame = a, marginTop = 10, marginBottom = 20 },
    }
  }):Layout()

  assert(a._test.height == 70) -- 100 - 10 - 20
  assert(a._test.point.offsetY == -10)
end

-- Test: cross-axis margin centers the child's own margin box, not just
-- its content box, within the line's cross-size.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 100,
    align = "CENTER",
    children = {
      { frame = a, height = 30, marginTop = 10, marginBottom = 10 },
    }
  }):Layout()

  assert(a._test.height == 30) -- explicit, unaffected by its own margin
  assert(a._test.point.offsetY == -35) -- (100 - (30 + 10 + 10)) / 2 + 10
end

-- Test: a per-side value overrides `margin` for that side only, on
-- either axis, the other sides still fall back to it.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 50, margin = 5, marginLeft = 15 },
      { frame = b },
    }
  }):Layout()

  assert(a._test.width == 50)
  assert(a._test.point.offsetX == 15)
  assert(a._test.height == 40)  -- 50 - 5 (margin, top) - 5 (margin, bottom)
  assert(a._test.point.offsetY == -5)
  assert(b._test.width == 230) -- 300 - 15 (marginLeft) - 50 - 5 (margin, right)
end

-- Test: `"AUTO"` on the main axis sums in each child's own margin along
-- with its size.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = "AUTO",
    height = 50,
    children = { { frame = a, width = 100, marginLeft = 5, marginRight = 15 } }
  }):Layout()

  assert(root._test.width == 120) -- 100 + 5 + 15
end

-- Test: `"AUTO"` on the cross axis does the same.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = "AUTO",
    children = { { frame = a, height = 30, marginTop = 5, marginBottom = 25 } }
  }):Layout()

  assert(root._test.height == 60) -- 30 + 5 + 25
end

-- Test: a child's own margin counts toward whether it still fits on the
-- current line under `wrap`, not just its own size; every line still
-- starts at the same main-axis leading padding regardless.
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
    children = {
      { frame = a, width = 40, height = 20, marginRight = 25 }, -- outer width 65
      { frame = b, width = 40, height = 30 }, -- doesn't fit alongside a (65 + 40 > 90), starts line 2
    }
  }):Layout()

  assert(a._test.point.offsetX == 10)
  assert(b._test.point.offsetX == 10) -- same leading padding, line 2
  assert(b._test.point.offsetY == -20) -- line 1's own cross-size, unaffected by a's main-axis margin
end

print("All assertions passed.")
