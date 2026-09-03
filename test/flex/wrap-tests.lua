--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: children that would overflow the main axis start a new line
-- instead; a new line's cross-offset accounts for the previous line's own
-- cross-size (a max over that line's children) plus `gap`.
do
  local parent = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 100,
    height = 200,
    wrap = true,
    gap = 10,
    children = {
      { frame = a, width = 40, height = 30 },
      { frame = b, width = 40, height = 30 },
      { frame = c, width = 40, height = 50 },
    }
  }):Layout()

  assert(a._test.width == 40 and a._test.height == 30)
  assert(b._test.width == 40 and b._test.height == 30)
  assert(c._test.width == 40 and c._test.height == 50)
  assert(a._test.point.offsetX == 0 and a._test.point.offsetY == 0)
  assert(b._test.point.offsetX == 50 and b._test.point.offsetY == 0) -- 40 + gap
  assert(c._test.point.offsetX == 0 and c._test.point.offsetY == -40) -- new line: line 1's max(30) + gap(10)
end

-- Test: a flexible child splits its own line's leftover space, not the
-- whole container's, independent of other lines.
do
  local parent = Mocks:CreateFrame()
  local fixed1, flex1, fixed2, flex2 = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 100,
    height = 50,
    wrap = true,
    children = {
      { frame = fixed1, width = 70 },
      { frame = flex1 }, -- joins line 1 regardless, nothing fixed to overflow-check yet
      { frame = fixed2, width = 90 }, -- doesn't fit alongside fixed1, starts line 2
      { frame = flex2 },
    }
  }):Layout()

  assert(flex1._test.width == 30) -- line 1: 100 - 70
  assert(flex2._test.width == 10) -- line 2: 100 - 90, unrelated to line 1's leftover
end

-- Test: `justify` distributes each line's own leftover space independently.
do
  local parent = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 210,
    height = 50,
    wrap = true,
    justify = "CENTER",
    children = {
      { frame = a, width = 100 },
      { frame = b, width = 100 },
      { frame = c, width = 50 }, -- doesn't fit alongside a/b, starts line 2
    }
  }):Layout()

  assert(a._test.point.offsetX == 5)   -- line 1 leftover 10, centered: 10/2
  assert(b._test.point.offsetX == 105) -- 5 + 100
  assert(c._test.point.offsetX == 80)  -- line 2 leftover 160, centered: 160/2
end

-- Test: a STRETCH child fills its own line's cross-size, not the
-- container's and not a different line's.
do
  local parent = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 100,
    height = 200,
    wrap = true,
    children = {
      { frame = a, width = 100, height = 30 }, -- fills line 1 alone
      { frame = b, width = 50, height = 20 },  -- line 2
      { frame = c, width = 30 },               -- line 2, no height: STRETCH
    }
  }):Layout()

  assert(a._test.height == 30)
  assert(b._test.height == 20)
  assert(c._test.height == 20) -- line 2's own max (b's 20), not line 1's 30 or the container's 200
end

-- Test: a single child larger than the main axis on its own still gets
-- placed, on its own line, rather than looping or leaving a line empty.
do
  local parent = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 50,
    height = 50,
    wrap = true,
    children = { { frame = a, width = 100 } }
  }):Layout()

  assert(a._test.width == 100)
  assert(a._test.point.offsetX == 0)
end

-- Test: a hidden child is excluded from line assignment entirely, doesn't
-- consume space or trigger a wrap.
do
  local parent = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 100,
    height = 50,
    wrap = true,
    children = {
      { frame = a, width = 60 },
      { frame = b, width = 60, hidden = true },
      { frame = c, width = 30 },
    }
  }):Layout()

  assert(a._test.point.offsetX == 0)
  assert(c._test.point.offsetX == 60) -- right after a, b never considered
  assert(b._test.width == nil)        -- never positioned
end

-- Test: omitting `wrap` (or `false`) is unaffected, overflowing children
-- still stay on one line, same as before this feature existed.
do
  local parent = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 100,
    height = 50,
    children = {
      { frame = a, width = 60 },
      { frame = b, width = 60 },
    }
  }):Layout()

  assert(a._test.point.offsetX == 0)
  assert(b._test.point.offsetX == 60) -- not wrapped, despite overflowing
end

-- Test: wrapping works the same way on a COLUMN, main axis is height,
-- cross axis is width, lines stack sideways instead of downward.
do
  local parent = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "COLUMN",
    height = 100,
    width = 200,
    wrap = true,
    children = {
      { frame = a, height = 40, width = 30 },
      { frame = b, height = 40, width = 30 },
      { frame = c, height = 40, width = 50 },
    }
  }):Layout()

  assert(a._test.point.offsetX == 0 and a._test.point.offsetY == 0)
  assert(b._test.point.offsetX == 0 and b._test.point.offsetY == -40)
  assert(c._test.point.offsetX == 30 and c._test.point.offsetY == 0) -- new line, line 1's own max width
  assert(a._test.width == 30 and b._test.width == 30 and c._test.width == 50)
end

print("All assertions passed.")
