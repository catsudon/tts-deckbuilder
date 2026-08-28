--[==[  bottcg.com Deck Builder for Tabletop Simulator  ------------------------

    HOW TO USE
    ----------
    1. Right-click any object > Scripting. Select-all, delete, paste this file.
       Click "Save & Play".
    2. The object gets a text field + a "Build Deck" button. Click the field,
       paste your decklist, click somewhere else to commit it.
    3. Click "Build Deck".
       -> "Main Deck" spawns beside the object, "Life Cards" next to it.

    The DECKLIST block just below is only the STARTING text for that field
    (and the fallback if the field is left empty). Edit the field in-game for
    day-to-day use; edited text is saved with the game.

    Images are pulled live from cdn.bottcg.com by TTS. A card that shows blank
    means that code isn't on the CDN - check the spelling.

    Card size is the CARD_SCALE constant near the bottom. To match an existing
    card, measure it with measure-card.lua and adjust.

--------------------------------------------------------------------------- ]==]

------------------------------------------------------------------------------
--  Default / starting decklist. In-game you edit the text field on the object;
--  this is just what the field is pre-filled with.
------------------------------------------------------------------------------

DECKLIST = [[
# [DECK BUILDER #161] แป้นสกุล เมืองขีดขิน

# Main Deck
2x BT01-038-SCR
1x BT01-041-UR
1x BT02-054-SR
2x BT03-028-PR
2x BT03-034-UR
2x BT03-057-R
2x BT04-046-R
2x BT05-054-SCR
1x BT05-057-C
3x BT05-058-R
1x BT09-057-SCR
2x BT11-037-SR
2x BT11-039-C
4x BT11-041-C
2x CC01-052-UR
1x CC02-020-SR
4x CC02-040-SCR
2x PRMO-018-SR
2x PRMO-035-SR
1x PRMO-044-C
1x PRMO-068-SR
3x SD07-011-C
4x SD09-003-C
1x SD09-004-CBR
2x SD09-009-C

# Life Cards
1x KD02-023-C
1x KD02-024-C
1x SD02-021-C
1x SD02-022-C
1x SD02-023-C
]]

------------------------------------------------------------------------------
--  DeckBuilder module
------------------------------------------------------------------------------

DeckBuilder = {}

DeckBuilder.config = {
  backURL      = "https://steamusercontent-a.akamaihd.net/ugc/14987493501240081904/0AABF1E15CC2C4C5CA6D916C80B6C93BC039383D/",
  backIsHidden = true,
  faceBaseURL  = "https://cdn.bottcg.com/cards/",
  cardType     = 0,   -- 0 = rectangle card

  -- Per-section card back overrides. Key is matched (case-insensitive substring)
  -- against the section heading from the decklist.
  sectionBack = {
    ["life"] = "https://steamusercontent-a.akamaihd.net/ugc/10947240453818268133/EB10A13D52EEA567560C2F6CE6D5DEF6BDFF16E6/",
  },

  -- Some sets live in a sub-folder on the CDN. Key = set prefix, value = path
  -- segment inserted before the filename.
  setPath = {
    SD09 = "123v1k1/",   -- https://cdn.bottcg.com/cards/123v1k1/SD09-019.png
  },

  -- Rarity suffixes that are part of the CDN filename and must NOT be stripped.
  -- Everything else (C, R, UR, SR, ...) is dropped.
  keepRarity = {
    SCR = true,
    PR  = true,
    CBR = true,
  },
}

-- "BT11-041-C" -> "BT11-041"          (rarity stripped)
-- "BT01-038-SCR" -> "BT01-038-SCR"    (kept, listed in keepRarity)
-- "BT03-028-PR"  -> "BT03-028-PR"
-- "SD09-004-CBR" -> "SD09-004-CBR"
function DeckBuilder.cardSlug(code)
  code = tostring(code)
  local base, rarity = code:match("^(.-)%-([A-Za-z]+)$")
  if not base then return code end
  if DeckBuilder.config.keepRarity[rarity:upper()] then
    return base .. "-" .. rarity:upper()
  end
  return base
end

function DeckBuilder.faceURL(code)
  local cfg  = DeckBuilder.config
  local slug = DeckBuilder.cardSlug(code)
  local set  = tostring(code):match("^([A-Za-z]+%d*)")   -- "SD09" from "SD09-019-C"
  local sub  = (set and cfg.setPath[set]) or ""
  return cfg.faceBaseURL .. sub .. slug .. ".png"
end

function DeckBuilder.resolve(entry)
  if type(entry) == "string" then entry = { code = entry } end
  local face = entry.face
  if not face and entry.code then
    face = DeckBuilder.faceURL(entry.code)
  end
  return { name = entry.name or entry.code or "Card", face = face, back = entry.back }
end

function DeckBuilder.parseDecklist(text)
  local result = { name = "Deck", sections = {} }
  local current = nil
  for rawline in (tostring(text) .. "\n"):gmatch("(.-)\n") do
    local line = rawline:gsub("\r", ""):match("^%s*(.-)%s*$")
    if line == "" then
      -- skip
    elseif line:match("^#") then
      local heading = line:match("^#+%s*(.-)%s*$")
      local deckName = heading:match("%[DECK BUILDER[^%]]*%]%s*(.+)$")
      if deckName then
        result.name = deckName
      else
        current = { title = heading, cards = {} }
        result.sections[#result.sections + 1] = current
      end
    else
      local qty, code = line:match("^(%d+)%s*[xX]?%s+(%S+)$")
      if not qty then qty, code = "1", line:match("^(%S+)$") end
      if code then
        if not current then
          current = { title = "Deck", cards = {} }
          result.sections[#result.sections + 1] = current
        end
        for _ = 1, tonumber(qty) do current.cards[#current.cards + 1] = code end
      end
    end
  end
  return result
end

local function customDeckEntry(cfg, faceURL, backURL)
  return {
    FaceURL      = faceURL,
    BackURL      = backURL or cfg.backURL,
    NumWidth     = 1,
    NumHeight    = 1,
    BackIsHidden = cfg.backIsHidden,
    UniqueBack   = backURL ~= nil,
    Type         = cfg.cardType,
  }
end

local function cardObject(cfg, deckKey, nickname, faceURL, backURL, transform)
  return {
    Name       = "Card",
    Nickname   = nickname or "",
    Transform  = transform,
    CardID     = deckKey * 100,
    CustomDeck = { [tostring(deckKey)] = customDeckEntry(cfg, faceURL, backURL) },
    Locked     = false,
    Grid       = true,
    SidewaysCard = false,
  }
end

local function defaultTransform(position, rotation, scale)
  return {
    posX = position.x or position[1] or 0,
    posY = position.y or position[2] or 3,
    posZ = position.z or position[3] or 0,
    rotX = rotation and (rotation.x or rotation[1]) or 0,
    rotY = rotation and (rotation.y or rotation[2]) or 180,
    rotZ = rotation and (rotation.z or rotation[3]) or 180,
    scaleX = scale or 1, scaleY = scale or 1, scaleZ = scale or 1,
  }
end

function DeckBuilder.build(cardList, opts)
  opts = opts or {}
  local cfg = opts.config or DeckBuilder.config
  assert(type(cardList) == "table" and #cardList > 0, "cardList must be a non-empty array")

  local transform = defaultTransform(opts.position or {0, 3, 0}, opts.rotation, opts.scale)

  if #cardList == 1 then
    local c = DeckBuilder.resolve(cardList[1])
    assert(c.face, "no face URL for card 1")
    return cardObject(cfg, 1, c.name, c.face, c.back, transform)
  end

  local contained, deckIDs, customDeck = {}, {}, {}
  local keyByImage, nextKey = {}, 0

  for i, entry in ipairs(cardList) do
    local c = DeckBuilder.resolve(entry)
    assert(c.face, "no face URL for card " .. i .. " (" .. tostring(c.name) .. ")")

    local sig = c.face .. "|" .. tostring(c.back or "")
    local key = keyByImage[sig]
    if not key then
      nextKey = nextKey + 1
      key = nextKey
      keyByImage[sig] = key
      customDeck[tostring(key)] = customDeckEntry(cfg, c.face, c.back)
    end

    -- Contained cards carry the same scale as the deck so a card drawn OUT of
    -- the deck stays the right size (TTS uses the card's own transform then).
    contained[i] = cardObject(cfg, key, c.name, c.face, c.back, {
      posX = 0, posY = 0, posZ = 0,
      rotX = 0, rotY = transform.rotY, rotZ = transform.rotZ,
      scaleX = transform.scaleX, scaleY = transform.scaleY, scaleZ = transform.scaleZ,
    })
    deckIDs[i] = key * 100
  end

  return {
    Name = "Deck",
    Nickname = opts.name or "Deck",
    Transform = transform,
    DeckIDs = deckIDs,
    CustomDeck = customDeck,
    ContainedObjects = contained,
    SidewaysCard = false,
  }
end

function DeckBuilder.spawn(cardList, opts, callback)
  opts = opts or {}
  local data = DeckBuilder.build(cardList, opts)
  return spawnObjectData({
    data = data,
    position = { data.Transform.posX, data.Transform.posY, data.Transform.posZ },
    callback_function = function(obj)
      obj.setName(opts.name or data.Nickname or "Deck")
      if callback then callback(obj) end
    end,
  })
end

local function configForSection(baseCfg, title)
  local ov
  for key, url in pairs(baseCfg.sectionBack or {}) do
    if title:lower():find(key:lower(), 1, true) then ov = url end
  end
  if not ov then return baseCfg end
  local cfg = {}
  for k, v in pairs(baseCfg) do cfg[k] = v end
  cfg.backURL = ov
  return cfg
end

function DeckBuilder.spawnDecklist(text, opts)
  opts = opts or {}
  local parsed = DeckBuilder.parseDecklist(text)
  local origin = opts.position or { 0, 3, 0 }
  local gap    = opts.gap or 3.5
  local baseCfg = opts.config or DeckBuilder.config
  local spawned = {}
  for i, section in ipairs(parsed.sections) do
    if #section.cards > 0 then
      local pos = { origin[1] + (i - 1) * gap, origin[2], origin[3] }
      local obj = DeckBuilder.spawn(section.cards, {
        position = pos,
        scale    = opts.scale,
        name     = parsed.name .. " - " .. section.title,
        config   = configForSection(baseCfg, section.title),
      }, function(o) if opts.onDeck then opts.onDeck(o, section) end end)
      spawned[#spawned + 1] = obj
    end
  end
  return spawned, parsed
end

------------------------------------------------------------------------------
--  Object script: editable decklist field + a Build button
------------------------------------------------------------------------------

-- Card scale. A probed reference card (standard card mesh, same mesh the deck
-- builder produces) measured 6.0088 x 8.1768 world units at scale 2.67, so 2.67
-- reproduces that exact size. Raise/lower this one number to resize.
local CARD_SCALE   = 2.67

local SPAWN_OFFSET = { 8, 1, 0 }  -- FIRST deck position, relative to the
                                 -- generator object (x = right, z = forward)
local SPAWN_GAP    = 10           -- spacing between sections

-- Current decklist text. Seeded from the DECKLIST constant, then editable
-- in-game via the input field and persisted in the save.
local deckText = nil

function onLoad(saved)
  deckText = (saved and saved:match("%S")) and saved or DECKLIST

  self.clearButtons()
  self.clearInputs()

  self.createInput({
    input_function = "onDeckEdited",
    function_owner = self,
    label          = "paste decklist here",
    value          = deckText,
    alignment      = 2,          -- left-aligned
    position       = { 0, 0.3, -0.6 },
    width          = 2600, height = 1500,
    font_size      = 90,
    characterLimit = 10000,
    color          = { 1, 1, 1 },
    font_color     = { 0, 0, 0 },
  })

  self.createButton({
    click_function = "buildDeck",
    function_owner = self,
    label     = "Build Deck",
    position  = { 0, 0.3, 2.2 },
    width     = 1200, height = 400, font_size = 180,
    color     = { 0.15, 0.15, 0.15 }, font_color = { 1, 1, 1 },
  })
end

-- fires when the player clicks away from the field
function onDeckEdited(_, _, value, selected)
  if not selected then deckText = value end
end

function onSave()
  return deckText or ""
end

function buildDeck()
  buildFromText((deckText and deckText:match("%S")) and deckText or DECKLIST)
end

function buildFromText(text)
  local warn = function(m) broadcastToAll(m, { 1, 0.6, 0.6 }) end

  local parsed = DeckBuilder.parseDecklist(text)
  local total = 0
  for _, s in ipairs(parsed.sections) do total = total + #s.cards end
  if total == 0 then
    warn("No cards found in that text. Each card line must look like: 2x BT01-038-SCR")
    return
  end

  -- Spawn beside this object, not at fixed world coordinates.
  local base = self.getPosition()
  local origin = {
    base.x + SPAWN_OFFSET[1],
    base.y + SPAWN_OFFSET[2],
    base.z + SPAWN_OFFSET[3],
  }

  DeckBuilder.spawnDecklist(text, {
    position = origin,
    gap      = SPAWN_GAP,
    scale    = CARD_SCALE,
    onDeck   = function(obj, section)
      broadcastToAll(("%s: %d cards"):format(section.title, #section.cards), { 0.6, 1, 0.6 })
    end,
  })
end
