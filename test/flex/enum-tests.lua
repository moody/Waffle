--- @diagnostic disable: assign-type-mismatch, param-type-mismatch

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- =============================================================================
-- Setup
-- =============================================================================

--- A value no enum field will ever support.
local INVALID_VALUE = "INVALID_TEST_VALUE"

--- Asserts that `fn(...)` throws an error naming `field` and `INVALID_VALUE`, so
--- an unrelated error does not pass.
--- @param field string
--- @param fn function
--- @param ... any
local function assertRejects(field, fn, ...)
  local ok, err = pcall(fn, ...)
  assert(not ok, field)
  assert(tostring(err):find(field, 1, true) and tostring(err):find(INVALID_VALUE, 1, true),
    field .. ": " .. tostring(err))
end

--- @class EnumTestSpec
--- @field field string The enum field's name.
--- @field setter string The name of its setter.
--- @field getter string The name of its getter.
--- @field valid string A lowercase spelling of one of its real values.
--- @field onChild? boolean Puts the field on the first child, not the container.

-- The enum fields other than `visibility`, whose shared parsing
-- `visibility-tests.lua` covers in full.
--- @type EnumTestSpec[]
local SPECS = {
  { field = "direction", setter = "SetDirection", getter = "GetDirection", valid = "row_reverse" },
  { field = "align",     setter = "SetAlign",     getter = "GetAlign",     valid = "center" },
  { field = "alignSelf", setter = "SetAlignSelf", getter = "GetAlignSelf", valid = "end",          onChild = true },
  { field = "justify",   setter = "SetJustify",   getter = "GetJustify",   valid = "space_between" },
}

--- Builds a row of two fixed-size children with `value` given to the spec's
--- field.
--- @param spec EnumTestSpec
--- @param value any
--- @return WaffleFlexComponent container
--- @return WaffleFlexComponent firstChild
--- @return WaffleMockFrame firstChildFrame
local function build(spec, value)
  local frame = Mocks:CreateFrame()
  local first = { frame = frame, width = 30, height = 20 }
  local node = {
    frame = Mocks:CreateFrame(),
    direction = "ROW",
    width = 100,
    height = 50,
    children = { first, { frame = Mocks:CreateFrame(), width = 30, height = 20 } }
  }

  local target = spec.onChild and first or node
  target[spec.field] = value

  local container = Waffle:Flex(node)
  return container, container:GetChildren()[1], frame
end

-- =============================================================================
-- Tests
-- =============================================================================

-- Test: an unrecognized value in a node table throws an error naming the
-- field and the value when `Layout()` reads it.
for _, spec in ipairs(SPECS) do
  local container = build(spec, INVALID_VALUE)
  assertRejects(spec.field, container.Layout, container)
end

-- Test: a lowercase spelling of a real value lays out the same as its
-- uppercase spelling.
for _, spec in ipairs(SPECS) do
  local lowerContainer, _, lowerFrame = build(spec, spec.valid)
  local upperContainer, _, upperFrame = build(spec, spec.valid:upper())
  lowerContainer:Layout()
  upperContainer:Layout()

  assert(lowerFrame._test.point.offsetX == upperFrame._test.point.offsetX, spec.field)
  assert(lowerFrame._test.point.offsetY == upperFrame._test.point.offsetY, spec.field)
end

-- Test: the setter throws an error for an unrecognized value, leaving the
-- field unchanged and the tree clean.
for _, spec in ipairs(SPECS) do
  local container, child = build(spec, nil)
  container:Layout()

  local component = spec.onChild and child or container

  assertRejects(spec.field, component[spec.setter], component, INVALID_VALUE)
  assert(component[spec.getter](component) == nil, spec.field)
  assert(container:IsDirty() == false, spec.field)
end

-- Test: an unrecognized `justify` throws an error even when a flexible child
-- claims all the leftover space.
do
  local container = Waffle:Flex({
    frame = Mocks:CreateFrame(),
    direction = "ROW",
    justify = INVALID_VALUE,
    width = 100,
    height = 50,
    children = { { frame = Mocks:CreateFrame() } }
  })
  assertRejects("justify", container.Layout, container)
end

print("All assertions passed.")
