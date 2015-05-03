#!/usr/bin/env lua
-- Copyright 2015 Nashwan Azhari.
-- Licensed under the GPLv2. See LICENSE for details.

local WeatherStation = require('WeatherStation')

local ws = WeatherStation:new()

ws:monitor{ run_time = 90, frequency = 1 }

ws:cleanup()

