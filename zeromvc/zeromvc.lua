---------------------------------------------------------------------------------------------------------------
-- zeromvc lua 1.0
-- zeromvc lua 1.0.1 修改 pool.del 后数组少遍历一次
-- zeromvc lua 1.0.2 使用... 创建 command
-- zeromvc lua 1.0.3 getProxy 同一文件夹下可使用短地址 className 改 classPath
-- zeromvc lua 1.0.4 添加 hideSelf
-- zeromvc lua 1.0.5 添加 stage ,data
-- zeromvc lua 1.0.6 123 classPath 改 classPath or type

-- 创建lua类------------------------------------------------------------------------------------------- createClass
local classPool = {}
local function createClass(classPath, superClass)
    local i, j = string.find(classPath, "%.[^%.]+$")
    local classname
    local dir
    if i == nil then
        classname = classPath
    else
        classname = string.sub(classPath, i + 1, j)
        dir = string.sub(classPath, 1, i - 1)
    end
    local zeroClass = {}
    zeroClass.superClass = superClass
    zeroClass.classname = classname
    zeroClass.classPath = classPath
    zeroClass.dir = dir
    zeroClass.__cname = classname
    if superClass == nil then
    else
        setmetatable(zeroClass, { __index = superClass })
    end
    zeroClass.new = function(...)
        local instance = {}
        for key, var in pairs(zeroClass) do
            instance[key] = var
        end
        setmetatable(instance, { __index = zeroClass })
        instance.class = zeroClass
        instance:ctor(...)
        return instance
    end
    zeroClass.super = function(self, ...)
        self.superClass.ctor(self, ...)
    end
    classPool[classPath] = zeroClass
    return zeroClass
end

--从反射表中取得类
local function getClass(classPath)
    local _class = classPool[classPath]
    if _class == nil then
        local a, b = pcall(require, classPath)
        if a then
            _class = b
        end
    end
    return _class
end

--从反射表中删除类
local function removeClass(classPath)
    classPool[classPath] = nil
end

--从反射表中新建实例
local function new(classPath, ...)
    return getClass(classPath):new(...)
end


-- 有序table--------------------------------------------------------------------------------------------- Pool
local Pool = createClass("Pool")
function Pool:ctor(prototype)
    self.date = {}
    self.list = {}
end

function Pool:add(key, val)
    if self.date[key] == nil then
        table.insert(self.list, key)
    end
    self.date[key] = val
end

function Pool:get(key)
    return self.date[key]
end

function Pool:del(key)
    if self.date[key] ~= nil then
        local old = self.list
        self.list = {}
        for k, v in ipairs(old) do
            if v ~= key then
                table.insert(self.list, key)
            end
        end
        old = nil
    end
end

-- 伪单例观察者------------------------------------------------------------------------------------------- Observer
local Observer = createClass("Observer")
function Observer:ctor(prototype, target)
    self:reset(target)
end

--检测监听
function Observer:hasListener(type, classPath, methodName)
    if classPath ~= nil then
        return self.pool[type] ~= nil and (self.pool[type]:get(classPath) == methodName or "execute")
    else
        return self.pool[type] ~= nil and #self.pool[type].list > 0
    end
end

--添加监听
function Observer:addListener(type, classPath, methodName)
    if self.pool[type] == nil then
        self.pool[type] = Pool:new()
    end
    self.pool[type]:add(classPath or type, methodName or "execute")
end

--移除监听
function Observer:removeListener(type, classPath)
    if self.pool[type] ~= nil then
        self.pool[type]:del(classPath)
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
function Observer:clear(classPath)
    self.instancePool[classPath] = nil
end

--通知

function Observer:notify(key, ...)
    local happen = 0;
    local methods = self.pool[key]
    assert(type(key) == "string", "notify 第一个参数格式不对.不应该为" .. type(key))
    if methods == nil then
--        -------------------------------------------------------------------------------- 不兼容删除
--        local loaded, loadObserver = pcall(require, key)
--        if loaded then
--            print("使用强加载:" .. key.."不建议使用这个方法 请修改------------------------------------------")
--            --这里好像可以优化
--            self:addListener(key, loadObserver.classPath)
--            methods = self.pool[key]
--            if methods ~= nil then
--                for k, v in pairs(self.pool[key].list) do
--                    self:callSingle(key, v, methods.date[v], ...)
--                    happen = happen + 1
--                end
--            end
--        end
--        if methods == nil then
--            print("Observer " .. key .. " 命令未定义")
--        end
--        -------------------------------------------------------------------------------- 不兼容删除
    else
        for k, v in pairs(methods.list) do
            self:callSingle(key, v, methods.date[v], ...)
            happen = happen + 1
        end
    end
    return happen
end

--调用伪单例（伪单例针对本实例一个类有且只有一个实例）
function Observer:callSingle(key, classPath, methodName, ...)
    local neure = self.instancePool[classPath]
    if neure == nil then
        local classType = getClass(classPath)
        assert(classType ~= nil, "文件：" .. classPath .. " 不是有效的类文件")
        assert(classType.classPath ~= nil, "文件：" .. classPath .. " 不是类文件")
        neure = classType:new(self.target, classPath)
        self.instancePool[classPath] = neure
        if neure.init ~= nil then
            neure:init()
        end
    end
    neure.key = key
    local method = neure[methodName or "execute"]
    if method ~= nil then
        method(neure, ...)
    end
    neure = nil
end

-- mvc框架主类--------------------------------------------------------------------------------------------- Zero
local Zero = createClass("Zero")
Zero.model = nil
Zero.view = nil
Zero.control = nil
function Zero:ctor(prototype,stage,data)
    self.stage=stage
    self.data=data or {}
    self.model = {}
    self.view = Observer:new(self)
    self.control = Observer:new(self)
end

--添加逻辑
function Zero:addCommand(key, classPath, methodName)
    self.control:addListener(key, classPath, methodName)
end

--移除逻辑
function Zero:removeCommand(key, classPath)
    self.control:removeListener(key, classPath)
end

--添加视图
function Zero:addMediator(key, classPath)
    self.view:addListener(key, classPath, nil);
end

--移除视图
function Zero:removeMediator(key, classPath)
    self.view:removeListener(key, classPath);
end

--调用视图方法,（用于框架扩展不建议在罗辑中建议）
function Zero:callView(key, ...)
    self.view:notify(key, ...)
end

--激活视图
function Zero:activate(key, ...)
    self.view:notify(key, "_show", ...)
end

--删除视图
function Zero:inactivate(key)
    self.view:notify(key, "_hide")
end

--调用指命
function Zero:command(key, ...)
    self.control:notify(key, ...)
end

--释放 释放无法再使用
function Zero:dispose()
    self.model = nil
    self.view:dispose()
    self.control:dispose()
end

--一次性调用立马释放
function Zero:commandOne(classPath, methodName, ...)
    self.control:callSingle(nil, classPath, methodName, ...)
end

--获取数据
function Zero:getProxy(proxyPath)
    local proxy = self.model[proxyPath]
    if proxy == nil then
        local i, j = string.find(proxyPath, "%.[^%.]+$")
        if i ~= nil then
            proxy = self.model[string.sub(proxyPath, i + 1, j)]
        end
    end
    if proxy == nil then
        local ProxyFile = getClass(proxyPath)
        if ProxyFile ~= nil then
            proxy = ProxyFile:new(self)
            self.model[proxy.classPath] = proxy
        end
    end
    return proxy
end

-- 逻辑代码基类------------------------------------------------------------------------------------------ Command
local Command = createClass("Command")
function Command:ctor(prototype, zero, commandName)
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
    self.zero:command(key, ...)
end

--获取数据
function Command:getProxy(proxyName)
    return self.zero:getProxy(proxyName) or self.zero:getProxy(self.dir .. "." .. proxyName)
end

--激活视图
function Command:activate(key, ...)
    self.zero.view:notify(key, "_show", ...)
end

--删除视图
function Command:inactivate(key)
    self.zero.view:notify(key, "_hide")
end

-- 视图代码基类--------------------------------------------------------------------------------------------- Mediator
local Mediator = createClass("Mediator")
function Mediator:ctor(prototype, zero, mediatorKey)
    self._pool = {}
    self._isShow = false
    setmetatable(self._pool, { __mode = "k" });
    self.zero = zero
    self.stage = zero.stage
    self.mediatorKey = mediatorKey
    --    if self.init ~= nil then
    --        self:init()
    --    end
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
        self._isShow = true
        self:show(...)
    end
end

--实现执行方法
function Mediator:_hide(...)
    if self.hide and self._isShow then
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
    self:clear()
    self.zero.view:removeListener(self.key, self.mediatorKey)
end

--执行
function Mediator:command(key, ...)
    self.zero:command(key, ...)
end

--获取数据
function Mediator:getProxy(proxyName)
    return self.zero:getProxy(proxyName) or self.zero:getProxy(self.dir .. "." .. proxyName)
end

--激活视图
function Mediator:activate(key, ...)
    self.zero.view:notify(key, "_show", ...)
end

--删除视图
function Mediator:inactivate(key)
    self.zero.view:notify(key, "_hide")
end

-- 数据--------------------------------------------------------------------------------------------- Proxy
local Proxy = createClass("Proxy")
function Proxy:ctor(prototype,zero)
    self._pool = {}
    self.zero = zero
    self.data = self.zero.data
    setmetatable(self._pool, { __mode = "k" });
    if self.init ~= nil then
        self:init()
    end
end

--绑定
function Proxy:bind(mediator, callback)
    self._pool[mediator] = callback
end

--解除绑定
function Proxy:unbind(mediator)
    self._pool[mediator] = nil
end

--更新
function Proxy:update(...)
    for mediator, callback in pairs(self._pool) do
        callback(mediator, self, ...)
    end
end

-- lua 框架整合--------------------------------------------------------------------------------------------- zeromvc
local zeromvc = {}
zeromvc.createClass = createClass
zeromvc.getClass = getClass
zeromvc.new = new
zeromvc.Zero = Zero
zeromvc.Observer = Observer
zeromvc.Pool = Pool
zeromvc.Command = Command
zeromvc.Mediator = Mediator
zeromvc.Proxy = Proxy
zeromvc.classPool = classPool
function zeromvc:add(url, ...)
    local part = require(url)
    part(self, ...)
end

function zeromvc.classProxy(classPath)
    return createClass(classPath, Proxy)
end

function zeromvc.classCommand(classPath)
    return createClass(classPath, Command)
end

function zeromvc.classMediator(classPath)
    return createClass(classPath, Mediator)
end

function zeromvc.classObserver(classPath)
    return createClass(classPath, Observer)
end

function zeromvc.classZero(classPath)
    return createClass(classPath, Zero)
end

return zeromvc
