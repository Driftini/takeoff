local class = require "lib.middleclass"
local bump = require "lib.bump"
local ldtk = require "lib.ldtk"
local DCamera = require "obj.dcamera"
local utils = require "utils"

local Player = require "obj.entities.player"
local PlayerSpawnpoint = require "obj.entities.playerSpawnpoint"
local SCollider = require "obj.entities.scollider"
local MapTrigger = require "obj.entities.mapTrigger"
local SoundTrigger = require "obj.entities.soundTrigger"
local CloudSpawner = require "obj.entities.cloudSpawner"
local RainSpawner = require "obj.entities.rainSpawner"

local MapLoader = class("MapLoader")

function MapLoader:initialize()
	self.world = bump.newWorld() -- Colliding entities
	self.entities = {} -- All entities (should be merged with bump world probably)
	self.layers = {} -- Tile layers

	local resW, resH = G_CANVAS:getDimensions() -- Canvas resolution

	self.camera = DCamera:new(resW, resH, 0, 0, 1, 1)
end

function MapLoader:entitySwitch(e)
	local switch = {
		["PlayerSpawnpoint"]    = PlayerSpawnpoint,
		["SCollider"]           = SCollider,
		["MapTrigger"]          = MapTrigger,
		["SoundTrigger"]        = SoundTrigger,
		["CloudSpawner"]        = CloudSpawner,
		["RainSpawner"]         = RainSpawner,
	}

	return switch[e.identifier]:new(e, self.world, self.entities)
end

-- Load LDTK project separately from the maps themselves
function MapLoader:loadProject(project)
	ldtk:load("ldtk/levels/" .. project .. ".ldtk")
end

-- Clear old map data, then load the requested map and spawn the player at the right spawnpoint (if any)
-- Should add code to "convert" LDTK entities to the game's own format 
function MapLoader:loadLevel(level, playerSpawnpointID)
	local loadTime, finishTime

	function ldtk.entity(entity)
		self:entitySwitch(entity)
	end

	function ldtk.layer(layer)
		table.insert(self.layers, layer)
	end

	-- Clear old map data, reset camera and set the background to the map's defined color
	function ldtk.onLevelLoad(levelData)
		print("[MAPLOADER] Loading map " .. levelData.identifier .. "...")
		loadTime = love.timer.getTime()

		ldtk.removeCache()

		self.entities = {}
		self.layers = {}
		self.world = bump.newWorld()
		love.graphics.setBackgroundColor(levelData.bgColor)

		self.camera:setScene(0, 0, levelData.width, levelData.height)
		self.camera:targetZoom(1)
	end

	-- Decide where to spawn the player
	function ldtk.onLevelCreated(levelData)
		finishTime = love.timer.getTime()
		print("[MAPLOADER] Map " ..
			levelData.identifier .. " finished loading in " .. (finishTime - loadTime) * 1000 .. "ms.")

		if playerSpawnpointID then
			for i = 1, #self.entities do
				if self.entities[i].spawnID == playerSpawnpointID then
					local playerEntity = utils.blankEntity()
					playerEntity.x, playerEntity.y = self.entities[i].x, self.entities[i].y

					local p = Player:new(playerEntity, self.world, self.entities)

					-- Immediately point the camera at the player
					local camX, camY = utils.getRectCenter(p.x, p.y, p.w, p.h)

					self.camera:instantPosition(camX, camY)
					return
				end
			end
		end
	end

	ldtk:level(level)
end

-- Non-continuous key events get forwarded to entities accepting them
function MapLoader:keypressed(key)
	for i = 1, #self.entities do
		if self.entities[i].keyEvents then
			self.entities[i]:keypressed(key)
		end
	end
end

-- Update every entity, take care of destroyed ones, triggers, camera position and map switching
-- This needs a massive cleanup 
function MapLoader:update(dt)
	local destination -- For map switching

	local i = 1

	-- For loops won't work with a changing length
	while i <= #self.entities do
		if self.entities[i].destroyed then
			table.remove(self.entities, i)
		else
			self.entities[i]:update(dt)

			-- Trigger handling
			if self.entities[i].class.name == "MapTrigger" and self.entities[i].triggered then
				destination = self.entities[i].destination
			end

			-- Camera
			-- Spotlight boolean determines which entity gets targeted by the camera
			-- todo: spotlight priority?
			if self.entities[i].spotlight then
				local camX, camY = utils.getRectCenter(self.entities[i].x, self.entities[i].y, self.entities[i].w, self.entities[i].h)

				if self.entities[i].class.name == "Player" then
					camX, camY = camX + self.entities[i].vx / 4, camY + (self.entities[i].vy + self.entities[i].gravityVelocity) / 10
				end

				self.camera:targetPosition(camX, camY)
				self.camera:update()
			end
		end

		-- Double check if the current entity got destroyed mid-update
		if self.entities[i].destroyed then
			table.remove(self.entities, i)
		end

		i = i + 1
	end

	-- Map switching
	if destination then
		for i = 1, #self.entities do
			if self.entities[i].name == "Player" then
				-- DATA.player = self.entities[i].stats
			end
		end

		self:loadLevel(destination.map, destination.spawnpoint)
	end
end

-- Draw entities and tile layers in the right order
-- Should be edited to merge both tables and to use a new, dedicated z-index variable for sorting
function MapLoader:draw()
	self.camera:draw(
		function()
			local visibleEntities = self.world:queryRect(self.camera:getVisibleRect())

			print("# entities: " .. self.world:countItems(), "	# drawn: " .. #visibleEntities)

			table.sort(visibleEntities, function(a,b) return a.order < b.order end)
			table.sort(self.layers, function(a,b) return a.order < b.order end)

			for i = 1, #visibleEntities do
				visibleEntities[i]:draw()
			end

			for i = 1, #self.layers do
				self.layers[i]:draw()
			end
		end
	)
end

return MapLoader
