print('Run init.lua...')
print("-->Load cfg ", collectgarbage("count"), "kb")

require("baseUtils")



dofile('cfgManager.lua')
mainsysCfg=loadCfg()
printTable(mainsysCfg)
collectgarbage()
print("<--Load cfg ", collectgarbage("count"), "kb")
local mode = mainsysCfg['mode']
local normalMode = "normal"
print("....mode:["..mode.."],set:["..normalMode.."]")

local isNormal = string.find(normalMode,mode)
print(isNormal)
if (mode==normalMode) then
	print("Run normal.lua...");
	dofile('normal.lua');
elseif ('config'==mainsysCfg['mode']) then
	print("Run config.lua...");
	dofile('config.lua');
else
	print("---------Create default cfg.mode...");
	mainsysCfg['mode']='normal'
	saveCfg(mainsysCfg)
	node.restart()
end
print("-->Clear cfg", collectgarbage("count"), "kb")
mainsysCfg=nil
collectgarbage()
print("<--Clear cfg", collectgarbage("count"), "kb")
