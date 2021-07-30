print('Run init.lua...')
print("-->Load cfg ", collectgarbage("count"), "kb")
dofile('cfgManager.lua')
mainsysCfg=loadCfg()
collectgarbage()
print("<--Load cfg ", collectgarbage("count"), "kb")

if('normal'==mainsysCfg['mode'])then
	print("Run normal.lua...");
	dofile('normal.lua');
elseif('config'==mainsysCfg['mode'])then
	print("Run config.lua...");
	dofile('config.lua');
else
	print("Create default cfg.mode...");
	mainsysCfg['mode']='normal'
	saveCfg(mainsysCfg)
	node.restart()
end
print("-->Clear cfg", collectgarbage("count"), "kb")
mainsysCfg=nil
collectgarbage()
print("<--Clear cfg", collectgarbage("count"), "kb")
