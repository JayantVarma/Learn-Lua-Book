local  _W, _H = display.contentWidth, display.contentHeight

display.setStatusBar(display.HiddenStatusBar)

local isSimulator = system.getInfo("environment") == "simulator"
local _hasAccel = not isSimulator

local MAX_BULLETS  = 5         -- The maximum number of bullets you can shoot
local MAX_FUEL     = 500       -- The amount of fuel that you get when you refuel
local MAX_LIVES    = 3         -- The maximum number of lives
local lives        = MAX_LIVES -- The maximum number of tries
local fuel         = MAX_FUEL  -- The maximum amount of fuel available
local score        = 0
local distance     = 0
local hiscore      = 0
local collected    = 0
local filter       = 0.8
local gameover     = false
local NORMAL       = 4        -- The normal speed for things that move
local FAST         = 9       -- The speed of things that move Fast
local TOPLINE      = 100 
local BOTTOMLINE   = 500
local baseLine     = 578

local random       = math.random
local floor        = math.floor
local performAfter = timer.performWithDelay
background = display.newRect(0,0,_W,_H)
background:setFillColor(255,255,255)


local bullets      = {}       -- container to hold the bullets fired
local scenery      = {}       -- The objects that make up the scenery
local sounds       = {}       -- The array that holds all the sounds in it
local restartGame  = nil      -- the handler function

local waiting      = 0
local wTime        = 0
local fwait        = false
local fx, fy       = 0, 0

local survivor, tanker
local txtLives, txtFuel, txtSaved, txtScore, txtGameOver, txtTapAgain

local tapEvent = "tap"

-- Create named enumeration from an array of strings

function enumerate(theTextArray)
	local returnVal = {}
	for i,j in pairs(theTextArray) do
		returnVal[j] = i
	end 
	return returnVal
end 

-- Position the object at the position x, y

function position(theObj, x, y)
	if theObj == nil then 
		return 
	end

	x = x or 0
	y = y or 0
	theObj:setReferencePoint(display.TopLeftReferencePoint)
	theObj.x = x
	theObj.y = y
end 

-- Load the Image imageName and position it at x, y

function loadImage(imageName, x, y)
	local x = x or 0
	local y = y or 0
	local image  = display.newImage(imageName, x, y, true)
	return image
end

local gpx, gpy, gpz

-- wrap the accelerometer into a generic function

function onAccelerometer(event)
  -- capture the events here
  gpx, gpy, gpz = event.xGravity, event.yGravity, event.zGravity
end 

-- Return the acceleration angles

function getAcceleration()
    return gpx, gpy, gpz
end

-- Get the acceleration coordinates

function getAcceleration()
	local  px, py = accelerometer:getAcceleration()
	return py, px  -- swap the px, py
end 

-- get the position; x,y coordinates from the object

function getPosition(theObj)
	if theObj == nil then 
		return 
	end

	theObj:setReferencePoint(display.TopLeftReferencePoint)
	return theObj.x, theObj.y
end 

-- Set up sounds into an array

function setupSound()
	sounds = {
		explosion       = audio.loadSound("_001.wav"),  -- Explosion
		shoot           = audio.loadSound("_002.wav"),  -- Shoot Bullet
		collectSurvivor = audio.loadSound("_003.wav"),  -- Collect Survivor
		collectFuel     = audio.loadSound("_004.wav"),  -- Collected Fuel
		crash           = audio.loadSound("_005.wav"),  -- Crash
	}
end

--Play the sound as specified

function playSound(theSound)
	audio.play(theSound)
end

-- Remove an object when done

function destroyObject(theObject)
	if theObject == nil then 
		return 
	end 

	display.remove(theObject)
end

-- Get the visibility of the object

function isVisible(theObject)
	if theObject == nil then 
		return false 
	end
	return theObject.isVisible
end 

-- Change the visibility of the object

function setVisible(theObject, setHow)
	if theObject == nil then 
		return 
	end
	theObject.isVisible = (setHow or false)
end

-- Make the item the top most on the display items stack

function bringToFront(theObject)
	if theObject == nil then 
		return 
	end
	
	theObject:toFront()
end

-- Recolor the object with the color index specified

function colorize(theObject, theColor)
	if theColor < 1 or theColor > #colors then
		return
	end  

	local r, g, b, a = unpack(colors[theColor])
	a = a or 255
	theObject:setFillColor(r, g, b, a)
end 

-- Create a text object

function newText(theText, xPos, yPos, theFontName, theFontSize)
  local xPos, yPos   = xPos or 0, yPos or 0
  local theFontSize  = theFontSize or 14
  local theFontName  = theFontName or native.systemFont
  local _text        = display.newText(theText, xPos, yPos, font, 24)
  _text:setTextColor(0,0,0)
  --position(_text, xPos, yPos)
  return _text
end

-- Update the text for this object

function updateText(theObject, theNewText)
	if theObject == nil then 
		return 
	end
	theObject.text = theNewText or ""
	
	--print("updated ", theObject.text, " to ", theNewText)
end 

-- Add a handler for the particular object

function addHandler(theEventName, theHandler, theObject)
	local theObject = theObject or Runtime
	theObject:addEventListener(theEventName, theHandler)
end 

-- remove the handler for the particular object

function removeHandler(theEventName, theHandler, theObject)
	local theObject = theObject or Runtime
	theObject:removeEventListener(theEventName, theHandler)
end 

-- Update all the text items

function updateAllText()
	updateText(txtLives, lives)
	updateText(txtFuel,  math.floor(fuel))
	updateText(txtScore, score)
	updateText(txtSaved, collected)
end 

-- The collision checking function that checks if a rect1 overlaps rect2
	
function collides(rect1, rect2)
	local x,y,w,h = rect1.x,rect1.y, rect1.wd, rect1.ht
	local x2,y2,w2,h2 = rect2.x,rect2.y, rect2.wd, rect2.ht

	return not ((y+h < y2) or (y > y2+h2) or (x > x2+w2) or (x+w < x2))
end

--Create the HUD items for display

function createHUDItems()
	-- create the items lives, fuel, saved, score and gameover text
	txtLives     = newText(lives,     170, baseLine + 10)
	txtFuel      = newText(fuel,      610, baseLine + 10)
	txtSaved     = newText(collected, 840, baseLine + 10)
	txtScore     = newText(score,     410, baseLine + 10)
	txtGameOver  = newText("G a m e   O v e r",  0, 0)
	txtTapAgain  = newText("Tap to play again", 0, 0)

	position(txtGameOver, (_W - txtGameOver.width)/2, _H/2)
	position(txtTapAgain, (_W - txtGameOver.width)/2, _H/2 + 40)
end 

-- Setup 

function init()
	background = loadImage("background.png") 
	heli       = loadImage("_chopper.png", _W/2, _H/2) -- middle of the screen
	objects    = enumerate{"plane", "balloon", "flower", "grass", "lamppost",
	"house", "tallHouse", "cloud1", "cloud2", "cloud3", "angryCloud"}

	survivor = loadImage("_man.png")
	tanker   = loadImage("_tanker.png")
	crash	 = loadImage("_crash.png")

	position(survivor, _W + survivor.height, baseLine - survivor.height)
	position(tanker,   _W + tanker.height, baseLine - tanker.height)

	colors = {
		{0,   0,   255},    -- Blue
		{255, 0,   0},      -- Red
		{0,   255, 0},      -- Green
		{255, 0,   255},    -- Magenta
		{0,   255, 255},    -- Cyan
		{255, 255, 0},      -- Yellow
		{255, 255, 255},    -- White
		{179, 115, 255},    -- Orange
		}

	setupSound()
	createHUDItems()

	setVisible(txtGameOver,false)
	setVisible(tanker,     false)
	setVisible(survivor,   false)
	setVisible(txtTapAgain,false)
	setVisible(crash      ,false)

end

--Swap the tap handler from Shooting to restarting the game

function showReplayScreen()
	removeHandler(tapEvent, shoot)
	addHandler   (tapEvent, restartGame)
end

-- Restart the game

function restartGame(event)
	-- Restart the game by setting most of the values to defaults

	wTime = 2
	setVisible(txtGameOver, false)
	setVisible(txtTapAgain, false)
	setVisible(heli,        true)

	score     = 0
	distance  = 0
	collected = 0
	fuel      = MAX_FUEL
	lives     = MAX_LIVES

	updateText(txtFuel, fuel)
	updateText(txtScore, score)
	updateText(txtSaved, saved)
	updateText(txtLives, lives)

	-- remove the handler that will restart the game
	removeHandler(tapEvent, restartGame)
	-- add the handler to shoot bullets when tapped
	addHandler   (tapEvent, shoot)

	gameOver = false

	position  (heli    , _W/2, _H/2)
	setVisible(tanker  , false)
	setVisible(survivor, false)
end 

-- Shoot bullets when the screen is tapped

function shoot()
	-- Do not shoot if waiting of the game is over
	if gameOver == true or wTime > 0 then 
		return 
	end

    -- only allow MAX_BULLETS to be shot
	if #bullets > MAX_BULLETS then
		return 
	end 
	
	-- Position the bullet at the helicopter's x + width position
	local hx, hy = getPosition(heli)
	local spr    = loadImage("_bullet.png", hx + heli.width, hy + (heli.height/2))
	blt = {
		sprite = spr,
		x = hx + heli.width,
		y = hy + (heli.height/2),
		wd = spr.width,
		ht = spr.height,
	}
	table.insert(bullets, blt)
	playSound(sounds.shoot)     -- play the shooting sound
end 

-- Move the bullets from where it was shot to the right hand side of the screen

function moveBullets()
	local blt
	
	-- cycle through all the bullets
	for i = #bullets, 1, -1 do
		blt   = bullets[i]
		blt.x = blt.x + FAST
		position(blt.sprite, blt.x, blt.y)

		tRect = {
			x  = blt.x,
			y  = blt.y,
			wd = blt.wd,
			ht = blt.ht,
		}

		-- cycle through every scenery object
		for j = #scenery, 1, -1 do
			local nme = scenery[j]
			
			-- check if the item is a plane or a balloon
			if nme.objType == objects.plane or nme.objType == objects.balloon then 
				hx, hy = getPosition(nme.sprite)
				nRect = {
					x  = hx,
					y  = hy,
					wd = nme.sprite.width,
					ht = nme.sprite.height,
				}

				if collides(nRect, tRect) == true then
					--increment score
					if nme.objType == objects.plane then
						score = score + 50 
					end
					if nme.objType == objects.balloon then 
						score = score + 30 
					end
					updateText(txtScore, score)

					destroyObject(blt.sprite)
					table.remove(bullets,i)
					blt = nil

					destroyObject(nme.sprite)
					table.remove(scenery,j)
					nme = nil

					return
				end
			elseif nme.objType == objects.angryCloud or 
				   nme.objType == objects.tallHouse then 
					
				hx, hy = getPosition(nme.sprite)
				nRect = {
					x = hx,
					y = hy,
					wd = nme.sprite.width,
					ht = nme.sprite.height,
				}
				if collides(nRect, tRect) == true then
					-- Block the bullets if it is an angryCloud or a tallHouse
					destroyObject(blt.sprite)
					table.remove(bullets,i)
					blt = nil
				end                    
			end

			if blt and blt.x > _W then
				--remove it, if it is outside the right hand side of the screen
				destroyObject(blt.sprite)
				table.remove(bullets, i)
				blt = nil
			end 
		end 
	end
end

-- reposition the helicopter based on the coordinates from the accelerometer

function updatePlayer(theX, theY)
	local PLAYERSPEED = FAST * 2 -- twice as fast as the fastest item
	local px, py = getPosition(heli)
	px = px - (theX * PLAYERSPEED)
	py = py - (theY * PLAYERSPEED)

	if px < 0 then px = 0 end 
	if px > _W - heli.width then 
		px = _W - heli.width
	end

	if py < TOPLINE then 
		py = TOPLINE 
	end
	if py > BOTTOMLINE + 10 then 
		-- CRASH into the ground
		reduceLife()
		return
	end
	position(heli, px, py)
end 

--Spawn Enemies every second 

function spawnEnemies()
	waiting = waiting + 1  -- counter to slow down the spawn speed
	
	if waiting < 60 then 
		return 
	end 
	-- Hopefully an item per second
	
	waiting     = 0
	local spr   = nil
	local yDir  = 0
	local speed = NORMAL
	local rnd   = random(1, 11) -- get an item between 1 and 11
	local xPos, yPos = 0,0

	local B_Line = baseLine

	-- Random Color for the object
	clr = random(1, #colors)

	if rnd == objects.plane then 				-- Spawn a new Plane
		spr   = loadImage("_plane.png")
		yPos  = random(2,5) * spr.height
		speed = FAST
	elseif rnd == objects.balloon then 			-- Spawn a Balloon
		spr   = loadImage("_balloon.png")
		yPos  = random(2,5) * spr.height
		yDir  = 1
	elseif rnd == objects.flower then 			-- Spawn Flower
		spr   = loadImage("_flower.png")
		yPos  = B_Line - spr.height
		clr   = 8
	elseif rnd == objects.grass then 			-- Spawn grass
		spr   = loadImage("_grass.png")
		yPos  = B_Line - spr.height
		clr   = 3
	elseif rnd == objects.lamppost then 		-- Spawn a Lamppost
		spr   = loadImage("_post.png")
		yPos  = B_Line - spr.height
	elseif rnd == objects.house then 			-- Spawn a House
		spr   = loadImage("_house.png")
		yPos  = B_Line - spr.height
	elseif rnd == objects.cloud1 then 			-- Spawn Cloud1
		spr   = loadImage("_cloud1.png")
		yPos  = TOPLINE + random(1,5) * spr.height
		speed = random(NORMAL, FAST)
		clr   = 5
	elseif rnd == objects.cloud2 then 			-- Spawn Cloud2
		spr   = loadImage("_cloud2.png")
		yPos  = TOPLINE + random(1,5) * spr.height
		speed = random(NORMAL, FAST)
		clr   = 5
	elseif rnd == objects.cloud3 then 			-- Spawn Cloud3
		spr   = loadImage("_cloud3.png")
		yPos  = TOPLINE + random(1,5) * spr.height
		speed = random(NORMAL, FAST)
		clr   = 5
	elseif rnd == objects.tallHouse then 		-- Spawn TallHouse
		spr   = loadImage("_tallhouse.png")
		yPos  = B_Line - spr.height
	elseif rnd == objects.angryCloud then 		-- Spawn an Angry Cloud
		spr   = loadImage("_cloud.png")
		yPos  = TOPLINE + random(1,5) * spr.height
		speed = random(NORMAL, FAST)
	end

	spr:setReferencePoint(display.TopLeftReferencePoint)
	xPos = _W + random(3,8) * spr.width
	position(spr, xPos, yPos)

	colorize(spr, clr)

	table.insert(scenery,{
		sprite  = spr, 
		speed   = speed,
		x       = xPos, 
		y       = yPos, 
		dir     = yDir,
		wd      = spr.width, 
		ht      = spr.height,
		objType = rnd
	})
end 

--Check for collisions

function checkCollisions()
	-- create the Player Rect
	local hx, hy = getPosition(heli)
	pRect = {
		x  = hx, 
		y  = hy,
		wd = heli.width,
		ht = heli.height,
	}

	-- Find if the Helicopter collided with any scenery object
	for i = #scenery, 1, -1 do
		local nme = scenery[i]
		if nme.objType == objects.plane or nme.objType == objects.balloon or
		   nme.objType == objects.lamppost or nme.objType == objects.house or
		   nme.objType == objects.tallHouse or nme.objType == objects.angryCloud then 
			hx, hy = getPosition(nme.sprite)
			nRect = {
				x  = hx,
				y  = hy,
				wd = nme.sprite.width,
				ht = nme.sprite.height,
			}

			if collides(nRect, pRect) == true then
				reduceLife()
				break
			end
		end
	end

	if survivor ~= nil then
		hx, hy = getPosition(survivor)
		sRect = {
			x  = hx,
			y  = hy,
			wd = hx + survivor.width,
			ht = hy + survivor.height,
			}

		-- Check if we have collected the survivor
		if collides(sRect, pRect) == true then
			collected = collected + 1
			updateText(txtSaved, collected)
			setVisible(survivor, false)
			score = score + 100
			updateText(txtScore, score)
			playSound(sounds.collectSurvivor)
		end 
	end

	-- Check if we have collected the fuel
	if tanker~= nil and isVisible(tanker) then 
		hx, hy = getPosition(tanker)
		tRect = {
			x = hx,
			y = hy,
			wd = hx + tanker.width,
			ht = hy + tanker.height,
			}
		if collides(tRect, pRect) == true then 
			fuel = MAX_FUEL
			updateText(txtFuel, fuel)
			setVisible(tanker,  false)
			position  (tanker, _W + random(3,5) * tanker.width, baseLine - tanker.height)
			playSound (sounds.collectFuel)
		end
	end
end 

-- Move all of the scenery objects that are spawned

function moveScenery()
	-- position the scenery objects
	for i = #scenery, 1, -1 do
		local nme = scenery[i]
		nme.x = nme.x - nme.speed
		nme.y = nme.y + nme.dir

		if nme.y < TOPLINE or nme.y > BOTTOMLINE then 
			nme.dir = -nme.dir 
		end

		local rnd = random(1,10)
		if rnd > 3  and rnd < 4 then
			nme.dir = -nme.dir 
		end 

		position(nme.sprite, nme.x, nme.y)

		if nme.x < -nme.wd then
			destroyObject(nme.sprite)
			table.remove(scenery, i)
		end
	end 


	-- Update the distance travelled and reduce the fuel
	fuel     = fuel - 0.1
	distance = distance + 0.1

	-- Update the text
	updateAllText() -- Update the HUD

    -- check if there are any collisions
	checkCollisions()
	
	-- If the tanker is visible then move it
	if tanker~= nil and isVisible(tanker) then
		local tx, ty = getPosition(tanker)
		tx = tx - NORMAL
		ty = baseLine - tanker.height
		position(tanker, tx, ty)
		if tx < - tanker.width then
			setVisible(tanker, false)
			position(tanker, _W + random(5,10) * tanker.width, ty)
		end
	elseif tanker ~= nil and fuel <=100 then
		-- show it only if the tanker is hidden and the fuel is less than 100
		setVisible(tanker, true)
	end

	if survivor~= nil then
		if not isVisible(survivor) then
			position(survivor, _W+random(5,10)*survivor.width, ty)
			setVisible(survivor, true)
		else
			tx, ty = getPosition(survivor)
			tx = tx - NORMAL
			ty = baseLine - survivor.height
			position(survivor, tx, ty)
			if tx < - survivor.width then
				position(survivor , _W + random(5,10) * survivor.width, ty)
				score = score - 50  -- penalty to let a survivor away
				if score < 0 then score = 0 end 
			end
		end 
	end

	-- If out of fuel, lose a life
	if fuel <= 0 then 
		reduceLife()
		return
	end    
end 

-- Reduce a life if crashed or out of fuel

function reduceLife()
	lives = lives - 1
	fuel = MAX_FUEL -- a fresh start with every life
	playSound(sounds.crash) -- Crash Sound

	--show the crash Graphic
	hx, hy = getPosition(heli)
	position(crash, hx, hy)
	setVisible(heli, false)
	setVisible(crash, true)

	wTime = 2

	performAfter(1000, -- perform this after a second
	function()
		-- remove all scenery items
		for i=#scenery, 1, -1 do
			destroyObject(scenery[i].sprite)
			table.remove(scenery, i)
		end

		-- remove all bullets
		for i = #bullets, 1, -1 do
			destroyObject(bullets[i].sprite)
			table.remove(bullets, i)
		end

		wTime = 2

		position(heli,_W/2,_H/2)

		gameOver = lives <= 0
		setVisible(txtGameOver, gameOver)
		setVisible(txtTapAgain, gameOver)
		setVisible(heli,    not gameOver)

		updateAllText()

		setVisible(crash, false)
		setVisible(tanker, false)
		position  (tanker, _W + random(3,5) * tanker.width, baseLine - tanker.height)

		if gameOver == true then
			if floor(distance) + score > hiscore then 
				hiscore = floor(distance) + score
			end

			showReplayScreen()
		end
	end)
end

-- Update - the game loop that moves everything

function update(event)
	-- Check if the game is over
	if gameOver == true then 
		return 
	end

	fWait = (wTime > 0)
	if fWait then
		wTime = wTime - 0.01
		if wTime < 0 then 
			wTime = 0 
		end
		return 
	end

	if _hasAccel==true then
		local gx, gy = getAcceleration()
		fx = gx * filter + fx * (1-filter)
		fy = gy * filter + fy * (1-filter)
		updatePlayer(fx, fy)
	end

	moveBullets()
	spawnEnemies()
	moveScenery()
end 

init()

Runtime:addEventListener("enterFrame", update)
Runtime:addEventListener(tapEvent, shoot)
Runtime:addEventListener("accelerometer", onAccelerometer)

