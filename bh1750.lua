-- ***************************************************************************
-- BH1750 module for ESP8266 with nodeMCU
-- BH1750 compatible tested 2015-1-22
--
-- Written by xiaohu
--
-- MIT license, http://opensource.org/licenses/MIT
-- ***************************************************************************
local moduleName = ... 
local M = {}
_G[moduleName] = M



--I2C slave address of GY-30
local GY_30_address = 0x23
-- i2c interface ID
local I2C_ID = 0
--LUX
local bh1750Result = -1
--CMD
local CMD = 0x11 --0.5lx分辨率，测量时间120ms
local RESULT_LENGTH = 2
local init = false
--Make it more faster
local i2c = i2c

local count = 0
	
	

bh1750_read_timer=tmr.create()
bh1750_set_sleep_timer=tmr.create()



function bh1750Read()
	--print(node.uptime()..":read Bh1750...")
	i2c.start(I2C_ID)
    assert( i2c.address(I2C_ID, GY_30_address,i2c.RECEIVER), "!!i2c device dI2C_ID not ACK second address operation" )
    dataT = i2c.read(I2C_ID, RESULT_LENGTH)
    i2c.stop(I2C_ID)
	tmpValue = dataT:byte(1) * 256 + dataT:byte(2)
    bh1750Result = string.format("%.2f",tmpValue*10/12)
	count=count+1
	--print("read count:"..count)
	--print(node.uptime()..":stop delay timer,read res:"..bh1750Result)
	bh1750_set_sleep_timer:stop()
	
end
bh1750_set_sleep_timer:register( 300,tmr.ALARM_AUTO,bh1750Read)

function bh1750ReadCallback()
	--print(node.uptime()..":send cmd...")
	i2c.start(I2C_ID)
    assert(i2c.address(I2C_ID, GY_30_address, i2c.TRANSMITTER) , "!!i2c device dI2C_ID not ACK first address operation" )
	i2c.write(I2C_ID, CMD)
    i2c.stop(I2C_ID)
	--print(node.uptime()..":start delay timer:120ms...")
	bh1750_set_sleep_timer:start()

end


function M.init(sda, scl)
    print(node.uptime()..":init i2c..")
	i2c.setup(I2C_ID, sda, scl, i2c.SLOW)
    print(node.uptime()..":start BH1750 read thread..")
	bh1750_read_timer:register( 10000,tmr.ALARM_AUTO,bh1750ReadCallback)
	bh1750_read_timer:start()
    init = true
end


function M.getlux()
    if (not init) then
        --print(node.uptime()..":BH1750 not ready")
		return -1
    else
        return bh1750Result
    end
end
return M
