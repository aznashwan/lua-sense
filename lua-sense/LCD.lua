-- Copyright 2015 Nashwan Azhari.
-- Licensed under the GPLv2. See LICENSE for details.

local sleep = require('utils').sleep
local gpio = require('periphery').GPIO

--[[
	LCD is a table which models the functioning of the
	Adafruit PI-Shield 16x2 LCD.

	All constants are taken from the datasheet of our LCD:
	https://learn.adafruit.com/downloads/pdf/drive-a-16x2-lcd-directly-with-a-raspberry-pi.pdf

	Usage example:
	> local LCD = require('LCD')
	>
	> local lcd = LCD:new()
	> lcd:writeline{text = "First line ahoy!", line = 1}
	> lcd:writeline{text = "Second line ahoy!", line = 2}
	> lcd:clear()
]]--
local LCD = {
	-- screenwidth in characters.
	__screenwidth = 16,

	-- line selector constants.
	__line1 = 0x80,
	__line2 = 0xC0,

	-- definition of all our pins.
	-- these are constants due to the build and operation mode of our LCD.
	-- they are alingned to the BCM numbering scheme of the board.
	__datapin1 = 17,
	__datapin2 = 18,
	__datapin3 = 22,
	__datapin4 = 23,
	__enablepin = 24,
	__regselpin = 25,

	-- Creates a new table with the LCD's parameters and methods.
	new = function(self)
		local new = {
			datapin1 = gpio(self.__datapin1, 'out'),
			datapin2 = gpio(self.__datapin2, 'out'),
			datapin3 = gpio(self.__datapin3, 'out'),
			datapin4 = gpio(self.__datapin4, 'out'),
			enablepin = gpio(self.__enablepin, 'out'),
			regselpin = gpio(self.__regselpin, 'out'),
		}
		setmetatable(new, self)
		self.__index = self
		new:__initialise()
		return new
	end,

	-- Issues all the initialisation commands to the LCD.
	-- 8-bit mode is preffered due to its covering of the full ASCII range.
	__initialise = function(self)
		-- set the register mode to instruction:
		self:__regsel('cmd')

		-- send initialization instructions:
		self:__writebyte(0x33)
		self:__writebyte(0x32)

		-- send line configurations:
		self:__writebyte(0x28)

		-- set cursor off (0x0E to enable):
		self:__writebyte(0x0C)

		-- move cursor to beginning:
		self:__writebyte(0x06)

		-- set operation mode to 8-bit:
		self:__writebyte(0x01)
	end,

	-- Switches the regselpin to the appropriate value for signaling that the
	-- next byte to be written is a data byte (high), or a command byte (low).
	__regsel = function(self, mode)
		local mode = mode or "data"
		if mode == 'data' then
			self.regselpin:write(true)
		else
			self.regselpin:write(false)
		end
	end,

	-- Enables reading to the internal register of the values written to the 4
	-- datapins. This is done by taking the enablepin through a full cycle with
	-- a 50 microsecond period.
	__enableread =  function(self)
		local period = 50
		sleep(period)
		self.enablepin:write(true)
		sleep(period)
		self.enablepin:write(false)
		sleep(period)
	end,

	-- Writes a single byte to the register of the LCD.
	-- This is achieved by encoding the 4 most significant bits on the
	-- datapins, signaling the LCD to read the to the internal register, and
	-- then doing the same for the 4 least significant bits.
	__writebyte = function(self, byte)
		-- encode the leading 4 bits on the datapins:
		self.datapin1:write(bit32.band(byte, 0x20) == 0x20)
		self.datapin2:write(bit32.band(byte, 0x40) == 0x40)
		self.datapin3:write(bit32.band(byte, 0x80) == 0x80)
		self.datapin4:write(bit32.band(byte, 0x10) == 0x10)
		self:__enableread()

		-- encode the trailing 4 bits on the datapins:
		self.datapin1:write(bit32.band(byte, 0x02) == 0x02)
		self.datapin2:write(bit32.band(byte, 0x04) == 0x04)
		self.datapin3:write(bit32.band(byte, 0x08) == 0x08)
		self.datapin4:write(bit32.band(byte, 0x01) == 0x01)
		self:__enableread()
	end,

	-- Clears the LCD.
	clear = function(self)
		self:writeline{ text = string.rep(" ", self.__screenwidth), line = 1 }
		self:writeline{ text = string.rep(" ", self.__screenwidth), line = 2 }
	end,

	-- Writes the given text to the given line of the LCD.
	-- If the text exceds 16 characters; the text will be wrapped.
	-- If a line is not specified or inexistent; it will default to 1.
	writeline = function(self, args)
		local text = args.text or ''
		local line = args.line or 1

		-- select the appropriate line:
		self:__regsel('cmd')
		if line ~= 2 then
			self:__writebyte(self.__line1)
		else
			self:__writebyte(self.__line2)
		end

		-- write the message; byte by byte:
		self:__regsel('data')
		for i = 1, #text do
			self:__writebyte(text:byte(i))
		end
	end,
}

return LCD

