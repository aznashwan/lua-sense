-- Copyright 2015 Nashwan Azhari.
-- Licensed under the GPLv2. See LICENSE for details.

-- Does an exec call to sleep for the specified amount of time (seconds).
local function sleep(time)
	os.execute("sleep " .. time)
end

return {
	sleep = sleep
}

