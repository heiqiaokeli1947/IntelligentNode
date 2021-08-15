local moduleName = ... 
local M = {}
_G[moduleName] = M

--I2C slave address
local PMSensorAddr = 0x12
-- i2c interface ID
local I2C_ID = 0
local PM2_5_Value = -1
local RESULT_LENGTH = 32
local init = false
--Make it more faster
local i2c = i2c
	
PM_sensor_read_timer=tmr.create()

function PM2_5ReadCallback()
	--print(node.uptime()..":read Bh1750...")
	i2c.start(I2C_ID)
    assert( i2c.address(I2C_ID, PMSensorAddr,i2c.RECEIVER), "!!i2c device dI2C_ID not ACK second address operation" )
    dataT = i2c.read(I2C_ID, RESULT_LENGTH)
    i2c.stop(I2C_ID)
	local errCode = dataT:byte(30);
	--print("ver:"..dataT:byte(29))
	--print("error code:"..errCode)
	
	local checkSum = dataT:byte(31)*256+dataT:byte(32);
	--print("checkSum:"..checkSum)
	local checkSumCalc = 0;
	for i=1,30 do
		checkSumCalc = checkSumCalc + dataT:byte(i);
	end
	
	--print("checkSumCalc:"..checkSumCalc)
	
	if (checkSum == checkSumCalc) and (0 == errCode) then
		PM2_5_Value = dataT:byte(13)*256+dataT:byte(14)
		print("PM2.5:"..PM2_5_Value.." ug/m3.")
	else
		print("check sum error or sensor error:"..errCode)
		PM2_5_Value = -1;
	end
	
end

function M.init(sda, scl)
    print(node.uptime()..":init i2c..")
	i2c.setup(I2C_ID, sda, scl, i2c.SLOW)
    print(node.uptime()..":start PM2.5 sensor read thread..")
	PM_sensor_read_timer:register( 5000,tmr.ALARM_AUTO,PM2_5ReadCallback)
	PM_sensor_read_timer:start()
    init = true
end


function M.getPM2_5Value()
    if (not init) then
        print(node.uptime()..":PM2.5 sensor not ready")
		return -1
    else
        return PM2_5_Value
    end
end

return M