print('Run normal.lua...')
print("-->Init use ", collectgarbage("count"), "kb")

device_type='pwm*1+sw*2+temp*1+humi*1'
IO_SW1=0
IO_SW2=1
IO_SCL=3
IO_SDA=4
IO_PWM_R=5
IO_PWM_G=6
IO_PWM_B=7
IO_main_SW=8

gpio.mode(IO_SW1,gpio.OUTPUT)
gpio.write(IO_SW1,gpio.LOW)
gpio.mode(IO_SW2,gpio.OUTPUT)
gpio.write(IO_SW2,gpio.LOW)
gpio.mode(IO_main_SW,gpio.OUTPUT)
gpio.write(IO_main_SW,gpio.LOW)
pwm.setup(IO_PWM_R,1000,1000)
pwm.start(IO_PWM_R)
pwm.setduty(IO_PWM_R,0)
pwm.setup(IO_PWM_G,1000,1000)
pwm.start(IO_PWM_G)
pwm.setduty(IO_PWM_G,0)
pwm.setup(IO_PWM_B,1000,1000)
pwm.start(IO_PWM_B)
pwm.setduty(IO_PWM_B,0)

i2c.setup(0, IO_SDA, IO_SCL, i2c.SLOW)  -- call i2c.setup() only once
hdc1080.setup()
local temp,humi = hdc1080.read()
print('temp:'..temp..',humi:'..humi)
switch_1='false' switch_2='false'
pwm_r=0 pwm_g=0 pwm_b=0


dofile('cfgManager.lua')
sysCfg=loadCfg()

serverip=sysCfg['serverip']

devicepwd="pengping"
print('Setting up WIFI...')
sta_cfg={}
sta_cfg.ssid=sysCfg['wifiname']
sta_cfg.pwd=sysCfg['wifipwd']

print('WIFI info:'..sta_cfg.ssid..','..sta_cfg.pwd)
wifi.setmode(wifi.STATION)
wifi.sta.config(sta_cfg)
wifi.sta.autoconnect(1)

register_NO_heartbeat_count=30
connect_count=0;
wifi_connect_timer = tmr.create()
function print_count() 
	if(nil == wifi.sta.getip())then

			if(connect_count<10)then
				print("Tring to connect to AP:["..sta_cfg.ssid.."]...");
				connect_count=connect_count+1
			else
				print("Switch to config mode...");
				sysCfg['mode'] = 'config';
				saveCfg(sysCfg)
				node.restart();
			end

	else

		register_NO_heartbeat_count = register_NO_heartbeat_count+1
		if(register_NO_heartbeat_count < 30)then
			return;
		end
		print("Connect to ["..sta_cfg.ssid.."] success: IP:",wifi.sta.getip());
		print("Try register to:"..serverip);
		tmr.stop(wifi_connect_timer);
		local registerURL='http://'..serverip..':8080/springMVC/hello/deviceregister';
		local registerInfo='{"registerType":"simple","ip":"'..wifi.sta.getip()..'","devicepwd":"'..sysCfg['devicepwd']..'"}';

		http.post(registerURL,
		'Content-Type: application/json\r\n',
		registerInfo,
		function(code, data)
			print(code, data)
			if (code==200) then
				print("Register success.")
				register_NO_heartbeat_count=0
				tmr.start(wifi_connect_timer);
			else
				print("Register failed.")
				register_NO_heartbeat_count=30
				tmr.start(wifi_connect_timer);
			end
		end)
		
	end
end

wifi_connect_timer:register( 3000, tmr.ALARM_AUTO, print_count)
wifi_connect_timer:start()


print("-->Before dofile:httpServer.lua  ", collectgarbage("count"), "kb")
dofile('httpServer.lua')
collectgarbage()
print("-->Before init webserver ", collectgarbage("count"), "kb")
httpServer:listen(80)
collectgarbage()
print("<--After init webserver ", collectgarbage("count"), "kb")


OP_REJECT=-1
OP_OK=0

httpServer:use('/getstatus', function(req, res)
	res:type('application/json')
	if req.query.devicepwd ~= nil then 
	
		register_NO_heartbeat_count=0
		if req.query.devicepwd~= sysCfg['devicepwd'] then
			res:send('{"errCode":"' .. OP_REJECT..'","msg":"'..'Invalid pwd.'..'"}')
			return
		end
		local temp,humi = hdc1080.read()
		res:send('{"errCode":"' ..OP_OK.. '","serverip":"'..serverip..'","r":"'..pwm_r..'","g":"'..pwm_g..'","b":"'..pwm_b..'","sw1":"'..switch_1..'","sw2":"'..switch_2..'","temp":"'..temp..'","humi":"'..humi..'"}')
	else
		res:send('{"errCode":"'..OP_REJECT..'","msg":"'..'Invalid param.'..'"}')
	end
end)


httpServer:use('/getdeviceinfo', function(req, res)
	if req.query.devicepwd ~= nil then 
		register_NO_heartbeat_count=0
		if req.query.devicepwd~= sysCfg['devicepwd'] then
			res:send('{"errCode":"' .. OP_REJECT..'","msg":"'..'Invalid pwd.'..'"}')
			return
		end
	res:type('application/json')
	res:send('{"errCode":"' ..OP_OK.. '","serverip":"'..sysCfg['serverip']..'","type":"'..device_type..'","devicename":"'..sysCfg['devicename']..'","apip":"'..sysCfg['APIP']..'","apname":"'..sysCfg['APName']..'","chipid":"'..node.chipid()..'"}')
	else
		res:send('{"errCode":"'..OP_REJECT..'","msg":"'..'Invalid param.'..'"}')
	end
end)


httpServer:use('/setstatus', function(req, res)
	if req.query.devicepwd and req.query.r ~= nil and req.query.g ~= nil and req.query.b ~= nil and req.query.sw1 ~= nil and req.query.sw2 ~= nil then
		register_NO_heartbeat_count=0
		print("[setstatus]r:"..req.query.r..",g:"..req.query.g..",b:"..req.query.b..",sw1:"..req.query.sw1..",sw2:"..req.query.sw2)
		res:type('application/json')
		if req.query.devicepwd~= sysCfg['devicepwd'] then
			res:send('{"errCode":"'..OP_REJECT..'","msg":"'..'Invalid pwd.'..'"}')
		else
			pwm_r=tonumber(req.query.r)
			pwm_g=tonumber(req.query.g)
			pwm_b=tonumber(req.query.b)
			
			if(0 == pwm_r and 0 == pwm_g and 0 == pwm_b)then
				gpio.write(IO_main_SW, gpio.LOW)
			else
				gpio.write(IO_main_SW, gpio.HIGH)
			end
			pwm.setduty(IO_PWM_R, pwm_r) 
			pwm.setduty(IO_PWM_G, pwm_g)
			pwm.setduty(IO_PWM_B, pwm_b)
			
			if('true'==req.query.sw1)then
				switch_1='true'
				gpio.write(IO_SW1, gpio.LOW) 
			else
				switch_1='false'
				gpio.write(IO_SW1, gpio.HIGH)
			end
			
			if('true'==req.query.sw2)then
				switch_2='true'
				gpio.write(IO_SW2, gpio.LOW) 
			else
				switch_2='false'
				gpio.write(IO_SW2, gpio.HIGH)
			end
			
			res:send('{"errCode":"'..OP_OK..'","msg":"'..'Sucess.'..'"}')
		end

	else
		res:send('{"errCode":"'..OP_REJECT..'","msg":"'..'Invalid param.'..'"}')
	end
	end)
	
