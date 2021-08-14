HttpResult = {}


HttpResult.OP_ERROR=-1
HttpResult.OP_REJECT=-1
HttpResult.OP_OK=0


http_res_of_status_info={
				errCode=tostring(HttpResult.OP_OK),
				serverurl="",
--				type="",
				mode="",
				devicename="",
				sw1name="",
				sw2name="",
				rangename="",
				num1name="",
				num2name="",
				apip="",
				apname="",
				temp=0,
				humi=0,
				chipid=node.chipid(),
				sysOnTime=0
				}
				
http_res_of_status_get={
		errCode=tostring(HttpResult.OP_OK),
		mode="",
		devicename="",
		sw1name="",
		sw2name="",
		serverurl="",
		r=0,
		g=0,
		b=0,
		sw1="",
		sw2="",
		temp=0,
		humi=0,
		sysOnTime=0
		
		}
		
http_res_of_device_register_info={
				deviceIp="",
				deviceName="",
				devicetype="",
				description=node.chipid(),
				userName="",
				password="",
				productKey="",
				deviceSecret="",
				regionId="",
				longitude="",
				latitude="",
				altitude=""
				}
				
http_res_of_report_data={
				deviceIp="",
				timestamp=1234567890,
				temperature=-1,
				humidity=-1,
				pressure=-999999999,
				lumination=-1,
				color="FF00FF"
				}
function HttpResult.init_report_data(result)
 
		--http_res_of_report_data["deviceIp"]=result['APIP']
 
		return http_res_of_report_data
end
		
http_res_of_set_wifi={
		errCode=tostring(HttpResult.OP_OK),
		msg="",
		APName="",
		url=""
		}
		
function HttpResult.init_set_wifi(result)
 
		http_res_of_set_wifi["APName"]=result['APName']
		http_res_of_set_wifi["url"]=result['url']
		http_res_of_set_wifi["msg"]=result['msg']
		http_res_of_set_wifi["errCode"]=result['errCode']
 
		return http_res_of_set_wifi
end
		
function HttpResult.init_status_get( sysCfg)
 
		http_res_of_status_get["mode"]=sysCfg['mode']
		http_res_of_status_get["devicename"]=sysCfg['devicename']
		http_res_of_status_get["sw1name"]=sysCfg['sw1name']
		http_res_of_status_get["sw2name"]=sysCfg['sw2name']
		http_res_of_status_get["serverurl"]=sysCfg['serverurl']
 
		return http_res_of_status_get
end
		
function HttpResult.init_status_info( sysCfg )
    
	http_res_of_status_info["serverurl"]=sysCfg['serverurl']
	http_res_of_status_info["mode"]=sysCfg['mode']
	http_res_of_status_info["devicename"]=sysCfg['devicename']
	http_res_of_status_info["sw1name"]=sysCfg['sw1name']
	http_res_of_status_info["sw2name"]=sysCfg['sw2name']
	http_res_of_status_info["rangename"]=sysCfg['rangename']
	http_res_of_status_info["num1name"]=sysCfg['num1name']
	http_res_of_status_info["num2name"]=sysCfg['num2name']
	http_res_of_status_info["apip"]=sysCfg['APIP']
	http_res_of_status_info["apname"]=sysCfg['APName']
	
	return http_res_of_status_info
	
end

function HttpResult.init_device_register_info( sysCfg )
    
	http_res_of_device_register_info["deviceIp"]=sysCfg['serverurl']
	http_res_of_device_register_info["devicetype"]=sysCfg['devicetype']
	http_res_of_device_register_info["deviceName"]=sysCfg['devicename']
	http_res_of_device_register_info["userName"]=sysCfg['deviceusername']
	http_res_of_device_register_info["password"]=sysCfg['devicepwd']
	http_res_of_device_register_info["longitude"]=sysCfg['longitude']
	http_res_of_device_register_info["latitude"]=sysCfg['latitude']
	http_res_of_device_register_info["altitude"]=sysCfg['altitude']
	
	return http_res_of_device_register_info
	
end




return HttpResult
