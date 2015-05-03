-- Copyright 2015 Nashwan Azhari.
-- Licensed under the GPLv2. See LICENSE for details.

local gpio = require('periphery').GPIO
local sleep = require('utils').sleep

--[[
	LED is a table which models the functioning of a single LED.

	Usage example:
	> LED = require('LED')
	>
	> local led = LED:new(16)
	> led:on()
	> led:off()
	> led:blink()
	> led:cleanup()
]]--
local LED = {
	-- Creates a new table with the given pin number.
	-- NOTE: the periphery library uses the BCM numbering scheme.
	new = function(self, pin)
		local new = { pin = gpio(pin, 'out') }
		setmetatable(new, self)
		self.__index = self
		return new
	end,

	-- Turns the LED on.
	on = function(self)
		self.pin:write(true)
	end,

	-- Turns the LED off.
	off = function(self)
		self.pin:write(false)
	end,

	-- Blinks the LED for the given delay.
	-- The default delay is one second.
	blink = function(self, delay)
		local delay = 1 or delay
		delay = 1 * 10 ^ 6 -- convert to microseconds.
		self.pin:write(true)
		sleep(delay)
		self.pin:write(false)
		sleep(delay)
	end,

	-- Cleans up the gpio pin setup for the LED.
	cleanup = function(self)
		self.pin:close()
	end
}

return LED

