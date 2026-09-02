--- @diagnostic disable: undefined-field

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `SetGap` changes the gap applied on the next `Layout()` call.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a, width = 50 })
  container:AddChild({ frame = b, width = 50 })
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

-- Test: `SetWidth` makes a leaf's width fixed on the next `Layout()` call, taking
-- space from its flexible sibling; `SetWidth(nil)` un-fixes it.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leafA = container:AddChild({ frame = a })
  container:AddChild({ frame = b })
  container:Layout()

  assert(a._test.width == 100 and b._test.width == 100)

  leafA:SetWidth(50)
  container:Layout()

  assert(a._test.width == 50 and b._test.width == 150)

  leafA:SetWidth(nil)
  container:Layout()

  assert(a._test.width == 100 and b._test.width == 100)
end

-- Test: `SetWidth("AUTO")` switches a node from flexible to computed from
-- its own children, on the next `Layout()` call.
do
  local root = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local auto = container:AddChild({ frame = autoFrame, children = {} })
  auto:AddChild({ frame = a, width = 25 })
  container:Layout()

  assert(autoFrame._test.width == 200) -- still flexible, fills the row

  auto:SetWidth("AUTO")
  container:Layout()

  assert(autoFrame._test.width == 25) -- computed from its own child
end

-- Test: `SetHeight("AUTO")` does the same on a COLUMN container, main axis
-- there is height instead of width.
do
  local root = Mocks:CreateFrame()
  local autoFrame = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "COLUMN", width = 50, height = 200 })
  -- `auto` needs its own `direction = "COLUMN"` too: "AUTO" legality
  -- depends on a node's own main axis, not its parent's.
  local auto = container:AddChild({ frame = autoFrame, direction = "COLUMN", children = {} })
  auto:AddChild({ frame = a, height = 25 })
  container:Layout()

  assert(autoFrame._test.height == 200) -- still flexible, fills the column

  auto:SetHeight("AUTO")
  container:Layout()

  assert(autoFrame._test.height == 25) -- computed from its own child
end

-- Test: `SetWidth` also works on a container, not just a leaf.
do
  local root = Mocks:CreateFrame()
  local colFrame = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local col = container:AddColumn({ frame = colFrame })
  container:AddChild({ frame = b })
  container:Layout()

  assert(colFrame._test.width == 100 and b._test.width == 100)

  col:SetWidth(120)
  container:Layout()

  assert(colFrame._test.width == 120 and b._test.width == 80)
end

-- Test: `SetHeight` makes a leaf stop stretching on the next `Layout()`
-- call, sized to that instead; `SetHeight(nil)` reverts it to stretching.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leafA = container:AddChild({ frame = a })
  container:Layout()

  assert(a._test.height == 50)

  leafA:SetHeight(20)
  container:Layout()

  assert(a._test.height == 20)

  leafA:SetHeight(nil)
  container:Layout()

  assert(a._test.height == 50)
end

-- Test: `SetHeight` also works on a container, not just a leaf.
do
  local root = Mocks:CreateFrame()
  local colFrame = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local col = container:AddColumn({ frame = colFrame })
  container:Layout()

  assert(colFrame._test.height == 50)

  col:SetHeight(30)
  container:Layout()

  assert(colFrame._test.height == 30)
end

-- Test: `SetAlign` changes a container's default alignment on the next
-- `Layout()` call.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 100 })
  container:AddChild({ frame = a, height = 40 })
  container:Layout()

  assert(a._test.point.offsetY == 0) -- default STRETCH; a fixed height just isn't stretched, still starts at 0

  container:SetAlign("CENTER")
  container:Layout()

  assert(a._test.point.offsetY == -30) -- (100 - 40) / 2
end

-- Test: `SetAlignSelf` changes one child's own alignment, overriding the
-- container's, on the next `Layout()` call; `SetAlignSelf(nil)` reverts to
-- inheriting the container's `align` again.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 100, align = "START" })
  local leaf = container:AddChild({ frame = a, height = 40 })
  container:Layout()

  assert(a._test.point.offsetY == 0)

  leaf:SetAlignSelf("END")
  container:Layout()

  assert(a._test.point.offsetY == -60) -- 100 - 40

  leaf:SetAlignSelf(nil)
  container:Layout()

  assert(a._test.point.offsetY == 0) -- back to inheriting the container's START
end

-- Test: `SetJustify` changes a container's main-axis distribution on the
-- next `Layout()` call.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a, width = 50 })
  container:AddChild({ frame = b, width = 50 })
  container:Layout()

  assert(b._test.point.offsetX == 50) -- default START, packed together

  container:SetJustify("SPACE_BETWEEN")
  container:Layout()

  assert(a._test.point.offsetX == 0)
  assert(b._test.point.offsetX == 150) -- all 100 leftover between the two
end

-- Test: `SetGap`/`SetPadding`/`SetWidth`/`SetHeight` mark the tree dirty,
-- but only on an actual value change; calling any of them with the current
-- value is a no-op.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50, gap = 5, padding = 5 })
  local leaf = container:AddChild({ frame = a, width = 50 })
  container:Layout()
  assert(container:IsDirty() == false)

  container:SetGap(5)
  assert(container:IsDirty() == false)
  container:SetGap(10)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  container:SetPadding(5)
  assert(container:IsDirty() == false)
  container:SetPadding(10)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetWidth(50)
  assert(container:IsDirty() == false)
  leaf:SetWidth(60)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetHeight(nil)
  assert(container:IsDirty() == false)
  leaf:SetHeight(20)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  container:SetAlign(nil)
  assert(container:IsDirty() == false)
  container:SetAlign("CENTER")
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetAlignSelf(nil)
  assert(container:IsDirty() == false)
  leaf:SetAlignSelf("END")
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  container:SetJustify(nil)
  assert(container:IsDirty() == false)
  container:SetJustify("CENTER")
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)
end

-- Test: `SetGap`/`SetPadding`/`SetAlign`/`SetJustify` are container-only, a
-- leaf can never have children so it never gets them; `SetWidth`/
-- `SetHeight`/`SetAlignSelf` are shared by both.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })

  assert(leaf.SetGap == nil)
  assert(leaf.SetPadding == nil)
  assert(leaf.SetJustify == nil)
  assert(leaf.SetAlign == nil)
  assert(leaf.SetWidth ~= nil)
  assert(container.SetWidth ~= nil)
  assert(leaf.SetHeight ~= nil)
  assert(container.SetHeight ~= nil)
  assert(leaf.SetAlignSelf ~= nil)
  assert(container.SetAlignSelf ~= nil)
  assert(container.SetJustify ~= nil)
end

print("All assertions passed.")
