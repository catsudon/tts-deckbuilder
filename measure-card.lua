--[==[  Card size probe  ------------------------------------------------------

    Prints the size of whatever object you're hovering over, so you can copy
    the numbers into TARGET_CARD in the deck builder.

    INSTALL
      Modding menu > Scripting > Global tab. Paste this, Save & Play.
      (Or paste it into any object's script - the hotkey is global either way.)

    BIND THE KEY
      Options > Game Keys > scroll to "Add-on Key Actions" > set a key for
      "Print card size".

    USE
      Hover the mouse over the old card, press that key. Read the chat / the
      log window (` ~ ` opens it). Use the "unrotated size" line for TARGET_CARD:
        X = width, Z = height.

--------------------------------------------------------------------------- ]==]

function onLoad()
  addHotkey("Print card size", function(playerColor, hoveredObject)
    if not hoveredObject then
      printToAll("Hover over a card first, then press the key.", { 1, 0.6, 0.6 })
      return
    end

    local nb = hoveredObject.getBoundsNormalized()   -- size ignoring rotation
    local b  = hoveredObject.getBounds()             -- world axis-aligned
    local s  = hoveredObject.getScale()
    local id = hoveredObject.getName()
    if id == "" then id = hoveredObject.getGUID() end

    local msg = string.format(
      "%s\n  unrotated size : X=%.4f  Y=%.4f  Z=%.4f   <- use X (width) and Z (height)\n" ..
      "  world bounds   : X=%.4f  Y=%.4f  Z=%.4f\n" ..
      "  scale          : X=%.4f  Y=%.4f  Z=%.4f",
      id,
      nb.size.x, nb.size.y, nb.size.z,
      b.size.x,  b.size.y,  b.size.z,
      s.x, s.y, s.z)

    print(msg)
    printToAll("Card size printed to log ( ~ to open ).", { 0.6, 1, 0.6 })
  end)
end
