--[==[  Cardfight!! Vanguard Deck Builder (Decklog) for Tabletop Simulator ------

    HOW TO USE
    ----------
    1. Right-click any object > Scripting. Select-all, delete, paste this file.
       Click "Save & Play".
    2. The object gets a text field + a "Build Deck" button. Click the field,
       type a Decklog deck code (e.g. 1TGCD) or paste a full Decklog deck URL,
       then click somewhere else to commit it. Both the EN site
       (decklog-en.bushiroad.com) and the JP site (decklog.bushiroad.com) work -
       pasting a full URL picks the right one automatically. A bare code with
       no URL is assumed to be EN; prefix it with "jp:" (e.g. "jp:17X74G") to
       force the JP site instead.
    3. Click "Build Deck".
       -> The script POSTs to the matching decklog API, reads the card list,
          and spawns beside the object:
             "Ride Deck"  - the grade 0-3 first vanguards (p_list)
             "Main Deck"  - the 50-card deck (list)
             "G Zone"     - only if the deck has one (sub_list)

    A Decklog code is the last path segment of a shared deck URL:
       https://decklog-en.bushiroad.com/view/1TGCD    ->    1TGCD  (EN)
       https://decklog.bushiroad.com/view/17X74G      ->    17X74G (JP)

    Card images come from cf-vanguard.com (the "img" path in each card entry;
    EN uses the en. subdomain, JP the bare domain). That CDN blocks Tabletop
    Simulator's downloader by user-agent, so faces are fetched through the
    wsrv.nl image CDN - see FACE_CDN below. A card that shows blank means its
    "img" path isn't on cf-vanguard.

    IF THE FETCH COMES BACK EMPTY
    ----------------------------
    Decklog's API only answers requests that carry a "Referer" header pointing
    at decklog. The script sends one, but some Tabletop Simulator builds drop
    that header (a Unity limitation) and then the API returns nothing.

    Work around it without any proxy: open the deck in your browser at
    https://decklog-en.bushiroad.com/view/<code> (or decklog.bushiroad.com for
    JP), open the dev-tools Console (F12), and run

        fetch('/system/app/api/view/<code>',{method:'POST'})
          .then(r=>r.text()).then(t=>copy(t))

    That copies the deck JSON to your clipboard. Paste the whole blob into the
    field here (instead of the code) and click Build - the script uses it
    directly and makes no web request.

    Card size is the CARD_SCALE constant. 2.67 matches the standard card mesh
    the builder produces (same value as the bottcg builder in this repo); it's
    scaled by 0.65 here so Vanguard cards spawn at roughly tabletop size.

----------------------------------------------------------------------------- ]==]

------------------------------------------------------------------------------
--  Config
------------------------------------------------------------------------------

local DECK_CODE = "1TGCD"        -- pre-fill for the input field (and fallback)
local DEFAULT_REGION = "en"      -- region assumed for a bare code (no URL, no "jp:" prefix)

-- Decklog runs a separate site + API per region, but with the same JSON shape
-- and the same img-path convention (only the card CDN's subdomain differs).
local REGIONS = {
  en = {
    api_url  = "https://decklog-en.bushiroad.com/system/app/api/view/",
    img_base = "https://en.cf-vanguard.com/wordpress/wp-content/images/cardlist/",
    site_url = "https://decklog-en.bushiroad.com/",
  },
  jp = {
    api_url  = "https://decklog.bushiroad.com/system/app/api/view/",
    img_base = "https://cf-vanguard.com/wordpress/wp-content/images/cardlist/",
    site_url = "https://decklog.bushiroad.com/",
  },
}

-- Card faces live on cf-vanguard.com, whose CDN returns a fake 404 to
-- Tabletop Simulator's downloader (it filters on the "UnityPlayer/..." user-
-- agent). There is no official mirror with the same paths, so faces are served
-- through the wsrv.nl image CDN, which refetches them with a normal user-agent.
-- Set FACE_CDN = "" if you point img_base (in REGIONS) at a host TTS can read directly.
local FACE_CDN  = "https://wsrv.nl/?url="

-- Cardfight!! Vanguard card back (direct JPG from vanguardcard.io's asset host).
local CARD_BACK = "https://images.vanguardcard.io/images/assets/CardBack.jpg"

-- Headers for the API call, mirroring what the decklog site itself sends.
-- The Referer is the one that matters - without a decklog Referer the API
-- returns an empty list. Origin/Referer are filled in per-region at call time.
local API_HEADERS = {
  ["User-Agent"]       = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " ..
                         "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  ["Accept"]           = "application/json, text/plain, */*",
  ["Accept-Language"]  = "en-US,en;q=0.9",
  ["X-Requested-With"] = "XMLHttpRequest",
}

local CARD_SCALE   = 2.67 * 0.65
local SPAWN_OFFSET = { 8, 1, 0 }   -- FIRST pile position relative to this object
local SPAWN_GAP    = 10            -- spacing between piles

------------------------------------------------------------------------------
--  Helpers
------------------------------------------------------------------------------

-- "dzbt09/dzbt09_004.png" -> face image URL (via FACE_CDN unless it's "")
local function faceURL(region, img)
  local full = REGIONS[region].img_base .. tostring(img)
  if FACE_CDN == "" then return full end
  return FACE_CDN .. (full:gsub("^https?://", ""))
end

-- Accepts a bare code ("1TGCD"), a "jp:"/"en:"-prefixed code, or a full
-- Decklog URL (either region). Returns code, region.
local function normalizeCode(text)
  local s = tostring(text or ""):match("^%s*(.-)%s*$")

  local region = DEFAULT_REGION
  if s:match("decklog%-en%.bushiroad%.com") then
    region = "en"
  elseif s:match("decklog%.bushiroad%.com") then
    region = "jp"
  else
    local prefix, rest = s:match("^(%a%a):%s*(.+)$")
    if prefix and REGIONS[prefix:lower()] then
      region = prefix:lower()
      s = rest
    end
  end

  local code = s:match("([%w]+)%s*/?%s*$") or s
  return code, region
end

------------------------------------------------------------------------------
--  JSON decode with a "\uXXXX" -> UTF-8 pre-pass
------------------------------------------------------------------------------
-- The JP Decklog API escapes every non-ASCII character as \uXXXX (card names,
-- deck title, nation). TTS's bundled JSON.decode does not turn those back into
-- UTF-8, so JP card names spawn as mojibake. Convert them here before decoding.
-- Only code points >= 0x80 are rewritten, so structural escapes (" etc.)
-- are left untouched for JSON.decode.

local function utf8FromCodepoint(cp)
  if cp < 0x80 then
    return string.char(cp)
  elseif cp < 0x800 then
    return string.char(0xC0 + math.floor(cp / 0x40),
                       0x80 + cp % 0x40)
  elseif cp < 0x10000 then
    return string.char(0xE0 + math.floor(cp / 0x1000),
                       0x80 + math.floor(cp / 0x40) % 0x40,
                       0x80 + cp % 0x40)
  else
    return string.char(0xF0 + math.floor(cp / 0x40000),
                       0x80 + math.floor(cp / 0x1000) % 0x40,
                       0x80 + math.floor(cp / 0x40) % 0x40,
                       0x80 + cp % 0x40)
  end
end

local function decodeJSON(text)
  text = tostring(text or "")

  -- surrogate pairs: \uD800-\uDBFF immediately followed by \uDC00-\uDFFF
  text = text:gsub("\\u(%x%x%x%x)\\u(%x%x%x%x)", function(hi, lo)
    local h, l = tonumber(hi, 16), tonumber(lo, 16)
    if h >= 0xD800 and h <= 0xDBFF and l >= 0xDC00 and l <= 0xDFFF then
      return utf8FromCodepoint(0x10000 + (h - 0xD800) * 0x400 + (l - 0xDC00))
    end
  end)

  -- remaining single BMP escapes >= 0x80
  text = text:gsub("\\u(%x%x%x%x)", function(hex)
    local cp = tonumber(hex, 16)
    if cp >= 0x80 and not (cp >= 0xD800 and cp <= 0xDFFF) then
      return utf8FromCodepoint(cp)
    end
  end)

  local ok, data = pcall(function() return JSON.decode(text) end)
  if ok then return data end
  return nil
end

------------------------------------------------------------------------------
--  DeckBuilder module  (generic spawn logic, shared with the bottcg builder)
------------------------------------------------------------------------------

DeckBuilder = {}

DeckBuilder.config = {
  backURL      = CARD_BACK,
  backIsHidden = true,
  cardType     = 0,   -- 0 = rectangle card
}

function DeckBuilder.resolve(entry)
  if type(entry) == "string" then entry = { face = entry } end
  return { name = entry.name or "Card", face = entry.face, back = entry.back }
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
    Name         = "Card",
    Nickname     = nickname or "",
    Transform    = transform,
    CardID       = deckKey * 100,
    CustomDeck   = { [tostring(deckKey)] = customDeckEntry(cfg, faceURL, backURL) },
    Locked       = false,
    Grid         = true,
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

  local transform = defaultTransform(opts.position or { 0, 3, 0 }, opts.rotation, opts.scale)

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

------------------------------------------------------------------------------
--  Decklog JSON  ->  piles
------------------------------------------------------------------------------

-- One Decklog entry -> { {name=, face=}, ... } repeated `num` times.
local function expandEntries(region, entries)
  local out = {}
  if type(entries) ~= "table" then return out end
  for _, e in ipairs(entries) do
    if type(e) == "table" and e.img then
      local qty  = tonumber(e.num) or tonumber(e._num) or 1
      local card = { name = e.name or e.card_number or "Card", face = faceURL(region, e.img) }
      for _ = 1, qty do out[#out + 1] = card end
    end
  end
  return out
end

local function countEntries(entries)
  local n = 0
  if type(entries) == "table" then
    for _, e in ipairs(entries) do n = n + (tonumber(e.num) or 1) end
  end
  return n
end

local function spawnPiles(data, region)
  local base   = self.getPosition()
  local origin = {
    base.x + SPAWN_OFFSET[1],
    base.y + SPAWN_OFFSET[2],
    base.z + SPAWN_OFFSET[3],
  }

  local deckName = data.title
  if deckName == nil or deckName == "" then deckName = "Vanguard Deck" end

  local piles = {
    { title = "Ride Deck", entries = data.p_list },
    { title = "Main Deck", entries = data.list },
    { title = "G Zone",    entries = data.sub_list },
  }

  local slot = 0
  for _, pile in ipairs(piles) do
    local cards = expandEntries(region, pile.entries)
    if #cards > 0 then
      local pos = { origin[1] + slot * SPAWN_GAP, origin[2], origin[3] }
      DeckBuilder.spawn(cards, {
        position = pos,
        scale    = CARD_SCALE,
        name     = deckName .. " - " .. pile.title,
      }, function()
        broadcastToAll(("%s: %d cards"):format(pile.title, #cards), { 0.6, 1, 0.6 })
      end)
      slot = slot + 1
    end
  end

  local nation = data.deck_param2
  broadcastToAll(("Built \"%s\"%s"):format(
    deckName, (nation and nation ~= "") and (" - " .. nation) or ""), { 0.7, 0.85, 1 })
end

------------------------------------------------------------------------------
--  Build
------------------------------------------------------------------------------

local function warn(m) broadcastToAll(m, { 1, 0.6, 0.6 }) end

-- Turn a decoded Decklog payload into decks on the table. Returns true on
-- success, false (with a broadcast) if it holds no cards.
local function buildFromData(data, label, region)
  if type(data) ~= "table" then
    warn("The deck data for '" .. label .. "' wasn't valid JSON.")
    return false
  end

  local total = countEntries(data.list) + countEntries(data.p_list) + countEntries(data.sub_list)
  if total == 0 then
    warn("No cards in the deck data for '" .. label .. "'.")
    return false
  end

  spawnPiles(data, region)
  return true
end

local function onDeckResponse(req, code, region)
  if req.is_error then
    warn("Network error fetching '" .. code .. "': " .. tostring(req.error))
    return
  end
  if tonumber(req.response_code) ~= 200 then
    warn("Decklog returned HTTP " .. tostring(req.response_code) .. " for '" .. code .. "'.")
    return
  end

  local data = decodeJSON(req.text)

  if not buildFromData(data, code, region) then
    warn("If '" .. code .. "' is a valid code, this TTS build isn't sending the " ..
         "Referer header the API requires. Paste the deck JSON instead - see the " ..
         "notes at the top of the script.")
  end
end

-- Field holds either a Decklog code / URL, or a pasted deck JSON blob. Either
-- one may be prefixed "jp:" / "en:" to force a region (a bare code defaults to
-- DEFAULT_REGION; a URL or a pasted blob's own region prefix wins otherwise).
function buildDeck()
  local raw = (deckCode and deckCode:match("%S")) and deckCode or DECK_CODE
  local trimmed = raw:match("^%s*(.-)%s*$")

  local pasteRegion, rest = trimmed:match("^(%a%a):%s*(.+)$")
  if pasteRegion and REGIONS[pasteRegion:lower()] and
     (rest:sub(1, 1) == "{" or rest:sub(1, 1) == "[") then
    trimmed = rest
  else
    pasteRegion = nil
  end

  -- Pasted JSON path: no web request at all.
  if trimmed:sub(1, 1) == "{" or trimmed:sub(1, 1) == "[" then
    local data = decodeJSON(trimmed)
    broadcastToAll("Building Vanguard deck from pasted JSON ...", { 0.7, 0.85, 1 })
    buildFromData(data, "pasted JSON", pasteRegion and pasteRegion:lower() or DEFAULT_REGION)
    return
  end

  -- Deck-code path: fetch from Decklog.
  local code, region = normalizeCode(trimmed)
  if code == "" then
    warn("Enter a Decklog deck code (e.g. 1TGCD) or paste the deck JSON.")
    return
  end

  broadcastToAll("Fetching Vanguard deck '" .. code .. "' (" .. region .. ") ...", { 0.7, 0.85, 1 })

  local site = REGIONS[region].site_url
  local headers = {}
  for k, v in pairs(API_HEADERS) do headers[k] = v end
  headers["Origin"]  = site:gsub("/$", "")
  headers["Referer"] = site .. "view/" .. code

  WebRequest.custom(REGIONS[region].api_url .. code, "POST", true, "", headers,
    function(req) onDeckResponse(req, code, region) end)
end

------------------------------------------------------------------------------
--  Object script: editable code / JSON field + a Build button
------------------------------------------------------------------------------

-- Field contents. A Decklog code/URL, or a pasted deck JSON blob. Seeded from
-- DECK_CODE, editable in-game, persisted in the save.
deckCode = nil

function onLoad(saved)
  deckCode = (saved and saved:match("%S")) and saved or DECK_CODE

  self.clearButtons()
  self.clearInputs()

  self.createInput({
    input_function = "onCodeEdited",
    function_owner = self,
    label          = "Decklog code  (or paste deck JSON)",
    value          = deckCode,
    alignment      = 2,             -- left
    position       = { 0, 0.3, -0.5 },
    width          = 2600, height = 1400,
    font_size      = 110,
    characterLimit = 60000,
    color          = { 1, 1, 1 },
    font_color     = { 0, 0, 0 },
  })

  self.createButton({
    click_function = "buildDeck",
    function_owner = self,
    label     = "Build Deck",
    position  = { 0, 0.3, 2.1 },
    width     = 1400, height = 420, font_size = 200,
    color     = { 0.15, 0.15, 0.15 }, font_color = { 1, 1, 1 },
  })
end

-- fires when the player clicks away from the field
function onCodeEdited(_, _, value, selected)
  if not selected then deckCode = value end
end

function onSave()
  return deckCode or ""
end
