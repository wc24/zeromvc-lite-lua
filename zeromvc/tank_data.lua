local TYPE={
	HASH="hash",
	ARRAY="array",
	NUMBER="number",
	STRING="string"
}

local function metaType(obj)
	if getmetatable(obj)==nil then
		return type(obj)
	else
		return getmetatable(obj).__type or type(obj)
	end
end

local function traceError(val)
	print(debug.traceback(val, 3))
end

local function indexFn(obj, key)
	proxy=getmetatable(obj).__proxy
	return proxy[key]
end

local function newindexFn(obj, key, value)
	local meta=getmetatable(obj)
	local childType=metaType(value)
	if childType==TYPE.Array then
		traceError("array对象无法重置，请使用返原 revert", 2)
	elseif childType==TYPE.HASH then
		traceError("hash对象无法重置，请使用返原 revert", 2)
	elseif meta.__childTypes[key]==nil then
		traceError("对象属性 "..key.." 没有被初始化")
	elseif meta.__childTypes[key]==childType then
		if meta.__proxy[key]~=value then
			meta.__proxy[key]=value
			obj:change(key)
		end
	else
		traceError("类型不匹配,需要 "..meta.__childTypes[key].." 当前为 "..childType, 2)
	end
end

local function newindexArrayFn(obj, key, value)
	local meta=getmetatable(obj)
	local childType=metaType(value)
	if key > meta.__size+1 then
		traceError("无法添加", 2)
	elseif key == meta.__size+1 then
		addFn(obj)
		meta.__proxy[key]=value
	else
		if meta.__childType==childType then
			meta.__proxy[key]=value
			obj:change(key)
		else
			traceError("array对象类型不正确", 2)
		end
	end
end

local function initSet(obj, key, value)
	if metaType(obj)==TYPE.HASH then
		local meta=getmetatable(obj)
		local childType=metaType(value)
		meta.__proxy[key]=value
		meta.__initValues[key]=value
		meta.__childTypes[key]=childType
		if childType==TYPE.HASH or childType==TYPE.ARRAY then
			local childMeta=getmetatable(value)
			childMeta.__parent=obj
			childMeta.__key=key
		end
	elseif metaType(obj)==TYPE.ARRAY then
	else
		traceError("obj不是hash类型")
	end
end
local function changeFn(obj,key)
	local meta=getmetatable(obj)
	meta.__changePool[key] = true
	if meta.__parent~=nil and meta.__key~=nil then
		meta.__parent:change(meta.__key)
	end
end

local function revertFn(obj,loop)
	local meta=getmetatable(obj)
	for k,v in pairs(meta.__proxy) do
		if (meta.__childTypes[k]==TYPE.HASH or meta.__childTypes[k]==TYPE.ARRAY) then
			if loop then
				obj[k]:revert(loop)
			end
		else
			obj[k]=meta.__initValues[k] or meta.__initValue
		end
	end
end

local function revertArrayFn(obj,loop)
	local meta=getmetatable(obj)
	for i,v in ipairs(meta.__proxy) do
		obj:change(i)
	end
	meta.__proxy={}
end

local function addEventFn(obj,key,callBack)
	if obj[key]==nil then
		traceError(key.."不存在这个属性")
	else
		local meta=getmetatable(obj)
		if meta.__eventPool[key]==nil then
			meta.__eventPool[key]={}
		end
		meta.__eventPool[key][callBack]=true
	end
end

local function addEventArrayFn(obj,callBack)
	local meta=getmetatable(obj)
	meta.__eventPool[callBack]=true
end

local function removeEventFn(obj,key,callBack)
	local meta=getmetatable(obj)
	if meta.__eventPool[key]~=nil then
		meta.__eventPool[key][callBack]=nil
	end
end
local function removeEventArrayFn(obj,callBack)
	local meta=getmetatable(obj)
	meta.__eventPool[callBack]=nil
end

local function clearEventFn(obj,key)
	local meta=getmetatable(obj)
	if meta.__eventPool[key]~=nil then
		meta.__eventPool[key]=nil
	end
end

local function clearEventArrayFn(obj)
	local meta=getmetatable(obj)
	meta.__eventPool={}
end
local callEvent;
local callEventArray;
callEventArray = function (obj)
	local meta=getmetatable(obj)
	for k,v in pairs(meta.__changePool) do
		for callback,v in pairs(meta.__eventPool) do
			callback(obj,k,obj[k])
		end
		if obj[k]~=nil then
			if meta.__childType==TYPE.HASH then
				callEvent(obj[k])
			elseif meta.__childType==TYPE.ARRAY then
				callEventArray(obj[k])
			end
			meta.__changePool={}
		end
	end
end

callEvent = function (obj)
	local meta=getmetatable(obj)
	for k,v in pairs(meta.__changePool) do
		if meta.__eventPool[k]~=nil then
			for callback,v in pairs(meta.__eventPool[k]) do
				callback(obj,k,obj[k])
			end
		end
		if obj[k]~=nil then
			if meta.__childTypes[k]==TYPE.HASH then
				callEvent(obj[k])
			elseif meta.__childTypes[k]==TYPE.ARRAY then
				callEventArray(obj[k])
			end
			meta.__changePool={}
		end
	end
end

local function flushFn(obj)
	callEvent(obj)
end

local function flushArrayFn(obj)
	callEventArray(obj)
end

local function getKeyHd(obj)
	local meta=getmetatable(obj)
	return meta.__key
end

local function pairsFn(obj)
	local meta=getmetatable(obj)
	return pairs(meta.__proxy)
end

local function cloneFn(obj)
	local meta=getmetatable(obj)
	local newTable={}
	for k,v in pairs(obj) do
		newTable[k]=v
	end
	local newMeta={}
	for k,v in pairs(meta) do
		newMeta[k]=v
	end
	newMeta.__proxy={}
	newMeta.__changePool={}
	newMeta.__eventPool={}
	for k,v in pairs(meta.__proxy) do
		newMeta.__proxy[k]=v
	end
	setmetatable(newTable,newMeta)
	return newTable
end

local function addFn(obj)
	local meta=getmetatable(obj)
	local size=meta.__size+1
	meta.__size=size
	if meta.__childType==TYPE.HASH or meta.__childType==TYPE.ARRAY then
		meta.__proxy[size]=meta.__initValue:clone()
	else
		meta.__proxy[size]=meta.__initValue--todo 
	end 

	obj:change(size)
end

local function removeFn(obj)
	if meta.__size>0 then
		local meta=getmetatable(obj)
		local size=meta.__size-1
		meta.__size=size
		meta.__proxy[size]=nil
		obj:change(size)
	end
end

local function makeDataTable(obj)
	obj.revert=revertFn
	obj.change=changeFn
	obj.addEvent=addEventFn
	obj.removeEvent=removeEventFn
	obj.clearEvent=clearEventFn
	obj.flush=flushFn
	obj.pairs=pairsFn
	obj.clone=cloneFn
	obj.getKey=getKeyHd
	setmetatable(obj, {__childTypes={},__proxy={},__initValues={},__path={},__eventPool={}, __changePool={}, __type=TYPE.HASH, __index = indexFn,__newindex=newindexFn});
	return obj
end

local function makeDataArray(initValue)
	if initValue==nil then
		traceError("数组的初始化不能为空")
	end
	local obj={}
	obj.add=addFn
	obj.remove=removeFn
	obj.revert=revertArrayFn
	obj.change=changeFn
	obj.addEvent=addEventArrayFn
	obj.removeEvent=removeEventArrayFn
	obj.clearEvent=clearEventArrayFn
	obj.flush=flushArrayFn
	obj.pairs=pairsFn
	obj.clone=cloneFn
	obj.getKey=getKeyHd
	setmetatable(obj, {__size=0,__childType=metaType(initValue),__proxy={},__initValue=initValue,__path={},__eventPool={}, __changePool={}, __type=TYPE.ARRAY, __index = indexFn,__newindex=newindexArrayFn});
	return obj
end
local _td={}
makeDataTable(_td)

-- initSet(_td,"testa",makeDataTable({}))
-- initSet(_td.testa,"t",makeDataTable({}))
-- initSet(_td,"cc",1)


-- initSet(_td.testa.t,"a",2)
local T= makeDataTable({})
initSet(T,"t",2)
local a=makeDataArray(T)
-- initSet(a)
initSet(_td,"testa",a)

-- initSet(_td.testa,"t",2)


return _td