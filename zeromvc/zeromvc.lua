---------------------------------------------------------------------------------------------------------------
-- 文件：   zeromvc
-- 作者：   蓝面包(wc24@qq.com)
-- 时间：   2017
-- 功能：   MVC框架
-- 更新：   2.0.1
------------2.0.1------------
--修改提示的命名规则
--修改移除bug
--添加maped
---------------------------------------------------------------------------------------------------------------

local dir=...
local nameSpace={}
------------------------------------------------------------------------------------------------
local function trim(input)
    input = string.gsub(input, "^[ \t\n\r]+", "")
    return string.gsub(input, "[ \t\n\r]+$", "")
end
local function split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    for st,sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end
local function ucfirst(input)
    return string.upper(string.sub(input, 1, 1)) .. string.sub(input, 2)
end
function nameSpace.zeroDebug(tag,...)
    print("["..tag.."]",...)
end
function nameSpace.zeroWarn(txt,num)
    if num ==nil then
        num=0
    end
    local traceback = split(debug.traceback("", 0), "\n")
    local line="\n<<-----------------------[警告]".. trim(traceback[5+num]).."------------------------->>\n"
    print(line..txt..line)
end
function nameSpace.zeroError(txt,num)
    if num ==nil then
        num=0
    end
    local out=debug.traceback(txt, num+2)
    out=string.gsub(out, "\t%[C%]:.-\n", "")
    local line="\n<<-------------------------------[致命错误]--------------------------------->>\n"
    print(line..out..line)
end
function nameSpace.zeroAssert(bl,txt,num)
    if not bl then
        nameSpace.zeroError(txt,num)
    end
end
function nameSpace.getAddress(instance)
    return string.sub(tostring(instance),8,-1)
end
local function ObjectTostring(obj)
    if obj~=nil and obj.kind~=nil then
        return "["..obj.kind.path.." "..obj.name.."] @ ".. obj:getAddress()
    else
        return "@ ".. obj:getAddress()
    end
end
local function KindTostring(obj)
    if obj~=nil and obj.Kind~=nil then
        return "["..obj.Kind.name.." "..obj.path.."] @ ".. obj:getAddress()
    else
        return "@ ".. obj:getAddress()
    end
end
------------------------------------------------------------------------------------------------
--包
local Package={}
-- local ENUM
setmetatable(nameSpace, {dir="",__index=Package})
Package.build=function(package,fileArray)
    local currentPackage=nameSpace
    local dir=""
    for i,v in ipairs(fileArray) do
        dir=dir..v
        if currentPackage[v]==nil then
            currentPackage[v]={}
            setmetatable(currentPackage[v], {dir=dir,__index=Package})
        end
        dir=dir.."."
        currentPackage=currentPackage[v]
    end
    return currentPackage
end
Package.getDir=function(obj)
   return getmetatable(obj).dir
end
Package.addKind=function(package,obj)
    if package[obj.name]~=nil then
        nameSpace.zeroWarn("类重定义",2)
    end
   package[obj.name]=obj
end
Package.addEnum=Package.addKind
Package.get=function(obj,kindPathArray)
    local currentPackage=nameSpace
    for i,v in ipairs(kindPathArray) do
        if currentPackage[v]~=nil then
            currentPackage=currentPackage[v]
        else
            currentPackage=nil
            break
        end
    end
    return currentPackage
end
nameSpace.Package=Package
------------------------------------------------------------------------------------------------
--类

local function getCtor(kind)
    return kind.ctor or getCtor(kind.parent)
end
local function kindInstanceNew( kind ,... )
    local instance
    local address
    local meta
    nameSpace.zeroAssert(kind.__create~=nil,"缺少创建函数")
    instance = kind:__create(...)
    local ctor=getCtor(kind)
    ctor(instance,...)
    return instance
end
--基类
local Kind={}
local Object={}
Object.new=kindInstanceNew
Object.name="Object"
Object.parent=Kind
Object.package=Package:build({})
Object.package:addKind(Object)
Object.dir=Object.package.dir
Object.kind=Object
Object.ctor=function(this,name)
    this.name=name
end
Object.getZeroMeta=function(this)
    return getmetatable(this).__zeroMeta
end
Object.getAddress=function(this)
    return Object.getZeroMeta(this).address
end

Object.__create=function(kind,...)
    local instance
    local address
    local meta
    instance = {}
    meta={}
    address = nameSpace.getAddress(instance)
    meta.__zeroMeta = {type="object",address=address}
    meta.__index = kind
    meta.__tostring=ObjectTostring
    setmetatable(instance, meta)
    return instance
end
local meta={}
meta.__zeroMeta = {address=nameSpace.getAddress(Object)}
meta.__tostring=KindTostring
meta.__metatable = meta
setmetatable(Object,meta)

Kind.name="Kind"
Kind.new=function(kind,kindPath,superKind)
    local kindInstance={}
    local address = nameSpace.getAddress(kindInstance)
    kindInstance.new=kindInstanceNew
    local kindPathArray=split(kindPath,".")
    kindInstance.name=ucfirst(kindPathArray[#kindPathArray])
    kindPathArray[#kindPathArray]=nil
    kindInstance.package=Package:build(kindPathArray)
    kindInstance.package:addKind(kindInstance)
    kindInstance.dir=kindInstance.package:getDir()  
    kindInstance.path=kindPath
    local meta={}
    if superKind == nil then
        superKind=Object    
    end
    kindInstance.parent=superKind
    kindInstance.kind=kindInstance
    kindInstance.Kind=Kind
    kindInstance.isKind=true
    meta.__index = superKind
    meta.__tostring=KindTostring
    meta.__zeroMeta = {address=address}
    setmetatable(kindInstance,meta)
    return kindInstance
end
Kind.get=function(kindPath)
    local kindPathArray=split(kindPath,".")
    local name=ucfirst(kindPathArray[#kindPathArray])
    kindPathArray[#kindPathArray]=nil
    local package=Package:get(kindPathArray)
    if package==nil then
        return nil
    else
        return package[name]
    end
end
Kind.isInstance=function(kind,object)
    return Kind.isChild(kind,object.kind)
end
Kind.isKind=function(kind)
    return kind.isKind==true
end
Kind.isChild=function(kindParent,kindChild)    
    local parent=kindChild
    while parent~=nil do
        if kindParent==parent then
            return true
        end
        parent=parent.parent
    end
    return false
end
local function kind(...)
    return Kind:new(...)
end--从反射表中取得类
local function getKind(path)
    local _kind = Kind.get(path)
    if _kind == nil then
        local a, b = pcall(require, path)
        if a then
            _kind = b
        end
    end
    return _kind
end
nameSpace.Kind=Kind
nameSpace.kind=kind
nameSpace.getKind=getKind
------------------------------------------------------------------------------------------------
--枚举
local function EnumTostring(obj)
    return obj.parent.path.."."..obj.value
    -- return "ob"
end
local Enum={}
Enum.name="Enum"
Enum.new=function(enum,enumPath,...)
    local enumInstance={}
    local enumProxy={}
    local enumPathArray=split(enumPath,".")
    enumProxy.name=enumPathArray[#enumPathArray]
    enumPathArray[#enumPathArray]=nil
    local meta={}
    meta.__zeroMeta={address=nameSpace.getAddress(enumInstance)}
    meta.__index=enumProxy
    meta.__metatable = meta
    setmetatable(enumInstance,meta);
    meta.__tostring = KindTostring
    for i,v in ipairs({...}) do
        local objMeta={}
        objMeta.__tostring = EnumTostring
        objMeta.__index = Enum
        local obj={isEnum=true,parent=enumInstance,index=i,value=v}
        enumProxy[v]=obj
        enumInstance[i]=obj
        setmetatable(obj,objMeta);
    end
    enumProxy.parent=Enum
    enumProxy.path=enumPath
    enumProxy.Kind=Enum
    enumProxy.getAddress=Object.getAddress
    enumProxy.package=Package:build(enumPathArray)
    enumProxy.package:addEnum(enumInstance)
    enumProxy.isEnum=true
    enumProxy.dir=enumProxy.package:getDir()  
    return enumInstance
end
Enum.switch=function(this,fns)
    fns[this]()
end
Enum.getValue=function(this)
    return this.value
end
Enum.getIndex=function(this)
    return this.index
end
Enum.isEnum=function(this)
    return this~=nil and this.isEnum==true
end
local function enum(...)
    return Enum:new(...)
end
nameSpace.Enum=Enum
nameSpace.enum=enum
nameSpace.kindAddEnum=function(_kind,_enum)
    for k,v in ipairs(_enum) do
        -- print(k,v)
        _kind[v.value]=v
    end
end
--有key链表
local AntList=kind("AntList")
local tt=0
local lsNode
local function AntList_getnext(antList,node)
    if node==nil then
        node=antList:getZeroMeta().first.next
        if node.next==nil then
            return nil
        else
            return node,node.data
        end
    elseif node.next.next~=nil then
        node=node.next
        return node,node.data
    else
        return nil
    end
end
function AntList:ctor()
    local meta=self:getZeroMeta()
    meta.first={priority=-100000000}
    meta.last={priority=100000000}
    meta.first.next=meta.last
    meta.last.prev=meta.first
    meta.pool={}
    meta.size=0
end
function AntList:add(tag,obj,priority)
    if priority ==nil then
        priority=0
    end
    nameSpace.zeroAssert(math.abs(priority)<100000000,"添加对象 - 无效参数 priority")
    if  self[tag]==nil then
        local node={}
        node.priority=priority
        node.tag=tag
        node.data=obj
        local useNode=self:find(priority)
        node.next=useNode.next
        node.prev=useNode
        useNode.next.prev=node
        useNode.next=node
        self[tag]=obj
        local meta=self:getZeroMeta()
        meta.pool[tag]=node
        meta.size=meta.size+1
    else
        nameSpace.zeroWarn("数据重定义",4)
    end
end
function AntList:find(priority)
    ----------------------------
    --从链表中查找这个优先级将要插入的位置的前一个对象
    --使用从头遍历可以改用二分法来优化这个算法
    local meta=self:getZeroMeta()
    local useNode=meta.last.prev
    local cp=math.abs(useNode.priority-priority)
    for k,v in self:pairs() do
        local kcp=math.abs(k.priority-priority)
        if kcp==0 then
            useNode=k
            break
        elseif kcp<cp then
            cp=kcp
            useNode=k
        end
    end
    if useNode.priority>priority then
        useNode=useNode.prev
    end
    return useNode
end
function AntList:getPriority(tag)
    local meta=self:getZeroMeta()
    return meta.pool[tag].priority
end
function AntList:size()
    local meta=self:getZeroMeta()
    return meta.size
end
function AntList:del(tag)
    if self[tag]~=nil then
        local meta=self:getZeroMeta()
        local node=meta.pool[tag]
        node.prev.next=node.next
        node.next.prev=node.prev
        node=nil
        meta.pool[tag]=nil
        meta.size=meta.size-1
        self[tag]=nil
    end
end
function AntList:pairs()
    local meta=self:getZeroMeta()
    lsNode=meta.first.next
   return AntList_getnext,self,nil
end
nameSpace.AntList=AntList

local Mapped=kind("Mapped")
function Mapped:ctor(addFn,remFn,upFn)
   self._index=1
   self._indexs={}
   self._pool={}
   self._addFn=addFn
   self._remFn=remFn
   self._upFn=upFn
end
function Mapped:up(pool,indexKey)
    self._index=self._index+1
    for k,v in pairs(pool) do
        local key
        if indexKey==nil or v[indexKey]==nil then
            key=v
        else
            key=v[indexKey]
        end
        if self._pool[key]==nil then
            self._pool[key]=self._addFn(self,v,k)
            if self._pool[key]==nil then
                nameSpace.zeroWarn("添加函数返回反射对象不能为空")
            end
        else
            if self._upFn~=nil then
                self._upFn(self,self._pool[key],v,k)
            end
        end
        self._indexs[self._pool[key]]=self._index
    end
    for vo,ui in pairs(self._pool) do
        if self._indexs[ui]~=self._index then
            self._indexs[ui]=nil
            self._pool[vo]=nil
            self._remFn(self,ui)
        end
    end
end
nameSpace.Mapped=Mapped
local function Mapped_new(addFn,remFm)
   local self={}

   self.up=function(_self,pool)
      
   end
   return self
end

------------------------------------------------------------------------------------------------
local Event=kind(...)
Event.version = "Event 2.0"
local  function check( type )
    if Enum.isEnum(type) then
        return type.value
    else
        return type
    end
end
function Event:ctor(target)
    if target==nil then
        self.pool = {}
        self.target=self
    else
        self:bind(target)
    end
    self.isEvent=true
    return self
end
function Event:bind(target)
    self.pool = target.pool
    self.target=target
end
function Event:addEvent(type,callBack,priority)
    type=check(type)
    if self.pool[type] == nil then
        self.pool[type] = AntList:new()
    end
    self.pool[type]:add(callBack,true,priority)
end
function Event:event(type,...)
    type=check(type)
    if self.pool[type] ~= nil then
        for vo, v in self.pool[type]:pairs() do
            local isStop=vo.tag(self,type, ...)
            if isStop then
                break
            end
        end
    end
end
function Event:hasEvent(self)
    if self.pool[type] ~= nil then
        for vo, v in self.pool[type]:pairs() do
            if v then
                return true
            end
        end
    end
    return false
end
function Event:removeEvent(type,callBack)
    type=check(type)
    self.pool[type]:del(callBack)
end
function Event:clearEvent(type)
    type=check(type)
    self.pool[type] = AntList:new()
end

function Event.isEvent(obj)
    return obj.isEvent==true
end

nameSpace.Event=Event
------------------------------------------------------------------------------------------------
--以下为mvc核心类
-- 伪单例观察者------------------------------------------------------------------------------------------- Observer
local Observer = kind("zeromvc.Observer")
function Observer:ctor(target)
    self:reset(target)
end
--检测监听
function Observer:hasListener(type, path, methodName)
    if path ~= nil then
        return self.pool[type] ~= nil and (self.pool[type]:get(path) == methodName or "execute")
    else
        return self.pool[type] ~= nil and #self.pool[type] > 0
    end
end
--添加监听
function Observer:addListener(type, path, methodName,priority)
    if self.pool[type] == nil then
        self.pool[type] = AntList:new()
    end
    self.pool[type]:add(path or type, methodName or "execute",priority)
end
--移除监听
function Observer:removeListener(type, path)
    if self.pool[type] ~= nil then
        self.pool[type]:del(path)
    end
end
--消除type类型下所有临听
function Observer:clearListener(type)
    self.pool[type] = nil
end
--释放 释放无法再使用
function Observer:dispose()
    self.pool = nil
    self.instancePool = nil
end
--重置
function Observer:reset(target)
    self.pool = {}
    self.target = target or self
    self.instancePool = {}
end
--消除缓存
function Observer:clear(path)
    self.instancePool[path] = nil
end
--通知
function Observer:notify(key, ...)
    local happen = 0;
    local methods = self.pool[key]
    nameSpace.zeroAssert(type(key) == "string", "notify 第一个参数格式不对.不应该为" .. type(key))
    if methods ~= nil then
        for vo, v in methods:pairs() do
            local isStop=self:callSingle(key, vo.tag, v, ...)
            happen = happen + 1
            if isStop then
                break
            end
        end
    end
    return happen
end
--调用伪单例（伪单例针对本实例一个类有且只有一个实例）
function Observer:callSingle(key, path, methodName, ...)
    local neure = self.instancePool[path]
    local isStop=false
    if neure == nil then
        local kindType = getKind(path)
        nameSpace.zeroAssert(kindType ~= nil and type(kindType) == "table" and kindType.path ~= nil, "文件：" .. path .. " 不是有效的类文件",4)
        neure = kindType:new(self.target, path)
        self.instancePool[path] = neure
        if kindType.name~="init" then
            if neure.init ~= nil then
                neure:init()
            end
        end
    end
    neure.key = key
    local method = neure[methodName or "execute"]
    if method ~= nil then
        isStop=method(neure, ...)
    end
    neure = nil
    return isStop
end
-- mvc框架主类--------------------------------------------------------------------------------------------- Zero
local Zero = kind("zeromvc.Zero")
Zero.model = nil
Zero.view = nil
Zero.control = nil
function Zero:Zero(stage, data)
    self.stage = stage
    self.data = data or {}
    self.model = {}
    self.showList = {}
    self.showPool = {}
    self.view = Observer:new(self)
    self.control = Observer:new(self)
end
--添加逻辑
-- 同一个文件内的不同方法不能对应在同一个key中
function Zero:addCommand(key, path, methodName,priority)
    self.control:addListener(key, path, methodName,priority)
end
--移除逻辑
function Zero:removeCommand(key, path)
    self.control:removeListener(key, path)
end
--添加视图
function Zero:addMediator(key, path)
    self.view:addListener(key, path, nil);
end
--移除视图
function Zero:removeMediator(key, path)
    self.view:removeListener(key, path);
end
--调用视图方法,（用于框架扩展不建议在罗辑中建议）
function Zero:callView(key, ...)
    self.view:notify(key, ...)
end
--激活视图
function Zero:activate(key, ...)
    self.view:notify(key, "_show", ...)
end
--视图是否被激活
function Zero:isActivate(key)
    return self.showPool[key]~= nil
end
--删除视图
function Zero:inactivate(key)
    self.view:notify(key, "_hide")
end
--删除视图
function Zero:inactivateAll()
    for k,v in pairs(self.showPool) do
        self.view:notify(k, "_hide")
    end
end
--调用指命 key不能是"command"
function Zero:command(key, ...)
    self.control:notify(key, ...)
    -- self.control:notify("command",key, ...)
end
--释放 释放无法再使用
function Zero:dispose()
    for k,v in pairs(self.showList) do
        v:dispose()
    end
    self.showList = nil
    self.showPool = nil
    self.model = nil
    self.view:dispose()
    self.control:dispose()
end
--restart
function Zero:restart()
    self:dispose()
    self.showList ={}
    self.showPool ={}
    self.model = {}
    self.view = Observer:new(self)
    self.control = Observer:new(self)
end
--一次性调用立马释放
function Zero:commandOne(path, methodName, ...)
    self.control:callSingle(nil, path, methodName, ...)
end
--获取数据
function Zero:getProxy(proxyPath)
    local proxy = self.model[proxyPath]
    if proxy == nil then
        local ProxyFile = getKind(proxyPath)
        if ProxyFile ~= nil then
            proxy = ProxyFile:new(self)
            self.model[proxy.path] = proxy
        end
    end
    return proxy
end
-- 逻辑代码基类------------------------------------------------------------------------------------------ Command
local Command = kind("zeromvc.Command")
function Command:ctor(zero, commandName)
    self.zero = zero
    self.commandName = commandName
end
--清理 清理后再次执行会重新初始化
function Command:clear()
    self.zero.control:clear(self.commandName)
end
--释放 释放后再次执行本逻辑不反应
function Command:dispose()
    self:clear()
    self.zero.control:removeListener(self.key, self.commandName)
end
--执行命令
function Command:command(key, ...)
    self.zero:command(self.dir.."."..key, ...)
end
--这里 使用相对地址
function Command:addCommand(key, kindName, methodName)
    self.zero.control:addListener(self.dir .. "." .. key, self.dir .. "." .. (kindName or key), methodName)
end
--添加视图 使用相对地址
function Command:addMediator(key, kindName)
    self.zero.view:addListener(self.dir .. "." .. key, self.dir .. "." .. (kindName or key), nil);
end
--获取数据 使用相对地址
function Command:getProxy(proxyName)
    return self.zero:getProxy(self.dir .. "." .. proxyName)
end
--激活视图
function Command:activate(key, ...)
    self.zero.view:notify(self.dir.."."..key, "_show", ...)
end
--删除视图
function Command:inactivate(key)
    self.zero.view:notify(self.dir.."."..key, "_hide")
end
-- 视图代码基类--------------------------------------------------------------------------------------------- Mediator
local Mediator = kind("zeromvc.Mediator")
function Mediator:ctor(zero, mediatorKey)
    self._pool = {}
    self._isShow = false
    setmetatable(self._pool, { __mode = "k" });
    self.zero = zero
    self.mediatorKey = mediatorKey
end
--获得场景
function Mediator:getStage()
    return self.zero.stage
end
--实现执行方法
function Mediator:execute(method, ...)
    if method and self[method] then
        self[method](self, ...)
    end
end
--实现执行方法
function Mediator:_show(...)
    if self.show and not self._isShow then
        self.zero.showList[self.mediatorKey]=self
        self.zero.showPool[self.key]=self
        self._isShow = true
        self:show(...)
    end
end
--实现执行方法
function Mediator:_hide(...)
    if self.hide and self._isShow then
        self.zero.showList[self.mediatorKey]=nil
        self.zero.showPool[self.key]=nil
        self._isShow = false
        self:hide(...)
        for proxy, callBack in pairs(self._pool) do
            self:removeProxy(proxy)
        end
    end
end
--删除视图自己
function Mediator:hideSelf()
    self.zero.view:notify(self.key, "_hide")
end
--添加关心数据
function Mediator:addProxy(proxy, callBack)
    nameSpace.zeroAssert(proxy,"proxy 不能为空")
    nameSpace.zeroAssert(callBack,"callBack 不能为空")
    proxy:bind(self, callBack);
    self._pool[proxy] = callBack
end
--添加强制关心数据
function Mediator:bindProxy(proxy)
    nameSpace.zeroAssert(proxy,"proxy 不能为空")
    local function callBack(_self, _proxy, key, ...)
        if key ~= nil and self[key] ~= nil and type(key) == "string" then
            self[key](self,_proxy,...)
        elseif key == nil and self["upProxy"] ~= nil then
            self["upProxy"](self,_proxy,key,...)
        end
    end
    proxy:bind(self, callBack);
    self._pool[proxy] = callBack
end
--移除关心数据
function Mediator:removeProxy(proxy)
    proxy:unbind(self)
    self._pool[proxy] = nil
end
--清理 清理后所有关心数据都不关心  清理后再次执行会重新初始化
function Mediator:clear()
    for proxy, callBack in pairs(self._pool) do
        self:removeProxy(proxy)
    end
    self.zero.view:clear(self.mediatorKey)
end
--释放
function Mediator:dispose()
    self:_hide()
    self:clear()
    self.zero.view:removeListener(self.key, self.mediatorKey)
end
--执行
function Mediator:command(key, ...)
    self.zero:command(self.dir.."."..key, ...)
end
--获取数据
function Mediator:getProxy(proxyName)
    return self.zero:getProxy(self.dir .. "." .. proxyName)
end
--激活视图
function Mediator:activate(key, ...)
    self.zero.view:notify(self.dir.."."..key, "_show", ...)
end
--删除视图
function Mediator:inactivate(key)
    self.zero.view:notify(self.dir.."."..key, "_hide")
end
-- 数据--------------------------------------------------------------------------------------------- Proxy
local Proxy = kind("zeromvc.Proxy")
function Proxy:ctor(zero)
    self.__pool = {}
    self.zero = zero
    self.data = self.zero.data
    setmetatable(self.__pool, { __mode = "k" });
    if self.init ~= nil then
        self:init()
    end
end
--绑定
function Proxy:bind(mediator, callback)
    self.__pool[mediator] = callback
end
--解除绑定
function Proxy:unbind(mediator)
    self.__pool[mediator] = nil
end
--更新
function Proxy:update(...)
    for mediator, callback in pairs(self.__pool) do
        callback(mediator, self, ...)
    end
end
---------------------------------------------------------------------------------------------
-- nameSpace
nameSpace.Zero = Zero
nameSpace.Observer = Observer
nameSpace.Pool = Pool
nameSpace.Command = Command
nameSpace.Mediator = Mediator
nameSpace.Proxy = Proxy
function nameSpace.kindProxy(path)
    return kind(path, Proxy)
end
function nameSpace.kindCommand(path)
    return kind(path, Command)
end
function nameSpace.kindMediator(path)
    return kind(path, Mediator)
end
function nameSpace.kindObserver(path)
    return kind(path, Observer)
end
function nameSpace.kindZero(path)
    return kind(path, Zero)
end
nameSpace.classProxy=nameSpace.kindProxy
nameSpace.classCommand=nameSpace.kindCommand
nameSpace.classMediator=nameSpace.kindMediator
nameSpace.classObserver=nameSpace.kindObserver
nameSpace.classZero=nameSpace.kindZero
return nameSpace
