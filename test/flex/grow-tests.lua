--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: leftover space splits proportional to `grow`, not evenly.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a },            -- flexible, default grow 1
      { frame = b, grow = 2 },  -- flexible, grow 2
    }
  }):Layout()

  assert(a._test.width == 100) -- 300 * (1/3)
  assert(b._test.width == 200) -- 300 * (2/3)
end

-- Test: three different grow weights split three ways, not just two.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, grow = 1 },
      { frame = b, grow = 2 },
      { frame = c, grow = 3 },
    }
  }):Layout()

  assert(a._test.width == 50)  -- 300 * (1/6)
  assert(b._test.width == 100) -- 300 * (2/6)
  assert(c._test.width == 150) -- 300 * (3/6)
end

-- Test: fractional `grow` values split correctly too, not just whole numbers.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, grow = 0.5 },
      { frame = b, grow = 1.5 },
    }
  }):Layout()

  assert(a._test.width == 75)  -- 300 * (0.5/2)
  assert(b._test.width == 225) -- 300 * (1.5/2)
end

-- Test: `grow = 0` claims none of the leftover, an equally-flexible
-- sibling gets all of it.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, grow = 0 },
      { frame = b },
    }
  }):Layout()

  assert(a._test.width == 0)
  assert(b._test.width == 300)
end

-- Test: `justify` stays suppressed as long as any child has a positive
-- `grow` share, even alongside a `grow = 0` sibling.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    justify = "END",
    children = {
      { frame = a, grow = 0 },
      { frame = b }, -- grow 1, claims the leftover
    }
  }):Layout()

  assert(b._test.width == 300)
  assert(a._test.point.offsetX == 0) -- justify never ran, b already claimed everything
end

-- Test: once every flexible child has `grow = 0`, `justify` applies to
-- the untouched leftover instead of staying suppressed.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    justify = "END",
    children = {
      { frame = a, width = 100 },
      { frame = b, grow = 0 },
    }
  }):Layout()

  assert(b._test.width == 0)
  assert(a._test.point.offsetX == 200) -- leftover (300 - 100) pushed to the end
  assert(b._test.point.offsetX == 300) -- right after a
end

-- Test: `grow` has no effect on a child with its own explicit main-axis
-- size, only a flexible child ever consumes leftover space.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 100, grow = 5 }, -- fixed size, grow is irrelevant
      { frame = b },
    }
  }):Layout()

  assert(a._test.width == 100)
  assert(b._test.width == 200)
end

-- Test: `grow` works the same way on a COLUMN, main axis is height
-- instead of width.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "COLUMN",
    width = 50,
    height = 300,
    children = {
      { frame = a },
      { frame = b, grow = 3 },
    }
  }):Layout()

  assert(a._test.height == 75)  -- 300 * (1/4)
  assert(b._test.height == 225) -- 300 * (3/4)
end

-- Test: `grow` weights are computed per line under `wrap`, each line's
-- own leftover space distributed independently of any other line's.
do
  local root = Mocks:CreateFrame()
  local fixed1, flexA, flexB, fixed2, flexC =
      Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 100,
    height = 50,
    wrap = true,
    children = {
      { frame = fixed1, width = 40 }, -- line 1
      { frame = flexA, grow = 1 },    -- line 1
      { frame = flexB, grow = 3 },    -- line 1
      { frame = fixed2, width = 100 }, -- doesn't fit alongside line 1, starts line 2
      { frame = flexC, grow = 1 },    -- line 2
    }
  }):Layout()

  assert(flexA._test.width == 15) -- line 1 leftover 60, split 1:3
  assert(flexB._test.width == 45)
  assert(flexC._test.width == 0)  -- line 2 leftover 0, unrelated to line 1's
end

-- Test: a later line splits its own real leftover proportionally too,
-- not just the zero-leftover case above.
do
  local root = Mocks:CreateFrame()
  local fixed1, flexA, fixed2, flexB, flexC =
      Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 100,
    height = 50,
    wrap = true,
    children = {
      { frame = fixed1, width = 40 }, -- line 1
      { frame = flexA, grow = 1 },    -- line 1, leftover 60
      { frame = fixed2, width = 70 }, -- doesn't fit alongside line 1, starts line 2
      { frame = flexB, grow = 1 },    -- line 2, leftover 30
      { frame = flexC, grow = 2 },    -- line 2
    }
  }):Layout()

  assert(flexA._test.width == 60)
  assert(flexB._test.width == 10) -- line 2 leftover 30, split 1:2
  assert(flexC._test.width == 20)
end

print("All assertions passed.")
