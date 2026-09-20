--- @diagnostic disable: assign-type-mismatch, param-type-mismatch

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: a `"GONE"` child is excluded from the layout flow, its flex-share
-- space is reallocated to visible siblings.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()
  local c = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = a, width = 50 },
      { frame = b, width = 100, visibility = "GONE" },
      { frame = c },
    }
  }):Layout()

  assert(c._test.width == 150)        -- 200 - 50 (b's width excluded)
  assert(c._test.point.offsetX == 50) -- right after a, b's slot skipped
  assert(b._test.width == nil)        -- never positioned
  assert(b._test.point == nil)
end

-- Test: a `"GONE"` child's frame gets `Hide()` called; a visible sibling's
-- frame doesn't.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = a },
      { frame = b, visibility = "GONE" },
    }
  }):Layout()

  assert(b._test.hideCalls == 1)
  assert(a._test.hideCalls == 0)
end

-- Test: making a `"GONE"` child `"VISIBLE"` again brings it back into the layout
-- flow and calls `Show()` on its frame; making it `"GONE"` calls `Hide()`.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a })
  local leaf = container:AddChild({ frame = b })
  container:Layout()

  assert(a._test.width == 100 and b._test.width == 100)
  assert(b._test.showCalls == 1 and b._test.hideCalls == 0)

  leaf:SetVisibility("GONE")
  container:Layout()
  assert(a._test.width == 200)
  assert(b._test.hideCalls == 1)

  leaf:SetVisibility("VISIBLE")
  container:Layout()
  assert(a._test.width == 100 and b._test.width == 100)
  assert(b._test.showCalls == 2)
end

-- Test: a child set to `"GONE"` before its first `Layout()` never gets a frame
-- created via `frameFactory` while `"GONE"`; making it `"VISIBLE"` creates one.
do
  local root = Mocks:CreateFrame()
  local factoryCalls = 0
  local created

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({
    visibility = "GONE",
    frameFactory = function(parent)
      factoryCalls = factoryCalls + 1
      created = Mocks:CreateFrame()
      return created
    end,
  })
  container:Layout()

  assert(factoryCalls == 0)
  assert(leaf:GetFrame() == nil)

  leaf:SetVisibility("VISIBLE")
  container:Layout()

  assert(factoryCalls == 1)
  assert(created._test.showCalls == 1)
end

-- Test: a `"GONE"` nested container's own children are never laid out (or
-- given frames) while it stays `"GONE"`, but any already-resolved frame
-- anywhere in its subtree is still hidden.
do
  local root = Mocks:CreateFrame()
  local rowFrame = Mocks:CreateFrame()
  local childFrame = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local row = container:AddRow({ frame = rowFrame, visibility = "GONE" })
  row:AddChild({ frame = childFrame })
  container:Layout()

  assert(rowFrame._test.hideCalls == 1)
  assert(childFrame._test.hideCalls == 1)
  assert(childFrame._test.width == nil) -- never laid out, parent is `"GONE"`
end

-- Test: a root declared `"GONE"` from construction, with a declarative
-- `children` table (never touching `AddChild`), skips laying anything out
-- and hides any already-resolved frame anywhere in it on the first
-- `Layout()` call.
do
  local root = Mocks:CreateFrame()
  local childFrame = Mocks:CreateFrame()
  local grandchildFrame = Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    visibility = "GONE",
    children = {
      { frame = childFrame, children = { { frame = grandchildFrame } } },
    },
  })
  container:Layout()

  assert(root._test.hideCalls == 1)
  assert(childFrame._test.hideCalls == 1)
  assert(grandchildFrame._test.hideCalls == 1)
  assert(root._test.width == nil and childFrame._test.width == nil)
end

-- Test: `AddChild()`-ing an already-resolved frame under a currently
-- `"GONE"` tree doesn't hide it until the next `Layout()` call, the same
-- as any other mutation.
do
  local root = Mocks:CreateFrame()
  local goneFrame = Mocks:CreateFrame()
  local existingFrame = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local gone = container:AddRow({ frame = goneFrame, visibility = "GONE" })
  container:Layout()

  gone:AddChild({ frame = existingFrame })
  assert(existingFrame._test.hideCalls == 0)

  container:Layout()
  assert(existingFrame._test.hideCalls == 1)
end

-- Test: `AttachComponent()`-ing an already-composed, already-shown subtree
-- under a currently `"GONE"` tree hides every already-resolved frame in it,
-- once `Layout()` runs again.
do
  local root = Mocks:CreateFrame()
  local goneFrame = Mocks:CreateFrame()
  local otherRoot = Mocks:CreateFrame()
  local grandchildFrame = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local gone = container:AddRow({ frame = goneFrame, visibility = "GONE" })
  container:Layout()

  local otherTree = Waffle:Flex({ frame = otherRoot, width = 100, height = 50 })
  local grandchild = otherTree:AddChild({ frame = grandchildFrame, width = 50, height = 50 })
  otherTree:Layout()
  assert(grandchildFrame._test.hideCalls == 0)

  grandchild:Detach()
  gone:AttachComponent(grandchild)
  assert(grandchildFrame._test.hideCalls == 0)

  container:Layout()
  assert(grandchildFrame._test.hideCalls == 1)
end

-- Test: a `frameFactory`-only child attached under a currently `"GONE"` tree
-- isn't resolved early, even once `Layout()` runs again.
do
  local root = Mocks:CreateFrame()
  local goneFrame = Mocks:CreateFrame()
  local factoryCalls = 0

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local gone = container:AddRow({ frame = goneFrame, visibility = "GONE" })
  container:Layout()

  gone:AddChild({
    frameFactory = function()
      factoryCalls = factoryCalls + 1
      return Mocks:CreateFrame()
    end,
  })
  container:Layout()

  assert(factoryCalls == 0)
end

-- Test: gap is only applied between visible siblings, a `"GONE"` child in
-- between doesn't consume a gap on either side.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()
  local c = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 210,
    height = 50,
    gap = 10,
    children = {
      { frame = a },
      { frame = b, visibility = "GONE", width = 999 },
      { frame = c },
    }
  }):Layout()

  assert(a._test.width == 100 and a._test.point.offsetX == 0)
  assert(c._test.width == 100 and c._test.point.offsetX == 110)
end

-- Test: an `"INVISIBLE"` child keeps its space in the layout flow, so its siblings
-- are sized and positioned as if it were visible.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()
  local c = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = a, width = 50 },
      { frame = b, width = 100, visibility = "INVISIBLE" },
      { frame = c },
    }
  }):Layout()

  assert(c._test.width == 50 and c._test.point.offsetX == 150) -- 200 - 50 - 100, b's slot kept
  assert(b._test.width == 100 and b._test.point.offsetX == 50) -- b is still sized and positioned
end

-- Test: an `"INVISIBLE"` child's frame gets `Hide()` called and never `Show()`, a
-- visible sibling's frame the reverse.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = a },
      { frame = b, visibility = "INVISIBLE" },
    }
  }):Layout()

  assert(b._test.visible == false and b._test.showCalls == 0 and b._test.hideCalls == 1)
  assert(a._test.visible == true and a._test.showCalls == 1 and a._test.hideCalls == 0)
end

-- Test: an `"INVISIBLE"` child's frame stays hidden through later `Layout()` calls
-- that change the tree.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })
  container:AddChild({ frame = b, visibility = "INVISIBLE" })
  container:Layout()

  leaf:SetWidth(50)
  container:Layout()
  container:SetWidth(300)
  container:Layout()

  assert(b._test.visible == false and b._test.showCalls == 0)
end

-- Test: switching a child between `"VISIBLE"` and `"INVISIBLE"` shows and hides
-- its frame without resizing its sibling.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a })
  local leaf = container:AddChild({ frame = b })
  container:Layout()

  assert(a._test.width == 100 and b._test.showCalls == 1)

  leaf:SetVisibility("INVISIBLE")
  container:Layout()
  assert(a._test.width == 100 and b._test.visible == false)

  leaf:SetVisibility("VISIBLE")
  container:Layout()
  assert(a._test.width == 100 and b._test.visible == true and b._test.showCalls == 2)
end

-- Test: switching a child between `"INVISIBLE"` and `"GONE"` toggles whether
-- its siblings reflow into its space.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a })
  local leaf = container:AddChild({ frame = b, visibility = "INVISIBLE" })
  container:Layout()
  assert(a._test.width == 100)

  leaf:SetVisibility("GONE")
  container:Layout()
  assert(a._test.width == 200)

  leaf:SetVisibility("INVISIBLE")
  container:Layout()
  assert(a._test.width == 100)
end

-- Test: an `"INVISIBLE"` child counts toward an `"AUTO"` sum and its gaps.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = "AUTO",
    height = 50,
    gap = 10,
    children = {
      { frame = a, width = 40 },
      { frame = b, width = 60, visibility = "INVISIBLE" },
    }
  }):Layout()

  assert(root._test.width == 110) -- 40 + 10 + 60
end

-- Test: an `"INVISIBLE"` node's own children are still laid out.
do
  local root = Mocks:CreateFrame()
  local rowFrame = Mocks:CreateFrame()
  local childFrame = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local row = container:AddRow({ frame = rowFrame, visibility = "INVISIBLE" })
  row:AddChild({ frame = childFrame })
  container:Layout()

  assert(rowFrame._test.visible == false)
  assert(childFrame._test.width == 200 and childFrame._test.height == 50)
end

-- Test: an `"INVISIBLE"` node's frame is created at the first `Layout()`, and stays
-- hidden.
do
  local root = Mocks:CreateFrame()
  local created
  local readyFrame

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({
    visibility = "INVISIBLE",
    frameFactory = function()
      created = Mocks:CreateFrame()
      return created
    end
  })
  leaf:WhenFrameReady(function(frame) readyFrame = frame end)
  container:Layout()

  assert(created ~= nil and readyFrame == created)
  assert(created._test.visible == false and created._test.showCalls == 0)
end

-- Test: `onLayout` fires for an `"INVISIBLE"` child, not for a `"GONE"` one.
do
  local root = Mocks:CreateFrame()
  local invisibleCalls, goneCalls = 0, 0

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      {
        frame = Mocks:CreateFrame(),
        visibility = "INVISIBLE",
        onLayout = function() invisibleCalls = invisibleCalls + 1 end
      },
      {
        frame = Mocks:CreateFrame(),
        visibility = "GONE",
        onLayout = function() goneCalls = goneCalls + 1 end
      },
    }
  }):Layout()

  assert(invisibleCalls == 1 and goneCalls == 0)
end

-- Test: an `"INVISIBLE"` root hides its own frame but still lays out its children.
do
  local root = Mocks:CreateFrame()
  local child = Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    visibility = "INVISIBLE",
    width = 200,
    height = 50,
    children = { { frame = child } }
  }):Layout()

  assert(root._test.visible == false and root._test.showCalls == 0)
  assert(root._test.width == 200 and child._test.width == 200)
end

-- Test: `SetVisibility()` marks the tree dirty for a change between any two
-- values, not for the same value again.
do
  local root = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = Mocks:CreateFrame() })
  container:Layout()

  for _, value in ipairs({ "INVISIBLE", "GONE", "VISIBLE" }) do
    leaf:SetVisibility(value)
    assert(container:IsDirty() == true)
    container:Layout()

    leaf:SetVisibility(value)
    assert(container:IsDirty() == false)
  end
end

-- Test: `visibility` tolerates case, same as `direction` does.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, visibility = "gone" },
      { frame = b, visibility = "Invisible" },
      { frame = c },
    }
  }):Layout()

  assert(a._test.width == nil and a._test.hideCalls == 1)   -- gone, excluded from the layout
  assert(b._test.width == 150 and b._test.visible == false) -- invisible, keeps its half
  assert(c._test.width == 150)
end

-- Test: an unrecognized `visibility` in a node table throws an error naming
-- the value when `Layout()` reads it.
do
  local root = Mocks:CreateFrame()

  local container = Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = Mocks:CreateFrame(), visibility = "hidden" },
    }
  })

  local ok, err = pcall(container.Layout, container)
  assert(not ok)
  assert(tostring(err):find("hidden", 1, true) and tostring(err):find("GONE", 1, true))
end

-- Test: a `visibility` that is not a string throws an error.
do
  local container = Waffle:Flex({
    frame = Mocks:CreateFrame(),
    width = 200,
    height = 50,
    visibility = true,
  })

  local ok, err = pcall(container.Layout, container)
  assert(not ok)
  assert(tostring(err):find("visibility", 1, true) and tostring(err):find("true", 1, true))
end

-- Test: `SetVisibility()` throws an error for an unrecognized value, leaving
-- the node's `visibility` unchanged and the tree clean.
do
  local root = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = Mocks:CreateFrame() })
  container:Layout()

  local ok, err = pcall(leaf.SetVisibility, leaf, "hidden")
  assert(not ok)
  assert(tostring(err):find("hidden", 1, true) and tostring(err):find("GONE", 1, true))
  assert(leaf:GetVisibility() == nil)
  assert(container:IsDirty() == false)
end

-- Test: `GetVisibility()` returns the value as given, whatever its case.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a })
  local leaf = container:AddChild({ frame = b })

  leaf:SetVisibility("gone")
  container:Layout()

  assert(leaf:GetVisibility() == "gone")
  assert(a._test.width == 200 and b._test.width == nil)

  local declared = container:AddChild({ frame = Mocks:CreateFrame(), visibility = "Invisible" })
  assert(declared:GetVisibility() == "Invisible")
end

-- Test: `SetVisibility(nil)` resets a `"GONE"` or `"INVISIBLE"` child to
-- `"VISIBLE"`, back in the layout flow and shown.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()
  local b = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  container:AddChild({ frame = a })
  local leaf = container:AddChild({ frame = b })

  leaf:SetVisibility("GONE")
  container:Layout()
  assert(a._test.width == 200)

  leaf:SetVisibility(nil)
  container:Layout()
  assert(a._test.width == 100 and b._test.visible == true)

  leaf:SetVisibility("INVISIBLE")
  container:Layout()
  assert(b._test.visible == false)

  leaf:SetVisibility(nil)
  container:Layout()
  assert(b._test.visible == true)
end

-- Test: an `"INVISIBLE"` child's `order` still applies, unlike a `"GONE"`
-- child's.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 100, order = 2, visibility = "INVISIBLE" },
      { frame = b, width = 100, order = 0 },
      { frame = c, width = 100, order = 1 },
    }
  }):Layout()

  assert(b._test.point.offsetX == 0)
  assert(c._test.point.offsetX == 100)
  assert(a._test.point.offsetX == 200 and a._test.visible == false)
end

-- Test: an `"INVISIBLE"` child counts as an item for `justify`, so the
-- leftover space is divided as if it were visible.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    justify = "SPACE_EVENLY",
    width = 300,
    height = 50,
    children = {
      { frame = a, width = 50 },
      { frame = b, width = 50, visibility = "INVISIBLE" },
      { frame = c, width = 50 },
    }
  }):Layout()

  assert(a._test.point.offsetX == 37.5) -- (300 - 150) / 4
  assert(b._test.point.offsetX == 125)
  assert(c._test.point.offsetX == 212.5)
end

-- Test: an `"INVISIBLE"` child takes part in `wrap`, consuming space and
-- pushing later children onto the next line.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 100,
    height = 50,
    wrap = true,
    children = {
      { frame = a, width = 60 },
      { frame = b, width = 60, visibility = "INVISIBLE" },
      { frame = c, width = 30 },
    }
  }):Layout()

  assert(b._test.point.offsetX == 0 and b._test.point.offsetY == c._test.point.offsetY) -- b and c share line two
  assert(c._test.point.offsetX == 60)
  assert(b._test.point.offsetY ~= a._test.point.offsetY)
end

-- Test: an `"INVISIBLE"` child takes part in the `shrink` deficit, so its
-- siblings shrink as if it were visible.
do
  local root = Mocks:CreateFrame()
  local a, b, c = Mocks:CreateFrame(), Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 90,
    height = 50,
    children = {
      { frame = a, width = 100 },
      { frame = b, width = 100, visibility = "INVISIBLE" },
      { frame = c, width = 100 },
    }
  }):Layout()

  assert(a._test.width == 30 and b._test.width == 30 and c._test.width == 30)
  assert(c._test.point.offsetX == 60)
end

-- Test: a flexible `"INVISIBLE"` child, with no `width` of its own, still
-- claims its equal share of the flexible space.
do
  local root = Mocks:CreateFrame()
  local a, b = Mocks:CreateFrame(), Mocks:CreateFrame()

  Waffle:Flex({
    frame = root,
    direction = "ROW",
    width = 200,
    height = 50,
    children = {
      { frame = a },
      { frame = b, visibility = "INVISIBLE" },
    }
  }):Layout()

  assert(a._test.width == 100 and b._test.width == 100)
end

-- Test: an `"INVISIBLE"` child under a `"GONE"` parent is not laid out, and
-- no frame is created for it.
do
  local root = Mocks:CreateFrame()
  local rowFrame = Mocks:CreateFrame()
  local suppliedFrame = Mocks:CreateFrame()
  local factoryCalls = 0

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local row = container:AddRow({ frame = rowFrame, visibility = "GONE" })
  row:AddChild({ frame = suppliedFrame, visibility = "INVISIBLE" })
  row:AddChild({
    visibility = "INVISIBLE",
    frameFactory = function()
      factoryCalls = factoryCalls + 1
      return Mocks:CreateFrame()
    end
  })
  container:Layout()

  assert(suppliedFrame._test.width == nil)
  assert(factoryCalls == 0)
end

-- Test: an `"INVISIBLE"` root becoming `"VISIBLE"` shows its frame.
do
  local root = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, visibility = "INVISIBLE", width = 200, height = 50 })
  container:Layout()
  assert(root._test.visible == false and root._test.showCalls == 0)

  container:SetVisibility("VISIBLE")
  container:Layout()
  assert(root._test.visible == true and root._test.showCalls == 1)
end

print("All assertions passed.")
