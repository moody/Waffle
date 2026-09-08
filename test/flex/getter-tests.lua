--- @diagnostic disable: invisible

--- @type Waffle
local Waffle = require("test/waffle")
local Mocks = require("test/mocks")

-- Test: every getter returns the raw value most recently given to its
-- matching setter, nil if never set.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })

  assert(container:GetDefaultFrameFactory() == nil)
  local factory = function() return Mocks:CreateFrame() end
  container:SetDefaultFrameFactory(factory)
  assert(container:GetDefaultFrameFactory() == factory)

  assert(container:GetDirection() == "ROW")
  container:SetDirection("COLUMN")
  assert(container:GetDirection() == "COLUMN")

  assert(leaf:GetWidth() == nil)
  leaf:SetWidth(50)
  assert(leaf:GetWidth() == 50)

  assert(leaf:GetHeight() == nil)
  leaf:SetHeight(20)
  assert(leaf:GetHeight() == 20)

  leaf:SetSize(60, 30)
  local width, height = leaf:GetSize()
  assert(width == 60 and height == 30)

  assert(leaf:GetGrow() == nil)
  leaf:SetGrow(2)
  assert(leaf:GetGrow() == 2)

  assert(leaf:GetShrink() == nil)
  leaf:SetShrink(0)
  assert(leaf:GetShrink() == 0)

  assert(container:GetAlign() == nil)
  container:SetAlign("CENTER")
  assert(container:GetAlign() == "CENTER")

  assert(leaf:GetAlignSelf() == nil)
  leaf:SetAlignSelf("END")
  assert(leaf:GetAlignSelf() == "END")

  assert(container:GetJustify() == nil)
  container:SetJustify("SPACE_BETWEEN")
  assert(container:GetJustify() == "SPACE_BETWEEN")

  assert(container:GetWrap() == nil)
  container:SetWrap(true)
  assert(container:GetWrap() == true)

  assert(container:GetGap() == nil)
  container:SetGap(8)
  assert(container:GetGap() == 8)

  assert(container:GetLineGap() == nil)
  container:SetLineGap(16)
  assert(container:GetLineGap() == 16)

  assert(container:GetPadding() == nil)
  container:SetPadding(8)
  assert(container:GetPadding() == 8)

  assert(container:GetPaddingTop() == nil)
  container:SetPaddingTop(4)
  assert(container:GetPaddingTop() == 4)

  assert(container:GetPaddingRight() == nil)
  container:SetPaddingRight(4)
  assert(container:GetPaddingRight() == 4)

  assert(container:GetPaddingBottom() == nil)
  container:SetPaddingBottom(4)
  assert(container:GetPaddingBottom() == 4)

  assert(container:GetPaddingLeft() == nil)
  container:SetPaddingLeft(4)
  assert(container:GetPaddingLeft() == 4)

  assert(leaf:GetMargin() == nil)
  leaf:SetMargin(4)
  assert(leaf:GetMargin() == 4)

  assert(leaf:GetMarginTop() == nil)
  leaf:SetMarginTop(2)
  assert(leaf:GetMarginTop() == 2)

  assert(leaf:GetMarginRight() == nil)
  leaf:SetMarginRight(2)
  assert(leaf:GetMarginRight() == 2)

  assert(leaf:GetMarginBottom() == nil)
  leaf:SetMarginBottom(2)
  assert(leaf:GetMarginBottom() == 2)

  assert(leaf:GetMarginLeft() == nil)
  leaf:SetMarginLeft(2)
  assert(leaf:GetMarginLeft() == 2)

  assert(leaf:GetMinWidth() == nil)
  leaf:SetMinWidth(50)
  assert(leaf:GetMinWidth() == 50)

  assert(leaf:GetMaxWidth() == nil)
  leaf:SetMaxWidth(300)
  assert(leaf:GetMaxWidth() == 300)

  assert(leaf:GetMinHeight() == nil)
  leaf:SetMinHeight(50)
  assert(leaf:GetMinHeight() == 50)

  assert(leaf:GetMaxHeight() == nil)
  leaf:SetMaxHeight(300)
  assert(leaf:GetMaxHeight() == 300)

  assert(leaf:GetHidden() == nil)
  leaf:SetHidden(true)
  assert(leaf:GetHidden() == true)

  assert(leaf:GetKey() == nil)
  leaf:SetKey("sidebar")
  assert(leaf:GetKey() == "sidebar")

  assert(leaf:GetOrder() == nil)
  leaf:SetOrder(1)
  assert(leaf:GetOrder() == 1)

  assert(leaf:GetOnLayout() == nil)
  local onLayout = function() end
  leaf:SetOnLayout(onLayout)
  assert(leaf:GetOnLayout() == onLayout)
end

-- Test: getters don't mark the tree dirty.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a, width = 50 })
  container:Layout()
  assert(container:IsDirty() == false)

  leaf:GetWidth()
  leaf:GetHeight()
  leaf:GetSize()
  container:GetGap()
  leaf:GetHidden()
  assert(container:IsDirty() == false)
end

-- Test: every getter is available on any component, whether or not it
-- currently has any children of its own.
do
  local root = Mocks:CreateFrame()
  local a = Mocks:CreateFrame()

  local container = Waffle:Flex({ frame = root, direction = "ROW", width = 200, height = 50 })
  local leaf = container:AddChild({ frame = a })

  assert(leaf.GetDefaultFrameFactory ~= nil)
  assert(leaf.GetDirection ~= nil)
  assert(leaf.GetWidth ~= nil)
  assert(leaf.GetHeight ~= nil)
  assert(leaf.GetSize ~= nil)
  assert(leaf.GetGrow ~= nil)
  assert(leaf.GetShrink ~= nil)
  assert(leaf.GetAlign ~= nil)
  assert(leaf.GetAlignSelf ~= nil)
  assert(leaf.GetJustify ~= nil)
  assert(leaf.GetWrap ~= nil)
  assert(leaf.GetGap ~= nil)
  assert(leaf.GetLineGap ~= nil)
  assert(leaf.GetPadding ~= nil)
  assert(leaf.GetPaddingTop ~= nil)
  assert(leaf.GetPaddingRight ~= nil)
  assert(leaf.GetPaddingBottom ~= nil)
  assert(leaf.GetPaddingLeft ~= nil)
  assert(leaf.GetMargin ~= nil)
  assert(leaf.GetMarginTop ~= nil)
  assert(leaf.GetMarginRight ~= nil)
  assert(leaf.GetMarginBottom ~= nil)
  assert(leaf.GetMarginLeft ~= nil)
  assert(leaf.GetMinWidth ~= nil)
  assert(leaf.GetMaxWidth ~= nil)
  assert(leaf.GetMinHeight ~= nil)
  assert(leaf.GetMaxHeight ~= nil)
  assert(leaf.GetHidden ~= nil)
  assert(leaf.GetKey ~= nil)
  assert(leaf.GetOrder ~= nil)
  assert(leaf.GetOnLayout ~= nil)
end

print("All assertions passed.")
