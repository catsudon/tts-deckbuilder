function onLoad(save_state)
  self.setPosition({36.11, 1.25, -1.00})
  self.setRotation({0,180,0})
  self.setLock(true)
  millNum = 1
  excNum = 1
end

-- Life card = name starts with "ไม่นะ" and ends with "!"
-- (the deck builder names Life Cards "ไม่นะ <code>!")
function isLifeCard(name)
  if type(name) ~= "string" then return false end
  name = name:match("^%s*(.-)%s*$")
  return name:sub(1, #"ไม่นะ") == "ไม่นะ" and name:sub(-1) == "!"
end

function setUp()
  local mainDeck = nil
  for i, find in ipairs(findHitsDeck()) do
    if find.hit_object.type == "Deck" then
      mainDeck = find.hit_object
      break
    end
  end
  if mainDeck == nil then return end

  local lifes = {}

  -- Take by index, not guid: cards spawned by the deck builder can share an
  -- empty/duplicate guid, which makes takeObject grab the top card instead.
  -- getObjects() is re-read each pass because indexes shift after a take.
  for count = 1, 5 do
    local found = false
    for _, obj in ipairs(mainDeck.getObjects()) do
      if isLifeCard(obj.name) then
        table.insert(lifes, mainDeck.takeObject({index = obj.index}))
        found = true
        break
      end
    end
    if not found then break end
  end

  if #lifes <= 0 then
    broadcastToAll("No life card found (name must start with ไม่นะ and end with !)", {1, 0.6, 0.6})
    return
  end
  shuffle(lifes)
  local pos = {-21.97, 1.51, -4.06}
  for i, obj in ipairs(lifes) do
    obj.setPositionSmooth({pos[1],pos[2],pos[3]-(5.95*(i-1))}, bool, bool)
    obj.setRotation({0,90,180})
  end

  mainDeck.shuffle()
  mainDeck.deal(5,"Red")
end

function excCard()
  local mainDeck = nil
  for i, find in ipairs(findHitsDeck()) do
    if find.hit_object.type == "Deck" then
      mainDeck = find.hit_object
      break
    end
  end
  if mainDeck == nil then return end

  local pos = {44.34, 1.21, -27.38}
  for i=1, excNum do
    mainDeck.takeObject({position={pos[1]+(5.86*(i-1)),1.2,pos[3]},rotation={0,180,0}})
  end
end

function millCard()
  local mainDeck = nil
  for i, find in ipairs(findHitsDeck()) do
    if find.hit_object.type == "Deck" then
      mainDeck = find.hit_object
      break
    end
  end
  if mainDeck == nil then return end

  local pos = {27.00, 1.51, -12.75}
  for i=1, millNum do
    mainDeck.takeObject({position={pos[1],2+(0.1*(i-1)),pos[3]},rotation={0,180,0}})
  end
end

function millNumButt(play,click)
  if click == "-1" then
    millNum = millNum+1
  elseif click == "-2" then
    millNum = millNum-1
  elseif click == "-3" then
    millNum = 0
  end
  self.UI.setValue("mill",millNum)
end

function excNumButt(play,click)
  if click == "-1" then
    excNum = excNum+1
  elseif click == "-2" then
    excNum = excNum-1
  elseif click == "-3" then
    excNum = 0
  end
  self.UI.setValue("exc",excNum)
end

function excSend(player,para)
  local mainDeck = nil
  for i, find in ipairs(findHitsDeck()) do
    if find.hit_object.type == "Deck" then
      mainDeck = find.hit_object
      break
    end
  end
  if mainDeck == nil then return end

  local cards = {}
  for i, find in ipairs(findHitsExc()) do
    if find.hit_object.type == "Card" then
      table.insert(cards,find.hit_object)
    end
  end
  if cards[1] == nil then end
  if para == "Deck" then
    for i, card in ipairs(cards) do
      mainDeck.putObject(card)
    end
    mainDeck.shuffle()
  elseif para == "Bottom" then
    local pos = mainDeck.getPosition()
    mainDeck.setPosition({pos[1],2.5,pos[3]})
    for i, card in ipairs(cards) do
      mainDeck.putObject(card)
    end
  end
end

function shuffle(t)
    -- ใช้ Fisher-Yates shuffle
    local n = #t
    for i = n, 2, -1 do
        local j = math.random(i)  -- สุ่มตำแหน่ง 1 ถึง i
        t[i], t[j] = t[j], t[i]   -- สลับค่า
    end
    return t
end

function findHitsDeck(pos, radius)
    local radius = (radius or 3)
    local hitList = Physics.cast({
        origin       = {26.98, 1, -26.99},
        direction    = {0,1,0},
        type         = 3,
        size         = {6,5,10},
        max_distance = 0,
        debug        = false,
    })

    return hitList
end

function findHitsExc(pos, radius)
    local radius = (radius or 3)
    local hitList = Physics.cast({
        origin       = {82.61, 1, -26.96},
        direction    = {0,1,0},
        type         = 3,
        size         = {83,5,10},
        max_distance = 0,
        debug        = false,
    })

    return hitList
end
