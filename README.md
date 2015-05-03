lua-sense
========

Raspberry PI + sensors + leds = weather station

#### Abilities:
  * constant monitoring of temperature and humidity
  * displaying registered values on the LCD
  * alerting of extreme values with LED's

#### Requirements:
##### Hardware:
  * Raspberry PI B+.
  * [Adafruit 16x2 LCD](http://www.adafruit.com/product/181).
  * [Sensirion SHT1x](http://www.sensirion.com/en/products/humidity-temperature/humidity-temperature-sensor-sht1x/) temperature and humidity sensor.
  * Handful of brick LED's and way too much wiring...

##### Software:
  * gcc.
  * [Lua](http://www.lua.org/) 5.2+.
  * [LuaRocks](https://luarocks.org/).
  * [lua-periphery](https://github.com/vsergeev/lua-periphery) rock for GPIO pin handling:
```sh
$ sudo luarocks install lua-periphery
```

#### Usage instructions:
  * properly set up your hardware.

  * cd into the project directory and pre-build the utils C module:
```sh
$ gcc -Wall -shared -fPIC -o utils.so utils.c
```

  * write a config file for your setup (see [example.conf](https://github.com/aznashwan/lua-sense/blob/master/lua-sense/example.conf)).

  * either run [main.lua](https://github.com/aznashwan/lua-sense/blob/master/lua-sense/main.lua) or do the following in the interpreter:
```lua
> WeatherStation = require('WeatherStation')
>
> ws = WeatherStation:new('/absolute/path/to/config/file.conf')
>
> ws:monitor{ run_time = 90, frequency = 1 }
>
> -- and when you're done, don't forget to:
> ws:cleanup()
```

##### License:
Licensed under the GPLv2. See [LICENSE](https://github.com/aznashwan/lua-sense/blob/master/LICENSE) file for details.
