--[==[  Rainbow Flashing Dice  ----------------------------------------------

    HOW TO USE
    ----------
    1. Spawn a die (or any object). Right-click > Scripting. Select-all,
       delete, paste this file. Click "Save & Play".
    2. Pick it up, throw it, or let physics roll it - the die itself cycles
       rapidly through the rainbow while moving, and settles back to its
       original color once it stops.
    3. Right-click the object > "Toggle Rainbow (always on)" to make it flash
       nonstop instead of only while rolling.

    Uses self.setColorTint(), which recolors the object's actual material
    (not just the selection border). Works on dice, tokens, custom models,
    etc. Objects with a fixed texture that ignore tint won't change color.

------------------------------------------------------------------------- ]==]

local FLASH_SPEED = 2.2   -- hue cycles per second (idle / always-on)
local ROLL_SPEED  = 12    -- hue cycles per second while rolling - rapid strobe
local TICK        = 0.15  -- seconds between color steps
local FRAMES_PER_STEP = math.floor(TICK * 60)

local flashing  = false
local alwaysOn  = false
local hue       = 0
local baseTint  = { r = 1, g = 1, b = 1 }

function onLoad()
  baseTint = self.getColorTint()
  self.addContextMenuItem("Toggle Rainbow (always on)", function()
    alwaysOn = not alwaysOn
    broadcastToAll(self.getName() .. ": rainbow " .. (alwaysOn and "always on" or "roll-triggered"), { 1, 1, 1 })
  end)
end

function update()
  local isMoving = self.held_by_color ~= nil or self.resting == false
  local shouldFlash = alwaysOn or isMoving
  if shouldFlash and not flashing then
    flashing = true
    startLuaCoroutine(self, "flashLoop")
  elseif not shouldFlash and flashing then
    flashing = false
  end
end

function flashLoop()
  while flashing do
    local isMoving = self.held_by_color ~= nil or self.resting == false
    local speed = isMoving and ROLL_SPEED or FLASH_SPEED
    hue = (hue + speed * TICK) % 1
    self.setColorTint(hsvToRgb(hue))
    for _ = 1, FRAMES_PER_STEP do coroutine.yield(0) end
  end
  self.setColorTint(baseTint)
  return 1
end

-- h in [0,1] -> {r,g,b} in [0,1], full saturation/value
function hsvToRgb(h)
  local i = math.floor(h * 6) % 6
  local f = h * 6 - math.floor(h * 6)
  local q, t = 1 - f, f
  if     i == 0 then return { r = 1, g = t, b = 0 }
  elseif i == 1 then return { r = q, g = 1, b = 0 }
  elseif i == 2 then return { r = 0, g = 1, b = t }
  elseif i == 3 then return { r = 0, g = q, b = 1 }
  elseif i == 4 then return { r = t, g = 0, b = 1 }
  else                return { r = 1, g = 0, b = q } end
end
