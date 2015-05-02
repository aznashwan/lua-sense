-- Copyright 2015 Nashwan Azhari.
-- Licensed under the GPLv2. See LICENSE for details.

local sleep = require('utils').sleep
local gpio = require('periphery').GPIO

--[[
	This table contains all methods relevant to using the Sensirion SHT11
	temperature and humidity sensor.
	The balow code conforms to the normal operation of the sensor as is
	outlined in the sensor's datasheet:
	http://www.sensirion.com/fileadmin/user_upload/customers/sensirion/Dokumente/Humidity/Sensirion_Humidity_SHT1x_Datasheet_V5.pdf

	Example usage:
	> SHT11 = require('SHT11')
	>
	> sht11 = SHT11:new(27, 4)
	>
	> temp = sht11:temperature()
	> print("The temperature is: " .. temp)
	>
	> -- **always** wait at least one second between readings!!!
	>
	> humid = sht11:humidity()
	> print("The humidity is: " .. humid)
--]]
local SHT11 = {
	-- humidity computation constants:
	C1 = -2.0568,
	C2 = 0.0367,
	C3 = -0.0000015955,

	-- humidity/temperature correction constants:
	T1 = 0.01,
	T2 = 0.00008,

	-- temperature correction constants:
	-- unfortunately; the datasheet on Sesnsirion's website is tailored for the
	-- latest revision of the sensor and do not apply to my particular one.
	-- the below constants were re-computed based on my sensor:
	D1 = -50,		-- old = 40.1
	D2 = 0.00785,	-- old = 0.01

	-- commands for the sensor:
	__tempcmd = 0x03,
	__humcmd = 0x05,

	-- Creates a new table containing all the functionality expected of an
	-- SHT11 sensor. The data and clock pins must be specified with respect
	-- to the BCM numbering scheme.
	new = function(self, datapin, clockpin)
		assert(datapin and clockpin)
		local new = {
			datapin = datapin,
			clockpin = gpio(clockpin, 'out')
		}
		setmetatable(new, self)
		self.__index = self

		-- the sensor has an initial startup time of 11 milliseconds.
		-- although very unlikely for it not to have been started up already;
		-- we issue the wait here to be safe.
		sleep(11 * 10 ^ 3)

		return new
	end,

	-- Issues a tick of the clock pin of exactly 100 nanoseconds.
	__tick = function(self, tick)
		self.clockpin:write(tick)
		sleep(1)
	end,

	--[[
		First, we must alert the sensor that a command is about to be sent
        by the following sequence of signals:
            data(1) + clock(0)
            clock(1) - data(0) - clock(0) - clock(1) - data(1)
            clock(0) + data(0)

        Then, we send out all 8 command bits one at a time:
		data(bit) - clock(1) - clock(0)
        After all 8 bits are sent, the sensor acknowledges their recieval
        after one clock cycle by pulling data low and then high again.
            clock(1)
            read(data) == 0 - clock(0) - read(data) == 1
	]]--
	__sendcmd = function(self, cmd)
		local datapin = gpio(self.datapin, 'out')

		-- alert sensor that command is inbount:
		self:__tick(false)
		datapin:write(true)

		self:__tick(true)
		datapin:write(false)
		self:__tick(false)
		self:__tick(true)
		datapin:write(true)
		self:__tick(false)

		-- send the actual command bits:
		for i = 0, 7 do
			bit = bit32.band(cmd, bit32.lshift(1, 7 - i)) ~= 0 or false
			datapin:write(bit)
			self:__tick(true)
			self:__tick(false)
		end

		-- wait for acknowledge signal:
		self:__tick(true)
		datapin = gpio(self.datapin, 'in')
		self:__tick(false)

		assert(datapin:read(), "Error whilst sending command: " .. cmd)
	end,

	-- Waits the required 320 milliseconds for a command to be carried out.
	-- After computations are over; the sensor should pull the datapin down.
	__awaitresult = function(self)
		local datapin = gpio(self.datapin, 'in')
		assert(datapin:read(), "Result waiting procedure not initiated!")

		-- sleep for 400 milliseconds to be sure:
		sleep(4 * 10 ^ 5)

		assert(not datapin:read(), "Result finalization signal never came...")
	end,

	-- Reads the result of a command from the sensor.
	-- In 16-bit mode, the sensor will return the raw result in two one-byte
	-- pieces, most significant byte and bits first.
	-- Each recieved byte must be acknowledged with by pulling data down.
	__readresult = function(self)
		-- read the forst byte:
		byte1 = self:__readbyte()

		local datapin = gpio(self.datapin, 'out')
		datapin:write(true)
		datapin:write(false)
		self:__tick(true)
		self:__tick(false)

		-- read the second byte:
		byte2 = self:__readbyte()

		result = bit32.bor(bit32.lshift(byte1, 8), byte2)
		return result
	end,

	-- Reads a single byte, bit-by-bit, most significant first.
	__readbyte = function(self)
		local buf = 0
		local datapin = gpio(self.datapin, 'in')

		for i = 0, 7 do
			self:__tick(true)
			local read = datapin:read() and 1 or 0
			buf = (buf * 2) + read
			self:__tick(false)
		end

		return buf
	end,

	-- Sends the signal to skip the sending of the CRC checksum byte by the
	-- sensor and immediately go back to idle mode.
	-- This is done by keeping data high for a full clock cycle.
	__denyCRC = function(self)
		local datapin = gpio(self.datapin, 'out')

		datapin:write(true)
		self:__tick(false)
		self:__tick(true)
	end,

	-- Sends the hard-reset signal to the sensor. Clearing all register and
	-- re-initializing all communications.
	-- This is done by keeping data high for 9 clock cycles.
	reset = function(self)
		local datapin = gpio(self.datapin, 'out')

		datapin:write(true)
		for i = 1, 9 do
			self:__tick(true)
			self:__tick(false)
		end
	end,

	-- The main method which issues the necessary command for reading the
	-- temperature and reads the result; applying all needed corrections before
	-- the final return.
	temperature = function(self)
		self:__sendcmd(self.__tempcmd)

		self:__awaitresult()
		local raw = self:__readresult()
		self:__denyCRC()

		local result = raw * self.D2 + self.D1
		return result
	end,

	-- The main method which issues the necessary command for reading the
	-- raw humidity value; returning it after all the needed corrections have
	-- been applied.
	-- The sensor calculates humidity relative to the ambient temperature.
	-- As such, computing the absolute humidity requires a temperature reading,
	-- which can be passed as an optional parameter. If no temperature is
	-- provided; one is computed on the spot.
	humidity = function(self, temp)
		local temp = temp or self:temperature()

		self:__sendcmd(self.__humcmd)

		self:__awaitresult()
		local raw = self:__readresult()
		self:__denyCRC()

		local actual = self.C1 + self.C2 * raw + self.C3 * raw ^ 2
		local result = (temp - 25.0) * (actual * self.T2 + self.T1) + actual
		return result
	end,
}

return SHT11

