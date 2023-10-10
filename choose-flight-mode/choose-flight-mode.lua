-- Implements a screen that allows the user to pick a flight mode
-- This means the flight mode can be accessed without being assigned to any switches
-- Place this file in SCRIPTS/TOOLS on the microSD card if you want this to be accessible through the SYS button
-- Place this file, with a shorter file name, in SCRIPTS/TELEMETRY on the microSD card, if you want this to be accessible as a telemetry screen

-- warning: this script will override logical switches L63 and L64

local cur_fm = 0
local cur_fmData = nil
local sel_fm = 0
local need_reload = true

local function init()
  need_reload = true
end

local function run(event, touchState)

  if need_reload then
    cur_fm = getFlightMode()
    cur_fmData = model.getFlightMode(cur_fm)
    sel_fm = cur_fm
    need_reload = false
  end

  if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then -- handle key presses that navigate
    sel_fm = sel_fm + 1
    if sel_fm > 8 then
      sel_fm = 0
    end
  elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then -- handle key presses that navigate
    sel_fm = sel_fm - 1
    if sel_fm < 0 then
      sel_fm = 8
    end
  elseif event == EVT_VIRTUAL_ENTER then -- handle key press that selects
    fmData = model.getFlightMode(sel_fm) -- get the data for the new flight model
    if sel_fm ~= cur_fm then -- is a new selection
      if fmData ~= nil and cur_fmData ~= nil then
        -- make a logical switch that is always true
        local lsData = model.getLogicalSwitch(63)
        lsData.func = LS_FUNC_EQUAL
        lsData.v1 = getSourceIndex("MAX")
        lsData.v2 = lsData.v1
        model.setLogicalSwitch(63, lsData)
        -- make a logical switch that is always false
        lsData = model.getLogicalSwitch(62)
        lsData.func = LS_FUNC_XOR
        lsData.v1 = getSwitchIndex("L64")
        lsData.v2 = lsData.v1
        model.setLogicalSwitch(62, lsData)

        -- need to deactivate current flight mode by assigning it something false
        cur_fmData.switch = getSwitchIndex("L63")
        model.setFlightMode(cur_fm, cur_fmData)

        if sel_fm ~= 0 then
          -- activate the new flight mode by assigning it an always-true logical switch
          fmData.switch = getSwitchIndex("L64") -- this can probably also be "MAX" but there is no "MIN" for the other call
          model.setFlightMode(sel_fm, fmData)
        else
          -- note: cannot assign switch to default flight mode, so do nothing here
        end

        need_reload = true
        return 1
      end
    else
      -- same selection, do nothing and quit
      return 1
    end
  end

  lcd.clear()
  lcd.drawText(2, 2, "Choose Flight Mode")
  local line_spacing = 8
  local y_start = 16
  local y = y_start
  local x = 0

  for i=0,8,1 do

    if y > LCD_H - line_spacing then -- out of room on this column, move to next column
      x = x + (LCD_W / 2)
      y = y_start
    end

    local s = ""

    local fmIdx, fmStr = getFlightMode(i)

    if fmStr == nil or string.len(fmStr) <= 0 then -- if no name, then use a default name
      fmStr = "FM" .. tostring(fmIdx)
    end

    if i == sel_fm and i == cur_fm then
      s = "=>"
    elseif i == sel_fm then
      s = " >"
    elseif i == cur_fm then
      s = "= "
    else
      s = "  "
    end
    lcd.drawText(x, y, s)
    lcd.drawText(x + 10, y, fmStr)
    y = y + line_spacing
  end

  lcd.refresh()

  return 0
end

local function background()
  -- empty function required for this screen to work as a telemetry screen
end

return { run=run, init=init, background=background }
