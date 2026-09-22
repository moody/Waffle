--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: a main-axis percentage resolves against the parent's own
-- content-box size, a flexible sibling splits whatever's left.
do
  local root, a, b = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = a, width = "50%" },
      { frame = b },
    }
  }):Layout()

  assert(a._test.width == 100)
  assert(b._test.width == 100)
end

-- Test: a cross-axis percentage works the same way, resolving against
-- the parent's own cross size instead.
do
  local root, a = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 100,
    children = {
      { frame = a, width = 50, height = "50%" },
    }
  }):Layout()

  assert(a._test.height == 50)
end

-- Test: a percentage works the same way on a COLUMN, main axis is height.
do
  local root, a = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "COLUMN",
    width = 50,
    height = 200,
    children = {
      { frame = a, height = "25%" },
    }
  }):Layout()

  assert(a._test.height == 50)
end

-- Test: a percentage resolves against the parent's content box, padding
-- already subtracted.
do
  local root, a = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 220,
    height = 50,
    padding = 10,
    children = {
      { frame = a, width = "50%" },
    }
  }):Layout()

  assert(a._test.width == 100) -- 50% of (220 - 20 padding), not 220
end

-- Test: `minWidth`/`maxWidth` have no effect on a percentage width,
-- same as any other fixed width.
do
  local root, a = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = a, width = "50%", maxWidth = 20 },
    }
  }):Layout()

  assert(a._test.width == 100)
end

-- Test: a string that's neither `"AUTO"` nor a valid percentage errors.
do
  local root, a = Mocks:CreateFrame(), Mocks:CreateFrame()
  local ok, err = pcall(function()
    Waffle:Flex({
      frame = root,
      direction = "ROW",
      width = 200,
      height = 50,
      children = { { frame = a, width = "5o%" } }
    }):Layout()
  end)

  assert(not ok)
  assert(tostring(err):find("must be a number"))
end

-- Test: a percentage on the root errors, nothing above it to resolve
-- against.
do
  local root = Mocks:CreateFrame()
  local ok, err = pcall(function()
    Waffle:Flex({ frame = root, width = "50%", height = 50 }):Layout()
  end)

  assert(not ok)
  assert(tostring(err):find("percentage"))
end

-- Test: a percentage on a child of a main-axis `"AUTO"` parent errors:
-- the parent's own size needs every child's size to sum first, a child
-- needing the parent's size back is circular.
do
  local root, a = Mocks:CreateFrame(), Mocks:CreateFrame()
  local ok, err = pcall(function()
    Waffle:Flex({
      frame = root,
      direction = "ROW",
      width = "AUTO",
      height = 50,
      children = { { frame = a, width = "50%" } }
    }):Layout()
  end)

  assert(not ok)
  assert(tostring(err):find("percentage"))
end

-- Test: a container's own main-axis percentage, its cross axis
-- `"AUTO"`, and `wrap`, all composed together: the percentage resolves
-- against the container's real (outer) parent first, so wrapping and
-- the `"AUTO"` cross size both work from the right width.
do
  local root, mid, a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame(),
      Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "COLUMN",
    width = 300,
    height = 300,
    children = {
      {
        frame = mid,
        direction = "ROW",
        wrap = true,
        width = "50%", -- 150, resolved against root's real width
        height = "AUTO",
        children = {
          { frame = a, width = 70, height = 20 },
          { frame = b, width = 70, height = 20 }, -- a + b = 140, fits in 150
          { frame = c, width = 70, height = 20 }, -- + c = 210, wraps
        }
      },
    }
  }):Layout()

  assert(mid._test.width == 150)
  assert(a._test.point.offsetY == 0 and b._test.point.offsetY == 0) -- share line 1
  assert(a._test.point.offsetX == 0 and b._test.point.offsetX == 70) -- side by side
  assert(c._test.point.offsetY == -20) -- wraps to line 2
  assert(mid._test.height == 40) -- sums both lines' own heights
end

-- Test: a percentage `width` errors when its parent's own width is still being
-- computed, even though the parent's height is known.
do
  local ok, err = pcall(function()
    Waffle:Flex({
      frame = Mocks:CreateFrame(),
      direction = "ROW",
      width = 400,
      height = 300,
      children = {
        {
          frame = Mocks:CreateFrame(),
          direction = "COLUMN",
          wrap = true,
          width = "AUTO",
          height = 100,
          children = {
            {
              frame = Mocks:CreateFrame(),
              direction = "ROW",
              wrap = true,
              width = "50%",
              height = "AUTO",
              children = { { frame = Mocks:CreateFrame(), width = 10, height = 10 } }
            },
          }
        },
      }
    }):Layout()
  end)

  assert(not ok)
  assert(tostring(err):find("percentage"), tostring(err))
end

print("All assertions passed.")
