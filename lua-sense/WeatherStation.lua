-- Copyright 2015 Nashwan Azhari.
-- Licensed under the GPLv2. See LICENSE for details.

local sleep = require('utils').sleep
local LED = require('LED')
local LCD = require('LCD')
local SHT11 = require('SHT11')

--[[
	Control class for the entire hardware setup.
	Contains:
		- 16x2 LCD.
		- temperature and humidity sensor.
		- green LED to indicate that the station is operational.
		- blue LED to indicate sensors are being queried.
		- red LED to indicate extreme temperature readings.
		- yellow LED to indicate extreme humidity readings.

	Usage example:
	> local WeatherStation = require('WeatherStation')
	>
	> -- for details on config file; see config.lua
	> ws = WeatherStation:new('/path/to/config/file.conf')
	> ws.monitor{ run_time = 360, frequency = 5 }
]]--
local WeatherStation = {
	-- Returns a new table with all the functionality of a WeatherStation.
	new = function(self, confpath)
		local file = confpath or "./example.conf"
		assert(loadfile(file))()

		-- crate new empty table:
		new = {
			-- instantiate all environment parameters and default values:
			__maxtemp = Parameters.MAX_TEMP or 40,
			__mintemp = Parameters.MIN_TEMP or 30,
			__maxhumid = Parameters.MAX_HUMID or 70,
			__minhumid = Parameters.MIN_HUMID or 30,

			-- instantiate the LCD:
			__lcd = LCD:new(),

			-- instantiate the sensor:
			__sensor = {
				data = Sensor.DATA,
				clk = Sensor.CLK,
			},

			-- instantiate all LEDs:
			__leds = {
				templed = LED:new(LEDs.RED),
				humidled = LED:new(LEDs.YELLOW),
				queryled = LED:new(LEDs.BLUE),
				statled = LED:new(LEDs.GREEN)
			}
		}

		setmetatable(new, self)
		self.__index = self

		for i, led in pairs(new.__leds) do
			led:blink(0.3)
		end
		new:__lcd_write{ line1 = "Awaiting", line2 = "your command." }

		return new
	end,

	-- Centers the given text to the LCD's screen width.
	__center_text = function(self, text)
		local n = math.floor((self.__lcd.SCREENWIDTH - #text) / 2)
		n = n > 0 and n or 0
		return string.rep(n, ' ') .. text
	end,

	-- Writes the two given lines to the LCD screen.
	__lcd_write = function(self, args)
		self.__lcd:__writeline{ text = self:__center_text(args.line1), line = 1 }
		self.__lcd:__writeline{ text = self:__center_text(args.line2), line = 2 }
	end,

	-- Triggers the apropriate LEDs depending on the parameters.
	__trigger_leds = function(self, temp, humid)
		if temp < self.__mintemp or temp > self.__maxtemp then
			self.__leds.templed:on()
		else
			self.__leds.templed:off()
		end

		if humid < self.__minhumid or humid > self.__maxhumid then
			self.__leds.humidled:on()
		else
			self.__leds.humidled:off()
		end
	end,

	-- Monitor is the main method of the WeatherStation.
	-- It continuously queries the sensor; lights the appropriate alarm LEDs
	-- and displays the information on the LCD.
	monitor = function(self, args)
		self.__leds.statled:on()
		local args = args or {}
		local run_time = args.run_time or 600
		local stop_time = os.time() + run_time
		local frequency = args.frequency or 1

		while os.time() <= stop_time do
			local sht11 = SHT11:new(self.__sensor.data, self.__sensor.clk)
			self.__leds.queryled:on()
			local temp = sht11:temperature()
			sht11 = SHT11:new(self.__sensor.data, self.__sensor.clk)
			local humid = sht11:humidity(temp)
			self.__leds.queryled:off()

			self:__trigger_leds(temp, humid)

			self:__lcd_write{
				line1 = string.format("%.2f %s", temp, "(C)"),
				line2 = string.format("%.2f %s", humid, "(RH%)"),
			}

			sleep(frequency * 10 ^ 6)
		end

		self:clear()
		self:__lcd_write { line1 = "Awaiting", line2 = "your command." }
	end,

	-- Cleans up all the pins used by the WeatherStation.
	cleanup = function(self)
		local sht11 = SHT11:new(self.__sensor.data, self.__sensor.clk)
		sht11:cleanup()
		self.__lcd:cleanup()
		for i, led in pairs(self.__leds) do
			led:clenup()
		end
	end,

	-- Clears the LCD and all the LEDs.
	clear = function(self)
		for i, led in pairs(self.__leds) do
			led:off()
		end

		self.__lcd:clear()
	end,
}

return WeatherStation

