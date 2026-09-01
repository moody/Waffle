--- @diagnostic disable: invisible

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `RemoveChild` detaches a leaf entirely, siblings reflow into the
-- freed space.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  local leafA = container:AddChild({ frame = a, size = 100 })
  container:AddChild({ frame = b, size = 100 })
  container:AddChild({ frame = c, size = 100 })
  container:Layout()

  assert(a._test.point.offsetX == 0 and b._test.point.offsetX == 100 and c._test.point.offsetX == 200)

  container:RemoveChild(leafA)
  container:Layout()

  assert(b._test.point.offsetX == 0)
  assert(c._test.point.offsetX == 100)
end

-- Test: `RemoveChild` doesn't touch the removed child's own frame, only
-- Waffle's tracking of it, the caller owns what happens to it afterward.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a, size = 100 })
  container:Layout()

  local hideCallsBefore = a._test.hideCalls
  container:RemoveChild(leaf)
  container:Layout()

  assert(a._test.hideCalls == hideCallsBefore)
end

-- Test: removing a container detaches its whole subtree, nested children
-- stop being laid out too.
do
  local root = Mocks:CreateFrame()
  local nested = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  local row = container:AddRow({ frame = Mocks:CreateFrame() })
  row:AddChild({ frame = nested })
  container:Layout()
  assert(nested._test.width ~= nil)

  container:RemoveChild(row)
  nested._test.width = nil
  container:Layout()

  assert(nested._test.width == nil)
end

-- Test: a removed child's `key` no longer resolves via `GetChild`.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a, key = "sidebar" })
  container:Layout()

  assert(container:GetChild("sidebar").node.frame == a)

  container:RemoveChild(leaf)

  local ok = pcall(function() container:GetChild("sidebar") end)
  assert(not ok)
end

-- Test: `RemoveChild` returns `false` if `child` isn't actually a child of
-- this container, including calling it again on an already-removed child.
-- Returns `true` when it actually removed something.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local containerA = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local containerB = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = containerA:AddChild({ frame = a })

  assert(containerB:RemoveChild(leaf) == false)
  assert(containerA:RemoveChild(leaf) == true)
  assert(containerA:RemoveChild(leaf) == false)
end

-- Test: `RemoveChild` marks the tree dirty.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })
  container:Layout()
  assert(container.isDirty == false)

  container:RemoveChild(leaf)
  assert(container.isDirty == true)
  container:Layout()
  assert(container.isDirty == false)
end

-- Test: a removed child added again later gets a fresh declaration order,
-- not its original one, so it tie-breaks after whatever's currently there,
-- not back in its old position.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  container:AddChild({ frame = a, size = 100 })
  local leafB = container:AddChild({ frame = b, size = 100 })
  container:AddChild({ frame = c, size = 100 })
  container:Layout()

  assert(b._test.point.offsetX == 100) -- b's old position, before removal

  local bNode = leafB.node
  container:RemoveChild(leafB)
  container:AddChild(bNode)
  container:Layout()

  assert(a._test.point.offsetX == 0)
  assert(c._test.point.offsetX == 100)
  assert(b._test.point.offsetX == 200)
end

-- Test: `Clear` removes every child at once, `Layout()` treats the
-- container as empty afterward.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a, size = 100 })
  container:AddChild({ frame = b, size = 100 })
  container:Layout()

  container:Clear()
  container:Layout()

  assert(#container.node.children == 0)
end

-- Test: `Clear` is a no-op, `isDirty` included, if already empty.
do
  local root = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:Layout()
  assert(container.isDirty == false)

  container:Clear()
  assert(container.isDirty == false)
end

print("All assertions passed.")
