-- refer to jmdasnoy(BMP180),create by pengping
-- NodeMCU ESP32 lua handler for Bosch Sensortech BMP-280 Digital pressure and temperature sensor
--
-- populate table with register addresses, reset/read values, symbolic settings, expected values ie settings
local function populatetable()
  local bmp={}
-- i2c particulars and defaults
  bmp.i2cinterface =i2c.HW0  -- only works with hardware i2c subsystems
  bmp.i2caddress = 0x76  -- fixed
-- 
  bmp.register = {} -- register hardware addresses
  bmp.expect = {} -- expected value from register
  bmp.set = {} -- special values for register
--
  bmp.register.CHIP_ID = 0xD0
  bmp.expect.CHIP_ID = 0x58
--
  bmp.register.CALIB_LSB = 0x88
  bmp.register.CTRL_MEAS = 0xF4
  bmp.register.CONFIG = 0xF5
  bmp.register.STATUS = 0xF3
  
  bmp.register.TEMP_LSB = 0xFA
  bmp.register.PRES_LSB = 0xF7
--
  bmp.register.softreset = 0xE0
  bmp.set.softreset = 0xB6
--
  bmp.oss = 0 -- default oversampling mode, ultra low power, range [0-3]
  bmp.i2c_err_max = 5 -- maximum number of cumulative i2c read errors
--
  bmp.name = "BMP280" -- default device name
--
  bmp.health = "STOP" -- default state of health, other values are INIT , RUN or ERROR
--
  return bmp
end
--
local function tick( self ) -- execute function acccording to FSM state
  self:state()
end
-- functions for FSM states
--
-- forward declarations of state functions
local checkchip
local resetchip
local getcalib
local setOverSample
local setStandByMode
local requestUT
local readUT
local requestUP
local readUP

-- forward declarations of functions called from states
local readbytes
local writebytes
local cleancalib
local ut2t
local up2p
local fsm_start
local fsm_disable
local i2c_ok
local i2c_err
--
checkchip = function( self ) -- state 0: attempt to get a response from the bus/address and compare with expected signature
  readbytes( self.i2cinterface, self.i2caddress, self.register.CHIP_ID, 1,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        if data:byte( 1 ) == self.expect.CHIP_ID then
          self.state = resetchip
          self.health = "INIT"
        else
          self:chip_err_log(self, data )
          fsm_disable( self )
        end
      end
    end
  )
end
--
resetchip = function ( self )  -- state 1: soft chip reset
  writebytes( self.i2cinterface, self.i2caddress, self.register.softreset, self.set.softreset ,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        self.state = getcalib
      end
    end
  )
end
--
getcalib = function( self )  -- state 2: get EEPROM calibration values 13*16bits
  readbytes( self.i2cinterface, self.i2caddress, self.register.CALIB_LSB, 26,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        self.calib = true -- calibration data is validate, if not then ucleancalib/cleancalib will set it to false
-- calibration values are signed except AC4, AC5 , AC6
        self.T1 = ucleancalib( self, data, 1)
        self.T2 = cleancalib( self, data, 3)
        self.T3 = cleancalib( self, data, 5)

        self.P1 = cleancalib( self, data, 7)
        self.P2 = cleancalib( self, data, 9)
        self.P3 = cleancalib( self, data, 11)
        self.P4 = cleancalib( self, data, 13)
        self.P5 = cleancalib( self, data, 15)
        self.P6 = cleancalib( self, data, 17)
        self.P7 = cleancalib( self, data, 19)
        self.P8 = cleancalib( self, data, 21)
		self.P9 = cleancalib( self, data, 23)
		self.RESERVED =  cleancalib( self, data, 25)
        if self.calib then
          self.state = requestUT
          self.health = "RUN"
        else
          self:calib_err_log( )
          fsm_disable( self )
        end
      end
    end
  )
end

setOverSample = function ( self )  -- state 3: request temperature measure
  writebytes( self.i2cinterface, self.i2caddress, self.register.CTRL_MEAS, 0x2E,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        self.state = setStandByMode
      end
    end
  )
end

setStandByMode = function ( self )  -- state 3: request temperature measure
  writebytes( self.i2cinterface, self.i2caddress, self.register.CONFIG, 0x00,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        self.state = waitMeasureFinish
      end
    end
  )
end

BMP280_MEASURING_BIT					0x01
#define	BMP280_IM_UPDATE_BIT					0x08

waitMeasureFinish = function ( self )  -- state 3: request temperature measure
  readbytes( self.i2cinterface, self.i2caddress, self.register.STATUS, 1 ,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        if bit.isclear( data:byte( 1 ), 3 ) then
          self.state = waitIMUpdateFinish
        else
          self:measure_wait_log( )--waitMeasureFinishlog
        end
      end
    end
  )
end


waitIMUpdateFinish = function ( self )  -- state 3: request temperature measure
  readbytes( self.i2cinterface, self.i2caddress, self.register.STATUS, 1 ,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
        if bit.isclear( data:byte( 1 ), 0 ) then
          self.state = readUT
        else
          self:IM_update_wait_log( )--waitMeasureFinishlog
        end
      end
    end
  )
end

  bmp.register.TEMP_LSB = 0xFA
  bmp.register.PRES_LSB = 0xF7

readUT = function ( self )  -- state 4: read temperature
  readbytes( self.i2cinterface, self.i2caddress, self.register.TEMP_LSB, 3 ,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
          local ut = bit.lshift( data:byte( 0 ) , 12 ) +bit.lshift( data:byte( 1 ) , 4 )+ bit.rshift( data:byte( 2 ) , 4 )
          self:temperature_update( )
          self.state = readUP
      end
    end
  )
end
--

readUP = function ( self )  -- state 6: read pressure
  readbytes( self.i2cinterface, self.i2caddress, self.register.PRES_LSB, 3 ,
    function( data, ack )
      if not ack then
        i2c_err( self )
      else
        i2c_ok( self )
          local up = bit.lshift( data:byte( 0 ) , 12 ) +bit.lshift( data:byte( 1 ) , 4 )+ bit.rshift( data:byte( 2 ) , 4 )
          up2p( self , up )
          self:pressure_update( )
          self.state = setStandByMode
      end
    end
  )
end
--
readbytes = function( interface, address, register, nbytes, callback) -- block read multiple bytes from registers and execute callback when done
  i2c.start( interface )
  i2c.address( interface, address, i2c.TRANSMITTER, true )
  i2c.write( interface, register, true )
  i2c.start( interface )
  i2c.address( interface, address, i2c.RECEIVER, true)
  i2c.read( interface,nbytes )
  i2c.stop( interface)
  i2c.transfer( interface,callback )
end
--
writebytes = function( interface, address, register, value, callback) -- write value(s) to register and execute callback when done
  i2c.start( interface )
  i2c.address( interface , address, i2c.TRANSMITTER, true )
  i2c.write( interface, register, value, true ) -- value may be multiple bytes 
  i2c.stop( interface )
  i2c.transfer( interface,callback )
  end
--
cleancalib = function( self, data, index)
  local val = ( data:byte( index + 1 ) + bit.lshift( data:byte( index ), 8 ) )
  if val == 0 or val == 0xFFFF then
    self.calib = false
    return 0
  elseif val>32767 then
    return (val-65536)
  else
    return val
  end
end
--
ucleancalib = function( self, data, index)
  local val = ( data:byte( index + 1 ) + bit.lshift( data:byte( index ), 8 ) )
  if val == 0 or val == 0xFFFF then
    self.calib = false
    return 0
  else
    return val
  end
end

-- conversion functions
ut2t = function( self , ut )
  local x1 = bit.arshift( ((ut - self.AC6) * self.AC5 ) , 15)
local x2 = bit.lshift( self.MC, 11) / (x1 + self.MD)
-- round to integer after division
  x2 = x2>=0 and math.floor(x2+0.5) or math.ceil(x2-0.5)
  local b5 = x1 + x2
  self.B5 = b5
  self.T = bit.arshift( ( b5 + 8), 4) / 10
end
--
up2p = function( self, up )
  local b6 = self.B5-4000
  local x1 = bit.arshift( self.B2 * b6 * b6, 23 )
  local x2 = bit.arshift( self.AC2 * b6, 11)
  local x3 = x1 + x2
  local b3 = bit.arshift( (bit.lshift( self.AC1 * 4 + x3, self.oss) + 2) , 2)
  x1 = bit.arshift( self.AC3 * b6, 13)
  x2 = bit.arshift( self.B1 * b6 * b6 / 4096 , 16)
  x3 = bit.arshift( x1 + x2 + 2 , 2)
  local b4 = bit.arshift( self.AC4 * ( x3 + 32768 ), 15)
  local b7 = ( up - b3 ) * bit.arshift( 50000 , self.oss )
  local p = 2 * b7 / b4
  p = p>=0 and math.floor(p+0.5) or math.ceil(p-0.5)
  x1 = bit.arshift( p , 8)
  x1 = x1 * x1
  x1 = bit.arshift( x1 * 3038 , 16)
  x2 = bit.arshift( -7357 * p , 16 )
  self.P = ( p + bit.arshift(( x1 + x2 + 3791) , 4 ) ) / 100
end



-- Returns temperature in DegC, double precision. Output value of “51.23” equals 51.23 DegC.
-- t_fine carries fine temperature as global value
--double bmp280_compensate_T_double(BMP280_S32_t adc_T)
--{
--	double var1, var2, T;
--	var1 = (((double)adc_T)/16384.0 - ((double)dig_T1)/1024.0) * ((double)dig_T2);
--	var2 = ((((double)adc_T)/131072.0 - ((double)dig_T1)/8192.0) *
--	(((double)adc_T)/131072.0 - ((double) dig_T1)/8192.0)) * ((double)dig_T3);
--	t_fine = (BMP280_S32_t)(var1 + var2);
--	T = (var1 + var2) / 5120.0;
--	return T;
--}

--Returns pressure in Pa as double. Output value of “96386.2” equals 96386.2 Pa = 963.862 hPa
--double bmp280_compensate_P_double(BMP280_S32_t adc_P)
--{
--	double var1, var2, p;
--	var1 = ((double)t_fine/2.0) - 64000.0;
--	var2 = var1 * var1 * ((double)dig_P6) / 32768.0;
--	var2 = var2 + var1 * ((double)dig_P5) * 2.0;
--	var2 = (var2/4.0)+(((double)dig_P4) * 65536.0);
--	var1 = (((double)dig_P3) * var1 * var1 / 524288.0 + ((double)dig_P2) * var1) / 524288.0;
--	var1 = (1.0 + var1 / 32768.0)*((double)dig_P1);
--	if (var1 == 0.0)
--	{
--	return 0; // avoid exception caused by division by zero
--	}
--	p = 1048576.0 - (double)adc_P;
--	p = (p - (var2 / 4096.0)) * 6250.0 / var1;
--	var1 = ((double)dig_P9) * p * p / 2147483648.0;
--	var2 = p * ((double)dig_P8) / 32768.0;
--	p = p + (var1 + var2 + ((double)dig_P7)) / 16.0;
--	return p;
--}


-- FSM control
fsm_start = function( self )
  self.i2c_err_count = 0
  self.state = checkchip
end
--
fsm_disable = function( self )
  self.state = function() end
  self:fatal_err_log( )
  self.health = "ERROR"
end
-- error handlers
i2c_ok = function( self )
  if self.i2c_err_count > 0 then
    self.i2c_err_count = self.i2c_err_count - 1
  end
end
--
i2c_err = function( self )
  self:i2c_err_log()
  if self.i2c_err_count < self.i2c_err_max then
    self.i2c_err_count = self.i2c_err_count + 1
  else
    fsm_disable( self )
  end
end
--
local function new( interface , oss )
  local bmp = populatetable()
  bmp.i2cinterface = interface or bmp.i2cinterface
--
  bmp.oss = oss or bmp.oss
  bmp.oss = bit.band( bmp.oss , 3) -- keep in range [0-3]
  bmp.pressureread = 0x34 + bit.lshift( bmp.oss, 6)
-- error loggers and data available hooks are initially set to do nothing 
  local function donothing( ) end
  local function waitMeasureFinishLog( ) print("wait measure finish.") end
  local function waitIMUpdateFinishLog( ) print("wait IM update finish.") end
  local function readTempFinishLog( self ) print("read temp:"..self.T) end
  local function readPressFinishLog( self ) print("read press:"..self.P) end
  
  local function badi2c( self )
  print( (time.get() .. self.name .." no response from i2c bus: %d at address: 0x%X ") : format ( self.i2cinterface , self.i2caddress))
  end
  --
  local function badchipsignature( self, data )
  	print( "i2c device on bus: ", self.i2cinterface, " at address: ", self.i2caddress, "does not have the expected signature for BMP180")
  	print( "expected chip signature", self.expect.CHIP_ID )
  	print( "received chip signature", data:byte( 1 ) )
  end
  --
  local function badcalib( self  )
  print( self.name .. " One or more invalid calibration values read from chip" )
  end
  --
  local function badfatal( self )
  print( self.name .. " handler is now disabled" )
  end
  
  bmp.i2c_err_log = badi2c
  bmp.chip_err_log = badchipsignature
  bmp.calib_err_log = badcalib
  bmp.fatal_err_log = badfatal
-- default data update hooks
  bmp.temperature_update = readTempFinishLog
  bmp.pressure_update = readPressFinishLog
  bmp.measure_wait_log = waitMeasureFinishLog
  bmp.IM_update_wait_log = waitIMUpdateFinishLog
-- initial FSM state
  fsm_start( bmp )
-- exported functions
  bmp.tick = tick
  bmp.reset = fsm_start
--[[ export the two conversion functions only for testing purposes
  bmp.ut2t = ut2t
  bmp.up2p = up2p
--]]
--
  return bmp
end
--
return { new = new }
