--- @diagnostic disable: invisible, undefined-field

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `SetGap` changes the gap applied on the next `Layout()` call.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a, size = 50 })
  container:AddChild({ frame = b, size = 50 })
  container:Layout()

  assert(b._test.point.offsetX == 50)

  container:SetGap(10)
  container:Layout()

  assert(b._test.point.offsetX == 60)
end

-- Test: `SetPadding` changes the padding applied on the next `Layout()` call.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a })
  container:Layout()

  assert(a._test.point.offsetX == 0)
  assert(a._test.width == 200)

  container:SetPadding(10)
  container:Layout()

  assert(a._test.point.offsetX == 10)
  assert(a._test.width == 180)
end

-- Test: `SetSize` makes a leaf's size fixed on the next `Layout()` call, taking
-- space from its flexible sibling; `SetSize(nil)` un-fixes it.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leafA = container:AddChild({ frame = a })
  container:AddChild({ frame = b })
  container:Layout()

  assert(a._test.width == 100 and b._test.width == 100)

  leafA:SetSize(50)
  container:Layout()

  assert(a._test.width == 50 and b._test.width == 150)

  leafA:SetSize(nil)
  container:Layout()

  assert(a._test.width == 100 and b._test.width == 100)
end

-- Test: `SetSize` also works on a container, not just a leaf.
do
  local root = Mocks:CreateFrame()
  local colFrame = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local col = container:AddColumn({ frame = colFrame })
  container:AddChild({ frame = b })
  container:Layout()

  assert(colFrame._test.width == 100 and b._test.width == 100)

  col:SetSize(120)
  container:Layout()

  assert(colFrame._test.width == 120 and b._test.width == 80)
end

-- Test: `SetGap`/`SetPadding`/`SetSize` mark the tree dirty, but only on an
-- actual value change; calling any of them with the current value is a no-op.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50, gap = 5, padding = 5 })
  local leaf = container:AddChild({ frame = a, size = 50 })
  container:Layout()
  assert(container.isDirty == false)

  container:SetGap(5)
  assert(container.isDirty == false)
  container:SetGap(10)
  assert(container.isDirty == true)
  container:Layout()
  assert(container.isDirty == false)

  container:SetPadding(5)
  assert(container.isDirty == false)
  container:SetPadding(10)
  assert(container.isDirty == true)
  container:Layout()
  assert(container.isDirty == false)

  leaf:SetSize(50)
  assert(container.isDirty == false)
  leaf:SetSize(60)
  assert(container.isDirty == true)
  container:Layout()
  assert(container.isDirty == false)
end

-- Test: `SetGap`/`SetPadding` are container-only, a leaf can never have
-- children so it never gets them; `SetSize` is shared by both.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })

  assert(leaf.SetGap == nil)
  assert(leaf.SetPadding == nil)
  assert(leaf.SetSize ~= nil)
  assert(container.SetSize ~= nil)
end

print("All assertions passed.")
