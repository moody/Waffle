--- @diagnostic disable: undefined-field

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: children are positioned in `order` sequence, not declaration
-- sequence.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 100, order = 2 },
      { frame = b, width = 100, order = 0 },
      { frame = c, width = 100, order = 1 },
    }
  }):Layout()

  assert(b._test.point.offsetX == 0)
  assert(c._test.point.offsetX == 100)
  assert(a._test.point.offsetX == 200)
end

-- Test: a child with no `order` defaults to 0, interleaving correctly
-- with siblings that have an explicit order.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 100 }, -- no order, defaults to 0
      { frame = b, width = 100, order = -1 },
      { frame = c, width = 100 }, -- no order, defaults to 0
    }
  }):Layout()

  assert(b._test.point.offsetX == 0)   -- order -1, first
  assert(a._test.point.offsetX == 100) -- order 0, declared before c
  assert(c._test.point.offsetX == 200) -- order 0, declared after a
end

-- Test: equal `order` values keep their declaration order.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 100, order = 5 },
      { frame = b, width = 100, order = 5 },
      { frame = c, width = 100, order = 5 },
    }
  }):Layout()

  assert(a._test.point.offsetX == 0)
  assert(b._test.point.offsetX == 100)
  assert(c._test.point.offsetX == 200)
end

-- Test: `SetOrder` moves a node on the next `Layout()` call; `SetOrder(nil)`
-- resets it back to the default.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  local leafA = container:AddChild({ frame = a, width = 100 })
  container:AddChild({ frame = b, width = 100 })
  container:AddChild({ frame = c, width = 100 })
  container:Layout()

  assert(a._test.point.offsetX == 0 and b._test.point.offsetX == 100 and c._test.point.offsetX == 200)

  leafA:SetOrder(10)
  container:Layout()

  assert(b._test.point.offsetX == 0 and c._test.point.offsetX == 100 and a._test.point.offsetX == 200)

  leafA:SetOrder(nil)
  container:Layout()

  assert(a._test.point.offsetX == 0 and b._test.point.offsetX == 100 and c._test.point.offsetX == 200)
end

-- Test: a child added after a previous `Layout()` call already reordered
-- its siblings still tie-breaks by when it was actually added.
do
  local root = Mocks:CreateFrame()
  local a, b, c, d = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 400, height = 50 })
  container:AddChild({ frame = a, width = 100 })
  local leafB = container:AddChild({ frame = b, width = 100 })
  container:AddChild({ frame = c, width = 100 })
  container:Layout()

  leafB:SetOrder(5)
  container:Layout()                            -- b now sorts last

  container:AddChild({ frame = d, width = 100 }) -- added after the reorder
  container:Layout()

  -- a, c, d default to order 0, tie-broken by add order; b (order 5) last.
  assert(a._test.point.offsetX == 0)
  assert(c._test.point.offsetX == 100)
  assert(d._test.point.offsetX == 200)
  assert(b._test.point.offsetX == 300)
end

-- Test: `SetOrder` marks the tree dirty, but only on an actual value
-- change; calling it with the current order (nil included) is a no-op.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetOrder(nil) -- already nil, no-op
  assert(container:IsDirty() == false)

  leaf:SetOrder(5)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetOrder(5) -- same value, no-op
  assert(container:IsDirty() == false)
end

-- Test: gap applies between visually adjacent siblings after reordering,
-- not declaration-adjacent ones.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 210,
    height = 50,
    gap = 10,
    children = {
      { frame = a, width = 100, order = 2 },
      { frame = b, width = 100, order = 0 },
    }
  }):Layout()

  assert(b._test.point.offsetX == 0)
  assert(a._test.point.offsetX == 110) -- 100 + gap, right after b
end

-- Test: a hidden child's `order` has no effect, it's excluded from the
-- layout flow entirely regardless of where it'd otherwise sort.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 100, order = 2, hidden = true },
      { frame = b, width = 100, order = 0 },
      { frame = c, width = 100, order = 1 },
    }
  }):Layout()

  assert(b._test.point.offsetX == 0)
  assert(c._test.point.offsetX == 100)
  assert(a._test.width == nil) -- excluded entirely
end

print("All assertions passed.")
