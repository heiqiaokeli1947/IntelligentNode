print("-->Init config.lua use ", collectgarbage("count"), "kb")
require("HttpResult")


function print_r ( t )  
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print(tostring(t).." {")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end


wifi_timer=tmr.create()

dofile('cfgManager.lua')
sysCfg=loadCfg()
print_r(sysCfg)

wifi.mode(wifi.STATIONAP)
wifi.start()
local AP_SSID=sysCfg['devicename'].."_"..sysCfg['APIP'].."_"..node.chipid()
local AP_PWD=sysCfg['devicepwd']
print('AP SSID:['..AP_SSID.."]")
wifi.ap.config({ ssid = AP_SSID, pwd = AP_PWD,auth = wifi.AUTH_OPEN })
wifi.ap.setip({ip=sysCfg['APIP'],netmask=sysCfg['APNetMask'],gateway=sysCfg['APGateway']})

local TM_OUT=240

wait_count=TM_OUT
wifi_timer = tmr.create()
function wifiHook() 
	if(wait_count > 0)then
		print("Tick down:"..wait_count);
		wait_count = wait_count - 1;
	else
		print("Time out:Switch to normal mode...");
		sysCfg['mode'] = 'normal';
		saveCfg(sysCfg)
		node.restart();
	end
end
wifi_timer:register( 1000, tmr.ALARM_AUTO, wifiHook)
wifi_timer:start()



print("-->Before dofile:httpServer.lua  ", collectgarbage("count"), "kb")
dofile('httpServer.lua')
collectgarbage()
print("-->Before init webserver ", collectgarbage("count"), "kb")
httpServer:listen(80)
collectgarbage()
print("<--After init webserver ", collectgarbage("count"), "kb")

try_connect_wifi_count=0

httpServer:use('/status', function(req, res)
	print("call:status")
	res:type('application/json')
	if req.query.devicepwd ~= nil then 
		wait_count=TM_OUT
		register_NO_heartbeat_count=0
		if req.query.devicepwd~= sysCfg['devicepwd'] then
			print("device pwd invalid.")
			res:type('application/json')
			res:send('{"errCode":"' .. HttpResult.OP_REJECT..'","msg":"'..'Invalid pwd.'..'"}')
			return
		end

		print("call ok...")
		res:type('application/json')
		--res:send('{"errCode":"' ..OP_OK.. '","mode":"'..sysCfg['mode']..'","devicename":"'..sysCfg['devicename']..'","sw1name":"'..sysCfg['sw1name']..'","sw2name":"'..sysCfg['sw2name']..'","serverip":"none","r":"'..'0'..'","g":"'..'0'..'","b":"'..'0'..'","sw1":"'..'0'..'","sw2":"'..'0'..'","temp":"'..'1234'..'","humi":"'..'4321'..'"}')
		
			local retTmp = HttpResult.init_status_info( sysCfg )
			retTmp["sysOnTime"]=node.uptime()

			local ok, ret = pcall(sjson.encode, HttpResult.init_status_info( sysCfg ))
				if ok then
				res:send(ret)
				else
				res:send('{"errCode":"'..HttpResult.OP_ERROR..'","msg":"'..'json encode failed.'..'"}')
				end
		
		--res:send('{"errCode":"' ..OP_OK.. '","mode":"config","devicename":"'..sysCfg['devicename']..'","sw1name":"'..sysCfg['sw1name']..'","sw2name":"F2","serverip":"none","r":"0","g":"0","b":"0","sw1":"0","sw2":"0","temp":"1234","humi":"4321"}')
		
	else
		print("param invalid.")
		res:type('application/json')
		res:send('{"errCode":"'..HttpResult.OP_REJECT..'","msg":"'..'Invalid param.'..'"}')
	end
end)

local wifi_get_ip=0
local wifi_ip
function wifiGotIpHook(event, info) 
	print("got ip "..info.ip) 
	wifi_get_ip=1
	wifi_ip=info.ip
end

httpServer:use('/setwifi', function(req, res)
	if req.query.ssid ~= nil and req.query.pwd ~= nil and req.query.devicepwd ~= nil and req.query.serverip ~= nil then
		try_connect_wifi_count=0
		wait_count=TM_OUT
		print("new ssid:"..req.query.ssid..",pwd:"..req.query.pwd)
		local recive_devicepwd=req.query.devicepwd
		res:type('application/json')
		if recive_devicepwd~= sysCfg['devicepwd'] then
			res:send('{"errCode":"' ..HttpResult.OP_REJECT..'","msg":"'..'Invalid pwd.'..'"}')
			return
		end


		wifi.sta.on("got_ip", wifiGotIpHook)
		local tmp_station_cfg={}
		tmp_station_cfg.ssid=req.query.ssid
		tmp_station_cfg.pwd=req.query.pwd
		wifi.sta.config(tmp_station_cfg)

		wifi_timer:register(1000, tmr.ALARM_AUTO, function()
			if (1 == wifi_get_ip) then
				wifi_timer:stop();
				print("Switch to normal mode...");
				sysCfg['wifiname']=req.query.ssid
				sysCfg['wifipwd']=req.query.pwd
				sysCfg['serverip']=req.query.serverip
				sysCfg['devicepwd']=req.query.devicepwd
				sysCfg['devicename']=req.query.devicename
				sysCfg['sw1name']=req.query.sw1name
				sysCfg['sw2name'] =req.query.sw2name
				sysCfg['mode']='normal'
				saveCfg(sysCfg)
				res:type('application/json')
				
				
				local retTmp = HttpResult.init_set_wifi( {errCode=tostring(HttpResult.OP_OK),url="http://"..wifi_ip,APName=req.query.ssid,msg="connect success I will switch to noarmal mode."} )
				
				local ok, ret = pcall(sjson.encode, retTmp)
				if ok then
				res:send(ret)
				else
				res:send('{"errCode":"'..HttpResult.OP_ERROR..'","msg":"'..'json encode failed.'..'"}')
				end
				--res:send('{"errCode":"'..HttpResult.OP_OK..'","msg":"'..'connect success I will switch to noarmal mode.'..'"}')
				print("resopnse finish...");
				node.restart();
			else
				if(try_connect_wifi_count<20)then
					print('try to connect again...')
					try_connect_wifi_count=try_connect_wifi_count+1
				else
					print('Connect to new WIFI failed.')
					res:send('{"errCode":"'..HttpResult.OP_REJECT..'","msg":"'..'connect time out.'..'"}')
					wifi_timer:stop();
				end
			end
			
		end)
		wifi_timer:start()
	else
		res:type('application/json')
		res:send('{"errCode":"'..HttpResult.OP_REJECT..'","msg":"'..'Invalid param.'..'"}')
	end
end)


httpServer:use('/scanap', function(req, res)
	wait_count=TM_OUT
	wifi.sta.scan({ hidden = 0 }, function(err,arr)
		local aptable = {}
		
		if err then
			print ("Scan failed:", err)
		else
		
		
			local count = 0
			for i,ap in pairs(arr) do
				aptable[ap.ssid] = ap.rssi
				count=count+1
				if(count >= 30)then
					print("wifi count >30, exit")
					break
				end
			end
		end
		
		res:type('application/json')
		res:send(sjson.encode(aptable))
		aptable=nil
	end)
end)
