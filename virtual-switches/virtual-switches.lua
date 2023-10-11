-- this script is a screen that implements a few more switches or dials virtually
-- it's meant to enhance smaller transmitters with less switches available
-- place this script in SCRIPTS/TOOLS on the microSD card, so it can be run from the SYS button
-- place this script in SCRIPTS/TELEMETRY on the microSD card, if you want to access it as a telemetry screen
-- for different configs for different models, use a different name for the .lua file
-- warning: this will override the last few inputs, using I32 and going backwards

-- you should edit this list
local virtual_switches = {
  { name3 = "SW1", note6 = "", min_val = -100, max_val =  100, step = 100, val = 0, special =  0, icon = CHAR_SWITCH },
  { name3 = "PT2", note6 = "", min_val = -100, max_val =  100, step =  10, val = 0, special =  0, icon = CHAR_POT },
  { name3 = "BIG", note6 = "", min_val =    0, max_val = 1023, step =   1, val = 0, special =  2, icon = CHAR_SLIDER },
  { name3 = "BIT", note6 = "", min_val =    0, max_val =  255, step =   1, val = 0, special =  1, icon = 0 },
  { name3 = "GVR", note6 = "", min_val =    0, max_val = 1023, step =   1, val = 0, special = 18, icon = 0 },
  { name3 = "SW5", note6 = "", min_val = -100, max_val =  100, step = 200, val = 0, special =  0, icon = 0 },
  { name3 = "SW7", note6 = "", min_val = -100, max_val =  100, step = 100, val = 0, special =  0, icon = 0 },
  { name3 = "SW8", note6 = "", min_val = -100, max_val =  100, step = 100, val = 0, special =  0, icon = 0 }
}
-- current implementation can only show about 12 items on a B&W 128x64 pixel screen
-- name3 is the name shown (3 char long max), note6 is only used to fill in blank input-line names (6 char long max)
-- to implement a 3-way switch, use -100 to 100 range and step size 100
-- to implement a 2-way switch, there are a few ways:
--     range -100 to 100 with step size 200
--     range    0 to 100 with step size 100
--     range -100 to   0 with step size 100
-- for bit flags, set special to 1
-- other configurations are considered sliders

-- NOTE on using larger numbers for transmission:
-- 16 shared variables are available, for special = 2 to 17, values are raw integers (limited by the RF protocol, which is 0 to 1023 when using CRSF), and stored as strings
-- since it is stored as a string, these values are not accessible through the mixer
-- this means another Lua mixer script needs to be used to translate these shared variables to the LUA1a items that can be used by the mixer

-- NOTE on using Global variables
-- setting special = 18 to 26 means GVAR1 to GVAR9
-- storage does occupy an input but the value is not stored within the input structure, storage uses the GVAR of the flight mode

-- warning: the "weight" variable of an input can only be an integer, and 100% combined with MAX means the radio is already transmitting the number +1023
-- this means this script is unable to use high precision numbers, or numbers above 100 (or below -100)
-- for more precise numbers, use global variables

local is_edit_state = false
local sel_idx = 1
local sel_bit = 0
local inp_start = 24
local num_switches = 0 -- table.getn is not available for all radios

local bit_flag_limit = 6 -- because of the way the weight variable works, we are limited to 6 bit flags per item
local bit_flag_cache = {0, 0, 0, 0, 0, 0, 0, 0, 0} -- there are no bitwise operators available for this version of Lua, so use an array to represent bits

local last_fm = nil -- track flight modes to detect changes in flight mode

-- these variables are used for detecting fast continuous inc/dec
local last_scroll_flag = 0
local last_scroll_time = 0
local scroll_cont_cnt = 0

local function set_input_const(idx, vsw)
  local midx = idx + inp_start - 1 -- correct the index

  local val = vsw.val
  local val_str = tostring(val)

  -- clear all lines in the input except one
  while model.getInputsCount(midx) > 1 do -- until no more lines except 1
    model.deleteInput(midx, 1)
  end
  if model.getInputsCount(midx) >= 1 then
    -- get the old line of input if possible
    -- use the settings inside as much as possible
    inp = model.getInput(midx, 0)
    inp.source = getSourceIndex("MAX")
    if vsw.special < 2 then -- value is a small number, less than 100
      inp.weight = val
    else -- value is a larger number, bigger than 100
      -- stored as a string
      inp.name = val_str
      inp.weight = 0
    end
    inp.offset = 0
    inp.curveType = 0
    inp.curveValue = 0
    model.deleteInput(midx, 0)
    model.insertInput(midx, 0, inp)
  else
    -- nothing previously configured here
    -- insert the new line
    if vsw.special < 2 then -- value is a small number, less than 100
      model.insertInput(midx, 0, {name=vsw.note6, inputName=vsw.name3, source=getSourceIndex("MAX"), weight=val, offset=0, curveType=1, curveValue=0, carryTrim=false, flightModes=0, switch=0})
    elseif vsw.special <= 17 then -- value is a larger number, bigger than 100, store value as a string in the name
      model.insertInput(midx, 0, {name=val_str, inputName=vsw.name3, source=getSourceIndex("MAX"), weight=0, offset=0, curveType=1, curveValue=0, carryTrim=false, flightModes=0, switch=0})
    end
  end
end

local function load_data()
  local i = 0
  -- iterate through all previously configured inputs
  -- load previously configured settings
  while i < num_switches do
    j = i + inp_start
    if virtual_switches[i + 1].special >= 18 and virtual_switches[i + 1].special <= 26 then -- is a GVAR
      virtual_switches[i + 1].val = model.getGlobalVariable(virtual_switches[i + 1].special - 18, getFlightMode())
    else -- not a GVAR, stored as an input item instead
      n = model.getInputsCount(j)
      if n > 0 then
        inp = model.getInput(j, 0)
        -- load previously configured settings
        if virtual_switches[i + 1].special == 0 then -- not a bit flag field
          virtual_switches[i + 1].val = inp.weight -- load normally
        elseif virtual_switches[i + 1].special == 1 then
          virtual_switches[i + 1].val = inp.weight -- bit.tobit(inp.weight) -- load as bits
        elseif virtual_switches[i + 1].special >= 2 and virtual_switches[i + 1].special <= 17 then
          -- larger numbers are stored as strings in the input's name
          local shmvar = 0
          if getShmVar ~= nil then shmvar = getShmVar(virtual_switches[i + 1].special - 1) end
          if shmvar == nil then
            shmvar = 0
          end
          if inp.name == nil then
            virtual_switches[i + 1].val = shmvar
          elseif string.len(inp.name) <= 0 then
            virtual_switches[i + 1].val = shmvar
          else
            virtual_switches[i + 1].val = tonumber(inp.name)
            if virtual_switches[i + 1].val == nil then
              virtual_switches[i + 1].val = shmvar
            end
          end
        end
      end
    end
    i = i + 1
  end
  last_fm = getFlightMode()
end

local function init()
  local i = 0
  -- count the number of switches
  for _,__ in pairs(virtual_switches) do
    i = i + 1
  end
  num_switches = i

  is_edit_state = false
  sel_idx = 1
  inp_start = 32 - num_switches
  load_data()
end

local function run(event, touchState)

  local cur_fm = getFlightMode()
  if cur_fm ~= last_fm then
    -- if the flight mode changed, then GVARs need to be updated
    load_data()
  end

  local old_val = virtual_switches[sel_idx].val
  local new_val = old_val

  local step_size = virtual_switches[sel_idx].step
  local cur_time = getTime()
  local scroll_delta_time = cur_time - last_scroll_time
  if scroll_delta_time <= 50 then -- fast inc/dec without pause
    if is_edit_state == true and virtual_switches[sel_idx].special ~= 1 then
      if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT or event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
        if last_scroll_flag == 1 then -- direction unchanged
          scroll_cont_cnt = scroll_cont_cnt + 1
        else -- direction changed, reset continuous inc/dec state
          scroll_cont_cnt = 0
        end
        last_scroll_flag = 1
      elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT or event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
        if last_scroll_flag == -1 then
          scroll_cont_cnt = scroll_cont_cnt + 1
        else -- direction changed, reset continuous inc/dec state
          scroll_cont_cnt = 0
        end
        last_scroll_flag = -1
      end
      if scroll_cont_cnt >= 10 and scroll_delta_time <= 20 then
        scroll_cont_cnt = 10
        step_size = virtual_switches[sel_idx].step * 100 -- super fast step speed
      elseif scroll_cont_cnt >= 5 then
        step_size = virtual_switches[sel_idx].step * 10 -- slightly fast step speed
      end
    end
  else -- long pause in inc/dec detected
    last_scroll_flag = 0
    scroll_cont_cnt = 0
  end

  if is_edit_state == false then
    if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then -- handle key presses that navigate
      sel_idx = sel_idx + 1
      if sel_idx > num_switches then
        sel_idx = 1
      end
    elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then -- handle key presses that navigate
      sel_idx = sel_idx - 1
      if sel_idx <= 0 then
        sel_idx = num_switches
      end
    elseif event == EVT_VIRTUAL_ENTER then -- handle key press that selects
      local range = virtual_switches[sel_idx].max_val - virtual_switches[sel_idx].min_val
      local nchoices = range / virtual_switches[sel_idx].step
      if nchoices <= 1.1 then
        -- if the configured switch only has two possibilities, then toggle on key
        if new_val == virtual_switches[sel_idx].min_val then
          new_val = virtual_switches[sel_idx].max_val
        else
          new_val = virtual_switches[sel_idx].min_val
        end
      else
        -- else, go into editing state
        is_edit_state = true
        if virtual_switches[sel_idx].special == 1 then -- is a bit flag field
          sel_bit = bit_flag_limit - 1 -- start from the left
          -- the bitwise operation library isn't available, so fill the table of bits manually
          local val_cache = old_val
          local bit_idx = bit_flag_limit - 1
          while bit_idx >= 0 do
            local bit_val = 2 ^ bit_idx
            if val_cache >= bit_val then
              bit_flag_cache[bit_idx + 1] = 1
              val_cache = val_cache - bit_val
            else
              bit_flag_cache[bit_idx + 1] = 0
            end
            bit_idx = bit_idx - 1
          end
        end
      end
    end
  else -- is_edit_state
    if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT or event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then -- handle key presses that increment value
      if virtual_switches[sel_idx].special ~= 1 then -- is not a bit flag field
        new_val = new_val + step_size
        if new_val > virtual_switches[sel_idx].max_val then
          new_val = virtual_switches[sel_idx].max_val
        end
        last_scroll_time = cur_time
      else -- is a bit flag field, scrollView
        sel_bit = sel_bit - 1
        if sel_bit < 0 then -- exit editing if out of range
          is_edit_state = false
        end
      end
    elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT or event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then -- handle key presses that decrement value
      if virtual_switches[sel_idx].special ~= 1 then -- is not a bit flag field
        new_val = new_val - step_size
        if new_val < virtual_switches[sel_idx].min_val then
          new_val = virtual_switches[sel_idx].min_val
        end
        last_scroll_time = cur_time
      else -- is a bit flag field
        sel_bit = sel_bit + 1
        if sel_bit >= bit_flag_limit then -- exit editing if out of range
          is_edit_state = false
        end
      end
    elseif event == EVT_VIRTUAL_ENTER then -- handle key press that quits
      if virtual_switches[sel_idx].special ~= 1 then -- is not a bit flag field
        is_edit_state = false -- quit
      else -- is a bit flag field
        -- toggle the bit
        -- bitwise operations are not available in this version of Lua
        --if bit.band(virtual_switches[sel_idx].val, bit.lshift(1, sel_bit)) == 0 then
        --  new_val = bit.bor(old_val, bit.lshift(1, sel_bit))
        --else
        --  new_val = bit.band(old_val, bit.bnot(bit.lshift(1, sel_bit)))
        --end
        if bit_flag_cache[sel_bit + 1] == 0 then
          bit_flag_cache[sel_bit + 1] = 1
          new_val = old_val + (2 ^ sel_bit)
        else
          bit_flag_cache[sel_bit + 1] = 0
          new_val = old_val - (2 ^ sel_bit)
        end
      end
    end
  end

  if old_val ~= new_val then
    -- actually apply the change if old value needs update
    virtual_switches[sel_idx].val = new_val
    if virtual_switches[sel_idx].special < 18 then -- store as input item
      set_input_const(sel_idx, virtual_switches[sel_idx])
    elseif virtual_switches[sel_idx].special >= 18 and virtual_switches[sel_idx].special <= 26 then -- store as GVAR
      model.setGlobalVariable(virtual_switches[sel_idx].special - 18, cur_fm, new_val)
    end
    if virtual_switches[sel_idx].special >= 2 and virtual_switches[sel_idx].special <= 17 then -- set Lua shared variable
      if setShmVar ~= nil then setShmVar(virtual_switches[sel_idx].special - 1, new_val) end
    end
  end

  lcd.clear()

  local nw = 0
  local nh = 0
  local titleStr = "Virtual Switches"

  lcd.drawText(2, 2, titleStr)
  --nw, nh = lcd.sizeText(titleStr)
  nh = 8

  local line_spacing = nh
  local y_start = 16
  local y = y_start
  local x = 0
  local xw = LCD_W / 2
  local xm = 2
  if xw > 64 then
    xw = 64
  end

  local x2 = xw / 2

  for i=0,num_switches - 1,1 do
    local j = i + 1

    if y > LCD_H - line_spacing then -- out of room on this column, move to next column
      x = x + xw
      y = y_start
      lcd.drawLine(x, y_start, x, LCD_H, DOTTED, 0) -- column divider
    end

    local s = ""

    local nameStr = virtual_switches[j].name3
    local valStr = tostring(virtual_switches[j].val)

    if virtual_switches[j].icon ~= 0 then
      nameStr = virtual_switches[j].icon .. nameStr
    end

    -- to show bit flag fields, use hexadecimal
    if virtual_switches[j].special == 1 then -- is a bit flag field
      valStr = string.format("0x%02X", virtual_switches[j].val)
    end

    -- draw the strings
    if is_edit_state and j == sel_idx then
      if virtual_switches[j].special ~= 1 then -- is not a bit flag field
        lcd.drawText(x + xm, y, nameStr)
        lcd.drawText(x + x2, y, valStr, INVERS) -- indicate we are editing value
      else -- is a bit flag field
        local xspace = 6
        xi = x + xm
        local k = bit_flag_limit - 1
        while k >= 0 do
          local draw_flag = 0
          if k == sel_bit then
            draw_flag = INVERS
          end
          lcd.drawText(xi, y, tostring(bit_flag_cache[k + 1]), draw_flag)
          xi = xi + xspace
          k = k - 1
        end
        local nameLong = nameStr
        while true do
          --nw, nh = lcd.sizeText(nameLong)
          nw = 4 * string.len(nameLong)
          if (nw + 8) < xw then
            nameLong = nameLong .. " "
          else
            break
          end
        end
        lcd.drawText(x + xm, y - line_spacing, nameLong, INVERS)
      end
    else -- is not editing
      if j == sel_idx then
        lcd.drawText(x + xm, y, nameStr, INVERS) -- indicate current selection
        lcd.drawText(x + x2, y, valStr)
      else
        lcd.drawText(x + xm, y, nameStr)
        lcd.drawText(x + x2, y, valStr)
      end
    end

    y = y + line_spacing -- next line
  end

  lcd.refresh()

  return 0
end

local function background()
  -- empty function required for this screen to work as a telemetry screen
end

return { run=run, init=init, background=background }
