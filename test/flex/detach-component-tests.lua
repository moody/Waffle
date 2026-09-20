--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `DetachComponent` detaches a child entirely, siblings reflow into
-- the freed space.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  local leafA = container:AddChild({ frame = a, width = 100 })
  container:AddChild({ frame = b, width = 100 })
  container:AddChild({ frame = c, width = 100 })
  container:Layout()

  assert(a._test.point.offsetX == 0 and b._test.point.offsetX == 100 and c._test.point.offsetX == 200)

  container:DetachComponent(leafA)
  container:Layout()

  assert(b._test.point.offsetX == 0)
  assert(c._test.point.offsetX == 100)
end

-- Test: `DetachComponent` doesn't touch the removed child's own frame,
-- only Waffle's tracking of it, the caller owns what happens to it afterward.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a, width = 100 })
  container:Layout()

  local hideCallsBefore = a._test.hideCalls
  container:DetachComponent(leaf)
  container:Layout()

  assert(a._test.hideCalls == hideCallsBefore)
end

-- Test: detaching a component detaches its whole subtree, nested children
-- stop being laid out too.
do
  local root = Mocks:CreateFrame()
  local nested = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  local row = container:AddRow({ frame = Mocks:CreateFrame() })
  row:AddChild({ frame = nested })
  container:Layout()
  assert(nested._test.width == 300)

  container:DetachComponent(row)
  nested._test.width = nil
  container:Layout()

  assert(nested._test.width == nil)
end

-- Test: a detached child's `key` no longer resolves via `FindByKey`.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a, key = "sidebar" })
  container:Layout()

  assert(container:FindByKey("sidebar"):GetFrame() == a)

  container:DetachComponent(leaf)

  local ok = pcall(function() container:FindByKey("sidebar") end)
  assert(not ok)
end

-- Test: `DetachComponent` returns `false` if `component` isn't actually a
-- child of this container, including calling it again on an
-- already-detached component. Returns `true` when it actually detached something.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local containerA = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local containerB = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = containerA:AddChild({ frame = a })

  assert(containerB:DetachComponent(leaf) == false)
  assert(containerA:DetachComponent(leaf) == true)
  assert(containerA:DetachComponent(leaf) == false)
end

-- Test: `DetachComponent` marks the tree dirty.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })
  container:Layout()
  assert(container:IsDirty() == false)

  container:DetachComponent(leaf)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)
end

-- Test: a detached child attached again later gets a fresh declaration
-- order, not its original one, so it tie-breaks after whatever's
-- currently there, not back in its old position.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  container:AddChild({ frame = a, width = 100 })
  local leafB = container:AddChild({ frame = b, width = 100 })
  container:AddChild({ frame = c, width = 100 })
  container:Layout()

  assert(b._test.point.offsetX == 100) -- b's old position, before detaching

  container:DetachComponent(leafB)
  container:AttachComponent(leafB)
  container:Layout()

  assert(a._test.point.offsetX == 0)
  assert(c._test.point.offsetX == 100)
  assert(b._test.point.offsetX == 200)
end

-- Test: `Detach` removes a child from its current owner, siblings reflow
-- into the freed space, same as `DetachComponent` called on that owner.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a, width = 100 })
  container:AddChild({ frame = b, width = 100 })
  container:Layout()

  assert(b._test.point.offsetX == 100)
  assert(#container:GetChildren() == 2)

  leaf:Detach()
  container:Layout()

  assert(b._test.point.offsetX == 0)
  assert(#container:GetChildren() == 1)
end

-- Test: `Detach` returns the same component, usable immediately, whether
-- or not it actually had an owner to release.
do
  local leafFrame = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = Mocks:CreateFrame(), direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = leafFrame })
  local root = Waffle:Flex({ frame = Mocks:CreateFrame(), direction = "ROW", width = 200, height = 50 })

  assert(leaf:Detach() == leaf)
  assert(leaf:Detach() == leaf) -- already detached, still returns itself
  assert(root:Detach() == root) -- never had an owner at all, same result
end

-- Test: `Detach` moves a component straight into a different tree in one
-- step, no need to already hold its current owner.
do
  local rootAFrame, rootBFrame = Mocks:CreateFrame(), Mocks:CreateFrame()
  local sidebarFrame = Mocks:CreateFrame()

  local containerA = Waffle:Flex({ frame = rootAFrame, direction = "ROW", width = 200, height = 50 })
  containerA:AddChild({ frame = sidebarFrame, key = "sidebar", width = 100 })
  containerA:Layout()

  assert(#containerA:GetChildren() == 1)
  assert(sidebarFrame._test.point.parent == rootAFrame)

  local containerB = Waffle:Flex({ frame = rootBFrame, direction = "ROW", width = 300, height = 50 })
  containerB:AttachComponent(containerA:FindByKey("sidebar"):Detach())
  containerB:Layout()

  assert(#containerA:GetChildren() == 0)
  assert(#containerB:GetChildren() == 1)
  assert(sidebarFrame._test.point.parent == rootBFrame)
end

-- Test: `Clear` removes every child at once, `Layout()` treats the
-- container as empty afterward.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a, width = 100 })
  container:AddChild({ frame = b, width = 100 })
  container:Layout()

  container:Clear()
  container:Layout()

  assert(#container:GetChildren() == 0)
end

-- Test: `Clear` is a no-op, `isDirty` included, if already empty.
do
  local root = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:Layout()
  assert(container:IsDirty() == false)

  container:Clear()
  assert(container:IsDirty() == false)
end

print("All assertions passed.")
