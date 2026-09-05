--- @diagnostic disable: undefined-field

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: COLUMN swaps the main/cross axes, main axis grows downward
-- (negative Y offsets), cross axis (width) stretches to fill.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "COLUMN",
    width = 200,
    height = 100,
    children = {
      { frame = a, height = 30 },
      { frame = b, height = 30 },
    }
  }):Layout()

  assert(a._test.width == 200 and a._test.height == 30)
  assert(b._test.width == 200 and b._test.height == 30)
  assert(a._test.point.offsetX == 0 and a._test.point.offsetY == 0)
  assert(b._test.point.offsetX == 0 and b._test.point.offsetY == -30)
end

-- Test: omitting `direction` defaults to ROW, same as `direction = "ROW"`.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    width = 200,
    height = 50,
    children = {
      { frame = a, width = 50 },
      { frame = b },
    }
  }):Layout()

  assert(a._test.point.offsetX == 0 and a._test.point.offsetY == 0)
  assert(b._test.point.offsetX == 50 and b._test.point.offsetY == 0)
  assert(a._test.height == 50 and b._test.height == 50) -- cross axis stretches
end

-- Test: `ROW_REVERSE` lays out children starting from the right edge:
-- the first declared child ends up rightmost, not leftmost.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW_REVERSE",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 100 },
      { frame = b, width = 100 },
      { frame = c, width = 100 },
    }
  }):Layout()

  assert(c._test.point.offsetX == 0)
  assert(b._test.point.offsetX == 100)
  assert(a._test.point.offsetX == 200)
end

-- Test: `COLUMN_REVERSE` is the same, vertically: the first declared
-- child ends up at the bottom, not the top.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "COLUMN_REVERSE",
    width = 50,
    height = 300,
    children = {
      { frame = a, height = 100 },
      { frame = b, height = 100 },
      { frame = c, height = 100 },
    }
  }):Layout()

  assert(c._test.point.offsetY == 0)
  assert(b._test.point.offsetY == -100)
  assert(a._test.point.offsetY == -200)
end

-- Test: `direction` tolerates case, same as `"ROW"`/`"COLUMN"` already do.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "row_reverse",
    width = 200,
    height = 50,
    children = {
      { frame = a, width = 100 },
      { frame = b, width = 100 },
    }
  }):Layout()

  assert(b._test.point.offsetX == 0)
  assert(a._test.point.offsetX == 100)
end

-- Test: `order` sorts first, `_REVERSE` only flips the already-order-
-- sorted sequence's own starting edge, it doesn't change what "first"
-- means for `order` purposes.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW_REVERSE",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 100, order = 2 },
      { frame = b, width = 100, order = 0 },
      { frame = c, width = 100, order = 1 },
    }
  }):Layout()

  -- Order-sorted sequence is b, c, a; reversed edge means b (order 0)
  -- ends up rightmost instead of leftmost.
  assert(a._test.point.offsetX == 0)
  assert(c._test.point.offsetX == 100)
  assert(b._test.point.offsetX == 200)
end

-- Test: `gap` still applies between visually-adjacent children.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW_REVERSE",
    width = 210,
    height = 50,
    gap = 10,
    children = {
      { frame = a, width = 100 },
      { frame = b, width = 100 },
    }
  }):Layout()

  assert(b._test.point.offsetX == 0)
  assert(a._test.point.offsetX == 110)
end

-- Test: leftover main-axis space (default `justify = "START"`) packs
-- against the right edge under `ROW_REVERSE`, not the left; every test
-- above has zero leftover space, which reversing the child array alone
-- would get right by coincidence.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW_REVERSE",
    width = 250, -- 50px of leftover space past the two 100-wide children
    height = 50,
    children = {
      { frame = a, width = 100 },
      { frame = b, width = 100 },
    }
  }):Layout()

  assert(a._test.point.offsetX == 150) -- first child, rightmost, hugging the right edge
  assert(b._test.point.offsetX == 50)
end

-- Test: `wrap` splits into lines exactly as it would for `ROW`, `order`
-- and all, `_REVERSE` doesn't change which children share a line; only
-- each line's own item order (and, per the leftover-space test above,
-- which edge `justify` hugs) flips.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW_REVERSE",
    wrap = true,
    width = 250, -- fits two 100-wide children per line, not three
    height = 200,
    children = {
      { frame = a, width = 100, height = 30 },
      { frame = b, width = 100, height = 30 },
      { frame = c, width = 100, height = 30 },
    }
  }):Layout()

  -- Line 1: a, b (same grouping `ROW` would produce), reversed within
  -- the line, packed against the right edge (50px leftover on this line).
  assert(b._test.point.offsetX == 50 and b._test.point.offsetY == 0)
  assert(a._test.point.offsetX == 150 and a._test.point.offsetY == 0)

  -- Line 2: c alone, its own line, no leftover to distinguish edges,
  -- stacked below line 1.
  assert(c._test.point.offsetX == 150 and c._test.point.offsetY == -30)
end

-- Test: `"AUTO"` main-axis sizing still sums (not maxes) under
-- `ROW_REVERSE`, the same as it would for `ROW`; `_REVERSE` doesn't
-- change which axis is main.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW_REVERSE",
    width = "AUTO",
    height = 50,
    gap = 10,
    children = {
      { frame = a, width = 80, height = 50 },
      { frame = b, width = 60, height = 50 },
    }
  }):Layout()

  assert(root._test.width == 150) -- 80 + 60 + 10 gap
  assert(b._test.point.offsetX == 0)
  assert(a._test.point.offsetX == 70)
end

-- Test: `"AUTO"` cross-axis sizing still maxes (not sums) under
-- `COLUMN_REVERSE`.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "COLUMN_REVERSE",
    width = "AUTO",
    height = 100,
    children = {
      { frame = a, width = 80, height = 40 },
      { frame = b, width = 60, height = 40 },
    }
  }):Layout()

  assert(root._test.width == 80) -- max(80, 60), not 80 + 60
  assert(b._test.point.offsetY == -20)
  assert(a._test.point.offsetY == -60)
end

print("All assertions passed.")
