--- @diagnostic disable: invisible

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: a freshly created root starts dirty, so the first `Layout()` call
-- runs and clears it.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { { frame = a } }
  })
  assert(container.isDirty == true)

  container:Layout()
  assert(container.isDirty == false)
  assert(a._test.clearedPoints == 1)
end

-- Test: calling `Layout()` again without any change is a no-op, the flag
-- stays clear and `flexLayout` doesn't run again.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = { { frame = a } }
  })

  container:Layout()
  assert(container.isDirty == false)
  assert(a._test.clearedPoints == 1)

  container:Layout()
  assert(a._test.clearedPoints == 1)
end

-- Test: `AddChild` marks the tree dirty again after a clean `Layout()`.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a })
  container:Layout()
  assert(container.isDirty == false)

  container:AddChild({ frame = b })
  assert(container.isDirty == true)

  container:Layout()
  assert(container.isDirty == false)
  assert(a._test.clearedPoints == 2)
  assert(b._test.clearedPoints == 1)
end

-- Test: `AddRow`/`AddColumn` mark the tree dirty too.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a })
  container:Layout()
  assert(container.isDirty == false)

  container:AddRow({ frame = Mocks:CreateFrame() })
  assert(container.isDirty == true)

  container:Layout()
  assert(container.isDirty == false)
  assert(a._test.clearedPoints == 2)

  container:AddColumn({ frame = Mocks:CreateFrame() })
  assert(container.isDirty == true)

  container:Layout()
  assert(container.isDirty == false)
  assert(a._test.clearedPoints == 3)
end

-- Test: mutating through a nested container marks the root's dirty flag (not
-- the nested container itself), so the root's next `Layout()` still picks it up.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local row = container:AddRow({ frame = a })
  container:Layout()
  assert(container.isDirty == false)

  row:AddChild({ frame = b })
  assert(container.isDirty == true)

  container:Layout()
  assert(container.isDirty == false)
  assert(b._test.clearedPoints == 1)
end

-- Test: `GetChild`, a non-mutating call, doesn't mark the tree dirty.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a, key = "a" })
  container:Layout()
  assert(container.isDirty == false)

  container:GetChild("a")
  assert(container.isDirty == false)

  container:Layout()
  assert(a._test.clearedPoints == 1)
end

print("All assertions passed.")
