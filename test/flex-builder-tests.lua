--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `AddChild` appends children fluently, equivalent to `options.children`.
do
  local parent = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({ parent = parent, direction = "ROW", width = 200, height = 50 })
      :AddChild({ frame = a, size = 50 })
      :AddChild({ frame = b })
      :Layout()

  assert(a._test.width == 50 and a._test.point.offsetX == 0)
  assert(b._test.width == 150 and b._test.point.offsetX == 50) -- 200 - 50
end

-- Test: `AddChild` returns the same builder, so calls chain.
do
  local parent = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local builder = Waffle:Flex({ parent = parent, direction = "ROW", width = 100, height = 50 })
  local returned = builder:AddChild({ frame = a })

  assert(returned == builder)
end

-- Test: children from `options.children` and children added via `AddChild`
-- combine into one layout, in order.
do
  local parent = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    parent = parent,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { { frame = a, size = 50 } }
  }):AddChild({ frame = b }):Layout()

  assert(a._test.width == 50 and a._test.point.offsetX == 0)
  assert(b._test.width == 150 and b._test.point.offsetX == 50)
end

-- Test: `AddRow` returns a builder scoped to a nested ROW container; one
-- root `Layout()` lays out the whole tree.
do
  local root = Mocks:CreateFrame()
  local titleBar = Mocks:CreateFrame()
  local rowFrame = Mocks:CreateFrame()
  local left, right = Mocks:CreateFrame(), Mocks:CreateFrame()

  local builder = Waffle:Flex({ parent = root, direction = "COLUMN", width = 400, height = 300 })
  builder:AddChild({ frame = titleBar, size = 50 })

  local row = builder:AddRow({ frame = rowFrame })
  row:AddChild({ frame = left, size = 150 })
  row:AddChild({ frame = right })

  builder:Layout()

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

  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 100 })
  local col = builder:AddColumn({ frame = colFrame })
  col:AddChild({ frame = top, size = 30 })
  col:AddChild({ frame = bottom })

  builder:Layout()

  assert(colFrame._test.width == 200 and colFrame._test.height == 100)
  assert(top._test.point.offsetX == 0 and top._test.point.offsetY == 0)
  assert(bottom._test.point.offsetX == 0 and bottom._test.point.offsetY == -30)
end

-- Test: nested builders keep nesting (AddRow -> AddColumn), still resolving
-- from one root `Layout()`.
do
  local root = Mocks:CreateFrame()
  local rowFrame, colFrame = Mocks:CreateFrame(), Mocks:CreateFrame()
  local leaf = Mocks:CreateFrame()

  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 100 })
  local row = builder:AddRow({ frame = rowFrame, size = 100 })
  local col = row:AddColumn({ frame = colFrame })
  col:AddChild({ frame = leaf, size = 40 })

  builder:Layout()

  assert(rowFrame._test.width == 100 and rowFrame._test.height == 100)
  assert(colFrame._test.width == 100 and colFrame._test.height == 100)
  assert(leaf._test.width == 100 and leaf._test.height == 40)
  assert(leaf._test.point.parent == colFrame)
end

print("All assertions passed.")
