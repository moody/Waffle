--- @diagnostic disable: undefined-field

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: fixed ROW children anchor to the parent directly, not to each
-- other, and stretch to fill the container's height.
do
  local parent = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 100 },
      { frame = b, width = 100 },
      { frame = c, width = 100 },
    }
  }):Layout()

  assert(a._test.width == 100 and a._test.height == 50)
  assert(b._test.width == 100 and b._test.height == 50)
  assert(c._test.width == 100 and c._test.height == 50)

  assert(a._test.point.parent == parent and a._test.point.point == "TOPLEFT" and a._test.point.relativePoint == "TOPLEFT")
  assert(a._test.point.offsetX == 0 and a._test.point.offsetY == 0)
  assert(b._test.point.offsetX == 100 and b._test.point.offsetY == 0)
  assert(c._test.point.offsetX == 200 and c._test.point.offsetY == 0)
end

-- Test: one flexible child (no `width`) among fixed ones fills whatever's
-- left over.
do
  local parent = Mocks:CreateFrame()
  local fixed1, flex, fixed2 = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = fixed1, width = 50 },
      { frame = flex },
      { frame = fixed2, width = 50 },
    }
  }):Layout()

  assert(fixed1._test.width == 50)
  assert(flex._test.width == 200) -- 300 - 50 - 50
  assert(fixed2._test.width == 50)
  assert(flex._test.point.offsetX == 50)
  assert(fixed2._test.point.offsetX == 250)
end

-- Test: multiple flexible children with no fixed siblings split the space evenly.
do
  local parent = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a },
      { frame = b },
      { frame = c },
    }
  }):Layout()

  assert(a._test.width == 100 and b._test.width == 100 and c._test.width == 100)
  assert(a._test.point.offsetX == 0 and b._test.point.offsetX == 100 and c._test.point.offsetX == 200)
end

-- Test: `gap` only applies between children, not before the first or after
-- the last.
do
  local parent = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 340,
    height = 50,
    gap = 10,
    children = {
      { frame = a, width = 100 },
      { frame = b, width = 100 },
      { frame = c, width = 100 },
    }
  }):Layout()

  assert(a._test.point.offsetX == 0)
  assert(b._test.point.offsetX == 110) -- 100 + gap
  assert(c._test.point.offsetX == 220) -- 100 + gap + 100 + gap
end

-- Test: `padding` insets the whole row from every edge, and is subtracted
-- from both the main and cross axis available space.
do
  local parent = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 220,
    height = 60,
    padding = 10,
    children = {
      { frame = a, width = 50 },
      { frame = b }, -- flex: (220 - 20 padding) - 50 = 150
    }
  }):Layout()

  assert(a._test.point.offsetX == 10 and a._test.point.offsetY == -10)
  assert(a._test.height == 40)        -- 60 - 10*2
  assert(b._test.width == 150)
  assert(b._test.point.offsetX == 60) -- 10 padding + 50
end

-- Test: an empty children list is a safe no-op, the container is still sized.
do
  local parent = Mocks:CreateFrame()
  Waffle:Flex({ frame = parent, direction = "ROW", width = 100, height = 50, children = {} }):Layout()

  assert(parent._test.width == 100 and parent._test.height == 50)
end

-- Test: fixed children that overflow the container clamp the flex size to
-- zero instead of going negative.
do
  local parent = Mocks:CreateFrame()
  local fixed, flex = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 100,
    height = 50,
    children = {
      { frame = fixed, width = 150 }, -- already exceeds the container
      { frame = flex },
    }
  }):Layout()

  assert(flex._test.width == 0)
end

-- Test: the container itself (`options.frame`) is sized to the given
-- width/height, not just its children.
do
  local parent = Mocks:CreateFrame()
  local child = Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 300,
    height = 50,
    children = { { frame = child, width = 100 } }
  }):Layout()

  assert(parent._test.width == 300 and parent._test.height == 50)
end

-- Test: each child's frame is parented to its container's frame, including a
-- frame that started under a different parent.
do
  local parent = Mocks:CreateFrame()
  local child = Mocks:CreateFrame()
  child:SetParent(Mocks:CreateFrame())

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 100,
    height = 50,
    children = { { frame = child, width = 100 } }
  }):Layout()

  assert(child._test.parent == parent)
end

print("All assertions passed.")
