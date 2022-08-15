local mapLoader = require "obj.mapLoader"

function love.load()
	print("Game started.")
	--player = Player:new(world, 100, 100)

	if arg[#arg] == "-debug" then require("mobdebug").start() end

	-- Graphics configuration
	love.window.setMode(1280, 720)
	love.graphics.setDefaultFilter('nearest', 'nearest')
	love.graphics.setLineStyle('rough')

	mapLoader:new()

	mapLoader:loadProject("debug")
	mapLoader:loadLevel("Level_Landing", "Center")
end

function love.keypressed(key, scancode, isRepeat)
	mapLoader:keypressed(key)
end

function love.update(dt)
	-- For delta time-related debugging
	if love.keyboard.isDown("z") then
		dt = dt / 5
	end

	mapLoader:update(dt)
end

function love.draw()
	love.graphics.scale(2)

	mapLoader:draw()

	love.graphics.scale(0.5)

	local sizeX, sizeY = love.graphics.getDimensions()
	local debugHUD =
	"FPS: " .. love.timer.getFPS() .. "\n" ..
	"Resolution:" .. sizeX .. "x" .. sizeY .. "\n" ..
	"Entity count: " .. #mapLoader.entities

	love.graphics.print(debugHUD, 4, 4)
end