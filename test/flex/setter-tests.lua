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

-- Test: `SetPadding` changes the padding applied on the next `Layout()`
-- call, on all four sides at once.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 100 })
  container:AddChild({ frame = a })
  container:Layout()

  assert(a._test.point.offsetX == 0 and a._test.width == 200)
  assert(a._test.point.offsetY == 0 and a._test.height == 100)

  container:SetPadding(10)
  container:Layout()

  assert(a._test.point.offsetX == 10 and a._test.width == 180)
  assert(a._test.point.offsetY == -10 and a._test.height == 80)

  container:SetPadding(nil)
  container:Layout()

  assert(a._test.point.offsetX == 0 and a._test.width == 200)
  assert(a._test.point.offsetY == 0 and a._test.height == 100)
end

-- Test: `SetPaddingTop` insets the cross axis on the next `Layout()`
-- call; `SetPaddingTop(nil)` removes it.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 100 })
  container:AddChild({ frame = a })
  container:Layout()

  assert(a._test.height == 100 and a._test.point.offsetY == 0)

  container:SetPaddingTop(10)
  container:Layout()

  assert(a._test.height == 90 and a._test.point.offsetY == -10)

  container:SetPaddingTop(nil)
  container:Layout()

  assert(a._test.height == 100 and a._test.point.offsetY == 0)
end

-- Test: `SetPaddingRight` shrinks the main axis on the next `Layout()`
-- call without moving its content, unlike `SetPaddingLeft`, which shifts
-- it too; `SetPaddingRight(nil)` removes it.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a })
  container:Layout()

  assert(a._test.width == 200 and a._test.point.offsetX == 0)

  container:SetPaddingRight(30)
  container:Layout()

  assert(a._test.width == 170 and a._test.point.offsetX == 0)

  container:SetPaddingRight(nil)
  container:Layout()

  assert(a._test.width == 200 and a._test.point.offsetX == 0)
end

-- Test: `SetPaddingBottom` shrinks the cross axis on the next `Layout()`
-- call without moving its content, unlike `SetPaddingTop`, which shifts
-- it too; `SetPaddingBottom(nil)` removes it.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 100 })
  container:AddChild({ frame = a })
  container:Layout()

  assert(a._test.height == 100 and a._test.point.offsetY == 0)

  container:SetPaddingBottom(20)
  container:Layout()

  assert(a._test.height == 80 and a._test.point.offsetY == 0)

  container:SetPaddingBottom(nil)
  container:Layout()

  assert(a._test.height == 100 and a._test.point.offsetY == 0)
end

-- Test: `SetPaddingLeft` overrides `SetPadding` for that side only on the
-- next `Layout()` call; `nil` reverts to it.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50, padding = 10 })
  container:AddChild({ frame = a })
  container:Layout()

  assert(a._test.point.offsetX == 10)
  assert(a._test.width == 180)

  container:SetPaddingLeft(30)
  container:Layout()

  assert(a._test.point.offsetX == 30)
  assert(a._test.width == 160) -- 200 - 30 - 10 (padding, right)

  container:SetPaddingLeft(nil)
  container:Layout()

  assert(a._test.point.offsetX == 10)
  assert(a._test.width == 180)
end

-- Test: `SetWidth` makes a node's width fixed on the next `Layout()` call, taking
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

-- Test: `SetHeight` makes a node stop stretching on the next `Layout()`
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

-- Test: `SetSize` sets width and height together; `SetSize(nil, nil)` reverts
-- both to flex/stretch.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })

  leaf:SetSize(50, 20)
  container:Layout()

  assert(a._test.width == 50)
  assert(a._test.height == 20)

  leaf:SetSize(nil, nil)
  container:Layout()

  assert(a._test.width == 200) -- back to flexing, alone on the line so it claims all of it
  assert(a._test.height == 50) -- back to stretching
end

-- Test: `SetGrow` changes a flexible child's own share of leftover
-- space on the next `Layout()` call; `SetGrow(nil)` reverts it to the
-- default (equal) share.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  local leafA = container:AddChild({ frame = a })
  container:AddChild({ frame = b })
  container:Layout()

  assert(a._test.width == 150 and b._test.width == 150)

  leafA:SetGrow(2)
  container:Layout()

  assert(a._test.width == 200 and b._test.width == 100)

  leafA:SetGrow(nil)
  container:Layout()

  assert(a._test.width == 150 and b._test.width == 150)
end

-- Test: `SetMinWidth`/`SetMaxWidth` clamp a flexible child's own share of
-- leftover space on the next `Layout()` call; `nil` removes the clamp.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  local leafA = container:AddChild({ frame = a })
  container:AddChild({ frame = b })
  container:Layout()

  assert(a._test.width == 150 and b._test.width == 150)

  leafA:SetMaxWidth(50)
  container:Layout()

  assert(a._test.width == 50 and b._test.width == 250)

  leafA:SetMaxWidth(nil)
  leafA:SetMinWidth(200)
  container:Layout()

  assert(a._test.width == 200 and b._test.width == 100)

  leafA:SetMinWidth(nil)
  container:Layout()

  assert(a._test.width == 150 and b._test.width == 150)
end

-- Test: `SetMinHeight`/`SetMaxHeight` do the same on a COLUMN, main axis
-- there is height instead of width.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "COLUMN", width = 50, height = 300 })
  local leafA = container:AddChild({ frame = a })
  container:AddChild({ frame = b })
  container:Layout()

  assert(a._test.height == 150 and b._test.height == 150)

  leafA:SetMaxHeight(50)
  container:Layout()

  assert(a._test.height == 50 and b._test.height == 250)

  leafA:SetMaxHeight(nil)
  leafA:SetMinHeight(200)
  container:Layout()

  assert(a._test.height == 200 and b._test.height == 100)

  leafA:SetMinHeight(nil)
  container:Layout()

  assert(a._test.height == 150 and b._test.height == 150)
end

-- Test: `SetAlign` changes a container's default alignment on the next
-- `Layout()` call.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 100 })
  container:AddChild({ frame = a, height = 40 })
  container:Layout()

  assert(a._test.point.offsetY == 0) -- default `STRETCH`; a fixed height just isn't stretched, still starts at 0

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

-- Test: `SetMargin` sets all four sides at once on the next `Layout()`
-- call, affecting both axes; `SetMargin(nil)` removes it.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 100 })
  local leafA = container:AddChild({ frame = a, width = 50 })
  container:AddChild({ frame = b })
  container:Layout()

  assert(a._test.point.offsetX == 0 and a._test.height == 100 and a._test.point.offsetY == 0)
  assert(b._test.width == 250 and b._test.point.offsetX == 50)

  leafA:SetMargin(10)
  container:Layout()

  assert(a._test.point.offsetX == 10 and a._test.height == 80 and a._test.point.offsetY == -10)
  assert(b._test.width == 230 and b._test.point.offsetX == 70) -- 10 + 50 + 10

  leafA:SetMargin(nil)
  container:Layout()

  assert(a._test.point.offsetX == 0 and a._test.height == 100 and a._test.point.offsetY == 0)
  assert(b._test.width == 250 and b._test.point.offsetX == 50)
end

-- Test: `SetMarginTop` insets a `STRETCH`-ed child's cross-axis size on
-- the next `Layout()` call; `SetMarginTop(nil)` removes it.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 100 })
  local leafA = container:AddChild({ frame = a })
  container:Layout()

  assert(a._test.height == 100 and a._test.point.offsetY == 0)

  leafA:SetMarginTop(10)
  container:Layout()

  assert(a._test.height == 90 and a._test.point.offsetY == -10)

  leafA:SetMarginTop(nil)
  container:Layout()

  assert(a._test.height == 100 and a._test.point.offsetY == 0)
end

-- Test: `SetMarginRight` adds space after this node on the next
-- `Layout()` call, taken out of its flexible sibling's own share;
-- `SetMarginRight(nil)` removes it.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  local leafA = container:AddChild({ frame = a, width = 50 })
  container:AddChild({ frame = b })
  container:Layout()

  assert(b._test.width == 250 and b._test.point.offsetX == 50)

  leafA:SetMarginRight(20)
  container:Layout()

  assert(b._test.width == 230 and b._test.point.offsetX == 70) -- 50 + 20

  leafA:SetMarginRight(nil)
  container:Layout()

  assert(b._test.width == 250 and b._test.point.offsetX == 50)
end

-- Test: `SetMarginBottom` shrinks a `STRETCH`-ed child's cross-axis size
-- on the next `Layout()` call without moving it, unlike `SetMarginTop`,
-- which shifts it too; `SetMarginBottom(nil)` removes it.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 100 })
  local leafA = container:AddChild({ frame = a })
  container:Layout()

  assert(a._test.height == 100 and a._test.point.offsetY == 0)

  leafA:SetMarginBottom(10)
  container:Layout()

  assert(a._test.height == 90 and a._test.point.offsetY == 0)

  leafA:SetMarginBottom(nil)
  container:Layout()

  assert(a._test.height == 100 and a._test.point.offsetY == 0)
end

-- Test: `SetMarginLeft` shifts this node's own position on the next
-- `Layout()` call, unlike `SetMarginRight`, which only shifts what comes
-- after it; `SetMarginLeft(nil)` removes it.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 300, height = 50 })
  local leafA = container:AddChild({ frame = a, width = 50 })
  container:AddChild({ frame = b })
  container:Layout()

  assert(a._test.point.offsetX == 0)
  assert(b._test.width == 250 and b._test.point.offsetX == 50)

  leafA:SetMarginLeft(20)
  container:Layout()

  assert(a._test.point.offsetX == 20)
  assert(b._test.width == 230 and b._test.point.offsetX == 70) -- 20 + 50

  leafA:SetMarginLeft(nil)
  container:Layout()

  assert(a._test.point.offsetX == 0)
  assert(b._test.width == 250 and b._test.point.offsetX == 50)
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

-- Test: `SetWrap` makes overflowing children wrap onto a new line on the
-- next `Layout()` call, each fitting on its own so neither needs to
-- shrink; `SetWrap(false)` reverts to one line, both shrinking to fit
-- it since default `shrink` gives some back rather than overflowing.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 100, height = 200 })
  container:AddChild({ frame = a, width = 60, height = 30 })
  container:AddChild({ frame = b, width = 60, height = 40 })
  container:Layout()

  assert(a._test.point.offsetX == 0 and a._test.point.offsetY == 0)
  assert(b._test.point.offsetX == 50 and b._test.point.offsetY == 0) -- both shrink to 50, same line

  container:SetWrap(true)
  container:Layout()

  assert(a._test.point.offsetX == 0 and a._test.point.offsetY == 0)
  assert(b._test.point.offsetX == 0 and b._test.point.offsetY == -30) -- new line, after a's own height

  container:SetWrap(false)
  container:Layout()

  assert(b._test.point.offsetX == 50 and b._test.point.offsetY == 0) -- back to one line, shrinking again
end

-- Test: every setter marks the tree dirty, but only on an actual value
-- change; calling one with its current value is a no-op.
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

  container:SetPaddingTop(nil)
  assert(container:IsDirty() == false)
  container:SetPaddingTop(5)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  container:SetPaddingRight(nil)
  assert(container:IsDirty() == false)
  container:SetPaddingRight(5)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  container:SetPaddingBottom(nil)
  assert(container:IsDirty() == false)
  container:SetPaddingBottom(5)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  container:SetPaddingLeft(nil)
  assert(container:IsDirty() == false)
  container:SetPaddingLeft(5)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetMargin(nil)
  assert(container:IsDirty() == false)
  leaf:SetMargin(5)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetMarginTop(nil)
  assert(container:IsDirty() == false)
  leaf:SetMarginTop(5)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetMarginRight(nil)
  assert(container:IsDirty() == false)
  leaf:SetMarginRight(5)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetMarginBottom(nil)
  assert(container:IsDirty() == false)
  leaf:SetMarginBottom(5)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetMarginLeft(nil)
  assert(container:IsDirty() == false)
  leaf:SetMarginLeft(5)
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

  leaf:SetGrow(nil)
  assert(container:IsDirty() == false)
  leaf:SetGrow(2)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetMinWidth(nil)
  assert(container:IsDirty() == false)
  leaf:SetMinWidth(100)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetMaxWidth(nil)
  assert(container:IsDirty() == false)
  leaf:SetMaxWidth(150)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetMinHeight(nil)
  assert(container:IsDirty() == false)
  leaf:SetMinHeight(10)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetMaxHeight(nil)
  assert(container:IsDirty() == false)
  leaf:SetMaxHeight(40)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetVisibility(nil)
  assert(container:IsDirty() == false)
  leaf:SetVisibility("GONE")
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  container:SetJustify(nil)
  assert(container:IsDirty() == false)
  container:SetJustify("CENTER")
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  container:SetWrap(nil)
  assert(container:IsDirty() == false)
  container:SetWrap(true)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  container:SetDirection("ROW")
  assert(container:IsDirty() == false)
  container:SetDirection("COLUMN")
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetOnLayout(nil)
  assert(container:IsDirty() == false)
  leaf:SetOnLayout(function() end)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  container:SetDefaultFrameFactory(nil)
  assert(container:IsDirty() == false)
  container:SetDefaultFrameFactory(function() return Mocks:CreateFrame() end)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)

  container:SetLineGap(nil)
  assert(container:IsDirty() == false)
  container:SetLineGap(4)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)
  container:SetLineGap(4) -- same value, no-op
  assert(container:IsDirty() == false)

  leaf:SetShrink(nil)
  assert(container:IsDirty() == false)
  leaf:SetShrink(0)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)
  leaf:SetShrink(0) -- same value, no-op
  assert(container:IsDirty() == false)

  leaf:SetOrder(nil)
  assert(container:IsDirty() == false)
  leaf:SetOrder(5)
  assert(container:IsDirty() == true)
  container:Layout()
  assert(container:IsDirty() == false)
  leaf:SetOrder(5) -- same value, no-op
  assert(container:IsDirty() == false)
end

-- Test: unlike every other setter, `SetKey` never marks the tree dirty,
-- there's nothing for a `Layout()` call to recompute.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:SetKey("a")
  assert(container:IsDirty() == false)
end

print("All assertions passed.")
