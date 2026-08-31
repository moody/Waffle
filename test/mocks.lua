--- @class WaffleMocks
local Mocks = {}

--- @class WaffleMockFrame : WaffleFrame
--- @field _test table

--- Returns a mock frame, recording every call made to it under `._test`.
--- @return WaffleMockFrame MockFrame
function Mocks:CreateFrame()
  local MockFrame = {
    _test = {
      width = nil,
      height = nil,
      point = nil,
      parent = nil,
      clearedPoints = 0,
      visible = true,
      hideCalls = 0,
      showCalls = 0,
    }
  }

  function MockFrame:SetWidth(width)
    self._test.width = width
  end

  function MockFrame:SetHeight(height)
    self._test.height = height
  end

  function MockFrame:SetPoint(point, parent, relativePoint, offsetX, offsetY)
    self._test.point = {
      point = point,
      parent = parent,
      relativePoint = relativePoint,
      offsetX = offsetX,
      offsetY = offsetY
    }
  end

  function MockFrame:ClearAllPoints()
    self._test.point = nil
    self._test.clearedPoints = self._test.clearedPoints + 1
  end

  function MockFrame:SetParent(parent)
    self._test.parent = parent
  end

  function MockFrame:Hide()
    self._test.visible = false
    self._test.hideCalls = self._test.hideCalls + 1
  end

  function MockFrame:Show()
    self._test.visible = true
    self._test.showCalls = self._test.showCalls + 1
  end

  return MockFrame
end

return Mocks
