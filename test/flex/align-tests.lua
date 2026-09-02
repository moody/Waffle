--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: `align = "START"` sizes a child to its own cross-axis dimension
-- (`height`, for ROW; required, doesn't fall back to stretching) and
-- anchors it at the cross axis's start.
do
  local parent = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 200,
    height = 100,
    align = "START",
    children = { { frame = a, height = 30 } }
  }):Layout()

  assert(a._test.height == 30)
  assert(a._test.point.offsetY == 0)
end

-- Test: `align = "CENTER"` centers a child within the cross axis, using
-- its own `height`.
do
  local parent = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 200,
    height = 100,
    align = "CENTER",
    children = { { frame = a, height = 40 } }
  }):Layout()

  assert(a._test.height == 40)
  assert(a._test.point.offsetY == -30) -- (100 - 40) / 2
end

-- Test: `align = "END"` anchors a child flush against the cross axis's far edge.
do
  local parent = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 200,
    height = 100,
    align = "END",
    children = { { frame = a, height = 40 } }
  }):Layout()

  assert(a._test.height == 40)
  assert(a._test.point.offsetY == -60) -- 100 - 40
end

-- Test: a child's own `alignSelf` overrides the container's `align`.
do
  local parent = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 200,
    height = 100,
    align = "START",
    children = {
      { frame = a, height = 40 },                     -- inherits START from the container
      { frame = b, height = 40, alignSelf = "END" },
    }
  }):Layout()

  assert(a._test.point.offsetY == 0)
  assert(b._test.point.offsetY == -60) -- 100 - 40
end

-- Test: a child resolved to a non-`STRETCH` alignment with no `height` of
-- its own errors clearly, alignment never falls back to stretching.
do
  local parent = Mocks:CreateFrame()
  local container = Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 200,
    height = 100,
    align = "CENTER",
  })
  container:AddChild({ frame = Mocks:CreateFrame() }) -- no height

  local ok, err = pcall(function() container:Layout() end)
  assert(not ok)
  assert(tostring(err):find("height"))
end

-- Test: alignment applies to the cross axis regardless of direction: for
-- COLUMN, that's width (X), not height (Y).
do
  local parent = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "COLUMN",
    width = 200,
    height = 100,
    align = "CENTER",
    children = { { frame = a, width = 60 } }
  }):Layout()

  assert(a._test.width == 60)
  assert(a._test.point.offsetX == 70) -- (200 - 60) / 2
end

-- Test: `padding` still applies at the cross axis's start/end even with
-- non-`STRETCH` alignment.
do
  local parent = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 200,
    height = 100,
    padding = 10,
    align = "END",
    children = { { frame = a, height = 30 } }
  }):Layout()

  -- available cross space = 100 - 10*2 = 80; end offset = 10 + (80 - 30) = 60
  assert(a._test.point.offsetY == -60)
end

-- Test: omitting `align`/`alignSelf` entirely still defaults to `STRETCH`,
-- same as before alignment existed.
do
  local parent = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  Waffle:Flex({
    frame = parent,
    direction = "ROW",
    width = 200,
    height = 100,
    children = { { frame = a } }
  }):Layout()

  assert(a._test.height == 100)
  assert(a._test.point.offsetY == 0)
end

print("All assertions passed.")
