-- ***************************************************************************
-- BH1750 module for ESP32 with nodeMCU
-- BH1750 compatible tested 2021-11-28
--
-- Written by pengping
--
-- MIT license, http://opensource.org/licenses/MIT
-- ***************************************************************************
local moduleName = ... 
local M = {}
_G[moduleName] = M

require("baseUtils")
--$GPRMC,<1>,<2>,<3>,<4>,<5>,<6>,<7>,<8>,<9>,<10>,<11>,<12>*hh
--<1> UTC时间，hhmmss.sss(时分秒.毫秒)格式
--<2> 定位状态，A=有效定位，V=无效定位
--<3> 纬度ddmm.mmmm(度分)格式(前面的0也将被传输)
--<4> 纬度半球N(北半球)或S(南半球)
--<5> 经度dddmm.mmmm(度分)格式(前面的0也将被传输)
--<6> 经度半球E(东经)或W(西经)
--<7> 地面速率(000.0~999.9节，前面的0也将被传输)
--<8> 地面航向(000.0~359.9度，以正北为参考基准，前面的0也将被传输)
--<9> UTC日期，ddmmyy(日月年)格式
--<10> 磁偏角(000.0~180.0度，前面的0也将被传输)
--<11> 磁偏角方向，E(东)或W(西)
--<12> 模式指示(仅NMEA0183 3.00版本输出，A=自主定位，D=差分，E=估算，N=数据无效)
--*后hh为$到*所有字符的异或和
local UART_ID = 2
local BAUD = 9600
local GPRMC_START_FLAG="$GPRMC,"
local GPRMC_END_FLAG="*"
local GPRMC_REPORT_MAX_LENGTH=1520 -- 76*2

local GPGGA_START_FLAG="$GPGGA,"
local GPGGA_END_FLAG="*"
local GPGGA_REPORT_MAX_LENGTH=1520 -- 76*2



local GPRMCReciveBuffer = ""
local GPGGAReciveBuffer = ""

local GPSResultCode = {}

GPSResult={
			timeStamp="",--yyyy-MM-dd HH:mm:ss
			Longitude=-999999,--经度
			latitude=-999999,--纬度
			altitude=-999999,--海拔
			speed=-999999,
			direction=-999999,
			mode=""
			}

local function GPRMCParser(report)
	if(report ~= nil) then
		print("---GPRMC report:"..report)
		local list = stringSplit(report,",")
		GPSResult.mode = list[12]
		
		if(GPSResult.mode ~= 'N') then
			utcTime = list[1]
			utcDate = list[9]
			GPSResult.timeStamp = "20"..string.sub(utcDate,5,6).."-"..string.sub(utcDate,3,4).."-"..string.sub(utcDate,1,2).." "..string.sub(utcTime,1,2)..":"..string.sub(utcTime,3,4)..":"..string.sub(utcTime,5,6)
			GPSResult.Longitude=tonumber(list[5])/100
			if(list[6] == 'E') then
				GPSResult.Longitude=tonumber(list[5])/100
			else
				GPSResult.Longitude=-tonumber(list[5])/100
			end
			
			if(list[4] == 'N') then
				GPSResult.latitude=tonumber(list[3])/100
			else
				GPSResult.latitude=-tonumber(list[3])/100
			end
			
			GPSResult.speed=tonumber(list[7])*1.852
		else
			GPSResult.Longitude=-999999--经度
			GPSResult.latitude=-999999--纬度
			GPSResult.altitude=-999999--海拔
			GPSResult.speed=-999999
			GPSResult.direction=-999999
		end

		printTable(GPSResult)
	end
end

local function GPGGAParser(report)
	if(report ~= nil) then
		print("---GPGGA report:"..report)
		return
	end
end


local function GPRMCProcessor(data)
	--print("recive:"..data)
	GPRMCReciveBuffer = GPRMCReciveBuffer..data
	--print("tmp bufer:"..GPRMCReciveBuffer)
	if(string.len(GPRMCReciveBuffer) > GPRMC_REPORT_MAX_LENGTH) then --删除头上部分报文
		--print("delete buffer...")
		GPRMCReciveBuffer = string.sub(GPRMCReciveBuffer,string.len(GPRMCReciveBuffer) - GPRMC_REPORT_MAX_LENGTH)
	end

	--print("now buffer"..GPRMCReciveBuffer)
	
	
	
	local startPos = string.find(GPRMCReciveBuffer,GPRMC_START_FLAG)
	local endPos = nil
	if(startPos ~= nil) then
		endPos = string.find(GPRMCReciveBuffer,GPRMC_END_FLAG,startPos)
	end

	print("startPos:"..startPos)
	print("endPos:"..endPos)
	if(endPos <= startPos) then
		print("flag invalid.")
		GPRMCReciveBuffer=""
		return
	end
	if(startPos ~= nil and endPos ~= nil) then
		local report = string.sub(GPRMCReciveBuffer,startPos+string.len(GPRMC_START_FLAG),endPos-1)
		GPRMCReciveBuffer = string.sub(GPRMCReciveBuffer,endPos+1)
		print("--new buffer:"..GPRMCReciveBuffer)
		GPRMCParser(report)
	elseif(startPos ~= nil) then
		GPRMCReciveBuffer = string.sub(GPRMCReciveBuffer,startPos)
	elseif(string.len(GPRMCReciveBuffer) > string.len(data)) then
		GPRMCReciveBuffer = string.sub(GPRMCReciveBuffer,string.len(data))
	end

end


local function GPGGAProcessor(data)
	--print("recive:"..data)
	GPGGAReciveBuffer = GPGGAReciveBuffer..data
	--print("tmp bufer:"..GPGGAReciveBuffer)
	if(string.len(GPGGAReciveBuffer) > GPGGA_REPORT_MAX_LENGTH) then --删除头上部分报文
		--print("delete buffer...")
		GPGGAReciveBuffer = string.sub(GPGGAReciveBuffer,string.len(GPGGAReciveBuffer) - GPGGA_REPORT_MAX_LENGTH)
	end

	--print("now buffer"..GPGGAReciveBuffer)
	
	
	
	local startPos = string.find(GPGGAReciveBuffer,GPGGA_START_FLAG)
	local endPos = nil
	if(startPos ~= nil) then
		endPos = string.find(GPGGAReciveBuffer,GPGGA_END_FLAG,startPos)
	end

	print("GPGGA startPos:"..startPos)
	print("GPGGA endPos:"..endPos)
	if(endPos <= startPos) then
		print("flag invalid.")
		GPGGAReciveBuffer=""
		return
	end
	if(startPos ~= nil and endPos ~= nil) then
		local report = string.sub(GPGGAReciveBuffer,startPos+string.len(GPGGA_START_FLAG),endPos-1)
		GPGGAReciveBuffer = string.sub(GPGGAReciveBuffer,endPos+1)
		--print("--new buffer:"..GPGGAReciveBuffer)
		GPGGAParser(report)
	elseif(startPos ~= nil) then
		GPGGAReciveBuffer = string.sub(GPGGAReciveBuffer,startPos)
	elseif(string.len(GPGGAReciveBuffer) > string.len(data)) then
		GPGGAReciveBuffer = string.sub(GPGGAReciveBuffer,string.len(data))
	end

end




function M.init()
	print(node.uptime()..":init GPS(UART):"..uart.getconfig(UART_ID))
	uart.setup(UART_ID, BAUD, 8, uart.PARITY_NONE, uart.STOPBITS_1, {tx = 16, rx = 17})
	uart.setmode(UART_ID, uart.MODE_UART)
	uart.start(UART_ID)
	uart.write(UART_ID, "Hello, UART2\n")
	
	-- uart 2
	uart.on(UART_ID, "data", "\r",
	function(data)
		--print("receive from uart:", data)
		GPRMCProcessor(data)
		GPGGAProcessor(data)
	end)
	
	-- error handler
	uart.on(UART_ID, "error",
	function(data)
		print("error from uart:", data)
		GPRMCReciveBuffer=""
		GPGGAReciveBuffer=""
		uart.stop(UART_ID)
		uart.setup(UART_ID, BAUD, 8, uart.PARITY_NONE, uart.STOPBITS_1, {tx = 16, rx = 17})
		uart.setmode(UART_ID, uart.MODE_UART)
		uart.start(UART_ID)
	end)

    init = true
end


function M.getGPSResult()
    if (not init) then
        --print(node.uptime()..":BH1750 not ready")
		return {}
    else
        return GPSResult
    end
end
return M
