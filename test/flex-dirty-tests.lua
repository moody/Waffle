--- @diagnostic disable: invisible

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: a freshly created root starts dirty, so the first `Layout()` call
-- runs and clears it.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { { frame = a } }
  })
  assert(builder.isDirty == true)

  builder:Layout()
  assert(builder.isDirty == false)
  assert(a._test.clearedPoints == 1)
end

-- Test: calling `Layout()` again without any change is a no-op, the flag
-- stays clear and `flexLayout` doesn't run again.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local builder = Waffle:Flex({
    parent = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { { frame = a } }
  })

  builder:Layout()
  assert(builder.isDirty == false)
  assert(a._test.clearedPoints == 1)

  builder:Layout()
  assert(a._test.clearedPoints == 1)
end

-- Test: `AddChild` marks the tree dirty again after a clean `Layout()`.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  builder:AddChild({ frame = a })
  builder:Layout()
  assert(builder.isDirty == false)

  builder:AddChild({ frame = b })
  assert(builder.isDirty == true)

  builder:Layout()
  assert(builder.isDirty == false)
  assert(a._test.clearedPoints == 2)
  assert(b._test.clearedPoints == 1)
end

-- Test: `AddRow`/`AddColumn` mark the tree dirty too.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  builder:AddChild({ frame = a })
  builder:Layout()
  assert(builder.isDirty == false)

  builder:AddRow({ frame = Mocks:CreateFrame() })
  assert(builder.isDirty == true)

  builder:Layout()
  assert(builder.isDirty == false)
  assert(a._test.clearedPoints == 2)

  builder:AddColumn({ frame = Mocks:CreateFrame() })
  assert(builder.isDirty == true)

  builder:Layout()
  assert(builder.isDirty == false)
  assert(a._test.clearedPoints == 3)
end

-- Test: mutating through a nested builder marks the root's dirty flag (not
-- the nested builder itself), so the root's next `Layout()` still picks it up.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  local row = builder:AddRow({ frame = a })
  builder:Layout()
  assert(builder.isDirty == false)

  row:AddChild({ frame = b })
  assert(builder.isDirty == true)

  builder:Layout()
  assert(builder.isDirty == false)
  assert(b._test.clearedPoints == 1)
end

-- Test: `GetChild`, a non-mutating call, doesn't mark the tree dirty.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local builder = Waffle:Flex({ parent = root, direction = "ROW", width = 200, height = 50 })
  builder:AddChild({ frame = a, key = "a" })
  builder:Layout()
  assert(builder.isDirty == false)

  builder:GetChild("a")
  assert(builder.isDirty == false)

  builder:Layout()
  assert(a._test.clearedPoints == 1)
end

print("All assertions passed.")
