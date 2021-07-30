function loadCfg()
	local cfg={};
	local fd=file.open("system.config", "rw")
	if fd then
		local line
		repeat
			line= fd:readline()
			if line then
				local delimPos=string.find(line, '=')
				local k=string.sub(line,1,delimPos-1)
				local paramEndPos=string.find(line, '\n')
				local v=string.sub(line,delimPos+1,delimPos+1+(#line)-delimPos-2)
				cfg[k] = v
				--print('Read:k:['..k..'],v:['..v.."]")
			end
		until line==nil
		fd:close(); fd = nil
	else
		print("open failed") 
	end
	return cfg
end

function saveCfg(table)
	if (nil==table) then
		return
	end
	local fd=file.open("system.config", "w+")
	if fd then
			for k,v in pairs(table) do
				--print('Save:k:['..k..'],v:['..v.."]")
				fd:writeline(k.."="..v)
			end
		fd:close()
	else
		print("open failed") 
	end
	fd = nil
end
