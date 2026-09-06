--- @diagnostic disable: invisible

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `AddChild` appends children fluently, equivalent to `options.children`.
do
  local parent = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = parent, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a, width = 50 })
  container:AddChild({ frame = b })
  container:Layout()

  assert(a._test.width == 50 and a._test.point.offsetX == 0)
  assert(b._test.width == 150 and b._test.point.offsetX == 50) -- 200 - 50
end

-- Test: `AddChild` returns a component for the child just added, not the
-- same container it was called on.
do
  local parent = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = parent, direction = "ROW", width = 100, height = 50 })
  local leaf = container:AddChild({ frame = a })

  assert(leaf ~= container)
  assert(leaf.node.frame == a)
end

-- Test: children from `options.children` and children added via `AddChild`
-- combine into one layout, in order.
do
  local parent = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { { frame = a, width = 50 } }
  })
  container:AddChild({ frame = b })
  container:Layout()

  assert(a._test.width == 50 and a._test.point.offsetX == 0)
  assert(b._test.width == 150 and b._test.point.offsetX == 50)
end

-- Test: `AddRow` returns the new ROW container, for further composition; one
-- root `Layout()` lays out the whole tree.
do
  local root = Mocks:CreateFrame()
  local titleBar = Mocks:CreateFrame()
  local rowFrame = Mocks:CreateFrame()
  local left, right = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "COLUMN", width = 400, height = 300 })
  container:AddChild({ frame = titleBar, height = 50 })

  local row = container:AddRow({ frame = rowFrame })
  row:AddChild({ frame = left, width = 150 })
  row:AddChild({ frame = right })

  container:Layout()

  assert(rowFrame._test.width == 400 and rowFrame._test.height == 250) -- 300 - 50
  assert(left._test.width == 150 and left._test.height == 250)
  assert(right._test.width == 250 and right._test.height == 250)       -- 400 - 150
  assert(left._test.point.parent == rowFrame)
  assert(right._test.point.parent == rowFrame)
end

-- Test: `AddColumn` works the same way as `AddRow`, but the nested container
-- is a COLUMN.
do
  local root = Mocks:CreateFrame()
  local colFrame = Mocks:CreateFrame()
  local top, bottom = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 100 })
  local col = container:AddColumn({ frame = colFrame })
  col:AddChild({ frame = top, height = 30 })
  col:AddChild({ frame = bottom })

  container:Layout()

  assert(colFrame._test.width == 200 and colFrame._test.height == 100)
  assert(top._test.point.offsetX == 0 and top._test.point.offsetY == 0)
  assert(bottom._test.point.offsetX == 0 and bottom._test.point.offsetY == -30)
end

-- Test: nested containers keep nesting (AddRow -> AddColumn), still
-- resolving from one root `Layout()`.
do
  local root = Mocks:CreateFrame()
  local rowFrame, colFrame = Mocks:CreateFrame(), Mocks:CreateFrame()
  local leaf = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 100 })
  local row = container:AddRow({ frame = rowFrame, width = 100 })
  local col = row:AddColumn({ frame = colFrame })
  col:AddChild({ frame = leaf, height = 40 })

  container:Layout()

  assert(rowFrame._test.width == 100 and rowFrame._test.height == 100)
  assert(colFrame._test.width == 100 and colFrame._test.height == 100)
  assert(leaf._test.width == 100 and leaf._test.height == 40)
  assert(leaf._test.point.parent == colFrame)
end

print("All assertions passed.")
