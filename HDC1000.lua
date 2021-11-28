
-------------------------------------------------------



--	HDC1000_HEAT_OFF			0x00	(heater)
--	HDC1000_TEMP_11BIT			0x40	(resolution)
-- 	HDC1000_HUMI_11BIT			0x01 	(resolution)
--	HDC1000_HUMI_8BIT			0x20 	(resolution)

-------------------------------------------------------

local modname = ...
local M = {}
_G[modname] = M

local I2C_ID = 0
local i2c = i2c


local HDC1000_ADDR = 0x40

local HDC1000_TEMP = 0x00
local HDC1000_HUMI = 0x01
local HDC1000_CONFIG = 0x02

local HDC1000_HEAT_ON = 0x20
local HDC1000_TEMP_HUMI_14BIT = 0x00

local hdc1080_init = false
local hdc1080Humi = -1
local hdc1080Temp = -1
local count = 0


hdc1080_read_timer=tmr.create()
hdc1080_read_humi_sleep_timer=tmr.create()
hdc1080_read_temp_sleep_timer=tmr.create()


-- reads 16bits from the sensor
local function read16()
	i2c.start(I2C_ID)
	i2c.address(I2C_ID, HDC1000_ADDR, i2c.RECEIVER)
	local ok, ret = pcall(i2c.address, I2C_ID, GY_30_address,i2c.RECEIVER)
	if ret then
		print("------------------------BH1750 1 IIC OK.")
	else
		print("************************read16():!!i2c device dI2C_ID not ACK second address operation")
		hdc1080_init = false
		return
	end	
	
	data_temp = i2c.read(0, 2)
	i2c.stop(I2C_ID)
	data = bit.lshift(string.byte(data_temp, 1, 1), 8) + string.byte(data_temp, 2, 2)
	return data
end


-- sets the register to read next
local function setReadRegister(register)
	i2c.start(I2C_ID)
	i2c.address(I2C_ID, HDC1000_ADDR, i2c.TRANSMITTER)
	local ok, ret = pcall(i2c.address, I2C_ID, HDC1000_ADDR, i2c.TRANSMITTER)
	if ret then
		print("------------------------BH1750 1 IIC OK.")
	else
		print("************************setReadRegister():!!i2c device dI2C_ID not ACK second address operation")
		hdc1080_init = false
		return
	end	
	
	i2c.write(I2C_ID, register)
	i2c.stop(I2C_ID)
end

-- writes the 2 configuration bytes
local function writeConfig(config)
	i2c.start(I2C_ID)
	--i2c.address(I2C_ID, HDC1000_ADDR, i2c.TRANSMITTER)
	local ok, ret = pcall(i2c.address, I2C_ID, HDC1000_ADDR, i2c.TRANSMITTER)
	if ret then
		print("------------------------BH1750 1 IIC OK.")
	else
		print("************************writeConfig():!!i2c device dI2C_ID not ACK second address operation")
		hdc1080_init = false
		return
	end	
	
	i2c.write(I2C_ID, HDC1000_CONFIG, config, 0x00)
	i2c.stop(I2C_ID)
end

-- returns true if battery voltage is < 2.7V, false otherwise
function M.batteryDead()
	setReadRegister(HDC1000_CONFIG)
	return(bit.isset(read16(), 11))

end

function config(addr, resolution, heater)
	-- default values are set if the function is called with no arguments
	HDC1000_ADDR = addr or HDC1000_ADDR
	resolution = resolution or HDC1000_TEMP_HUMI_14BIT
	heater = heater or HDC1000_HEAT_ON
	writeConfig(bit.bor(resolution, heater))
end

function hdc1080TempRead()
	hdc1080Temp = read16()/65535.0*165-40
	--print(node.uptime()..":stop delay timer,read temp res:"..hdc1080Temp)
	hdc1080_read_temp_sleep_timer:stop()
	
end

hdc1080_read_temp_sleep_timer:register( 400,tmr.ALARM_AUTO,hdc1080TempRead)


function hdc1080ReadTempCallback()
	setReadRegister(HDC1000_TEMP)
	--print(node.uptime()..":start delay timer:120ms...")
	hdc1080_read_temp_sleep_timer:start()
	
end

function hdc1080HumiRead()
	--print(node.uptime()..":read HDC1080 humi...")
	hdc1080Humi = read16()/65535.0*100
	count=count+1
	--print("read count:"..count)
	--print(node.uptime()..":stop delay timer,read res:"..hdc1080Humi)
	hdc1080_read_humi_sleep_timer:stop()
	
	--print(node.uptime()..":read HDC1080 temp...")
	hdc1080ReadTempCallback()
	
end

hdc1080_read_humi_sleep_timer:register( 400,tmr.ALARM_AUTO,hdc1080HumiRead)


function hdc1080ReadHumiCallback()
	setReadRegister(HDC1000_HUMI)
	--print(node.uptime()..":start delay timer:120ms...")
	hdc1080_read_humi_sleep_timer:start()
	
end

-- initalize i2c
function M.init(sda, scl)
	print(node.uptime()..":init i2c..")
	i2c.setup(I2C_ID, sda, scl, i2c.SLOW)
	config(HDC1000_ADDR, HDC1000_TEMP_HUMI_14BIT, HDC1000_HEAT_ON)
	print(node.uptime()..":start HDC1080 read thread..")
	hdc1080_read_timer:register( 10000,tmr.ALARM_AUTO,hdc1080ReadHumiCallback)
	hdc1080_read_timer:start()
	hdc1080_init = true
end


-- outputs temperature in Celsius degrees
function M.getHumi()
	--setReadRegister(HDC1000_HUMI)
	if(hdc1080_init ~= false) then
		return string.format("%.2f",hdc1080Humi)
	end
	
	return -9999
end

-- outputs humidity in %RH
function M.getTemp()
	if(hdc1080_init ~= false) then
		return string.format("%.2f",hdc1080Temp)
	end
	
	return -9999
end

return M

