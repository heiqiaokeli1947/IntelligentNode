print("-->Init normal.lua use ",collectgarbage("count"),"kb")
require("HttpResult")
--IO mapping:
IO_SW1,IO_SW2=21,4

IO_SCL,IO_SDA=22,23

IO_PWM_R,IO_PWM_G,IO_PWM_B,IO_main_SW=18,19,2,5

IO_UART_RX=16
IO_UART_TX=17

IO_ADC1_0=36
IO_ADC1_3=39

IO_DAC1=25
IO_DAC2=26

IO_HSPI_CS=15
IO_HSPI_CLK=14
IO_HSPI_MOSI=13
IO_HSPI_MISO=12



print("init SW...")
--gpio.mode(IO_SW1,gpio.OUTPUT)
gpio.config( { gpio=IO_SW1, dir=gpio.OUT} )
gpio.write(IO_SW1,0)
--gpio.mode(IO_SW2,gpio.OUTPUT)
gpio.config( { gpio=IO_SW2, dir=gpio.OUT} )
gpio.write(IO_SW2,0)




--led init:
print("init LED...")
gpio.config( { gpio=IO_main_SW, dir=gpio.OUT} )
gpio.write(IO_main_SW,0)

--duty Channel duty, the duty range is [0, (2**bit_num) - 1]. Example: if ledc.TIMER_13_BIT is used maximum value is 4096 x 2 -1 = 8091
RGB_Channel_R = ledc.newChannel({
  gpio=IO_PWM_R,
  bits=ledc.TIMER_11_BIT,
  mode=ledc.HIGH_SPEED,
  timer=ledc.TIMER_0,
  channel=ledc.CHANNEL_0,
  frequency=10000,
  duty=0
});

RGB_Channel_G = ledc.newChannel({
  gpio=IO_PWM_G,
  bits=ledc.TIMER_11_BIT,
  mode=ledc.HIGH_SPEED,
  timer=ledc.TIMER_0,
  channel=ledc.CHANNEL_1,
  frequency=10000,
  duty=0
});

RGB_Channel_B = ledc.newChannel({
  gpio=IO_PWM_B,
  bits=ledc.TIMER_11_BIT,
  mode=ledc.HIGH_SPEED,
  timer=ledc.TIMER_0,
  channel=ledc.CHANNEL_2,
  frequency=10000,
  duty=0
});

print("init I2C...")
--i2c.setup(0,IO_SDA,IO_SCL,i2c.SLOW)
--hdc1080.setup()
local temp,humi=54321,78901--hdc1080.read()
print('temp:'..temp..',humi:'..humi)
switch_1,switch_2='false','false'
pwm_r,pwm_g,pwm_b=0,0,0

dofile('cfgManager.lua')
sysCfg=loadCfg()
--device_type='{\\\"range\\\":[{\\\"name\\\":\\\"'..sysCfg['rangename']..'\\\",\\\"device\\\":[\\\"r\\\",\\\"g\\\",\\\"b\\\"],\\\"range\\\":\\\"0,100,1000\\\",\\\"op\\\":\\\"rw\\\"}],\\\"bool\\\":[{\\\"name\\\":\\\"'..sysCfg['sw1name']..'\\\",\\\"device\\\":[\\\"sw1\\\"],\\\"op\\\":\\\"rw\\\"},{\\\"name\\\":\\\"'..sysCfg['sw2name']..'\\\",\\\"device\\\":[\\\"sw2\\\"],\\\"op\\\":\\\"rw\\\"}],\\\"number\\\":[{\\\"name\\\":\\\"'..sysCfg['num2name']..'\\\",\\\"device\\\":[\\\"humi\\\"],\\\"op\\\":\\\"r\\\",\\\"unit\\\":\\\"RH%\\\"},{\\\"name\\\":\\\"'..sysCfg['num1name']..'\\\",\\\"device\\\":[\\\"temp\\\"],\\\"op\\\":\\\"r\\\",\\\"unit\\\":\\\"c\\\"}]}';
sta_cfg={}
sta_cfg.ssid=sysCfg['wifiname']
sta_cfg.pwd=sysCfg['wifipwd']

print('Set up WIFI:'..sta_cfg.ssid..','..sta_cfg.pwd)
local wifi_get_ip=0
local wifi_ip
function wifiGotIpHook(event, info) 
	print("got ip "..info.ip) 
	wifi_get_ip=1
	wifi_ip=info.ip
end


wifi.mode(wifi.STATION,true)
wifi.sta.on("got_ip", wifiGotIpHook)
wifi.start()
wifi.sta.config(sta_cfg)
--wifi.sta.autoconnect(1)

reg_count=30
connect_count=0;
wifi_timer=tmr.create()


function wifiHook() 
	if(0==wifi_get_ip)then
			if(connect_count<10)then
				print("Try connect to:["..sta_cfg.ssid.."]...");
				connect_count=connect_count+1
			else
				print("Switch to config mode...");
				sysCfg['mode']='config';
				saveCfg(sysCfg)
				node.restart();
			end
	else
		reg_count=reg_count+1
		if(reg_count < 30)then
			return;
		end
		print("Connected:",wifi_ip);
		print("Reg to:"..sysCfg['serverip']);
		wifi_timer:stop();

		headers = {
		["Content-Type"] = "application/json",
		}
		http.post('http://'..sysCfg['serverip']..':8080/springMVC/hello/deviceregister',
		{ headers = headers },
		'{"registerType":"simple","ip":"'..wifi_ip..'","devicepwd":"'..sysCfg['devicepwd']..'"}',
		function(code,data)
			print(code,data)
			if (code==200) then
				print("Reg success.")
				reg_count=0
				wifi_timer:start();
			else
				print("Reg failed.")
				reg_count=30
				wifi_timer:start();
			end
		end)
		
	end
end




wifi_timer:register( 5000,tmr.ALARM_AUTO,wifiHook)
wifi_timer:start()

print("-->Run httpServer.lua",collectgarbage("count"),"kb")
dofile('httpServer.lua')
collectgarbage()
print("-->Init webserver",collectgarbage("count"),"kb")
httpServer:listen(80)
collectgarbage()
print("<--Init webserver",collectgarbage("count"),"kb")

			

httpServer:use('/status',function(req,res)
	if req.query.devicepwd then
		reg_count=0
		res:type('application/json')
		if req.query.devicepwd~= sysCfg['devicepwd'] then
			res:send('{"errCode":"'..OP_REJECT..'","msg":"'..'Invalid pwd.'..'"}')
		else
			if req.query.mode=='info' then
				print('info mode.')
				
				local ok, ret = pcall(sjson.encode, HttpResult.init_status_info( sysCfg ))
				if ok then
				res:send(ret)
				else
				res:send('{"errCode":"'..HttpResult.OP_ERROR..'","msg":"'..'json encode failed.'..'"}')
				end
			
			elseif req.query.mode=='get' then
				print('get mode.')
				local temp,humi=12345,54321--hdc1080.read()
				
				local retTmp = HttpResult.init_status_get( sysCfg )
				retTmp["r"]=pwm_r
				retTmp["g"]=pwm_g
				retTmp["b"]=pwm_b
				retTmp["sw1"]=switch_1
				retTmp["sw2"]=switch_2
				retTmp["sysOnTime"]=node.uptime()
				
				local ok, ret = pcall(sjson.encode, retTmp)
				if ok then
				res:send(ret)
				else
				res:send('{"errCode":"'..HttpResult.OP_ERROR..'","msg":"'..'json encode failed.'..'"}')
				end

			else
				print('set mode.')
				pwm_r,pwm_g,pwm_b=tonumber(req.query.r),tonumber(req.query.g),tonumber(req.query.b)
				
				if(0==pwm_r and 0==pwm_g and 0==pwm_b)then
					gpio.write(IO_main_SW,0)
				else
					gpio.write(IO_main_SW,1)
				end
				RGB_Channel_R:setduty(pwm_r)
				RGB_Channel_G:setduty(pwm_g)
				RGB_Channel_B:setduty(pwm_b)
				
				if('true'==req.query.sw1)then
					switch_1='true'
					gpio.write(IO_SW1,0) 
				else
					switch_1='false'
					gpio.write(IO_SW1,1)
				end
				
				if('true'==req.query.sw2)then
					switch_2='true'
					gpio.write(IO_SW2,0) 
				else
					switch_2='false'
					gpio.write(IO_SW2,1)
				end
				res:send('{"errCode":"'..HttpResult.OP_OK..'","msg":"'..'Sucess.'..'"}')
			end
		end
	else
		res:send('{"errCode":"'..HttpResult.OP_ERROR..'","msg":"'..'Invalid param.'..'"}')
	end
	end)
	
