--ATP.Settings.Mode=1 紫门一波		=2紫门瀑布一波

ATP.Settings.Mode = 2


local Log = ATP.Log 
local Debug = function(format, params) 
    if params then 
        print(string.format(format, params)) 
    else 
        print(format) 
    end 
end 

local ATP_START_TASK = false 
local AddonName = "ATP-Maraudon-UI" 
local UpDateSetting = ATP.UpDateSetting 
local Player, Pet, Buff, Debuff, Spell, Target, Item 
local function Locals() 
    Player = DMW.Player 
    Pet = Player.Pet 
    Target = Player.Target or false 
    Buff = Player.Buffs 
    Debuff = Player.Debuffs 
    Spell = Player.Spells 
    Item = Player.Items 
end

local function Class() 
    local cls = {} 
    cls.__index = cls 
    setmetatable(cls, { __call = function(self, ...) local instance = setmetatable({}, self) instance:New(...) 
        return instance 
    end }) 
    return cls 
end

local function Delay(millisecond) 
    Scorpio.Delay(millisecond / 1000) 
end

local ATP_NEED_RESET = false 
local APT_LAST_BLIZZARD_POSITION = nil 
local ATP_BLIZZARD_TIME = 0 
local ATP_BLIZZARD_START = 0 
local ATP_BLIZZARD_CONTINUED = 0 
local ATP_SPELL_BLIZZARD_COUNT = 0 
local ATP_TIME = GetTime() 
local ATP_SPELL_CAST_SUCCESS = {} 
local ATP_ICE_BARRIER_AMOUNT = 0 
local CONST_STRING = {} 
CONST_STRING.ZoneText = "凄凉之地" 
CONST_STRING.ZoneInstanceText = "玛拉顿" 
CONST_STRING.HordeSupplyZoneText = "葬影村" 
CONST_STRING.AllianceSupplyZoneText = "尼耶尔前哨站" 
CONST_STRING.HordeSupplyNpcName = "海维拉尼" 
CONST_STRING.AllianceSupplyNpcName = "玛克斯顿·斯坦恩" 
CONST_STRING.Hearthstone = "炉石" 
CONST_STRING.Mailbox = "邮箱" 

local Position = Class() 

function Position:New(...) 
    if type(...) == "number" 
    then 
        self.X, self.Y, self.Z = unpack({ ... }) 
    elseif 
    type(...) == "string" 
    then 
        self.X, self.Y, self.Z = ObjectPosition(...) 
    elseif type(...) == "table" 
    then 
        local arg = ... 
        if arg.PosX 
        then 
            self.X, self.Y, self.Z = arg.PosX, arg.PosY, arg.PosZ 
        else 
            self.X, self.Y, self.Z = unpack(arg)   
        end 
    else 
        Log.Error("Position:New - 错误的参数")    
    end
end

function Position:Distance(...) 
    local x, y, z 
    if type(...) == "number" then 
        x, y, z = unpack({ ... }) 
    elseif type(...) == "string" then 
        x, y, z = ObjectPosition(...) 
    elseif type(...) == "table" then 
        local arg = ... 
        if arg.PosX then 
            x, y, z = arg.PosX, arg.PosY, arg.PosZ 
        else 
            x, y, z = unpack(arg) 
        end 
    else 
        Log.Error("Position:Distance - 错误的参数") 
        return -1 
    end 
    return sqrt((self.X - x) ^ 2 + (self.Y - y) ^ 2 + (self.Z - z) ^ 2) 
end

function Position:Distance2D(...) 
    local x, y, z 
    if type(...) == "number" then 
        x, y, z = unpack({ ... }) 
    elseif type(...) == "string" then 
        x, y, z = ObjectPosition(...) 
    elseif type(...) == "table" then 
        local arg = ... 
        if arg.PosX then 
            x, y, z = arg.PosX, arg.PosY, arg.PosZ 
        else 
            x, y, z = unpack(arg) 
        end 
    else 
        Log.Error("Position:Distance - 错误的参数") 
        return -1 
    end 
    return sqrt((self.X - x) ^ 2 + (self.Y - y) ^ 2) 
end

local Nav = {} 
Nav.State = { None = "None", Moving = "Moving", Success = "Success", Fault = "Fault", } Nav.Stuck = { MoveTime = DMW.Time, CurrentDest = nil, LastPos = nil, Count = 0 } 

local function GetPositionFromRadian(toX, toY, toZ, Distance, radian) 
    local _, AngleXYZ = GetAnglesBetweenPositions(Player.PosX, Player.PosY, Player.PosZ, toX, toY, toZ) 
    return GetPositionFromPosition(Player.PosX, Player.PosY, Player.PosZ, Distance, radian, AngleXYZ) 
end

local function CreateNodes(x, y, z, movingDistance, detectionDistance) 
    local nodes = {} 
    local canGo = true 
    local x1, y1, z1, x2, y2, z2, newPlayerZ 
    for radian = rad(0), rad(360), rad(30) do 
        canGo = true 
        for h = 1, 3, 0.5 do 
            x1, y1, z1 = GetPositionFromRadian(x, y, z, detectionDistance, radian) 
            z1 = z1 + h newPlayerZ = Player.PosZ + h 
            if TraceLine(Player.PosX, Player.PosY, newPlayerZ, x1, y1, z1, 0x100121) ~= nil then 
                canGo = false 
                break 
            end 
        end 
        if canGo then 
            x2, y2, z2 = GetPositionFromRadian(x, y, z, movingDistance, radian) 
            table.insert(nodes, { X = x2, Y = y2, Z = z2, Dist = GetDistanceBetweenPositions(x2, y2, z2, x, y, z) }) 
        end 
    end 
    table.sort(nodes, function(b, c) return b.Dist < c.Dist end) 
    return nodes 
end

function Nav:Start(x, y, z, OffSet) 
    self.OffSet = OffSet or 1 
    if not self.CurrentPath or (self.EndPos and (self.EndPos.X ~= x or self.EndPos.Y ~= y or self.EndPos.Z ~= z)) then 
        local newPath = CalculatePath(GetMapId(), Player.PosX, Player.PosY, Player.PosZ, x, y, z, true, false, 3) 
        if newPath then 
            self.EndPos = Position(x, y, z) 
            self.CurrentPath = {} 
            self.CurrentIndex = 1 
            for i = 1, #newPath do 
                table.insert(self.CurrentPath, Position(newPath[i])) 
            end 
        end 
    end 
    if self.CurrentIndex > #self.CurrentPath then 
        self:Reset() 
        return self.State.Success 
    end 
    if self.EndPos:Distance2D(Player) <= self.OffSet then 
        self:Reset() 
        return self.State.Success 
    end 
    local CurrentNode = self.CurrentPath[self.CurrentIndex] 
    if CurrentNode then 
        if CurrentNode:Distance2D(Player) <= self.OffSet then 
            if self.CurrentIndex == #self.CurrentPath then 
                self:Reset() 
                return self.State.Success 
            else 
                self.CurrentIndex = self.CurrentIndex + 1 
                return self.State.Moving 
            end 
        else 
            self:MoveTo(CurrentNode) 
            return self.State.Moving 
        end 
    else 
        return self.State.Fault 
    end
end

function Nav:UnStuck(Dest) 
    if self.Stuck.LastPos and DMW.Time > self.Stuck.MoveTime then 
        if self.Stuck.LastPos:Distance2D(Player) < 1 then 
            print( "卡位处理 %d", self.Stuck.Count) 
            if self.Stuck.Count == 0 then 
                MoveBackwardStart() 
                Delay(350) 
                MoveBackwardStop() 
                MoveForwardStart() 
                Delay(100) 
                JumpOrAscendStart() 
                AscendStop() 
                MoveForwardStop() 
            elseif self.Stuck.Count == 1 then 
                local r = math.random(1, 10) 
                if r < 6 then 
                    MoveBackwardStart() 
                    Delay(500) 
                    MoveBackwardStop() 
                    StrafeLeftStart() 
                    MoveForwardStart() 
                    Delay(500) 
                    StrafeLeftStop() 
                    MoveForwardStop() 
                else 
                    MoveBackwardStart() 
                    Delay(500) 
                    MoveBackwardStop() 
                    StrafeRightStart() 
                    MoveForwardStart() 
                    Delay(800) 
                    StrafeRightStop() 
                    MoveForwardStop() 
                end 
            else 
                self:StopMove() 
                MoveBackwardStart() 
                Delay(500) 
                MoveBackwardStop() 
                local Nodes = CreateNodes(Dest.X, Dest.Y, Dest.Z, 5, 5) 
                if #Nodes > 0 then 
                    MoveTo(Nodes[1].X, Nodes[1].Y, Nodes[1].Z) Delay(1500) else 
                        print( "无法摆脱卡位") 
                    end 
                end 
                self.Stuck.Count = self.Stuck.Count + 1 
            else 
                self.Stuck.Count = 0 
            end 
            self.Stuck.MoveTime = DMW.Time + 0.5 self.Stuck.LastPos = Position(Player)
end
end

function Nav:MoveTo(Dest) 
    if Dest:Distance2D(Player) > 20 then 
    end 
    if Dest ~= self.Stuck.CurrentDest then 
        self.Stuck.CurrentDest = Dest 
        self.Stuck.Count = 0 
        self.Stuck.LastPos = nil 
        self.Stuck.MoveTime = nil 
    end 
    if not self.Stuck.LastPos then 
        self.Stuck.LastPos = Position(Player) 
        self.Stuck.MoveTime = DMW.Time + 0.5 
    end 
    self:UnStuck(Dest) MoveTo(Dest.X, Dest.Y, Dest.Z) 
end

function Nav:Reset() 
    self.CurrentIndex = 0 self.CurrentPath = nil self.EndPos = nil 
end

function Nav:StopMove() 
    if Player.Moving then 
        MoveForwardStart() MoveForwardStop() 
    end 
    Nav:Reset() 
end

local FixedPath = Class() 
function FixedPath:New(Nodes, OffSet, Nearby) 
    self.OffSet = OffSet or 1 
    self.Nearby = Nearby or false 
    self.Nodes = Nodes 
    self.Count = #Nodes 
    self.Index = 1 
    self.IsRunning = false 
    self.CurrentNodeDistance = 0 
end

function FixedPath:Move(Facing, EndIndex) 
    EndIndex = EndIndex or false 
    if self.Nearby and not self.IsRunning then 
        local tmp = {} 
        for i = 1, #self.Nodes do 
            table.insert(tmp, { i = i, d = sqrt((Player.PosX - self.Nodes[i].x) ^ 2 + (Player.PosY - self.Nodes[i].y) ^ 2) }) 
        end 
        table.sort(tmp, function(a, b) return a.d < b.d end) 
        self.Index = tmp[1].i 
    end 
    local Pos = self.Nodes[self.Index] 
    if Pos and (not EndIndex or EndIndex >= self.Index) then 
        self.IsRunning = true 
        self.CurrentNodeDistance = sqrt((Player.PosX - Pos.x) ^ 2 + (Player.PosY - Pos.y) ^ 2) 
        if (Pos.offset and self.CurrentNodeDistance < Pos.offset) or (not Pos.offset and self.CurrentNodeDistance < self.OffSet) then 
            self.Index = self.Index + 1 
            if self.Index > self.Count then 
                MoveForwardStart() 
                MoveForwardStop() 
                return true 
            else 
                Pos = self.Nodes[self.Index] 
                self.CurrentNodeDistance = sqrt((Player.PosX - Pos.x) ^ 2 + (Player.PosY - Pos.y) ^ 2) 
            end 
        end 
        if Facing then 
            FaceDirection(Pos.x, Pos.y, true) 
        end 
        MoveTo(Pos.x, Pos.y, Pos.z) 
    else 
        return true 
    end
end

function FixedPath:UnStuckMove(Facing, EndIndex) 
    EndIndex = EndIndex or false 
    if self.Nearby and not self.IsRunning then 
        local tmp = {} 
        for i = 1, #self.Nodes do 
            table.insert(tmp, { i = i, d = sqrt((Player.PosX - self.Nodes[i].x) ^ 2 + (Player.PosY - self.Nodes[i].y) ^ 2) }) 
        end 
        table.sort(tmp, function(a, b) 
            return a.d < b.d 
        end) 
            
        self.Index = tmp[1].i 
    end 
    
    local Pos = self.Nodes[self.Index] 
    if Pos and (not EndIndex or EndIndex >= self.Index) then 
        self.IsRunning = true 
        local Dist = sqrt((Player.PosX - Pos.x) ^ 2 + (Player.PosY - Pos.y) ^ 2) 
        if Dist < self.OffSet then 
            self.Index = self.Index + 1 
            if self.Index > self.Count then 
                MoveForwardStart() 
                MoveForwardStop() 
                return true 
            end 
        end 
        if Facing then 
            FaceDirection(Pos.x, Pos.y, true) 
        end 
        if self.Index ~= self.CurrentIndex then 
            self.CurrentIndex = self.Index 
            self.StuckCount = 0 
            self.LastPos = nil 
            self.LastMoveTime = nil 
        end 
        if not self.LastPos then 
            self.LastPos = Position(Player) 
            self.LastMoveTime = DMW.Time + 0.5 
        end 
        self:UnStuck(Pos.x, Pos.y, Pos.z) MoveTo(Pos.x, Pos.y, Pos.z) 
    else 
        return true 
    end
end

function FixedPath:NavMove(Facing, EndIndex) 
    EndIndex = EndIndex or false 
    if self.Nearby and not self.IsRunning then 
        local tmp = {} 
        for i = 1, #self.Nodes do 
            table.insert(tmp, { i = i, d = sqrt((Player.PosX - self.Nodes[i].x) ^ 2 + (Player.PosY - self.Nodes[i].y) ^ 2) }) 
        end 
        table.sort(tmp, function(a, b) return a.d < b.d end) 
        self.Index = tmp[1].i 
    end 
    local Pos = self.Nodes[self.Index] 
    if Pos and (not EndIndex or EndIndex >= self.Index) then 
        self.IsRunning = true 
        if Facing then 
            FaceDirection(Pos.x, Pos.y, true) 
        end 
        if Nav.State.Success == Nav:Start(Pos.x, Pos.y, Pos.z, self.OffSet) then 
            self.Index = self.Index + 1 
            if self.Index > self.Count then 
                MoveForwardStart() 
                MoveForwardStop() 
                return true 
            end 
        end 
    else 
        return true 
    end 
end

function FixedPath:UnStuck(x, y, z) 
    if self.LastPos and DMW.Time > self.LastMoveTime then 
        if self.LastPos:Distance2D(Player) < 1 then 
            print( "卡位处理 %d", self.StuckCount) 
            if self.StuckCount == 0 then 
                MoveBackwardStart() 
                Delay(350) 
                MoveBackwardStop() 
                Delay(100) 
                MoveForwardStart() 
                Delay(200) 
                JumpOrAscendStart() 
                AscendStop() 
                MoveForwardStop() 
            elseif 
            self.StuckCount == 1 then 
                local r = math.random(1, 10) 
                if r < 6 then 
                    MoveBackwardStart() 
                    Delay(500) 
                    MoveBackwardStop() 
                    StrafeLeftStart() 
                    MoveForwardStart() 
                    Delay(500) 
                    StrafeLeftStop() 
                    MoveForwardStop() 
                else 
                    MoveBackwardStart() 
                    Delay(500) 
                    MoveBackwardStop() 
                    StrafeRightStart() 
                    MoveForwardStart() 
                    Delay(800) 
                    StrafeRightStop() 
                    MoveForwardStop() 
                end 
            else 
                if Player.Moving then 
                    MoveForwardStart() 
                    MoveForwardStop() 
                end 
                MoveBackwardStart() 
                Delay(500) 
                MoveBackwardStop() 
                local Nodes = CreateNodes(x, y, z, 5, 5) 
                if #Nodes > 0 then 
                    MoveTo(Nodes[1].X, Nodes[1].Y, Nodes[1].Z) Delay(1500) 
                else 
                    print( "无法摆脱卡位") 
                end 
            end 
            self.StuckCount = self.StuckCount + 1 
        else 
            self.StuckCount = 0 
        end 
        self.LastMoveTime = DMW.Time + 0.5 
        self.LastPos = Position(Player)
end
end

function FixedPath:GetIndex() 
    return self.Index 
end

function FixedPath:SetIndex(Value) 
    self.Index = Value 
end

function FixedPath:Facing(Index) 
    Index = Index or self.Index 
    local tmp = self.Nodes[Index] 
    if tmp then 
        FaceDirection(tmp.x, tmp.y, true) 
    end 
end

function FixedPath:Reset() 
    self.Index = 1 
    self.IsRunning = false 
    self.CurrentIndex = 0 
    self.StuckCount = 0 
    self.LastPos = nil 
    self.LastMoveTime = nil 
    self.CurrentNodeDistance = 0 
    if Player.Moving then 
        MoveForwardStart() 
        MoveForwardStop() 
    end 
end

local FixedNode = Class() 
function FixedNode:New(path, offset) 
    self.Path = path 
    self.Count = #path 
    self.Offset = offset 
    self.CurOffset = 999 
    self.Index = 1 
    self.Pause = false 
    self.Tags = {} 
end

function FixedNode:Move() 
    if false and not self.Moved then 
        local tmp = {} 
        for i = 1, self.Count do 
            table.insert(tmp, { i = i, d = sqrt((Player.PosX - self.Path[i].x) ^ 2 + (Player.PosY - self.Path[i].y) ^ 2) }) 
        end 
        table.sort(tmp, function(a, b) 
            return a.d < b.d end) 
            self.Index = tmp[1].i 
        end 
        local node = self.Path[self.Index] 
        if node then 
            self.Moved = true 
            self.CurOffset = sqrt((Player.PosX - node.x) ^ 2 + (Player.PosY - node.y) ^ 2) 
            if node.func then 
                local inc = node.func(self) 
                if inc and type(inc) == "number" and inc > 0 then 
                    if self.CurOffset < self.Offset then 
                        self.Index = self.Index + inc - 1 
                    else 
                        self.Index = self.Index + inc 
                    end 
                end 
            end 
            if not self.Pause then 
                if self.CurOffset < self.Offset then 
                    self.Index = self.Index + 1 
                    if self.Index > self.Count then 
                        MoveForwardStart() 
                        MoveForwardStop() 
                        return true 
                    else 
                        node = self.Path[self.Index] 
                    end 
                end 
                MoveTo(node.x, node.y, node.z) 
            end 
        else 
            return true 
        end 
    end

function FixedNode:AddIndex(value) end

function FixedNode:Reset() 
    self.Index = 1 
    self.Pause = false 
    self.Moved = false 
    self.CurOffset = 999 
    self.Tags = {} 
end

local function CastBuff(self) 
    if Buff.IceBarrier:Remain() < 15 and Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
        Debug("寒冰护体") 
    end 
    if Buff.ManaShield:Remain() < 20 and Spell.ManaShield:IsReady() and Spell.ManaShield:Cast() then 
        Debug("法力盾") 
    end 
end

local Jump = (function() 
    local out = {} 
    out.Right = function(PosZ, Facing) 
        FaceDirection(Facing, true) 
        StrafeRightStart() 
        Delay(150) 
        JumpOrAscendStart() 
        StrafeRightStop() 
        AscendStop() 
        Delay(200) 
        while not UnitIsDeadOrGhost("player") and ATP_START_TASK do 
            if math.abs(PosZ - DMW.Player.PosZ) < 0.1 then 
                RunMacroText(".stopfall") break 
            end 
            Scorpio.Next() 
        end 
    end 
    out.Left = function(PosZ, Facing) 
        FaceDirection(Facing, true) 
        StrafeLeftStart() 
        Delay(150) 
        JumpOrAscendStart() 
        StrafeLeftStop() 
        AscendStop() 
        Delay(200) 
        
        while not UnitIsDeadOrGhost("player") and ATP_START_TASK do 
            if math.abs(PosZ - DMW.Player.PosZ) < 0.1 then 
                RunMacroText(".stopfall") break 
            end 
            Scorpio.Next() 
        end 
    end 
    out.Height = function(toZ, Forward, Facing) 
        Facing = Facing or 0 
        Forward = Forward or false 
        if DMW.Player.PosZ >= toZ then 
            return true 
        end 
        while not UnitIsDeadOrGhost("player") and ATP_START_TASK do 
            JumpOrAscendStart() 
            Delay(200) 
            AscendStop() 
            if DMW.Player.PosZ >= toZ then 
                RunMacroText(".stopfall") 
                FaceDirection(Facing, true) 
                if Forward then 
                    MoveForwardStart() 
                    Delay(200) 
                    MoveForwardStop() 
                end 
                return true 
            end 
        end 
    end 
    out.Forward = function() 
        local time = GetTime() 
        MoveForwardStart() 
        Scorpio.Next() 
        JumpOrAscendStart() 
        AscendStop() 
        MoveForwardStop() 
        while true do 
            if GetTime() - time > 0.82 then 
                RunMacroText(".stopfall") 
                break 
            end 
            Scorpio.Next() 
        end 
    end 
    out.ForwardUp = function(EndX, EndY, EndZ) 
        local x, y, z = ObjectPosition("player") 
        local dist = sqrt((x - EndX) ^ 2 + (y - EndY) ^ 2) 
        local startMove = false 
        local time, m 
        while not UnitIsDeadOrGhost("player") and ATP_START_TASK do 
            FaceDirection(EndX, EndY, true) 
            x, y, z = ObjectPosition("player") 
            dist = sqrt((x - EndX) ^ 2 + (y - EndY) ^ 2) 
            
            if not startMove and EndZ > z and dist > 7 then 
                x, y, z = ObjectPosition("player") 
                time = GetTime() 
                MoveForwardStart() 
                Scorpio.Next() 
                JumpOrAscendStart() 
                AscendStop() 
                MoveForwardStop() 
                
                while true do 
                    x, y, z = ObjectPosition("player") 
                    if sqrt((x - EndX) ^ 2 + (y - EndY) ^ 2) < 1 then 
                        if math.abs(EndZ - z) > 10 then 
                            RunMacroText(".stopfall") 
                        end 
                        break 
                    end 
                    m = (EndZ - z) / 1.64 
                    if m >= 1 then 
                        m = 2 
                    else 
                        m = 4 
                    end 
                    if GetTime() - time > 0.82 / m then 
                        RunMacroText(".stopfall") 
                        break 
                    end 
                    Scorpio.Next() 
                end 
            elseif not startMove and EndZ > z and dist <= 7 then 
                time = GetTime() 
                JumpOrAscendStart() 
                AscendStop() 
                while true do 
                    if GetTime() - time > 0.20 then 
                        RunMacroText(".stopfall") 
                        break 
                    end 
                    Scorpio.Next() 
                end 
            elseif not startMove and dist > 7 then 
                time = GetTime() 
                MoveForwardStart() 
                Scorpio.Next() 
                JumpOrAscendStart() 
                AscendStop() 
                MoveForwardStop() 
                
                while true do 
                    if GetTime() - time > 0.82 then 
                        RunMacroText(".stopfall") 
                        break 
                    end 
                    Scorpio.Next() 
                end 
            else 
                startMove = true 
                if dist > 1 then 
                    MoveTo(EndX, EndY, EndZ) 
                    Delay(200) 
                    Scorpio.Next() 
                    RunMacroText(".stopfall") 
                else 
                    return true 
                end
end
end
end 

out.ForwardDown = function(EndX, EndY, EndZ) 
    local x, y, z 
    local startX, startY, startZ = ObjectPosition("player") 
    local startMove = false 
    local dist, time, speed, args, t args = { GetUnitSpeed("player") } speed = args[2] t = sqrt((2 * 10 + 1.64) / 20) + 0.42 
    local Z = math.abs((EndZ - startZ) / 10) 
    local D = sqrt((startX - EndX) ^ 2 + (startY - EndY) ^ 2) / (1.42 * speed) 
    local downTimes = 0 
    local forwardTimes = 0 
    
    if Z > D then 
        downTimes = math.ceil(Z - D) 
    else 
        forwardTimes = math.ceil(D - Z) 
        
        if forwardTimes == 0 then 
            forwardTimes = 1 
        end 
    end 
    while not UnitIsDeadOrGhost("player") and ATP_START_TASK do 
        if not startMove then 
            FaceDirection(EndX, EndY, true) 
        end 
        x, y, z = ObjectPosition("player") 
        dist = sqrt((x - EndX) ^ 2 + (y - EndY) ^ 2) 
        
        if not startMove and downTimes == 0 and forwardTimes == 0 and z - EndZ >= 5 and dist >= speed * t then 
            x, y, z = ObjectPosition("player") 
            time = GetTime() 
            MoveForwardStart() 
            Scorpio.Next() 
            JumpOrAscendStart() 
            AscendStop() 
            MoveForwardStop() 
            
            while true do 
                x, y, z = ObjectPosition("player") 
                if dist < 5 then 
                    RunMacroText(".stopfall") 
                    break 
                end 
                
                if GetTime() - time >= t then 
                    RunMacroText(".stopfall") 
                    break 
                end 
                
                Scorpio.Next() 
            end 
        elseif not startMove and (forwardTimes > 0 or dist >= speed * 0.82) then 
            time = GetTime() 
            MoveForwardStart() 
            Scorpio.Next() 
            JumpOrAscendStart() 
            AscendStop() 
            MoveForwardStop() 
            
            while true do 
                if GetTime() - time > 0.82 or dist < 3 then 
                    RunMacroText(".stopfall") 
                    forwardTimes = forwardTimes - 1 
                    break 
                end 
                Scorpio.Next() 
            end 
        elseif not startMove and (downTimes > 0 or ((z - EndZ) > 0.5 and dist <= 1)) then 
            time = GetTime() 
            JumpOrAscendStart() 
            AscendStop() 
            
            while true do 
                if GetTime() - time > t then 
                    RunMacroText(".stopfall") 
                    downTimes = downTimes - 1 
                    break 
                end 
                Scorpio.Next() 
            end 
        else if dist > 1 then 
            MoveTo(EndX, EndY, EndZ) 
            Delay(200) 
            Scorpio.Next() 
            RunMacroText(".stopfall") 
        else 
            return true 
        end
end
end
end return out
end)() 

local JumpRight = Jump.Right 
local JumpLeft = Jump.Left 
local JumpHeight = Jump.Height 
local JumpForward = Jump.Forward 
local JumpForwardUp = Jump.ForwardUp 
local JumpForwardDown = Jump.ForwardDown 
local UnitsSwingTime = {} 
local function StopMove() 
    if Player.Moving then 
        MoveForwardStart() 
        MoveForwardStop() 
    end 
end

local function Stand() 
    if not Player:Standing() then 
        RunMacroText("/stand") 
        Delay(500) 
    end 
    return true 
end

local function FacingBack(angle) 
    angle = angle or 180 
    local facing = ObjectFacing("player") 
    facing = facing + math.rad(angle) 

    if facing > math.rad(360) then 
        facing = facing - math.rad(360) 
    end 
    FaceDirection(facing, true) 
    return true 
end

local function FacingTarget(Unit) 
    StopMove() 
    FaceDirection(Unit.Pointer, true) 
    Scorpio.Next() 
    return true 
end

local function Mount() 
    if ATP.Settings.MountName and ATP.Settings.MountName ~= "" and not IsMounted() and IsOutdoors() and not Player.Combat then 
        if Player.Moving then 
            MoveForwardStart() 
            MoveForwardStop() 
            Delay(500) 
        end 
        RunMacroText("/use " .. ATP.Settings.MountName) 
        Delay(500) 
        while Player.Casting do 
            Delay(500) 
        end 
    end 
end

local function ItemInBagTipLines(bagId, slotId) 
    local Lines = {} 
    local iLoc, iLink, frame iLoc = ItemLocation:CreateFromBagAndSlot(bagId, slotId) if C_Item.DoesItemExist(iLoc) then 
        iLink = C_Item.GetItemLink(iLoc) 
        frame = _G["ContainerFrame" .. tostring(bagId + 1) .. "Item" .. tostring(slotId)] 
        GameTooltip:SetOwner(frame, ANCHOR_NONE) 
        GameTooltip:SetBagItem(bagId, slotId) 
        for i = 1, GameTooltip:NumLines() do 
            local Left = _G["GameTooltipTextLeft" .. tostring(i)]:GetText() 
            local Right = _G["GameTooltipTextRight" .. tostring(i)]:GetText() 
            table.insert(Lines, Left) 
            table.insert(Lines, Right or "null") 
        end 
        GameTooltip:Hide() 
        return unpack(Lines) 
    else 
        return nil 
    end 
end

local function IsSoulBound(BagID, SlotId) 
    local _, _, BoundString = ItemInBagTipLines(BagID, SlotId) 
    if BoundString == ITEM_SOULBOUND then 
        return true 
    else 
        return false 
    end 
end

local function ContainValue(table, value) 
    for _, v in pairs(table) do 
        if v == value then 
            return true 
        end 
    end 
end

local function FuzzyCompare(table, value) 
    if table then for _, v in pairs(table) do 
        if string.find(value, v) then 
            return true 
        end 
    end 
end 
end

local Bag = { Update = false, Items = {}, DestroyItems = {}, DestroyDelay = 1, DestroyTimer = 0 } 

function Bag:UpdateItems() 
    self.Update = true 
    table.wipe(self.Items) 
    local i = 1 
    local NumSlot, ItemID 
    for BagID = 0, 4, 1 do 
        NumSlot = GetContainerNumSlots(BagID) 
        for Slot = 1, NumSlot, 1 do 
            ItemID = GetContainerItemID(BagID, Slot) 
            if ItemID then 
                local Temp_1 = { GetItemInfo(ItemID) } 
                local Temp_2 = { GetContainerItemInfo(BagID, Slot) } 
                local _, _, name = string.find(Temp_2[7], "%[(.*)]") 
                self.Items[i] = { 
                    BagID = BagID, 
                    Slot = Slot, 
                    Name = name or Temp_1[1], 
                    Rarity = Temp_1[3], 
                    Type = Temp_1[6], 
                    StackCount = Temp_1[8], 
                    SellPrice = Temp_1[11], 
                    Count = Temp_2[2], 
                    Locked = Temp_2[3], 
                    LootAble = Temp_2[6], 
                    NoValue = Temp_2[9], 
                    ItemID = Temp_2[10], 
                } i = i + 1 
            else 
                self.Items[i] = nil 
            end 
        end 
    end 
end

function Bag:GetDestroyItems() 
    table.wipe(self.DestroyItems) 
    for _, v in pairs(self.Items) do 
        if not v.NoValue and not IsSoulBound(v.BagID, v.Slot) and not FuzzyCompare(ATP.Settings.BagItems, v.Name) and not FuzzyCompare(ATP.Settings.MailItems, v.Name) and (v.SellPrice * v.StackCount < ATP.Settings.PriceLimit or FuzzyCompare(ATP.Settings.DestroyItems, v.Name)) then 
            table.insert(self.DestroyItems, v) 
        end 
    end 
end

function Bag:Destroy() 
    if GetTime() - self.DestroyTimer > self.DestroyDelay then 
        if self.Update and #self.DestroyItems == 0 and ATP.Settings.EnableDestroy then 
            self:GetDestroyItems() 
            self.Update = false 
        end 
        if #self.DestroyItems > 0 then 
            local item = table.remove(self.DestroyItems) 
            if self:ItemExist(item) then 
                PickupContainerItem(item.BagID, item.Slot) 
                DeleteCursorItem() 
                print("ffffff", "销毁 %s - %s", item.Name, GetCoinTextureString(item.SellPrice * item.Count)) 
                Bag.DestroyTimer = GetTime() 
            end 
        end 
    end 
end

function Bag:GeForceDestroyItems(count) local tmp = {} if #self.DestroyItems == 0 then for _, v in pairs(self.Items) do if (v.Rarity == 0 or v.Rarity == 1) and not v.NoValue and not IsSoulBound(v.BagID, v.Slot) and not FuzzyCompare(ATP.Settings.BagItems, v.Name) and not FuzzyCompare(ATP.Settings.MailItems, v.Name) then table.insert(tmp, v) end end if #tmp > 0 then table.sort(tmp, function(a, b) return a.SellPrice * a.Count < b.SellPrice * b.Count end) if count > #tmp then count = #tmp end for i = 1, count do table.insert(self.DestroyItems, tmp[i]) end return true end else return true end end

function Bag:ItemExist(item) for _, v in pairs(Bag.Items) do if type(item) == "number" then if v.ItemID == item then return true end elseif type(item) == "string" then if v.Name == item then return true end elseif v == item then return true end end return false end

function Bag:Destroying() return #self.DestroyItems ~= 0 end

local function ItemCooldown(item) local itemId if type(item) == "number" then itemId = item elseif type(item) == "string" then local _, link = GetItemInfo(item) if link then itemId = string.match(link, "Hitem:(%d+)") end end if itemId then local Start, Duration, Enable = GetItemCooldown(itemId) local CD = Start + Duration - DMW.Time return CD > 0 and CD or 0 else return 999 end end

local function Assets() local total = 0 for _, k in pairs(Bag.Items) do if not k.NoValue then total = total + k.SellPrice end end return total + GetMoney() end

local function LootBind() if StaticPopup1 and StaticPopup1:IsVisible() and (StaticPopup1.which == "LOOT_BIND") and StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then StaticPopup1Button1:Click() end end

local function NeedRepair(percent) local CurrentDbt, MaxDbt for k, _ in pairs(Player.Equipment) do CurrentDbt, MaxDbt = GetInventoryItemDurability(k) if CurrentDbt and MaxDbt then if CurrentDbt / MaxDbt * 100 <= percent then return true end end end end

local function GetHearthstoneCD() local Start, Duration, _ = GetItemCooldown(6948) local CD = Start + Duration - DMW.Time CD = CD > 0 and CD or 0 return CD end

InstanceTimer = (function() 
    local out = {} 
    local overSeconds = 0 
    local recordTime = 0 
    local currentInstanceDeadCount = 0 
    local path = GetWoWDirectory() .. "/Interface/AddOns/" .. AddonName .. "/aaa222.lua" 
    local frame = CreateFrame("Frame", nil, UIParent); 
    local frameLine = {} frame:SetSize(300, 144); 
    
    frame:SetBackdrop({ bgFile = "Interface/ChatFrame/ChatFrameBackground", edgeFile = "Interface/ChatFrame/ChatFrameBackground", tile = true, edgeSize = 1, tileSize = 5, }); 
    frame:SetPoint("CENTER"); 
    frame:Show(); 
    frame:SetMovable(true); 
    frame:EnableMouse(true); 
    frame:SetBackdropColor(0.0, 0.0, 0.0, 0.5); 
    frame:SetBackdropBorderColor(0.0, 0.0, 0.0, 0.5); 
    
    frame:SetScript("OnMouseDown", function(self, button) 
        if button == "LeftButton" then 
            self:StartMoving(); end end); 
            frame:SetScript("OnMouseUp", function(self, button) 
                self:StopMovingOrSizing(); 
            end); 
            
            local frameInit = function() 
                local left, line left = frame:CreateFontString(nil, "OVERLAY"); left:SetFont(GameFontNormal:GetFont(), 48); 
                left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0); 
                left:Show(); 
                left:SetText("|cff00ff00在线" .. "|r: "); 
                line = frame:CreateFontString(nil, "OVERLAY"); 
                line:SetFont(GameFontNormal:GetFont(), 48); 
                line:SetPoint("LEFT", left, "RIGHT", 0, 0); 
                line:Show(); 
                line:SetText("|cffff0000 00:00:00|r"); 
                frameLine[1] = line 
                
                left = frame:CreateFontString(nil, "OVERLAY"); 
                left:SetFont(GameFontNormal:GetFont(), 48); 
                left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -48); 
                left:Show(); 
                left:SetText("|cff00ff00重置" .. "\124r: "); 
                line = frame:CreateFontString(nil, "OVERLAY"); 
                line:SetFont(GameFontNormal:GetFont(), 48); 
                line:SetPoint("LEFT", left, "RIGHT", 0, 0); 
                line:Show(); 
                line:SetText("|cffff0000 0|r"); 
                frameLine[2] = line 
                left = frame:CreateFontString(nil, "OVERLAY"); 
                left:SetFont(GameFontNormal:GetFont(), 48); 
                left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -96); 
                left:Show(); 
                left:SetText("|cff00ff00死亡" .. "\124r: "); 
                line = frame:CreateFontString(nil, "OVERLAY"); 
                line:SetFont(GameFontNormal:GetFont(), 48); 
                line:SetPoint("LEFT", left, "RIGHT", 0, 0); 
                line:Show(); 
                line:SetText("|cffff0000 0|r"); 
                frameLine[3] = line
end 

out.UpdateFrame = function(played, resetCount, deathCount) 
    local t = string.format("%.2d:%.2d:%.2d", played / (60 * 60), played / 60 % 60, played % 60) 
    
    frameLine[1]:SetText(string.format("|cffff0000 %s|r", t)); 
    frameLine[2]:SetText(string.format("|cffff0000 %d|r", resetCount)); 
    frameLine[3]:SetText(string.format("|cffff0000 %d|r", deathCount)); 
end 

local formatStr_1 = "\n\t[\"%s\"] = {\n\t\tTimer = {\n\t\t\t[1] = %d, \-\-%s\n\t\t\t[2] = %d, \-\-%s\n\t\t\t[3] = %d, \-\-%s\n\t\t\t[4] = %d, \-\-%s\n\t\t\t[5] = %d, \-\-%s\n\t\t}," 
local formatStr_2 = "\t\t[%d] = {\n\t\t\tPlayed = %d,\n\t\t\tResetCount = %d,\n\t\t\tDeathCount = %d\n\t\t}," 

local function TimeStr(timestamp) 
    return date("%Y-%m-%d %H:%M:%S", timestamp) 
end

    local function Format() 
        local itemStr 
        local str = "aaa222 = {" for k, v in pairs(aaa222) do for n, m in pairs(v) do 
            if n == "Timer" then 
                itemStr = formatStr_1 
                itemStr = string.format(itemStr, k, m[1], TimeStr(m[1]), m[2], TimeStr(m[2]), m[3], TimeStr(m[3]), m[4], TimeStr(m[4]), m[5], TimeStr(m[5])) str = str .. itemStr .. "\n" 
            elseif 
            type(n) == "number" and #tostring(n) == 10 then 
                itemStr = formatStr_2 itemStr = string.format(itemStr, n, m.Played, m.ResetCount, m.DeathCount) 
                str = str .. itemStr .. "\n" 
            end 
        end 
        str = str .. "\t},\n" 
    end 
    str = str .. "}" 
    return str
 end

    out.LoadTimer = function() 
        local files = GetDirectoryFiles(path); 
        if files[1] ~= nil then 
            RunScript(ReadFile(path)) 
        end 
        local t = date("*t", time()) 
        local today = time({ day = t.day, month = t.month, year = t.year, hour = 0, minute = 0, second = 0 }) 
        
        if not aaa222 then 
            aaa222 = {} 
        end 
        
        if aaa222[Player.GUID] then 
            if not aaa222[Player.GUID].Timer then 
                local tmp = aaa222[Player.GUID] 
                aaa222[Player.GUID] = {} 
                aaa222[Player.GUID].Timer = tmp 
                aaa222[Player.GUID][today] = { Played = 0, ResetCount = 0 } 
            end 
        else 
            aaa222[Player.GUID] = { Timer = { [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, }, [today] = { Played = 0, ResetCount = 0 } } 
        end 
        
        if not aaa222[Player.GUID][today] then 
            aaa222[Player.GUID][today] = { Played = 0, ResetCount = 0, DeathCount = 0 } 
        end 
        if aaa222[Player.GUID].Timer[1] ~= 0 then 
            print( "最近重置记录时间 - " .. date("%Y-%m-%d %H:%M:%S", aaa222[Player.GUID].Timer[1])) 
        end 
        frameInit() 
    end 
    out.UpdatePlayed = function(save) 
        save = save or false 
        local t = date("*t", time()) 
        local today = time({ day = t.day, month = t.month, year = t.year, hour = 0, minute = 0, second = 0 }) 
        
        if not aaa222[Player.GUID][today] then 
            aaa222[Player.GUID][today] = { Played = 0, ResetCount = 0, DeathCount = 0 } 
        end 
        
        aaa222[Player.GUID][today].Played = aaa222[Player.GUID][today].Played + 1 
        
        out.UpdateFrame(aaa222[Player.GUID][today].Played, aaa222[Player.GUID][today].ResetCount, aaa222[Player.GUID][today].DeathCount) 
        
        if save or aaa222[Player.GUID][today].Played % 10 == 0 then 
            local str = Format() 
            WriteFile(path, str) 
        end 
    end 
    
    out.PlayerDead = function() 
        currentInstanceDeadCount = currentInstanceDeadCount + 1 
        print( "本次副本已经死亡:%d", currentInstanceDeadCount) 
        
        if currentInstanceDeadCount >= ATP.Settings.DeathCount then 
            ATP_NEED_RESET = true print( "触发副本重置条件") 
        end 
        
        local t = date("*t", time()) 
        local today = time({ day = t.day, month = t.month, year = t.year, hour = 0, minute = 0, second = 0 }) 
        
        if aaa222[Player.GUID][today].DeathCount then 
            aaa222[Player.GUID][today].DeathCount = aaa222[Player.GUID][today].DeathCount + 1 
        else 
            aaa222[Player.GUID][today].DeathCount = 1 
        end 
    end 
    
    out.SaveTimer = function() 
        currentInstanceDeadCount = 0 
        local t = date("*t", time()) 
        local today = time({ day = t.day, month = t.month, year = t.year, hour = 0, minute = 0, second = 0 }) 
        
        table.insert(aaa222[Player.GUID].Timer, 1, time()) 
        
        if not aaa222[Player.GUID][today] then 
            aaa222[Player.GUID][today] = { Played = 0, ResetCount = 0, DeathCount = 0 } 
        end 
        aaa222[Player.GUID][today].ResetCount = aaa222[Player.GUID][today].ResetCount + 1 
        if #aaa222[Player.GUID].Timer == 6 then 
            aaa222[Player.GUID].Timer[6] = nil 
        end 
        local str = Format() 
        WriteFile(path, str) 
        print( "本次重置记录时间 - " .. date("%Y-%m-%d %H:%M:%S", aaa222[Player.GUID].Timer[1])) 
        print( "今日游戏时间:%0.2f分 重置次数:%d", aaa222[Player.GUID][today].Played / 60, aaa222[Player.GUID][today].ResetCount) 
    end 
    
    out.Compare = function() 
        local lastTime = aaa222[Player.GUID].Timer[1] 
        local currentTime = time() 
        
        if currentTime - lastTime > 15 * 60 then 
            return 0 
        else 
            return 15 * 60 - currentTime + lastTime 
        end 
    end 
    
    out.Timeout = function(index) 
        if aaa222[Player.GUID].Timer[index] ~= 0 then 
            local timeout = 60 * 60 - time() + aaa222[Player.GUID].Timer[index] 
            if timeout < 0 then 
                timeout = 0 
            end 
            return timeout 
        else 
            return 0 
        end 
    end 
    out.CanEnter = function() 
        if overSeconds > 0 and recordTime > 0 then 
            if time() - recordTime > overSeconds then 
                recordTime = 0 overSeconds = 0 
                return true 
            else 
                return false 
            end 
        else 
            recordTime = 0 overSeconds = 0 
            return true 
        end 
    end 
    return out
end)() 

local function ChangeAccount(account, password, index, serverName) 
    RunMacroText(string.format(".login %s %s %s %s", password, account, index, serverName)) 
    RunMacroText(".relog 1") 
    RunMacroText(".dc") 
end

local function Swing() 
    local i = 1 
    local cur = GetTime() 
    while UnitsSwingTime[i] do 
        local time = UnitsSwingTime[i] 
        if cur > time + 1 then 
            table.remove(UnitsSwingTime, i) 
        else 
            i = i + 1 
        end 
    end 
    return #UnitsSwingTime 
end

local function GetUnits(x, y, z, radius, fun) 
    local nx, ny = false, false 
    local full_circle = math.rad(360) 
    local small_circle_step = math.rad(90) 
    local area = {} 
    local tmp = {} 
    for v = 0, full_circle, small_circle_step do 
        nx, ny = (x + math.cos(v) * radius), (y + math.sin(v) * radius) 
        table.insert(area, { x = nx, y = ny, z = z }) 
    end 
    AREA = area 
    for _, v in pairs(DMW.Units) do 
        if ATP.IsInRegion(v.PosX, v.PosY, area) then 
            if fun and type(fun) == "function" then 
                if fun(v) then 
                    table.insert(tmp, v) 
                end 
            else 
                table.insert(tmp, v) 
            end 
        end 
    end 
    if #tmp > 0 then 
        table.sort(tmp, function(a, b) 
            if a.ReachDistance < b.ReachDistance then 
                return true 
            end 
        end) 
    end 
    return #tmp, tmp 
end

local SearchTarget = function(x, y, z, radius, distance, isElite, name) 
    local count, units = GetUnits(x, y, z, radius, function(unit) 
        if not unit.Friend and not UnitAffectingCombat(unit.Pointer) and unit.ReachDistance <= distance and (not isElite or unit.Classification == "elite") and (not name or unit.Name == name) then 
            return true 
        end 
    end) 
    if count > 0 then 
        TargetUnit(units[1].Pointer) 
        Target = units[1] 
        return units[1] 
    end 
end 
GetUnit = function(x, y, z, radius, fun) 
    local count, units = GetUnits(x, y, z, radius, fun) 
    if count > 0 then 
        TargetUnit(units[1].Pointer) 
        Target = units[1] 
        return units[1] 
    end 
end 

local function SpellCastSuccess(spellName, destination) 
    if ATP_SPELL_CAST_SUCCESS.SpellName == spellName and ATP_SPELL_CAST_SUCCESS.Destination == destination then 
        return true 
    end 
    return false 
end

local function SendPartyMessage(message) 
    if message and message ~= "" and UnitPlayerOrPetInParty("player") then 
        SendChatMessage(message, 'PARTY') 
        Delay(1000) 
    end 
end

local layerFrame = CreateFrame("Frame", nil, UIParent) 
layerFrame:SetFrameStrata("BACKGROUND") 
local WindowsHeight, WindowsWidth = 0, 0 
local function Layer(show) 
    if show then 
        if layerFrame.texture:GetTexture() ~= "Color-0a875ff-CSimpleTexture" then 
            layerFrame.texture:SetColorTexture(0, 0.66, 0.46) 
            layerFrame:SetPoint("CENTER", 0, 0) 
        end 
        if not layerFrame:IsShown() then 
            layerFrame:Show() 
        end 
    else if layerFrame:IsShown() then 
        layerFrame:Hide() 
    end 
end 
end

local HUD = {} 
HUD.Frame = CreateFrame("BUTTON", "MAD", UIParent) 
local HUDFrame = HUD.Frame 
local HUDPosition = { point = "TOPLEFT", relativePoint = "TOPLEFT", xOfs = 300, yOfs = -125 } 
local TargetFrames = {} 
local MageProtect = (function() 
    local max, min = math.max, math.min 
    local MP = {} 
    MP.active = 0 
    MP.spellSchool = {} 
    MP.currentAbsorb = {} 
    MP.maxAbsorb = {} 
    MP.totalAbsorb = 0 
    MP.schoolAbsorb = { 0, 0, 0, 0, 0, 0, 0, 0, 0 } 
    
    local playerGUID = UnitGUID("player") 
    local pFrame = CreateFrame("FRAME") 
    pFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") 
    pFrame:SetScript("OnEvent", function(self, event) 
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then 
            MP.Handler(CombatLogGetCurrentEventInfo()) 
        end 
    end) 
    
    pFrame:SetScript("OnUpdate", function() 
        ATP_ICE_BARRIER_AMOUNT = MP.currentAbsorb["寒冰护体"] or 0 
        LibDraw.SetColorRaw(0, 1, 0) 
        LibDraw.Text(string.format("冰/法:%d/%d", MP.currentAbsorb["寒冰护体"], MP.currentAbsorb["法力护盾"]), "GameFontNormalSmall", Player.PosX, Player.PosY, Player.PosZ + 3) 
    end) 
    
    MP.Handler = function(...) 
        local event, spellName, spellId, auraName, value 
        local casterGUID = select(8, ...) 
        if playerGUID == casterGUID then 
            event = select(2, ...) 
            if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then 
                spellName = select(13, ...) 
                MP.ApplyAura(spellName) 
            elseif 
            event == "SPELL_AURA_REMOVED" then 
                spellName = select(13, ...) 
                MP.RemoveAura(spellName) 
            elseif event == "SPELL_ABSORBED" then 
                if select(20, ...) then 
                    spellName = select(20, ...) 
                    value = select(22, ...) or 0 
                else 
                    spellName = select(17, ...) 
                    value = select(19, ...) or 0 
                end 
                
                MP.ApplyDamage(spellName, value) 
            end 
        
        elseif not casterGUID then 
            MP.ResetValues() 
        end 
    end 
    
    function MP.ApplyAura(spellName) 
        local school = MP.spellSchool[spellName] 
        if 0 ~= school then 
            local spellId = MP.GetBuffId(spellName) 
            local absorbInfo = MP.absorbDb[spellId] 
            if absorbInfo then 
                local value = MP.CalculateAbsorbValue(spellName, spellId, absorbInfo) if nil == school then 
                    school = absorbInfo[MP.absorbDbKeys.school] MP.spellSchool[spellName] = school 
                end 
                if MP.maxAbsorb[spellName] then 
                    MP.currentAbsorb[spellName] = value 
                else 
                    MP.active = MP.active + 1 
                    local prevValue = MP.currentAbsorb[spellName] 
                    MP.currentAbsorb[spellName] = value + (prevValue or 0) 
                end 
                MP.maxAbsorb[spellName] = value 
            end 
        end 
    end

    function MP.RemoveAura(spellName) if MP.currentAbsorb[spellName] then MP.currentAbsorb[spellName] = nil MP.active = MP.active - 1 if MP.active < 1 then MP.active = 0 wipe(MP.maxAbsorb) end end end

    function MP.ApplyDamage(spellName, value) local newValue = (MP.currentAbsorb[spellName] or 0) - value if MP.maxAbsorb[spellName] then MP.currentAbsorb[spellName] = max(0, newValue) else MP.currentAbsorb[spellName] = newValue end end

    function MP.CalculateAbsorbValue(spellName, spellId, absorbInfo) 
        local value = 0 
        local keys = MP.absorbDbKeys 
        local bonusHealing = GetSpellBonusHealing() 
        local level = UnitLevel("player") 
        local base = absorbInfo[keys.basePoints] 
        local perLevel = absorbInfo[keys.pointsPerLevel] 
        local baseLevel = absorbInfo[keys.baseLevel] 
        local maxLevel = absorbInfo[keys.maxLevel] 
        local spellLevel = absorbInfo[keys.spellLevel] 
        local bonusMult = absorbInfo[keys.healingMultiplier] 
        local baseMultFn = MP.talentMultiplier[spellId] 
        local levelPenalty = min(1, 1 - (20 - spellLevel) * .0375) 
        local levels = max(0, min(level, maxLevel) - baseLevel) 
        local baseMult = baseMultFn and baseMultFn() or 1 
        value = (baseMult * (base + levels * perLevel) + bonusHealing * bonusMult * levelPenalty) 
        return value 
    end

    function MP.GetBuffId(spellName) local auraName, spellId for i = 1, 255 do auraName, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i) if auraName == spellName then break elseif not auraName then spellId = nil break end end return spellId end

    MP.talentMultiplier = { [17] = improvedPowerWordShieldMultiplier, [592] = improvedPowerWordShieldMultiplier, [600] = improvedPowerWordShieldMultiplier, [3747] = improvedPowerWordShieldMultiplier, [6065] = improvedPowerWordShieldMultiplier, [6066] = improvedPowerWordShieldMultiplier, [10898] = improvedPowerWordShieldMultiplier, [10899] = improvedPowerWordShieldMultiplier, [10900] = improvedPowerWordShieldMultiplier, [10901] = improvedPowerWordShieldMultiplier, } MP.absorbDbKeys = { ["school"] = 1, ["basePoints"] = 2, ["pointsPerLevel"] = 3, ["baseLevel"] = 4, ["maxLevel"] = 5, ["spellLevel"] = 6, ["healingMultiplier"] = 7, } MP.absorbDb = { [17740] = { 1, 119, 6, 20, 0, 20, 0 }, [17741] = { 1, 119, 6, 20, 0, 20, 0 }, [1463] = { 1, 119, 0, 20, 0, 20, 0 }, [8494] = { 1, 209, 0, 28, 0, 28, 0 }, [8495] = { 1, 299, 0, 36, 0, 36, 0 }, [10191] = { 1, 389, 0, 44, 0, 44, 0 }, [10192] = { 1, 479, 0, 52, 0, 52, 0 }, [10193] = { 1, 569, 0, 60, 0, 60, 0 }, [15041] = { 4, 119, 0, 20, 0, 20, 0 }, [543] = { 4, 164, 0, 20, 0, 20, 0 }, [8457] = { 4, 289, 0, 30, 0, 30, 0 }, [8458] = { 4, 469, 0, 40, 0, 40, 0 }, [10223] = { 4, 674, 0, 50, 0, 50, 0 }, [10225] = { 4, 919, 0, 60, 0, 60, 0 }, [15044] = { 16, 119, 0, 20, 0, 20, 0 }, [6143] = { 16, 164, 0, 22, 0, 22, 0 }, [8461] = { 16, 289, 0, 32, 0, 32, 0 }, [8462] = { 16, 469, 0, 42, 0, 42, 0 }, [10177] = { 16, 674, 0, 52, 0, 52, 0 }, [28609] = { 16, 919, 0, 60, 0, 60, 0 }, [11426] = { 127, 437, 2.8, 40, 46, 40, 0.1 }, [13031] = { 127, 548, 3.2, 46, 52, 46, 0.1 }, [13032] = { 127, 677, 3.6, 52, 58, 52, 0.1 }, [13033] = { 127, 817, 4, 58, 64, 58, 0.1 }, [26470] = { 127, 0, 0, 0, 0, 1, 0 }, }
end)() local Areas = {
    [1] = { { x = 743.64617919922, y = -475.48178100586, z = -39.741851806641, node = 0 }, { x = 749.42791748047, y = -473.01022338867, z = -38.296508789063, node = 1 }, { x = 740.55249023438, y = -463.87127685547, z = -38.511489868164, node = 2 }, },
    [2] = { { x = 716.49554443359, y = -509.13659667969, z = -36.414726257324, node = 0 }, { x = 725.09320068359, y = -501.02935791016, z = -37.21851348877, node = 1 }, { x = 719.25671386719, y = -490.46493530273, z = -36.989715576172, node = 2 }, { x = 706.71520996094, y = -496.27822875977, z = -36.509696960449, node = 3 }, },
    [3] = {
        { x = 754.79974365234, y = -495.67858886719, z = -53.1318359375, node = 0 }, { x = 769.80035400391, y = -499.37979125977, z = -52.934989929199, node = 1 }, { x = 779.30822753906, y = -516.81274414063, z = -52.631767272949, node = 2 }, { x = 780.79626464844, y = -495.77127075195, z = -53.034996032715, node = 3 }, { x = 773.89801025391, y = -490.98797607422, z = -52.621162414551, node = 4 }, { x = 765.02844238281, y = -481.23187255859, z = -53.039470672607, node = 5 }, { x = 762.96240234375, y = -473.15664672852, z = -50.954277038574, node = 6 }, { x = 751.83673095703, y = -465.12551879883, z = -52.833160400391, node = 7 }, { x = 744.9345703125, y = -457.98608398438, z = -52.593269348145, node = 8 }, { x = 739.92547607422, y = -450.17587280273, z = -52.309577941895, node = 9 }, { x = 726.69958496094, y = -451.9049987793, z = -52.402008056641, node = 10 }, { x = 731.33209228516, y = -466.49179077148, z = -52.804313659668, node = 11 }, { x = 741.22430419922, y = -475.50631713867, z = -52.726486206055, node = 12 }, { x = 747.66497802734, y = -478.84896850586, z = -52.731861114502, node = 13 }, { x = 752.89007568359, y = -486.74865722656, z = -52.740203857422, node = 14 }, { x = 753.54791259766, y = -493.39880371094, z = -53.131996154785, node = 15 },
    },
    [4] = {
        { x = 786.02490234375, y = -525.07702636719, z = -48.457328796387, node = 0 }, { x = 782.88739013672, y = -534.05712890625, z = -46.80778503418, node = 1 }, { x = 789.87255859375, y = -539.79016113281, z = -46.421211242676, node = 2 }, { x = 805.42590332031, y = -536.51666259766, z = -45.462898254395, node = 3 }, { x = 816.24176025391, y = -529.75982666016, z = -40.91283416748, node = 4 }, { x = 820.95025634766, y = -517.0205078125, z = -40.521575927734, node = 5 }, { x = 810.09375, y = -488.19772338867, z = -38.510887145996, node = 6 }, { x = 786.84039306641, y = -486.60073852539, z = -39.247932434082, node = 7 }, { x = 782.85076904297, y = -493.02502441406, z = -40.711944580078, node = 8 }, { x = 795.70843505859, y = -498.46664428711, z = -41.275108337402, node = 9 }, { x = 801.17700195313, y = -508.05999755859, z = -41.565872192383, node = 10 }, { x = 796.67132568359, y = -520.73034667969, z = -44.102920532227, node = 11 }, { x = 789.54742431641, y = -524.45202636719, z = -47.990562438965, node = 12 },
    },
    [5] = {
        { x = 754.79974365234, y = -495.67858886719, z = -53.1318359375, node = 0 }, { x = 769.80035400391, y = -499.37979125977, z = -52.934989929199, node = 1 }, { x = 779.30822753906, y = -516.81274414063, z = -52.631767272949, node = 2 }, { x = 782.40863037109, y = -523.82244873047, z = -49.958038330078, node = 3 }, { x = 792.66180419922, y = -523.49603271484, z = -45.898559570313, node = 4 }, { x = 802.47009277344, y = -515.88970947266, z = -41.739650726318, node = 5 }, { x = 801.95111083984, y = -507.28723144531, z = -40.929466247559, node = 6 }, { x = 796.05541992188, y = -497.73654174805, z = -39.960369110107, node = 7 }, { x = 808.36706542969, y = -486.45169067383, z = -39.350242614746, node = 8 }, { x = 817.88354492188, y = -507.11087036133, z = -39.883655548096, node = 9 }, { x = 813.80169677734, y = -531.97180175781, z = -41.44421005249, node = 10 }, { x = 800.55426025391, y = -538.78686523438, z = -45.885208129883, node = 11 }, { x = 786.19274902344, y = -536.67993164063, z = -46.41674041748, node = 12 }, { x = 765.40081787109, y = -527.73779296875, z = -52.930362701416, node = 13 }, { x = 753.20001220703, y = -531.26086425781, z = -52.843521118164, node = 14 }, { x = 749.21520996094, y = -516.10302734375, z = -52.702087402344, node = 15 }, { x = 757.39514160156, y = -502.78381347656, z = -53.062366485596, node = 16 },
    },
    [6] = { { x = 764.92547607422, y = -575.84008789063, z = -33.047348022461, node = 0 }, { x = 783.53491210938, y = -544.64379882813, z = -32.562404632568, node = 1 }, { x = 809.86737060547, y = -533.97857666016, z = -43.587265014648, node = 2 }, { x = 817.20513916016, y = -497.92315673828, z = -39.22794342041, node = 3 }, { x = 787.55102539063, y = -485.85946655273, z = -39.489471435547, node = 4 }, { x = 778.49670410156, y = -462.0598449707, z = -41.161067962646, node = 5 }, { x = 756.23950195313, y = -457.08221435547, z = -39.62268447876, node = 6 }, { x = 728.14721679688, y = -453.64270019531, z = -52.581871032715, node = 7 }, { x = 725.35083007813, y = -467.28598022461, z = -40.490425109863, node = 8 }, { x = 715.7021484375, y = -490.84790039063, z = -35.942741394043, node = 9 }, { x = 719.80853271484, y = -509.98788452148, z = -40.906600952148, node = 10 }, { x = 730.08227539063, y = -543.89007568359, z = -33.318176269531, node = 11 }, },
    [7] = { { x = 844.99786376953, y = -380.47146606445, z = -61.185607910156, node = 0 }, { x = 864.73876953125, y = -375.86337280273, z = -62.880573272705, node = 1 }, { x = 866.80639648438, y = -385.04342651367, z = -62.880569458008, node = 2 }, { x = 847.60913085938, y = -390.99844360352, z = -61.93431854248, node = 3 }, },
    [8] = { { x = 778.70135498047, y = -366.30520629883, z = -60.771125793457, node = 0 }, { x = 761.25286865234, y = -352.33850097656, z = -61.638202667236, node = 1 }, { x = 769.21435546875, y = -337.0964050293, z = -61.655101776123, node = 2 }, { x = 786.69128417969, y = -357.46502685547, z = -61.386245727539, node = 3 }, },
    [9] = { { x = 900.99584960938, y = -401.06814575195, z = -53.290809631348, node = 0 }, { x = 888.24505615234, y = -403.93994140625, z = -52.140235900879, node = 1 }, { x = 889.28173828125, y = -410.37533569336, z = -52.261611938477, node = 2 }, { x = 901.75500488281, y = -410.09585571289, z = -52.860305786133, node = 3 }, },
    [10] = { { x = 870.50665283203, y = -326.27703857422, z = -48.787132263184, node = 0 }, { x = 862.31066894531, y = -330.65835571289, z = -50.526550292969, node = 1 }, { x = 865.05340576172, y = -336.56237792969, z = -50.671924591064, node = 2 }, { x = 875.11541748047, y = -328.93130493164, z = -48.780166625977, node = 3 }, },
    [11] = { { x = 622.47857666016, y = -252.35806274414, z = -53.165664672852, node = 0 }, { x = 626.40130615234, y = -267.19500732422, z = -53.647327423096, node = 1 }, { x = 634.49346923828, y = -268.46932983398, z = -53.385936737061, node = 2 }, { x = 629.22784423828, y = -250.92547607422, z = -52.848602294922, node = 3 }, },
    [12] = { { x = 605.68389892578, y = -198.12298583984, z = -63.89769744873, node = 0 }, { x = 624.94525146484, y = -196.26312255859, z = -63.89769744873, node = 1 }, { x = 624.20263671875, y = -212.93765258789, z = -63.89769744873, node = 2 }, { x = 613.68835449219, y = -216.74829101563, z = -63.89769744873, node = 3 }, },
    [13] = { { x = 651.35205078125, y = -353.76712036133, z = -52.01936340332, node = 0 }, { x = 642.34185791016, y = -350.69177246094, z = -52.01936340332, node = 1 }, { x = 649.93682861328, y = -340.6091003418, z = -52.01936340332, node = 2 }, { x = 657.25311279297, y = -343.54449462891, z = -52.01936340332, node = 3 }, },
    [14] = { { x = 649.34936523438, y = -227.81301879883, z = -63.89769744873, node = 0 }, { x = 655.91088867188, y = -236.14860534668, z = -63.89769744873, node = 1 }, { x = 665.66412353516, y = -230.15240478516, z = -63.897701263428, node = 2 }, { x = 659.48205566406, y = -218.28807067871, z = -63.89769744873, node = 3 }, },
} local SWING_COUNT = 0 local PLAYER_ENTERING_WORLD = false local TOO_MANY_INSTANCES = false 

-- 参数
local PROCESS_STATE = { 
    START_SOLO = "START_SOLO", 
    SUPPLY = "SUPPLY", 
    MAIL = "MAIL", 
    GOTO_INSTANCE = "GOTO_INSTANCE", 
    TOWN_TO_INSTANCE = "TOWN_TO_INSTANCE", 
    ENTER_INSTANCE = "ENTER_INSTANCE", 
    EXIT_INSTANCE = "EXIT_INSTANCE", 
    RESET_INSTANCE = "RESET_INSTANCE", 
    RESURRECTION = "RESURRECTION", 
    TIMEOUT = "TIMEOUT" 
} 

local CURRENT_PROCESS = PROCESS_STATE.EXIT_INSTANCE 
local LAST_PROCESS 
local PROCESS_ROUTER = {} 



local function ChangeProcess(Process) 
    print("测试。。1111")
    print( string.format("%s %s", CURRENT_PROCESS, Process)) 
    LAST_PROCESS = CURRENT_PROCESS 
    CURRENT_PROCESS = Process 
    PROCESS_ROUTER[CURRENT_PROCESS].Reset() 
end



local UpdateBlizzardTime = function(elapsed) 
    local info = { ChannelInfo("player") } 
    if info and info[1] == "暴风雪" then 
        if ATP_BLIZZARD_START == 0 then 
            ATP_BLIZZARD_CONTINUED = 0 
        else 
            ATP_BLIZZARD_CONTINUED = ATP_BLIZZARD_CONTINUED + elapsed 
        end 
        ATP_SPELL_BLIZZARD_COUNT = ATP_SPELL_BLIZZARD_COUNT + 1 
        if info[5] > ATP_TIME * 1000 then 
            ATP_BLIZZARD_START = info[4] / 1000 ATP_BLIZZARD_TIME = ATP_TIME * 1000 - info[4] 
        end 
        if ATP_BLIZZARD_TIME < 0 then 
            ATP_BLIZZARD_TIME = 0 
        end 
    else if 
        ATP_BLIZZARD_START ~= 0 then 
            ATP_BLIZZARD_CONTINUED = ATP_BLIZZARD_CONTINUED + elapsed 
        end 
        ATP_BLIZZARD_START = 0 ATP_BLIZZARD_TIME = 0 
    end 
end 



local function StartSolo() 
    print("测试11111111111111111");
    local out = {} 
    local SOLO_STATE = { INIT = "INIT", PREPARE = "PREPARE", GET_READY = "GET_READY", LURE = "LURE", LURE_1 = "LURE_1", LURE_2 = "LURE_2", LURE_EX = "LURE_EX", GATHER_1 = "GATHER_1", COMBAT = "COMBAT", LOOT = "LOOT" } 
    
    local SOLO_ROUTE = {} 
    local CURRENT_STATE = SOLO_STATE.PREPARE 
    local LURE_STOP_MOVE = false 
    local PATROL_TARGET = nil 
    local BLIZZARD_CASTING_TIME = 0 
    local OPEN_PACK_TIMER = 10 
    
    local NearPosition = function(position, distance, isElite) 
        local count = 0 
        local Table = {} 
        
        for _, v in pairs(DMW.Units) do 
            if v.Target and position:Distance2D(v) < distance and (not isElite or v.Classification == "elite") then 
                count = count + 1 
                
                table.insert(Table, v) 
            end 
        end 
        return count, Table 
    end 
    
    local NearPlayer = function(distance, all) 
        all = all or false 
        local Count = 0 
        local Table = {} 
        
        for _, v in pairs(DMW.Units) do 
            if not v.Dead and not v.Player and UnitAffectingCombat(v.Pointer) and (all or v.Classification == "elite") and v.ReachDistance < distance then 
                Count = Count + 1 table.insert(Table, v) 
            end 
        end 
        return Count, Table 
    end 
    
    local ImpCount = function(distance) 
        local Count = 0 for _, v in pairs(DMW.Units) do 
            if not v.Dead and v.Name == "毒劣魔" and v.ReachDistance < distance and UnitAffectingCombat(v.Pointer) then 
                Count = Count + 1 
            end 
        end 
        return Count 
    end 
    local ImpAreaCount = function(x, y, z, radius) 
        local nx, ny = false, false 
        local full_circle = math.rad(360) 
        local small_circle_step = math.rad(90) 
        local area = {} 
        
        for v = 0, full_circle, small_circle_step do 
            nx, ny = (x + math.cos(v) * radius), (y + math.sin(v) * radius) table.insert(area, { x = nx, y = ny, z = z }) 
        end 
        
        local count = 0 
        
        for _, v in pairs(DMW.Units) do 
            if ATP.IsInRegion(v.PosX, v.PosY, area) and not v.Dead and v.Name == "毒劣魔" and UnitAffectingCombat(v.Pointer) then 
                count = count + 1 
            end 
        end 
        return count 
    end 
    local BestRank = function(SpellName) 
        local rank = 1 
        local highestRank = Spell[SpellName]:HighestRank() 
        if not Player:AuraByID(12536) and Player.PowerPct < 85 then 
            for i = highestRank, 1, -1 do 
                if Player.Power > Spell[SpellName]:Cost(i) then 
                    rank = i 
                    break 
                end 
            end 
        else 
            rank = highestRank 
        end 
        return rank 
    end 
    
    CastBlizzard = function(position, rank) 
        if not Player.Moving and Player:GCDRemain() == 0 then 
            local MouseLooking = false 
            local _rank = BestRank("Blizzard") 
            
            if rank then 
                rank = math.min(_rank, rank) else 
                    rank = _rank 
                end 
                
                APT_LAST_BLIZZARD_POSITION = position 
                if Spell.Blizzard:IsReady(rank) then 
                    if IsMouselooking() then 
                        MouseLooking = true 
                        MouselookStop() 
                    end 
                    
                    CastSpellByID(Spell.Blizzard.Ranks[rank]) 
                    ClickPosition(APT_LAST_BLIZZARD_POSITION.X, APT_LAST_BLIZZARD_POSITION.Y, APT_LAST_BLIZZARD_POSITION.Z) 
                    
                    if MouseLooking then 
                        MouselookStart() 
                    end 
                    Delay(1000) 
                    return true 
                end 
            end 
        end 
        local function ChangeTask(Task) 
            print( string.format("%s %s", CURRENT_STATE, Task)) 
            CURRENT_STATE = Task 
        end

    local function GetPatrolTarget() 
        for _, v in pairs(DMW.Units) do 
            if not v.Dead and v.Distance < 100 and v.Name == "深腐践踏者" and ATP.IsInRegion(v.PosX, v.PosY, Areas[6]) then 
                return v 
            end 
        end 
    end

    local function Patrol() 
        if PATROL_TARGET then 
            if PATROL_TARGET.ReachDistance < 20 and PATROL_TARGET.Attackable and not UnitAffectingCombat(PATROL_TARGET.Pointer) and Spell.FrostNova:CD() > 0 and Spell.FireBlast:IsReady(1) then 
                local old_facing = ObjectFacing("player") 
                FaceDirection(PATROL_TARGET.Pointer, true) 
                if Spell.FireBlast:Cast(PATROL_TARGET, 1) then 
                    FaceDirection(old_facing, true) print( "释放火焰冲击") 
                end 
            end 
        end 
    end

    local function Loot(self) 
        if self.CurOffset < 1 then 
            self.Pause = false 
            if Bag:Destroying() then 
                self.Pause = true 
            else 
                for _, k in pairs(DMW.Units) do 
                    if k.Dead and k.Distance < 5 and UnitCanBeLooted(k.Pointer) then 
                        InteractUnit(k.Pointer) 
                        CloseLoot() 
                        self.Pause = true 
                    end 
                end 
                if self.Pause then 
                    if Player:GetFreeBagSlots() == 0 then 
                        if not Bag:GeForceDestroyItems(3) then 
                            print( "背包满无灰/白色物品可销毁,出本") 
                            ChangeProcess(PROCESS_STATE.EXIT_INSTANCE) 
                            return true 
                        end 
                    end 
                    Delay(2000) 
                end 
            end 
        end 
    end

    function UnitsChilledLess(remain) 
        local Count = 0 
        for _, v in pairs(DMW.Units) do 
            if v.Target and v.Classification == "elite" then 
                local EndTime = select(6, Debuff.Chilled:Query(v, true)) 
                if EndTime then 
                    if EndTime - DMW.Time < remain then 
                        Count = Count + 1 
                    end 
                else 
                    Count = Count + 1 
                end 
            end 
        end 
        return Count 
    end

    function ChilledRemain(unit) 
        local EndTime = select(6, Debuff.Chilled:Query(unit, true)) 
        if EndTime 
        then 
            return EndTime - DMW.Time 
        end 
        return 0 
    end

    local PREPARE_STEP = 0 local LOOT_TARGET = nil local FP_LOOT_TARGET = nil local POS_BLIZZARD = {
        [1] = Position(777.197327, -515.515076, -52.717289),
        [2] = Position(783.394348, -523.436462, -50.103352),
        [3] = Position(792.163696, -523.132813, -46.556576),
        [4] = Position(797.596619, -521.170654, -43.610668),
        [5] = Position(801.735474, -513.318115, -41.626545),
        [6] = Position(801.943542, -508.999268, -41.102764),
        [7] = Position(802.52648925781, -507.22470092773, -40.932758331299),
        [10] = Position(758.58190917969, -512.56585693359, -53.135047912598),
        [11] = Position(810.30145263672, -500.66204833984, -40.591041564941),
        [12] = Position(802.47393798828, -492.35879516602, -39.693054199219),
        [13] = Position(754.222961, -546.172607, -32.546616),
        [14] = Position(761.357727, -552.787842, -33.745457),
        [20] = Position(608.01959228516, -398.24160766602, -52.01936340332),
        [21] = Position(585.91137695313, -384.61721801758, -52.01936340332),
        ["6-1"] = Position(758.58190917969, -512.56585693359, -53.135047912598),
        ["6-2"] = Position(810.30145263672, -500.66204833984, -40.591041564941),
        ["6-3"] = Position(802.47393798828, -492.35879516602, -39.693054199219),
        ["14-1"] = Position(754.222961, -546.172607, -32.546616),
        ["14-2"] = Position(761.357727, -552.787842, -33.745457),
        ["59-1"] = Position(641.862244, -215.832794, -62.875187),
        ["71-1"] = Position(672.862976, -234.727829, -57.048923),
        ["78-1"] = Position(608.075, -400.153, -52.019),
        ["78-2"] = Position(587.538, -385.541, -52.019),
        ["86-1"] = Position(738.538574, -342.697540, -50.806553),
        ["87-1"] = Position(768.393127, -334.665344, -50.705585),
    } local POS_BLIZZARD_GATHER_1 = { [1] = Position(777.197327, -515.515076, -52.717289), [2] = Position(783.394348, -523.436462, -50.103352), [3] = Position(791.190490, -523.080017, -48.111625), [4] = Position(801.735474, -513.318115, -41.626545), [5] = Position(800.466125, -505.055969, -40.818390), [6] = Position(801.512146, -514.065491, -41.802635), } local POS_INSIDE_KILL_IMP = {
        { x = 801.310, y = -507.600, z = -41.439 }, { x = 801.326, y = -507.872, z = -41.441 }, { x = 801.330, y = -508.085, z = -41.449 }, { x = 801.319, y = -508.304, z = -41.469 }, { x = 801.318, y = -508.496, z = -41.480 }, { x = 801.316, y = -508.750, z = -41.495 }, { x = 801.310, y = -508.985, z = -41.512 }, { x = 801.308, y = -509.301, z = -41.531 }, { x = 801.301, y = -509.533, z = -41.548 }, { x = 801.309, y = -509.758, z = -41.554 }, { x = 801.289, y = -509.994, z = -41.582 }, { x = 801.274, y = -510.187, z = -41.603 }, { x = 801.250, y = -510.403, z = -41.633 }, { x = 801.249, y = -510.649, z = -41.647 }, { x = 801.252, y = -510.850, z = -41.656 }, { x = 801.228, y = -511.124, z = -41.689 }, { x = 801.223, y = -511.288, z = -41.702 }, { x = 801.217, y = -511.511, z = -41.718 }, { x = 801.216, y = -511.692, z = -41.728 }, { x = 801.196, y = -511.979, z = -41.759 }, { x = 801.190, y = -512.199, z = -41.775 }, { x = 801.180, y = -512.460, z = -41.797 }, { x = 801.209, y = -512.759, z = -41.811 }, { x = 801.226, y = -512.965, z = -41.824 }, { x = 801.230, y = -513.138, z = -41.839 }, { x = 801.243, y = -513.383, z = -41.858 }, { x = 801.231, y = -513.562, z = -41.881 }, { x = 801.216, y = -513.780, z = -41.909 }, { x = 801.194, y = -513.981, z = -41.939 }, { x = 801.205, y = -514.167, z = -41.953 }, { x = 801.153, y = -514.437, z = -42.003 },
    } local POS_BLIZZARD_GATHER_2 = { [1] = Position(757.147, -474.73721313477, -38.640037536621), [2] = Position(767.297, -474.88836669922, -40.602180480957), [3] = Position(780.388000, -490.928986, -40.426205), [4] = Position(795.173, -497.73602294922, -40.248474121094), [5] = Position(801.356934, -509.384888, -41.496964), [6] = Position(799.925964, -516.763245, -42.693459), } local POS_BLIZZARD_COMBAT = { [1] = Position(801.207825, -506.784637, -41.229176), [2] = Position(801.207825, -506.784637, -41.229176), [3] = Position(800.411621, -515.858398, -42.420876), } local POS_BLIZZARD_EX = {
        ["45-1"] = Position(670.149, -109.833, -56.135),
        ["50-1"] = Position(836.75469970703, -16.818630218506, -87.161979675293),
        ["59-1"] = Position(873.328, -208.448, -75.274),
        ["60-1"] = Position(814.95288085938, -242.57264709473, -60.631641387939),
        ["94-1"] = Position(608.075, -400.153, -52.019),
        ["94-2"] = Position(587.538, -385.541, -52.019),
        ["120-1"] = Position(758.58190917969, -512.56585693359, -53.135047912598),
        ["120-2"] = Position(779.213867, -516.201843, -52.695614),
        ["120-3"] = Position(802.47393798828, -492.35879516602, -39.693054199219),
        ["120-3"] = Position(810.30145263672, -500.66204833984, -40.591041564941),
        ["120-4"] = Position(802.47393798828, -492.35879516602, -39.693054199219),
        ["126-1"] = Position(753.820374, -551.112976, -32.970665),
        ["126-2"] = Position(760.454895, -551.140869, -34.223179),
        ["165-1"] = Position(641.862244, -215.832794, -62.875187),
        ["174-1"] = Position(671.965698, -224.711166, -59.559406),
        ["174-2"] = Position(669.021729, -210.713013, -60.673027),
        ["180-1"] = Position(721.701721, -333.673096, -51.580002),
    } local POS_BLIZZARD_REGATHER = { ["7-1"] = Position(753.820374, -551.112976, -32.970665), ["7-2"] = Position(760.454895, -551.140869, -34.223179), ["13-1"] = Position(834.576050, -451.043549, -56.413685), ["15-1"] = Position(856.411865, -424.107178, -52.452629), ["24-1"] = Position(780.455505, -338.391052, -50.169155), ["24-2"] = Position(767.027893, -333.640259, -50.875973), } local FP_PREPARE = FixedPath({ { x = 754.98260498047, y = -607.84973144531, z = -33.007301330566, node = 0 }, { x = 784.30657958984, y = -595.28723144531, z = -33.033130645752, node = 1 }, { x = 796.74530029297, y = -584.06420898438, z = -32.7180519104, node = 2 }, { x = 793.15283203125, y = -577.3291015625, z = -32.864406585693, node = 3 }, { x = 781.54443359375, y = -551.11090087891, z = -32.44006729126, node = 4 }, { x = 784.33911132813, y = -539.35229492188, z = -34.503322601318, node = 5 }, }, 1.5, true) 
    
    local FM_LURE = FixedNode({
        { x = 794.645, y = -531.358, z = -46.886, func = CastBuff }, 
        { x = 798.853, y = -519.546, z = -43.043, func = CastBuff }, 
        { x = 802.010, y = -514.362, z = -41.605, func = CastBuff }, 
        { x = 801.761, y = -507.132, z = -41.055, func = CastBuff }, 
        { x = 796.498, y = -497.640, z = -39.947, func = CastBuff }, 
        { x = 782.652, y = -491.672, z = -40.085,
            func = function(self) 
                if self.CurOffset < 1.5 then 
                    self.Pause = true 
                    
                    if PATROL_TARGET and not UnitAffectingCombat(PATROL_TARGET.Pointer) and ATP.IsInRegion(PATROL_TARGET.PosX, PATROL_TARGET.PosY, Areas[3]) and PATROL_TARGET.PosZ < -46 then 
                        
                        print( "等待巡逻-2") 
                        Delay(2000) 
                        return true 
                    end 
                    
                    if PATROL_TARGET and not UnitAffectingCombat(PATROL_TARGET.Pointer) and ATP.IsInRegion(PATROL_TARGET.PosX, PATROL_TARGET.PosY, Areas[5]) then 
                        if PATROL_TARGET.ReachDistance <= 35 and Spell.Frostbolt:IsReady(1) and FacingTarget(PATROL_TARGET) and Spell.Frostbolt:Cast(PATROL_TARGET, 1) then 
                            print( "释放寒冰箭术") 
                            Delay(550) 
                            
                            while Player.Casting do 
                                Delay(100) 
                            end 
                        end 
                        Delay(2000) 
                        return true 
                    end 
                    
                    if not PATROL_TARGET or UnitAffectingCombat(PATROL_TARGET.Pointer) or Player.Combat or (not ATP.IsInRegion(PATROL_TARGET.PosX, PATROL_TARGET.PosY, Areas[3]) and not ATP.IsInRegion(PATROL_TARGET.PosX, PATROL_TARGET.PosY, Areas[5])) then 
                        
                        if APT_LAST_BLIZZARD_POSITION == nil and ATP_BLIZZARD_START == 0 then 
                            CastBlizzard(POS_BLIZZARD["6-1"], 1) 
                        end 
                            
                        if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD["6-1"] and ATP_BLIZZARD_TIME > 1060 then 
                            CastBlizzard(POS_BLIZZARD["6-2"], 1) 
                        end 
                        
                        if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD["6-2"] and ATP_BLIZZARD_TIME > 1060 then 
                            CastBlizzard(POS_BLIZZARD["6-3"], 1) 
                        end 
                        
                        if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD["6-3"] and ATP_BLIZZARD_TIME > 1060 then 
                            self.Pause = false 
                        end end
            end
            end
        }, 
        { x = 766.102, y = -472.536, z = -40.957, func = Patrol }, 
        { x = 758.209, y = -471.141, z = -39.899, 
        func = function(self) 
            if self.CurOffset < 1.5 then 
                if Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
                    print( "释放冰环") 
                end 
            end 
        end }, 
        { x = 743.562, y = -472.709, z = -39.055, func = Patrol }, 
        { x = 733.957, y = -485.623, z = -41.135, func = function(self) 
            Patrol() 
            if self.CurOffset < 1.5 then 
                if Spell.Blink:IsReady() then 
                    FaceDirection(733.953, -511.494, true) 
                    if Spell.Blink:Cast(Player) then 
                        print( "释放闪现") 
                        return true 
                    end 
                end 
            end 
        end }, 
        { x = 739.193, y = -522.227, z = -39.571, r = 1, func = function(self) 
            Patrol() 
            if self.CurOffset < 1.5 and Spell.Counterspell:IsReady() and SearchTarget(717.124, -502.128, -36.591, 10, 30) then 
                if Spell.Counterspell:Cast(Target) then 
                    Debug("反制") 
                end 
            end 
        end }, 
        { x = 746.891, y = -533.922, z = -33.820, func = Patrol }, 
        { x = 754.024, y = -541.319, z = -32.348, func = Patrol }, 
        { x = 778.918, y = -535.783, z = -36.608, func = function(self) 
            if self.CurOffset < 1.5 then 
                self.Pause = true 
                if Player.Combat then 
                    if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD["6-3"] and ATP_BLIZZARD_START == 0 then 
                        CastBlizzard(POS_BLIZZARD["14-1"], 1) 
                    end 
                    
                    if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD["14-1"] and ATP_BLIZZARD_START == 0 then 
                        CastBlizzard(POS_BLIZZARD["14-2"], 1) 
                    end 
                    if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD["14-2"] and (ATP_BLIZZARD_START == 0 or NearPlayer(5) > 1) then 
                        self.Pause = false 
                    end 
                
                else ChangeProcess(PROCESS_STATE.EXIT_INSTANCE) 
                end 
            end 
        end }, 
        { x = 783.626, y = -520.195, z = -52.731, func = nil }, 
        { x = 786.078, y = -516.707, z = -52.812, func = function(self) 
            if self.CurOffset < 1.5 then 
                if Spell.Blink:IsReady() then 
                    FaceDirection(800.335, -498.072, true) 
                    if Spell.Blink:Cast(Player) then 
                        print( "释放闪现") 
                    end 
                end 
            end 
        end }, 
        { x = 800.335, y = -498.072, z = -53.614, func = CastBuff }, 
        { x = 810.796, y = -480.668, z = -54.825, func = CastBuff }, 
        { x = 820.116, y = -454.971, z = -56.304, func = CastBuff }, 
        { x = 820.353, y = -432.901, z = -55.776, func = CastBuff }, 
        { x = 810.965, y = -429.808, z = -54.250, func = CastBuff }, 
        { x = 805.994, y = -427.089, z = -53.596, func = CastBuff }, 
        { x = 802.770, y = -422.923, z = -53.525, func = CastBuff }, 
        { x = 802.409, y = -418.899, z = -53.615, func = CastBuff },
        { x = 805.013, y = -414.710, z = -54.283, func = CastBuff }, 
        { x = 817.520, y = -402.037, z = -57.734, func = CastBuff }, 
        { x = 825.427, y = -390.755, z = -59.103, r = 1, func = function(self) 
            if self.CurOffset < 1.5 then 
                self.Pause = true 
                if not Player.Moving then 
                    if SearchTarget(856.386, -386.619, -64.126, 15, 36) then 
                        FaceDirection(Target.Pointer, true) 
                        if Spell.Frostbolt:IsReady(1) and Spell.Frostbolt:Cast(Target, 1) then 
                            Debug("寒冰箭") 
                        end 
                        Delay(800) 
                        while Player.Casting do 
                            Delay(50) 
                        end 
                    end 
                    self.Pause = false 
                end 
            end 
        end }, 
        { x = 803.565, y = -389.473, z = -59.047, func = CastBuff },
        { x = 787.896, y = -379.052, z = -59.096, r = 1, func = function(self) 
            if self.CurOffset < 1.5 then 
                self.Pause = true 
                if not Player.Moving then 
                    if SearchTarget(771.665, -353.206, -61.652, 15, 36) then 
                        FaceDirection(Target.Pointer, true) 
                        
                        if Spell.Frostbolt:IsReady(1) and Spell.Frostbolt:Cast(Target, 1) then 
                            Debug("寒冰箭") 
                        end 
                        Delay(800) 
                        while Player.Casting do 
                            Delay(50) 
                        end 
                    end 
                    Delay(500) 
                    if Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
                        Debug("魔爆术") 
                    end 
                    self.Pause = false 
                end 
            end 
        end }, 
        { x = 808.757, y = -382.665, z = -59.091, func = function(self) 
            if self.CurOffset < 1.5 and Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
                Debug("魔爆术") 
            end 
        end }, 
        { x = 804.910, y = -394.939, z = -58.912, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(799.283, -423.404, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 799.283, y = -423.404, z = -53.548, func = nil }, 
        { x = 802.120, y = -428.099, z = -53.807, r = 1, func = function(self) 
            if self.CurOffset < 1.5 then 
                if Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
                    Debug("冰霜新星") 
                end 
            end 
        end }, 
        { x = 827.055, y = -438.522, z = -56.249, r = 1, func = function(self) 
            if self.CurOffset < 1.5 and SearchTarget(830.135, -446.087, -56.281, 10, 30) and Spell.ConeOfCold:IsReady() then 
                FaceDirection(Target.Pointer, true) 
                if Spell.ConeOfCold:Cast(Player, 1) then 
                    FaceDirection(844.542, -433.823, true) 
                    Debug("冰锥术") 
                end 
            end 
        end }, 
        { x = 834.130, y = -438.018, z = -55.994, r = 1, func = CastBuff }, 
        { x = 839.327, y = -435.642, z = -56.059, r = 1, func = CastBuff }, 
        { x = 873.265, y = -400.039, z = -51.747, r = 1, func = CastBuff }, 
        { x = 890.133850, y = -379.689331, z = -52.028820, r = 1, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Counterspell:IsReady() and SearchTarget(897.796, -406.071, -52.944, 10, 30) then 
                if Spell.Counterspell:Cast(Target) then 
                    Debug("反制") 
                end 
            end 
        end }, 
        { x = 874.263062, y = -333.994781, z = -50.126431, r = 1, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                Delay(500) 
                FaceDirection(819.415, -344.001, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 819.415, y = -344.001, z = -51.617, func = CastBuff }, 
        { x = 801.624695, y = -351.283447, z = -51.587639, func = CastBuff }, 
        { x = 782.624, y = -339.134, z = -50.241, func = function(self) 
            if self.CurOffset < 1.5 and Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
                Debug("魔爆术") 
            end 
        end }, 
        { x = 765.812, y = -331.620, z = -51.109, func = function(self) 
            if self.CurOffset < 1.5 and Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
                Debug("魔爆术") 
            end 
        end }, 
        { x = 743.795, y = -333.318, z = -50.641, func = function(self) 
            if self.CurOffset < 1.5 then 
                if Spell.Blink:IsReady() then 
                    FaceDirection(701.530640, -319.124603, true) 
                    if Spell.Blink:Cast(Player) then 
                        Debug("闪现") 
                    end 
                end 
            end 
        end }, 
        { x = 701.530640, y = -319.124603, z = -51.886127, func = function(self) 
            if Item.ManaCitrine:IsReady() and Item.ManaCitrine:InBag() and Item.ManaCitrine:Use() then 
                Debug("使用法力黄水晶") 
            end 
        end }, 
        { x = 687.883, y = -318.707, z = -52.019, func = CastBuff }, 
        { x = 673.812, y = -323.439, z = -52.112, func = CastBuff }, 
        { x = 661.925964, y = -324.234314, z = -52.020039, func = function(self) 
            if self.CurOffset < 1.5 and Spell.FireBlast:IsReady(1) and SearchTarget(674.105, -344.019, -51.633, 10, 20) then 
                FaceDirection(Target.Pointer) 
                if Spell.FireBlast:Cast(Target, 1) then 
                    FaceDirection(655.017, -318.181) 
                    Debug("火焰冲击") 
                end 
            end 
        end }, 
        { x = 655.017, y = -318.181, z = -52.019, func = CastBuff }, 
        { x = 647.989563, y = -310.049011, z = -52.023022, func = function(self) 
            if self.CurOffset < 1.5 and Spell.ConeOfCold:IsReady() then 
                FaceDirection(3.58838, true) 
                if Spell.ConeOfCold:Cast(Player, 1) then 
                    FaceDirection(645.705, -286.834, true) 
                    Debug("冰锥术") 
                end 
            end 
        end }, 
        { x = 645.705, y = -286.834, z = -52.519, func = CastBuff }, 
        { x = 646.015, y = -274.568, z = -52.990, func = CastBuff }, 
        { x = 650.074, y = -268.600, z = -53.110, func = CastBuff }, 
        { x = 655.606, y = -257.404, z = -53.198, func = function(self) 
            if self.CurOffset < 3 then 
                if Spell.FireBlast:IsReady(1) and SearchTarget(628.727, -261.367, -53.353, 8, 20) then 
                    FaceDirection(Target.Pointer, true) 
                    if Spell.FireBlast:Cast(Target, 1) then 
                        FaceDirection(657.829, -246.429, true) 
                        Debug("火焰冲击") 
                    end 
                end 
            end 
        end }, 
        { x = 657.829, y = -246.429, z = -64.391 }, 
        { x = 658.797913, y = -237.536987, z = -64.391083, r = 1, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(661.446, -211.615, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 661.446, y = -211.615, z = -60.952, func = CastBuff }, 
        { x = 671.849609, y = -208.588257, z = -60.936592, func = CastBuff }, 
        { x = 675.769165, y = -220.799103, z = -60.253593, r = 1, func = function(self) 
            if self.CurOffset < 1.5 then 
                self.Pause = true 
                if not Player.Moving then 
                    if NearPosition(POS_BLIZZARD["59-1"], 5, true) > 3 then 
                        if Spell.FireBlast:IsReady(1) and SearchTarget(657.331, -228.034, -64.391, 15, 20) then 
                            FaceDirection(Target.Pointer, true) 
                            if Spell.FireBlast:Cast(Target, 1) then 
                                FaceDirection(688.936, -257.890, true) 
                                Debug("火焰冲击") 
                            end 
                        end 
                        Delay(500) 
                        if Spell.Counterspell:IsReady() and SearchTarget(686.322, -196.200, -60.515, 15, 30, true) then 
                            if Spell.Counterspell:Cast(Target) then 
                                Debug("反制") 
                            end 
                        end 
                        self.Pause = false 
                    end 
                end 
            end 
        end }, 
        { x = 688.936, y = -257.890, z = -53.062, func = function(self) 
            if self.CurOffset < 1.5 and SearchTarget(692.116, -265.452, -52.898, 15, 15) and Spell.ConeOfCold:IsReady() then 
                FaceDirection(Target.Pointer, true) 
                if Spell.ConeOfCold:Cast(Player, 1) then 
                    FaceDirection(694.131, -252.028, true) 
                    Debug("冰锥术") 
                end 
            end 
        end }, 
        { x = 710.729, y = -231.757, z = -47.442, func = CastBuff }, 
        { x = 714.752686, y = -218.324432, z = -47.250694, func = function(self) 
            if self.CurOffset < 1.5 and Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
                Debug("魔爆术") 
            end 
        end }, 
        { x = 707.492615, y = -208.661697, z = -47.251263, func = function(self) 
            if self.CurOffset < 1.5 then 
                if Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
                    Debug("冰霜新星") 
                end 
            end 
        end }, 
        { x = 697.841309, y = -199.340714, z = -47.250977, desc = '闪现', func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(687.045, -177.829, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 687.045, y = -177.829, z = -48.720, func = CastBuff }, 
        { x = 675.546, y = -164.205, z = -48.790, desc = '魔爆术', func = function(self) 
            if self.CurOffset < 1.5 and Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
                Debug("魔爆术") 
            end 
        end }, 
        { x = 662.522, y = -165.818, z = -50.944, desc = '魔爆术', func = function(self) 
            if self.CurOffset < 1.5 and Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
                Debug("魔爆术") 
            end 
        end }, 
        { x = 640.122253, y = -174.106659, z = -53.607258, desc = '魔爆术', func = function(self) 
            if self.CurOffset < 1.5 and Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
                Debug("魔爆术") 
            end 
        end }, 
        { x = 637.722107, y = -182.460876, z = -53.483288, r = 1, func = function(self) 
            if self.CurOffset < 1.5 then 
                JumpOrAscendStart() 
                Delay(20) 
                AscendStop() 
            end 
        end }, 
        { x = 626.819458, y = -216.720566, z = -63.270630, r = 1, func = CastBuff }, 
        { x = 622.775330, y = -241.142532, z = -54.467468, r = 1, func = function(self) 
            if self.CurOffset < 1.5 then 
                self.Pause = true 
                if not Player.Moving then 
                    if SearchTarget(615.679, -204.636, -64.536, 10, 36) then 
                        FaceDirection(Target.Pointer, true) 
                        if Spell.Frostbolt:IsReady(1) and Spell.Frostbolt:Cast(Target, 1) then 
                            Debug("寒冰箭") 
                        end 
                        Delay(500) 
                        while Player.Casting do 
                            Delay(50) 
                        end 
                    end 
                    self.Pause = false 
                end 
            end 
        end }, 
        { x = 627.201172, y = -282.881592, z = -53.141193, r = 1, func = function(self) 
            if Spell.Blink:IsReady() then 
                FaceDirection(640.108, -317.193, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 640.108, y = -317.193, z = -52.095, func = CastBuff }, 
        { x = 641.349, y = -325.579, z = -52.034, func = CastBuff }, 
        { x = 642.182, y = -336.184, z = -52.019, func = CastBuff }, 
        { x = 637.410, y = -339.974, z = -52.019, func = CastBuff }, 
        { x = 622.362, y = -359.445, z = -52.019, func = CastBuff }, 
        { x = 613.337, y = -366.975, z = -52.018, r = 1, func = function(self) 
            if self.CurOffset < 1.5 then 
                self.Pause = true 
                if not Player.Moving then 
                    CastBlizzard(POS_BLIZZARD["78-1"], 1) 
                    Delay(1600 - ATP_BLIZZARD_TIME) 
                    CastBlizzard(POS_BLIZZARD["78-2"], 1) 
                    Delay(1200 - ATP_BLIZZARD_TIME) 
                    self.Pause = false 
                end 
            end 
        end }, 
        { x = 623.973, y = -355.896, z = -52.019, func = function(self) 
            if self.CurOffset < 1.5 and Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
                Debug("魔爆术") 
            end 
        end }, 
        { x = 644.986206, y = -358.945007, z = -52.019264, func = function(self) 
            if self.CurOffset < 1.5 then 
                if Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
                    Debug("冰霜新星") 
                end 
            end 
        end }, 
        { x = 658.221558, y = -361.874725, z = -52.019314, func = CastBuff }, 
        { x = 703.540405, y = -372.268494, z = -52.019268, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(712.498657, -351.085968, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 712.498657, y = -351.085968, z = -51.965038, func = function(self) end }, { x = 725.503662, y = -337.407562, z = -50.873936, func = CastBuff }, 
        { x = 738.538574, y = -342.697540, z = -50.806553, func = CastBuff }, 
        { x = 754.983093, y = -350.542236, z = -50.662857, func = function(self) 
            if self.CurOffset < 1.5 then 
                self.Pause = true 
                if not Player.Moving then 
                    if ATP_BLIZZARD_START == 0 and APT_LAST_BLIZZARD_POSITION ~= POS_BLIZZARD["86-1"] then 
                        CastBlizzard(POS_BLIZZARD["86-1"], 1) 
                    end 
                    if ATP_BLIZZARD_START == 0 or ATP_BLIZZARD_TIME > 3100 or NearPlayer(5) > 1 then 
                        if Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
                            Debug("魔爆术") 
                        end 
                        self.Pause = false 
                    end 
                end 
            end 
        end }, 
        { x = 765.284, y = -353.156, z = -61.386, func = function(self) 
            if self.CurOffset < 1.5 then 
                self.Pause = true 
                if not Player.Moving then 
                    if NearPosition(POS_BLIZZARD["87-1"], 13) > 0 then 
                        if ATP_BLIZZARD_START == 0 and APT_LAST_BLIZZARD_POSITION ~= POS_BLIZZARD["87-1"] then 
                            CastBlizzard(POS_BLIZZARD["87-1"], 1) 
                        end 
                    end 
                    if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD["87-1"] and (ATP_BLIZZARD_START == 0 or ATP_BLIZZARD_TIME > 4060) then 
                        self.Pause = false 
                    end 
                end 
            end 
        end }, 
        { x = 783.151, y = -368.847, z = -59.810, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(800.150, -403.169, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 800.150, y = -403.169, z = -58.253, func = function(self) 
            if not Buff.MageArmor:Exist() and not Spell.MageArmor:LastCast() and Spell.MageArmor:IsReady() and Spell.MageArmor:Cast(Player) then 
                Debug("释放魔甲术") 
            end 
        end }, 
        { x = 803.105, y = -423.044, z = -53.540, func = nil }, 
        { x = 818.074, y = -450.292, z = -56.276, func = nil }, 
        { x = 820.290, y = -456.885, z = -56.289, func = nil }, 
        { x = 806.466, y = -490.028, z = -54.335, func = function(self) 
            if Item.ManaRuby:IsReady() and Item.ManaRuby:InBag() and Item.ManaRuby:Use() then 
                Debug("使用法力红宝石") 
            end 
        end }, 
        { x = 779.317, y = -516.969, z = -52.584, func = function(self) 
            if Spell.Blink:IsReady() then 
                FaceDirection(777.564, -520.082, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 777.564, y = -520.082, z = -52.128, func = function(self) 
            if self.CurOffset < 1.5 then 
                if Buff.IceBarrier:Remain() < 50 and Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
                    Debug("寒冰护体") 
                end 
            end 
        end }, 
        { x = 782.163, y = -525.035, z = -49.489, func = nil }, 
        { x = 789.671, y = -525.863, z = -47.396, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(806.001465, -514.490540, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 806.001465, y = -514.490540, z = -41.474762, func = CastBuff }, 
        { x = 802.520, y = -507.210, z = -40.931, func = CastBuff }, 
        { x = 795.788391, y = -494.081482, z = -39.892342, func = function(self) 
            if self.CurOffset < 1.5 then 
                if Buff.ManaShield:Remain() < 40 and Spell.ManaShield:IsReady() and Spell.ManaShield:Cast() then 
                    Debug("法力盾") 
                end 
            end 
        end },
    }, 1.5) 
    
    local FM_REAATHER = FixedNode({
        { x = 783.566, y = -489.297, z = -40.131, func = function(self) 
            if self.CurOffset < 1.5 then 
                if Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
                    Debug("冰霜新星") 
                end 
            end 
        end }, 
        { x = 767.461, y = -473.609, z = -40.904, func = CastBuff }, 
        { x = 741.840, y = -471.367, z = -39.208, func = nil }, 
        { x = 735.873413, y = -482.493835, z = -40.937424, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(745.279968, -531.770630, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 745.279968, y = -531.770630, z = -35.009106, func = CastBuff }, 
        { x = 752.664, y = -541.457, z = -32.484 }, 
        { x = 777.229, y = -534.736, z = -37.139, func = function(self) 
            if self.CurOffset < 1.5 then 
                self.Pause = true 
                if not Player.Moving then 
                    if APT_LAST_BLIZZARD_POSITION ~= POS_BLIZZARD_REGATHER["7-1"] and APT_LAST_BLIZZARD_POSITION ~= POS_BLIZZARD_REGATHER["7-2"] and ATP_BLIZZARD_START == 0 then 
                        CastBlizzard(POS_BLIZZARD_REGATHER["7-1"], 1) 
                    end 
                    
                    if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_REGATHER["7-1"] and ATP_BLIZZARD_START == 0 then 
                        CastBlizzard(POS_BLIZZARD_REGATHER["7-2"], 1) 
                    end 
                    if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_REGATHER["7-2"] and (ATP_BLIZZARD_START == 0 or NearPlayer(8) > 1) then 
                        self.Pause = false 
                    end 
                end 
            end 
        end }, 
        { x = 782.359, y = -526.644, z = -48.832, func = CastBuff }, 
        { x = 787.019, y = -516.708, z = -52.802, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(811.887, -480.648, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 811.887, y = -480.648, z = -54.912, func = CastBuff }, 
        { x = 820.799, y = -468.357, z = -55.917, func = CastBuff }, 
        { x = 835.322, y = -450.158, z = -56.394, func = CastBuff }, 
        { x = 856.643, y = -423.649, z = -52.433, func = function(self) 
            if self.CurOffset < 1.5 then 
                self.Pause = true 
                if NearPosition(POS_BLIZZARD_REGATHER["13-1"], 12) > 0 then 
                    if APT_LAST_BLIZZARD_POSITION ~= POS_BLIZZARD_REGATHER["13-1"] and ATP_BLIZZARD_START == 0 then 
                        CastBlizzard(POS_BLIZZARD_REGATHER["13-1"], 1) 
                    end 
                    if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_REGATHER["13-1"] and (ATP_BLIZZARD_START == 0 or ATP_BLIZZARD_TIME > 4000) then 
                        if Spell.Blink:IsReady() then 
                            FaceDirection(872.628, -398.523, true) 
                            if Spell.Blink:Cast(Player) then 
                                Debug("闪现") 
                            end 
                        end 
                        
                        self.Pause = false 
                    end 
                end 
            end 
        end }, 
        { x = 872.628, y = -398.523, z = -51.789, func = nil }, 
        { x = 874.728, y = -392.915, z = -52.050, func = function(self) 
            if self.CurOffset < 1.5 then 
                self.Pause = true 
                if NearPosition(POS_BLIZZARD_REGATHER["15-1"], 12) > 0 then 
                    if APT_LAST_BLIZZARD_POSITION ~= POS_BLIZZARD_REGATHER["15-1"] and ATP_BLIZZARD_START == 0 then 
                        CastBlizzard(POS_BLIZZARD_REGATHER["15-1"], 1) 
                    end 
                    
                    if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_REGATHER["15-1"] and (ATP_BLIZZARD_START == 0 or ATP_BLIZZARD_TIME > 4000) then 
                        self.Pause = false 
                    end 
                end 
            end 
        end }, 
        { x = 873.252, y = -380.208, z = -52.050, func = CastBuff }, 
        { x = 869.291, y = -366.403, z = -52.050, func = CastBuff }, 
        { x = 845.586121, y = -360.740265, z = -51.471371, func = CastBuff }, 
        { x = 820.248352, y = -353.131927, z = -51.577480, func = nil }, 
        { x = 811.975098, y = -355.695038, z = -51.518608, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(779.863953, -340.787811, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 779.863953, y = -340.787811, z = -50.309078, func = CastBuff }, 
        { x = 766.998230, y = -333.499176, z = -50.886410, func = CastBuff }, 
        { x = 758.889648, y = -333.212250, z = -51.235672, func = nil }, 
        { x = 754.818, y = -349.923, z = -50.662, func = function(self) 
            if self.CurOffset < 1.5 then 
                self.Pause = true 
                if not Player.Moving and NearPosition(POS_BLIZZARD_REGATHER["24-1"], 12) > 0 then 
                    if APT_LAST_BLIZZARD_POSITION ~= POS_BLIZZARD_REGATHER["24-1"] and APT_LAST_BLIZZARD_POSITION ~= POS_BLIZZARD_REGATHER["24-2"] and ATP_BLIZZARD_START == 0 then 
                        CastBlizzard(POS_BLIZZARD_REGATHER["24-1"], 1) 
                    end 
                    
                    if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_REGATHER["24-1"] and (ATP_BLIZZARD_START == 0 or ATP_BLIZZARD_TIME > 4000) then 
                        CastBlizzard(POS_BLIZZARD_REGATHER["24-2"], 1) 
                    end 
                    
                    if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_REGATHER["24-2"] and (ATP_BLIZZARD_START == 0 or NearPlayer(8) > 0) then 
                        self.Pause = false 
                    end 
                end 
            end 
        end }, 
        { x = 763.548, y = -357.181, z = -61.608, func = nil }, 
        { x = 775.008, y = -364.194, z = -61.317, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(791.448, -378.962, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 791.448, y = -378.962, z = -59.086, func = nil }, 
        { x = 797.976, y = -400.188, z = -58.570, func = nil }, 
        { x = 801.459, y = -422.197, z = -53.523, func = nil }, 
        { x = 809.273, y = -436.363, z = -55.033, func = nil }, 
        { x = 819.873, y = -455.605, z = -56.293, func = nil }, 
        { x = 812.762, y = -475.530, z = -55.232, func = nil }, 
        { x = 810.921, y = -481.116, z = -54.817, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(796.043, -498.429, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 796.043, y = -498.429, z = -53.345, func = nil }, 
        { x = 779.317, y = -516.969, z = -52.584, func = CastBuff }, 
        { x = 777.564, y = -520.082, z = -52.128, func = CastBuff }, 
        { x = 782.163, y = -525.035, z = -49.489, func = CastBuff }, 
        { x = 789.671, y = -525.863, z = -47.396, func = CastBuff }, 
        { x = 806.001, y = -514.491, z = -41.475, func = CastBuff }, 
        { x = 802.520, y = -507.210, z = -40.931, func = CastBuff }, 
        { x = 795.788, y = -494.081, z = -39.892, func = CastBuff },
    }, 1.5) 
    
    local FM_LOOT = FixedNode({ { x = 775.08575439453, y = -509.5458984375, z = -52.721622467041, func = Loot }, { x = 777.67895507813, y = -517.12036132813, z = -52.730648040771, func = Loot }, { x = 781.33123779297, y = -523.84191894531, z = -50.105331420898, func = Loot }, { x = 788.61492919922, y = -526.21734619141, z = -47.438026428223, func = Loot }, { x = 795.37799072266, y = -522.57360839844, z = -44.710525512695, func = Loot }, { x = 801.4970703125, y = -517.89581298828, z = -42.294002532959, func = Loot }, { x = 803.16241455078, y = -510.02688598633, z = -41.200710296631, func = Loot }, { x = 800.30578613281, y = -502.55303955078, z = -40.456607818604, func = Loot }, { x = 794.84674072266, y = -496.62869262695, z = -39.953914642334, func = Loot }, }, 1) 
    
    local FM_LURE_EX = FixedNode({
        { x = 782.691, y = -525.771, z = -49.068, r = 1, func = CastBuff }, 
        { x = 801.078, y = -500.250, z = -53.530, r = 1, func = CastBuff }, 
        { x = 832.516, y = -456.808, z = -56.315, r = 1, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(852.365, -445.000, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 852.365, y = -445.000, z = -56.307, r = 1, func = CastBuff }, 
        { x = 859.221, y = -415.785, z = -52.290, r = 1, func = CastBuff }, { x = 872.629, y = -400.388, z = -51.735, r = 1, func = CastBuff }, { x = 874.311, y = -378.691, z = -52.050, r = 1, func = CastBuff }, { x = 870.083, y = -365.435, z = -52.050, r = 1, func = CastBuff }, { x = 844.595, y = -346.488, z = -52.049, r = 1, func = CastBuff }, { x = 823.250, y = -344.305, z = -51.793, r = 1, func = CastBuff }, { x = 808.916, y = -354.554, z = -51.532, r = 1, func = CastBuff }, { x = 784.066, y = -338.199, z = -50.201, r = 1, func = CastBuff }, { x = 761.515, y = -330.555, z = -51.373, r = 1, func = CastBuff }, 
        
        { x = 746.439, y = -334.680, z = -50.661, r = 1, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(721.220, -325.103, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 721.220, y = -325.103, z = -51.106, r = 1 }, 
        { x = 701.681, y = -315.226, z = -51.729, r = 1, func = function(self) 
            if self.CurOffset < 1.5 then 
                if Player.Combat then 
                    if Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
                        Debug("冰霜新星") 
                    end 
                else 
                    self.Index = self.Index + 2 
                end 
            end 
        end }, 
        { x = 699.219, y = -311.654, z = -52.019, r = 1, func = function(self) 
            if self.CurOffset < 1.5 then 
                FaceDirection(695.791, -310.909, true) 
                MoveForwardStart() 
                Delay(20) 
                JumpOrAscendStart() 
                Delay(20) 
                AscendStop() 
                MoveForwardStop() 
                
                while Player.Combat do 
                    Delay(1000) 
                end 
                FaceDirection(703.455, -311.965, true) 
                MoveForwardStart() 
                Delay(20) 
                JumpOrAscendStart() 
                Delay(20) 
                AscendStop() 
                MoveForwardStop() 
            end 
        end }, 
        { x = 703.455, y = -311.965, z = -51.750, r = 1, func = CastBuff }, { x = 675.518, y = -323.993, z = -52.134, r = 1, func = CastBuff }, { x = 665.174, y = -323.835, z = -52.088, r = 1, func = CastBuff }, { x = 659.908, y = -323.161, z = -52.019, r = 1, func = CastBuff }, { x = 654.665, y = -319.582, z = -52.019, r = 1, func = CastBuff }, { x = 649.244, y = -304.311, z = -52.211, r = 1, func = CastBuff }, { x = 645.453, y = -287.458, z = -52.486, r = 1, func = CastBuff }, { x = 646.700, y = -272.870, z = -52.932, r = 1, func = CastBuff }, 
        
        { x = 656.000, y = -258.052, z = -53.181, r = 1, func = function(self) 
            if self.CurOffset < 1.5 then 
                if Player.Combat then 
                    FaceDirection(664.117798, -251.125916, true) 
                    MoveForwardStart() 
                    Delay(20) 
                    JumpOrAscendStart() 
                    Delay(20) 
                    AscendStop() 
                    MoveForwardStop() 
                    while Player.Combat do 
                        Delay(1000) 
                    end 
                    FaceDirection(658.935608, -253.289673, true) 
                    MoveForwardStart() 
                    Delay(20) 
                    JumpOrAscendStart() 
                    Delay(20) 
                    AscendStop() 
                    MoveForwardStop() 
                end 
            end 
        end }, 
        { x = 651.210, y = -239.695, z = -64.391, r = 1, func = CastBuff }, { x = 645.268, y = -218.699, z = -64.390, r = 1, func = CastBuff }, { x = 658.564, y = -206.437, z = -64.391, r = 1, func = CastBuff }, { x = 664.011, y = -205.223, z = -62.702, r = 1, func = CastBuff }, { x = 672.758, y = -209.911, z = -60.066, r = 1, func = CastBuff }, { x = 686.442, y = -253.000, z = -53.075, r = 1, func = CastBuff }, { x = 689.632, y = -254.716, z = -53.060, r = 1, func = CastBuff }, { x = 693.107, y = -253.300, z = -53.050, r = 1, func = CastBuff }, { x = 693.336, y = -230.511, z = -47.281, r = 1, func = CastBuff }, { x = 693.095, y = -184.021, z = -48.219, r = 1, func = CastBuff }, 
        
        { x = 662.006, y = -160.286, z = -51.022, r = 1, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(644.321, -147.527, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 644.321, y = -147.527, z = -51.960, r = 1, func = CastBuff }, 
        { x = 636.605, y = -149.499, z = -52.310, r = 1, func = CastBuff }, 
        { x = 625.129, y = -148.007, z = -53.820, r = 1, func = CastBuff }, 
        { x = 612.070496, y = -141.008377, z = -54.654907, r = 1,
            func = function(self) 
                if self.CurOffset < 1.5 then 
                    self.Pause = true 
                    if not Buff.Drink:Exist() or Player.PowerPct > 95 then 
                        if Buff.DampenMagic:Remain() < 540 and Spell.DampenMagic:IsReady() and Stand() and Spell.DampenMagic:Cast() then 
                            print( "释放魔法抑制成功") 
                            Delay(1600) 
                        end 
                        
                        if Player.HP > 90 and Player.PowerPct > 95 then 
                            if Buff.IceBarrier:Remain() < 40 and Spell.IceBarrier:IsReady() and Stand() and Spell.IceBarrier:Cast() then 
                                print( "释放寒冰护体成功") 
                                Delay(1600) 
                            end 
                            
                            if Buff.ManaShield:Remain() < 30 and Spell.ManaShield:IsReady() and Stand() and Spell.ManaShield:Cast() then 
                                Delay(1600) 
                                print( "释放法力盾成功") 
                            end 
                        end 
                    end 
                    
                    if not Buff.Food:Exist() and Player.HP < 99 then 
                        RunMacroText("/use " .. ATP.Settings.FoodName) 
                        Delay(1500) 
                    end 
                    
                    if not Buff.Drink:Exist() and Player.PowerPct < 95 then 
                        RunMacroText("/use " .. ATP.Settings.WaterName) 
                        Delay(1500) 
                    end 
                    
                    if Player.HP > 98 and Player.PowerPct > 95 and Buff.ManaShield:Exist() and Buff.IceBarrier:Exist() and Buff.IceBarrier:Remain() > 40 then 
                        self.Pause = false 
                    end
            end
            end
        }, 
        { x = 614.204, y = -123.908, z = -55.042, r = 1, func = CastBuff }, 
        { x = 626.474, y = -110.571, z = -55.770, r = 1, func = CastBuff }, 
        { x = 634.707, y = -107.656, z = -56.113, r = 1, func = function(self) 
            if self.CurOffset < 1.5 then 
                if SearchTarget(624.787, -126.177, -55.284, 10, 20) then 
                    FaceDirection(Target.Pointer, true) 
                    if Spell.FireBlast:IsReady(1) and Spell.FireBlast:Cast(Target, 1) then 
                        Debug("火焰冲击") 
                    end 
                end 
                Delay(1000) 
                if SearchTarget(624.787, -126.177, -55.284, 20, 30) then 
                    if Spell.Counterspell:IsReady() and Spell.Counterspell:Cast(Target) then 
                        Debug("反制") 
                    end 
                end 
            end 
        end }, 
        { x = 657.094, y = -106.943, z = -56.386, r = 1, func = function(self) 
            if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
                FaceDirection(688.429, -105.207, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end }, 
        { x = 688.429, y = -105.207, z = -56.144, r = 1, func = CastBuff }, 
        { x = 699.926, y = -104.863, z = -56.262, r = 1, func = function(self) 
            if self.CurOffset < 1.5 then 
                self.Pause = true 
                if not Player.Moving then 
                    CastBlizzard(POS_BLIZZARD_EX["45-1"], 1) 
                    Delay(1200 - ATP_BLIZZARD_TIME) 
                    self.Pause = false 
                end 
            end 
        end }, 
        { x = 727.989, y = -99.002, z = -56.478, r = 1, func = CastBuff }, 
        { x = 764.828, y = -93.117, z = -56.525, r = 1, func = CastBuff }, 
        { x = 785.874, y = -84.291, z = -57.110, r = 1, func = nil }, 
        { x = 828.619, y = -57.277, z = -87.042, r = 1, func = function(self) 
            if self.CurOffset < 1.5 then 
                Delay(5000) 
                if Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
                    Debug("寒冰护体") 
                end 
                Delay(2000) 
            else if Player.PosZ < -75 and Spell.Blink:IsReady() then 
                FaceDirection(828.619, -57.277, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
        end 
    end }, 
    { x = 828.667419, y = -48.866768, z = -86.805260, r = 1, func = function(self) 
        if self.CurOffset < 1.5 then 
            self.Pause = true 
            if not Player.Moving then 
                CastBlizzard(POS_BLIZZARD_EX["50-1"], 1) 
                Delay(2100 - ATP_BLIZZARD_TIME) 
                if SearchTarget(818.846, -34.914, -88.245, 20, 36) then 
                    FaceDirection(Target.Pointer, true) 
                    if Spell.Frostbolt:IsReady(1) and Spell.Frostbolt:Cast(Target, 1) then 
                        Debug("寒冰箭") 
                    end 
                    Delay(500) 
                    while Player.Casting do 
                        Delay(50) 
                    end 
                end 
                self.Pause = false 
            end 
        end 
    end }, 
    { x = 835.626, y = -75.143, z = -87.477, func = function(self) 
        if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
            FaceDirection(857.982483, -102.863167, true) 
            if Spell.Blink:Cast(Player) then 
                Debug("闪现") 
            end 
        end 
    end }, 
    { x = 857.982483, y = -102.863167, z = -88.628212, r = 1, func = function(self) 
        if self.CurOffset < 1.5 then 
            self.Pause = true 
            if not Player.Moving then 
                if SearchTarget(831.117, -97.125, -88.750, 20, 36) then 
                    FaceDirection(Target.Pointer, true) 
                    if Spell.Frostbolt:IsReady(1) and Spell.Frostbolt:Cast(Target, 1) then 
                        Debug("寒冰箭") 
                    end 
                    Delay(500) 
                    while Player.Casting do 
                        Delay(50) 
                    end 
                end 
                self.Pause = false 
            end 
        end 
    end }, 
    { x = 856.759, y = -114.725, z = -88.553, r = 1, func = function(self) 
        if self.CurOffset < 1.5 then 
            if Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
                Debug("魔爆术") 
            end 
        end 
    end }, 
    { x = 861.451111, y = -127.031853, z = -88.282623, r = 1, func = function(self) 
        if self.CurOffset < 1.5 then 
            if SearchTarget(869.528, -126.999, -87.064, 15, 40, true, "塞雷布拉斯的姐妹") then 
                if SearchTarget(869.528, -126.999, -87.064, 10, 20, true, "毒性软泥怪") then 
                    self.Tags.Avoid = true 
                    if Spell.FireBlast:IsReady(1) then 
                        if not Target.Facing then 
                            FaceDirection(Target.Pointer, true) 
                        end 
                        if Spell.FireBlast:Cast(Target, 1) then 
                            FaceDirection(853.007, -145.040, true) 
                            Debug("火焰冲击") 
                        end 
                    end 
                end 
            else if Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
                Debug("冰霜新星") 
            end 
        end 
    end 
end }, 
{ x = 852.319458, y = -151.861572, z = -88.298660, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if self.Tags.Avoid then 
            if Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
                Debug("冰霜新星") 
            end 
        else if SearchTarget(843.625, -143.876, -88.294, 12, 12) and Spell.ConeOfCold:IsReady() then 
            FaceDirection(Target.Pointer, true) 
            if Spell.ConeOfCold:Cast(Player, 1) then 
                FaceDirection(859.916, -164.172, true) 
                Debug("冰锥术") 
            end 
        end 
    end 
end 
end }, 
{ x = 859.916, y = -164.172, z = -86.871, r = 1, func = CastBuff }, 
{ x = 861.445, y = -174.206, z = -86.889, r = 1, func = CastBuff }, 
{ x = 858.830, y = -188.214, z = -82.902, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if SearchTarget(839.380, -175.888, -88.341, 20, 30) then 
            if Spell.Counterspell:Cast(Target) then 
                Debug("反制") 
            end 
        end 
    end 
end }, 
{ x = 845.504517, y = -200.702408, z = -76.480209, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if Spell.Blink:IsReady() then 
            FaceDirection(3.970191955, true) 
            if Spell.Blink:Cast(Player) then 
                FaceDirection(815.885, -217.673, true) 
                Debug("闪现") 
            end 
        end 
    end 
end }, 
{ x = 815.885, y = -217.673, z = -77.148, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        self.Pause = true 
        if not Player.Moving then 
            CastBlizzard(POS_BLIZZARD_EX["60-1"], 1) 
            Delay(1600 - ATP_BLIZZARD_TIME) 
            if Spell.FireBlast:IsReady(1) and SearchTarget(815.821, -232.790, -74.633, 10, 20) then 
                if not Target.Facing then 
                    FaceDirection(Target.Pointer, true) 
                end 
                if Spell.FireBlast:Cast(Target, 1) then 
                    Debug("火焰冲击") 
                end 
            end 
            self.Pause = false 
        end 
    end 
end }, 
{ x = 802.321, y = -206.480, z = -77.148, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
            Debug("魔爆术") 
        end 
        local EndX, EndY, EndZ = 780.285889, -174.709442, -52.058472 
        local x, y, z = ObjectPosition("player") 
        local dist = sqrt((x - EndX) ^ 2 + (y - EndY) ^ 2) 
        local startMove = false 
        local time, m 
        
        while not UnitIsDeadOrGhost("player") and ATP_START_TASK do 
            FaceDirection(EndX, EndY, true) 
            x, y, z = ObjectPosition("player") 
            dist = sqrt((x - EndX) ^ 2 + (y - EndY) ^ 2) 
            if not startMove and EndZ > z and dist > 3 then 
                x, y, z = ObjectPosition("player") 
                time = GetTime() 
                MoveForwardStart() 
                Scorpio.Next() 
                JumpOrAscendStart() 
                AscendStop() 
                MoveForwardStop() 
                
                while true do 
                    x, y, z = ObjectPosition("player") 
                    if sqrt((x - EndX) ^ 2 + (y - EndY) ^ 2) < 1 then 
                        if math.abs(EndZ - z) > 10 then 
                            RunMacroText(".stopfall") 
                        end 
                        break 
                    end 
                    m = (EndZ - z) / 1.64 
                    if m >= 1 then 
                        m = 2 
                    else 
                        m = 4 
                    end 
                    if GetTime() - time > 0.7 / m then 
                        RunMacroText(".stopfall") 
                        break 
                    end 
                    Scorpio.Next() 
                end 
            else 
                break 
            end 
        end 
        if Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
            Debug("寒冰护体") 
        end 
        Delay(2000)
            
    end         
end},
{ x = 775.109, y = -157.329, z = -56.336, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        FaceDirection(763.014, -123.792, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 763.014, y = -123.792, z = -57.482, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if SearchTarget(766.893, -116.138, -57.567, 15, 20, true, "洞窟潜伏者") then 
            if Spell.FireBlast:IsReady(1) then 
                if not Target.Facing then 
                    FaceDirection(Target.Pointer, true) 
                end 
                if Spell.FireBlast:Cast(Target, 1) then 
                    FaceDirection(751.064, -107.024, true) 
                    Debug("火焰冲击") 
                end 
            end 
        end 
    end 
end }, 
{ x = 751.064, y = -107.024, z = -57.492, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
        Debug("魔爆术") 
    end 
end }, 
{ x = 755.780, y = -80.374, z = -57.382, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
            Debug("冰霜新星") 
        end 
    end 
end }, 
{ x = 746.221, y = -71.312, z = -57.466, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Counterspell:IsReady() and SearchTarget(750.123, -42.878, -56.236, 15, 30) then 
        if Spell.Counterspell:Cast(Target) then 
            Debug("反制") 
        end 
    end 
end }, 
{ x = 727.123, y = -75.284, z = -57.499, r = 1, func = function(self) 
    if Spell.Counterspell:IsReady() and SearchTarget(750.123, -42.878, -56.236, 15, 30) then 
        if Spell.Counterspell:Cast(Target) then 
            Debug("反制") 
        end 
    end 
    if self.CurOffset < 1.5 and Spell.ConeOfCold:IsReady() then 
        FaceDirection(5.65, true) 
        if Spell.ConeOfCold:Cast(Player, 1) then 
            FaceDirection(709.037, -86.048, true) 
            Debug("冰锥术") 
        end 
    end 
end }, 
{ x = 709.037, y = -86.048, z = -57.236, r = 1, func = function(self) 
    if Item.ManaCitrine:IsReady() and Item.ManaCitrine:InBag() and Item.ManaCitrine:Use() then 
        Debug("使用法力黄水晶") 
    end 
    if self.CurOffset < 6 then 
        if Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
            Debug("冰霜新星") 
        end 
    end 
end }, 
{ x = 671.120, y = -93.020, z = -57.500, r = 1, func = function(self) 
    if Spell.Blink:IsReady() then 
        FaceDirection(671.120, -93.020, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 651.817, y = -89.496, z = -57.500, r = 1, func = CastBuff }, 
{ x = 643.982, y = -92.089, z = -57.500, r = 1, func = CastBuff }, 
{ x = 632.544, y = -95.818, z = -57.500, r = 1, func = CastBuff }, 
{ x = 629.318, y = -99.311, z = -57.500, r = 1, func = nil }, 
{ x = 619.800, y = -106.120, z = -57.500, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if SearchTarget(619.123, -99.928, -57.500, 15, 12) then 
            if Spell.ConeOfCold:IsReady() then 
                FaceDirection(Target.Pointer, true) 
                if Spell.ConeOfCold:Cast(Player, 1) then 
                    FaceDirection(620.703, -138.738, true) 
                    Debug("冰锥术") 
                end 
            end 
        end 
    end 
end }, 
{ x = 620.703, y = -138.738, z = -54.646, r = 1, func = nil }, 
{ x = 615.340, y = -149.589, z = -54.641, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if Spell.FireBlast:IsReady(1) and SearchTarget(597.286, -159.130, -55.189, 15, 20) then 
            if not Target.Facing then 
                FaceDirection(Target.Pointer, true) 
            end 
            if Spell.FireBlast:Cast(Target, 1) then 
                FaceDirection(624.301, -169.813, true) 
                Debug("火焰冲击") 
            end 
        end 
    end 
end }, 
{ x = 624.301, y = -169.813, z = -53.941, r = 1, func = CastBuff }, 
{ x = 625.477, y = -175.872, z = -53.863, r = 1, func = CastBuff }, 
{ x = 624.585, y = -185.380, z = -53.600, r = 1, func = function(self) 
    if Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
        Debug("魔爆术") 
    end 
end }, 
{ x = 627.228, y = -200.102, z = -64.625, r = 1, func = CastBuff }, 
{ x = 639.916, y = -220.726, z = -60.992, r = 1, func = CastBuff }, 
{ x = 641.269, y = -249.200, z = -52.660, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        self.Pause = true 
        if not Player.Moving and Spell.Evocation:IsReady() and Spell.Evocation:Cast(Player) then 
            Debug("释放唤醒成功") 
        end 
        if NearPosition(Position(693.397400, -252.446960, -52.667274), 14) > 0 then 
            Debug("怪物就位") 
            self.Pause = false 
        end 
    end 
end }, 
{ x = 641.577, y = -251.258, z = -52.725, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        FaceDirection(644.242493, -278.281158, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 644.242493, y = -278.281158, z = -53.122379, r = 1, func = CastBuff }, 
{ x = 652.589, y = -313.375, z = -52.019, r = 1, func = nil }, 
{ x = 648.925, y = -329.759, z = -52.018, r = 1, func = nil }, 
{ x = 640.752, y = -338.900, z = -52.018, r = 1, func = nil }, 
{ x = 620.837, y = -359.174, z = -52.018, r = 1, func = nil }, 
{ x = 613.337, y = -366.975, z = -52.018, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        self.Pause = true 
        if not Player.Moving then 
            CastBlizzard(POS_BLIZZARD_EX["94-1"], 1) 
            Delay(1600 - ATP_BLIZZARD_TIME) 
            CastBlizzard(POS_BLIZZARD_EX["94-2"], 1) 
            Delay(1200 - ATP_BLIZZARD_TIME) 
            self.Pause = false 
        end 
    end 
end },     
{ x = 621.365, y = -359.075, z = -52.018, r = 1, func = CastBuff }, 
{ x = 625.762, y = -353.633, z = -52.020, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
        Debug("魔爆术") 
    end 
end }, 
{ x = 658.872, y = -362.157, z = -52.018, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if SearchTarget(651.955, -347.663, -52.019, 10, 20) then 
            if Spell.FireBlast:IsReady(1) then 
                FaceDirection(Target.Pointer, true) 
                if Spell.FireBlast:Cast(Target, 1) then 
                    FaceDirection(704.226, -370.663, true) 
                    Debug("火焰冲击") 
                end 
            end 
        end 
    end 
end }, 
{ x = 690.172, y = -367.997, z = -52.205, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if SearchTarget(696.538, -371.483, -52.019, 10, 30) then 
            if Spell.Counterspell:IsReady() then 
                if Spell.Counterspell:Cast(Target) then 
                    Debug("反制") 
                end 
            end 
        end 
    end 
end }, 
{ x = 704.226, y = -370.663, z = -52.019, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        FaceDirection(716.059, -343.529, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 716.059, y = -343.529, z = -51.671, r = 1, func = CastBuff }, 
{ x = 722.527, y = -336.419, z = -51.563, r = 1, func = CastBuff }, 
{ x = 753.929, y = -347.652, z = -50.692, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
        Debug("魔爆术") 
    end 
end }, 
{ x = 765.405, y = -360.670, z = -61.602, r = 1, func = CastBuff }, 
{ x = 779.589, y = -366.258, z = -60.736, r = 1, func = CastBuff }, 
{ x = 785.518, y = -372.234, z = -58.957, r = 1, func = CastBuff }, 
{ x = 799.286, y = -399.755, z = -58.611, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        FaceDirection(803.091492, -425.416199, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 803.091, y = -425.416, z = -53.693, r = 1, func = CastBuff }, 
{ x = 811.358, y = -441.869, z = -55.636, r = 1, func = CastBuff }, 
{ x = 816.717, y = -446.126, z = -56.118, r = 1, func = CastBuff }, { x = 819.998, y = -453.598, z = -56.315, r = 1, func = CastBuff }, { x = 818.572, y = -462.685, z = -56.088, r = 1, func = CastBuff }, { x = 811.432, y = -481.284, z = -54.852, r = 1, func = CastBuff }, { x = 778.595, y = -515.587, z = -52.691, r = 1, func = CastBuff }, { x = 782.287, y = -524.069, z = -49.816, r = 1, func = CastBuff }, { x = 789.622, y = -525.503, z = -47.400, r = 1, func = CastBuff }, { x = 798.038, y = -520.236, z = -43.310, r = 1, func = CastBuff }, { x = 802.297, y = -514.526, z = -41.562, r = 1, func = CastBuff }, { x = 802.224, y = -507.432, z = -40.940, r = 1, func = CastBuff }, { x = 796.761, y = -497.082, z = -39.930, r = 1, func = CastBuff }, 
{ x = 783.662, y = -491.382, z = -40.063, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        self.Pause = true 
        if NearPosition(POS_BLIZZARD_EX["120-2"], 20) > 0 then 
            CastBlizzard(POS_BLIZZARD_EX["120-1"], 1) Delay(1600 - ATP_BLIZZARD_TIME) CastBlizzard(POS_BLIZZARD_EX["120-2"], 1) Delay(7100 - ATP_BLIZZARD_TIME) CastBlizzard(POS_BLIZZARD_EX["120-3"], 1) Delay(1600 - ATP_BLIZZARD_TIME) CastBlizzard(POS_BLIZZARD_EX["120-4"], 1) Delay(1100 - ATP_BLIZZARD_TIME) self.Pause = false 
        end 
    end 
end }, 
{ x = 761.178772, y = -466.612915, z = -40.863789, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
            Debug("冰霜新星") 
        end 
    end 
end }, 
{ x = 741.840, y = -471.367, z = -39.208, r = 1, func = nil }, 
{ x = 731.088, y = -488.147, z = -41.283, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        FaceDirection(739.193, -522.227, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 739.193, y = -522.227, z = -39.571, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Counterspell:IsReady() and SearchTarget(717.124, -502.128, -36.591, 10, 30) then 
        if Spell.Counterspell:Cast(Target) then 
            Debug("反制") 
        end 
    end 
end }, 
{ x = 752.664, y = -541.457, z = -32.484, r = 1, func = CastBuff }, 
{ x = 777.229, y = -534.736, z = -37.139, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        self.Pause = true 
        if not Player.Moving then 
            if APT_LAST_BLIZZARD_POSITION ~= POS_BLIZZARD_EX["126-1"] and APT_LAST_BLIZZARD_POSITION ~= POS_BLIZZARD_EX["126-2"] and ATP_BLIZZARD_START == 0 then 
                CastBlizzard(POS_BLIZZARD_EX["126-1"], 1) 
            end 
            
            if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_EX["126-1"] and ATP_BLIZZARD_START == 0 then 
                CastBlizzard(POS_BLIZZARD_EX["126-2"], 1) 
            end 
            
            if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_EX["126-2"] and (ATP_BLIZZARD_START == 0 or NearPlayer(8) > 2) then 
                self.Pause = false 
            end 
        end 
    end 
end }, 
{ x = 782.359, y = -526.644, z = -48.832, r = 1, func = CastBuff }, 
{ x = 787.019, y = -516.708, z = -52.802, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        FaceDirection(811.887, -480.648, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 811.887, y = -480.648, z = -54.912, r = 1, func = nil }, 
{ x = 820.910, y = -455.063, z = -56.318, r = 1, func = nil }, 
{ x = 804.508, y = -427.699, z = -53.842, r = 1, func = nil }, 
{ x = 801.449, y = -423.651, z = -53.542, r = 1, func = nil }, 
{ x = 800.822, y = -418.693, z = -53.689, r = 1, func = nil }, 
{ x = 825.427, y = -390.755, z = -59.103, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        self.Pause = true 
        if not Player.Moving then 
            if SearchTarget(856.386, -386.619, -64.126, 15, 36) then 
                FaceDirection(Target.Pointer, true) 
                if Spell.Frostbolt:IsReady(1) and Spell.Frostbolt:Cast(Target, 1) then 
                    Debug("寒冰箭") 
                end 
                Delay(800) 
                while Player.Casting do 
                    Delay(50) 
                end 
            end 
            self.Pause = false 
        end 
    end 
end }, 
{ x = 807.747, y = -388.385, z = -59.071, r = 1, func = CastBuff }, 
{ x = 787.896, y = -379.052, z = -59.096, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        self.Pause = true 
        if not Player.Moving then 
            if SearchTarget(771.665, -353.206, -61.652, 15, 36) then 
                FaceDirection(Target.Pointer, true) 
                if Spell.Frostbolt:IsReady(1) and Spell.Frostbolt:Cast(Target, 1) then 
                    Debug("寒冰箭") 
                end 
                Delay(800) 
                while Player.Casting do 
                    Delay(50) 
                end 
            end 
            self.Pause = false 
        end 
    end 
end }, 
{ x = 798.207, y = -380.694, z = -59.036, r = 1, func = nil }, 
{ x = 808.757, y = -382.665, z = -59.091, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
        Debug("魔爆术") 
    end 
end }, 
{ x = 799.093, y = -422.973, z = -53.571, r = 1, func = function(self) 
    if Spell.Blink:IsReady() then 
        FaceDirection(802.120, -428.099, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 802.120, y = -428.099, z = -53.807, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
            Debug("冰霜新星") 
        end 
    end 
end }, 
{ x = 827.055, y = -438.522, z = -56.249, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and SearchTarget(830.135, -446.087, -56.281, 10, 30) and Spell.ConeOfCold:IsReady() then 
        FaceDirection(Target.Pointer, true) 
        if Spell.ConeOfCold:Cast(Player, 1) then 
            FaceDirection(834.130, -438.018, true) 
            Debug("冰锥术") 
        end 
    end 
end }, 
{ x = 834.130, y = -438.018, z = -55.994, r = 1, func = CastBuff }, 
{ x = 839.327, y = -435.642, z = -56.059, r = 1, func = CastBuff }, 
{ x = 873.265, y = -400.039, z = -51.747, r = 1, func = CastBuff }, 
{ x = 890.133850, y = -379.689331, z = -52.028820, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Counterspell:IsReady() and SearchTarget(897.796, -406.071, -52.944, 15, 30) then 
        if Spell.Counterspell:Cast(Target) then 
            Debug("反制") 
        end 
    end 
end }, 
{ x = 874.263062, y = -333.994781, z = -50.126431, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        Delay(500) 
        FaceDirection(819.415, -344.001, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 819.415, y = -344.001, z = -51.617, r = 1, func = CastBuff }, 
{ x = 784.705, y = -336.748, z = -50.120, r = 1, func = CastBuff }, 
{ x = 753.625, y = -332.139, z = -50.962, r = 1, func = nil }, 
{ x = 734.580017, y = -333.114960, z = -50.804169, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        FaceDirection(713.982, -322.012, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 713.982, y = -322.012, z = -51.415, r = 1, func = CastBuff }, 
{ x = 698.496, y = -315.016, z = -51.936, r = 1, func = CastBuff }, 
{ x = 674.693, y = -323.890, z = -52.089, r = 1, func = CastBuff }, 
{ x = 664.305, y = -324.071, z = -52.044, r = 1, func = CastBuff }, 
{ x = 659.774, y = -323.735, z = -52.019, r = 1, func = nil }, 
{ x = 654.586, y = -319.325, z = -52.019, r = 1, func = nil }, 
{ x = 648.838, y = -305.936, z = -52.168, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        FaceDirection(644.997, -286.972, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 644.997, y = -286.972, z = -52.535, r = 1, func = CastBuff }, 
{ x = 646.345, y = -273.126, z = -52.925, r = 1, func = CastBuff }, 
{ x = 655.378, y = -257.996, z = -53.174, r = 1, func = CastBuff }, 
{ x = 657.829, y = -246.429, z = -64.391, r = 1, func = nil }, 
{ x = 658.797913, y = -237.536987, z = -64.391083, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        FaceDirection(661.446, -211.615, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 661.446, y = -211.615, z = -60.952, r = 1, func = CastBuff }, 
{ x = 671.849609, y = -208.588257, z = -60.936592, r = 1, func = nil }, 
{ x = 675.769165, y = -220.799103, z = -60.253593, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        self.Pause = true 
        if not Player.Moving then 
            if ATP_BLIZZARD_START == 0 and NearPosition(POS_BLIZZARD_EX["165-1"], 14) > 0 then 
                CastBlizzard(POS_BLIZZARD_EX["165-1"], 1) 
            end 
            if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_EX["165-1"] and ATP_BLIZZARD_TIME > 4900 then 
                if Spell.Counterspell:IsReady() and SearchTarget(686.322, -196.200, -60.515, 15, 30, true) then 
                    if Spell.Counterspell:Cast(Target) then 
                        Debug("反制") 
                    end 
                end 
                self.Pause = false 
            end 
        end 
    end 
end }, 
{ x = 688.894, y = -259.486, z = -53.060, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and SearchTarget(692.116, -265.452, -52.898, 15, 15) and Spell.ConeOfCold:IsReady() then 
        FaceDirection(Target.Pointer, true) 
        if Spell.ConeOfCold:Cast(Player, 1) then 
            FaceDirection(694.131, -252.028, true) 
            Debug("冰锥术") 
        end 
    end 
end }, 
{ x = 694.131, y = -252.028, z = -52.542, r = 1, func = CastBuff }, 
{ x = 715.893, y = -217.660, z = -47.251, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
        Debug("魔爆术") 
    end 
end }, 
{ x = 703.090, y = -201.895, z = -47.262, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
            Debug("冰霜新星") 
        end 
    end 
end }, 
{ x = 676.746, y = -159.014, z = -48.877, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        if Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
            Debug("魔爆术") 
        end 
    else if self.CurOffset > 12 then 
        CastBuff() 
    end 
end 
end }, 
{ x = 655.423, y = -137.628, z = -50.325, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        self.Pause = true 
        if NearPlayer(11) > 1 then 
            if Spell.Blink:IsReady() then 
                FaceDirection(627.752136, -187.392868, true) 
                if Spell.Blink:Cast(Player) then 
                    Debug("闪现") 
                end 
            end 
            self.Pause = false 
        end 
    end 
end }, 
{ x = 627.752136, y = -187.392868, z = -52.167908, r = 1, func = CastBuff }, 
{ x = 633.946045, y = -202.239944, z = -64.391129, r = 1, func = CastBuff }, 
{ x = 639.408142, y = -224.285034, z = -60.164680, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        self.Pause = true 
        if not Player.Moving then 
            if ATP_BLIZZARD_START == 0 and NearPosition(POS_BLIZZARD_EX["174-1"], 12) > 0 then 
                CastBlizzard(POS_BLIZZARD_EX["174-1"], 1) 
            end 
            if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_EX["174-1"] and ATP_BLIZZARD_TIME > 4000 then 
                CastBlizzard(POS_BLIZZARD_EX["174-2"], 1) 
            end 
            if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_EX["174-2"] and (ATP_BLIZZARD_TIME > 4000 or NearPlayer(8) > 0) then 
                if SearchTarget(617.731, -204.076, -64.685, 15, 36) then 
                    FaceDirection(Target.Pointer, true) 
                    if Spell.Frostbolt:IsReady(1) and Spell.Frostbolt:Cast(Target, 1) then 
                        Debug("寒冰箭") 
                    end 
                    Delay(500) 
                    while Player.Casting do 
                        Delay(50) 
                    end 
                end 
                if SearchTarget(659.067, -228.007, -64.391, 15, 30) then 
                    FaceDirection(Target.Pointer, true) 
                    if Spell.Counterspell:IsReady() and Spell.Counterspell:Cast(Target) then 
                        Debug("反制") 
                    end 
                end 
                self.Pause = false 
            end 
        end 
    end 
end }, 
{ x = 639.136, y = -248.613, z = -52.450, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        FaceDirection(642.775, -289.487, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 642.775, y = -289.487, z = -52.445, r = 1, func = CastBuff }, 
{ x = 654.740, y = -323.219, z = -52.019, r = 1, func = CastBuff }, 
{ x = 681.064, y = -327.942, z = -52.387, r = 1, func = CastBuff }, 
{ x = 719.269, y = -333.417, z = -51.631, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        FaceDirection(754.547, -346.616, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 754.547, y = -346.616, z = -50.663, r = 1, func = function(self) 
    if self.CurOffset < 1.5 then 
        self.Pause = true 
        if not Player.Moving then 
            if ATP_BLIZZARD_START == 0 and NearPosition(POS_BLIZZARD_EX["180-1"], 14) > 0 then 
                CastBlizzard(POS_BLIZZARD_EX["180-1"], 1) 
            end 
            if APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_EX["180-1"] and (ATP_BLIZZARD_TIME > 4900 or NearPlayer(14) > 3) then 
                self.Pause = false 
            end 
        end 
    end 
end }, 
{ x = 780.388, y = -362.839, z = -61.287, r = 1, func = function(self) 
    if Item.ManaRuby:IsReady() and Item.ManaRuby:InBag() and Item.ManaRuby:Use() then 
        Debug("使用法力红宝石") 
    end 
    if Item.ManaCitrine:IsReady() and Item.ManaCitrine:InBag() and Item.ManaCitrine:Use() then 
        Debug("使用法力黄水晶") 
    end 
    if not Buff.MageArmor:Exist() and not Spell.MageArmor:LastCast() and Spell.MageArmor:IsReady() and Spell.MageArmor:Cast(Player) then 
        Debug("释放魔甲术") 
    end 
end }, 
{ x = 786.604, y = -372.569, z = -59.038, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        FaceDirection(799.812, -401.262, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 799.812, y = -401.262, z = -58.545, r = 1, func = nil }, 
{ x = 801.194, y = -423.907, z = -53.552, r = 1, func = nil }, 
{ x = 814.154, y = -442.457, z = -55.859, r = 1, func = nil }, 
{ x = 822.109, y = -455.357, z = -56.336, r = 1, func = nil }, 
{ x = 810.811, y = -483.333, z = -54.672, r = 1, func = function(self) 
    if self.CurOffset < 1.5 and Spell.Blink:IsReady() then 
        FaceDirection(779.317, -516.969, true) 
        if Spell.Blink:Cast(Player) then 
            Debug("闪现") 
        end 
    end 
end }, 
{ x = 779.317, y = -516.969, z = -52.584, r = 1, func = CastBuff }, 
{ x = 777.564, y = -520.082, z = -52.128, r = 1, func = CastBuff }, 
{ x = 782.163, y = -525.035, z = -49.489, r = 1, func = CastBuff }, 
{ x = 789.671, y = -525.863, z = -47.396, r = 1, func = CastBuff }, 
{ x = 806.001465, y = -514.490540, z = -41.474762, r = 1, func = CastBuff }, 
{ x = 802.520, y = -507.210, z = -40.931, r = 1, func = CastBuff }, 
{ x = 795.788391, y = -494.081482, z = -39.892342, r = 1, func = CastBuff },
    }, 1.5) 
    
    local FP_COMBAT = FixedPath({ 
        { x = 773.930115, y = -514.178345, z = -52.761795, node = 0 }, 
        { x = 778.61413574219, y = -517.43444824219, z = -52.638153076172, node = 0 }, { x = 782.05871582031, y = -524.34100341797, z = -49.777587890625, node = 1 }, { x = 791.16979980469, y = -525.78570556641, z = -46.971782684326, node = 2 }, { x = 797.5478515625, y = -522.57098388672, z = -44.026306152344, node = 3 }, { x = 800.66058349609, y = -518.87170410156, z = -42.62068939209, node = 4 }, { x = 802.76342773438, y = -515.36724853516, z = -41.643241882324, node = 5 }, { x = 803.64056396484, y = -511.0700378418, z = -41.308612823486, node = 6 }, { x = 802.44073486328, y = -505.94436645508, z = -40.810272216797, node = 7 }, { x = 800.10461425781, y = -501.44412231445, z = -40.351333618164, node = 8 }, { x = 777.199951, y = -516.329834, z = -52.729652, node = 9 }, }, 1.5) 
        
        local FP_TREE = FixedPath({ 
            { x = 781.415833, y = -497.579956, z = -42.769817, node = 15 }, }, 0.8) 
            
        local FP_STEP = FixedPath({ { x = 783.929504, y = -490.816528, z = -40.072525 } }, 0.8) 
        local FP_START_SOLO = nil 
        local POS_INSIDE = nil 
        local POS_BUFFER = nil 
        local FP_INSIDE = nil 
        local CATCH_BLIZZARD_TIME = nil 
        local GATHER_STEP = 1 
        local COMBAT_STEP = 1 
        local FIRST_COMBAT = false 
        local NEXT_LOOT_NODE = true 
        local RACE, SEX MoveToLocation = (function() 
            local FLAG = false 
            local FP_1 = FixedPath({ 
                { x = 788.485, y = -492.994, z = -39.932 }, 
                { x = 781.776, y = -491.581, z = -40.079 }, }, 0.5) 
            local FP_2 = nil 
            local function Reset(x, y, z, offset) 
                FLAG = false 
                FP_1:Reset() 
                FP_2 = FixedPath({ { x = x, y = y, z = z }, }, offset) 
            end

        local function Run() 
            if not FLAG and FP_1:Move() then 
                FLAG = true 
                FaceDirection(785.344, -487.638, true) 
                Delay(200) 
            end 
            if FLAG then 
                if FP_2:Move() then 
                    print( "就位%0.3f", FP_2.CurrentNodeDistance) 
                    return true 
                end 
            end 
        end

        local TML = {} 
        TML.Reset = Reset 
        TML.Run = Run 
        return TML
    end)() 
    
    Init = function() 
        RACE = UnitRace("player") 
        SEX = UnitSex("player") 
        if RACE == "亡灵" then 
            if SEX == 3 then 
                MoveToLocation.Reset(784.216, -489.302, -40.107, 0.5) 
                POS_INSIDE = { x = 785.936, y = -489.572, z = -40.031 } 
                FP_INSIDE = FixedPath({ POS_INSIDE }, 0.5) 
            
            else 
                MoveToLocation.Reset(784.308, -489.139, -40.110, 0.5) 
                POS_INSIDE = { x = 785.733, y = -489.205, z = -40.056 } 
                FP_INSIDE = FixedPath({ POS_INSIDE }, 0.5) 
            end 
        elseif RACE == "巨魔" then 
            if SEX == 3 then 
                MoveToLocation.Reset(784.404, -489.080, -40.108, 0.5) 
                POS_INSIDE = { x = 786.442, y = -488.614, z = -40.019 } 
                FP_INSIDE = FixedPath({ POS_INSIDE }, 0.5) 
            
            else 
                MoveToLocation.Reset(784.404, -489.080, -40.108, 0.5) 
                POS_INSIDE = { x = 786.442, y = -488.614, z = -40.019 } 
                FP_INSIDE = FixedPath({ POS_INSIDE }, 0.5) 
            end 
        elseif RACE == "人类" then 
            if SEX == 3 then 
                MoveToLocation.Reset(784.169, -489.280, -40.110, 0.5) 
                POS_INSIDE = { x = 785.733, y = -489.205, z = -40.056 } 
                FP_INSIDE = FixedPath({ POS_INSIDE }, 0.5) 
            else 
                MoveToLocation.Reset(784.133, -489.407, -40.110, 0.5) 
                POS_INSIDE = { x = 786.063, y = -489.396, z = -40.004 } 
                FP_INSIDE = FixedPath({ POS_INSIDE }, 0.5) 
            end 
        
        elseif RACE == "侏儒" then 
            POS_INSIDE = { x = 786.132, y = -490.613, z = -39.996 } 
            FP_INSIDE = FixedPath({ POS_INSIDE }, 0.5) 
            FP_START_SOLO = FixedPath({ 
                { x = 788.485, y = -492.994, z = -39.932 }, 
                { x = 783.745, y = -491.000, z = -40.048 }, }, 0.5)
    end
    end 
    
    function KillImp(limit) 
        local count, units = GetUnits(800.070679, -517.496094, -42.445313, 8, function(unit) if not unit.Dead and unit.Name == "毒劣魔" then return true end end) 
        
        if count > limit then 
            local tmp = {} 
            local c = 0 
            for _, v in pairs(POS_INSIDE_KILL_IMP) do 
                c = 0 
                for _, u in pairs(units) 
                do 
                    if sqrt((v.x - u.PosX) ^ 2 + (v.y - u.PosY) ^ 2) <= 8 then 
                        c = c + 1 
                    end 
                end 
                table.insert(tmp, { Pos = v, Count = c }) 
            end 
            table.sort(tmp, function(a, b) return a.Count > b.Count end) 
            for i = 1, #tmp do 
                if tmp[i].Count < count - limit then 
                    return tmp[i].Pos 
                end 
            end 
        end 
    end

    function MoveToStep() if true or GetSetting("躲避方式") == 1 then MoveForwardStart() Delay(150) JumpOrAscendStart() Delay(20) AscendStop() Delay(700) MoveForwardStop() return true else if FP_STEP:Move() then FP_STEP:Reset() return true end end end

    function MoveToTree() 
        if true or GetSetting("躲避方式") == 1 then 
            if FP_TREE:Move() then 
                FP_TREE:Reset() 
                return true 
            end 
        else 
            if FP_TREE:Move() then 
                FP_TREE:Reset() 
                return true 
            end 
        end 
    end

    local function LastTarget() 
        local tmp = {} 
        for _, unit in pairs(DMW.Units) do 
            if unit.Classification == "elite" and UnitAffectingCombat(unit.Pointer) and unit.ReachDistance < 36 and ATP.IsInRegion(unit.PosX, unit.PosY, { { x = 797.51031494141, y = -494.55126953125, z = -39.858921051025 }, { x = 795.68359375, y = -498.6315612793, z = -41.776260375977 }, { x = 800.70495605469, y = -507.25582885742, z = -42.217288970947 }, { x = 800.76037597656, y = -513.29602050781, z = -43.181350708008 }, { x = 797.18048095703, y = -519.07733154297, z = -45.525398254395 }, { x = 789.28564453125, y = -523.78509521484, z = -49.450714111328 }, { x = 790.19982910156, y = -528.17810058594, z = -47.276817321777 }, { x = 796.71740722656, y = -526.78436279297, z = -45.431419372559 }, { x = 804.40393066406, y = -520.1884765625, z = -42.28636932373 }, { x = 807.69329833984, y = -513.22357177734, z = -41.382709503174 }, { x = 804.92510986328, y = -503.19064331055, z = -40.644790649414 }, }) then 
                table.insert(tmp, unit) 
            end 
        end 
        if #tmp > 0 then 
            table.sort(tmp, function(a, b) return a.PosZ < b.PosZ end) 
            return Position(tmp[1].PosX, tmp[1].PosY, tmp[1].PosZ) 
        end
    end

    out.Reset = function() 
        print("重置。。。。。。。。。。。。。1111");
        Init() 
        print("重置。。。。。。。。。。。。。12");
        LURE_STOP_MOVE = false 
        print("重置。。。。。。。。。。。。。13");
        PREPARE_STEP = 0 
        LOOT_TARGET = nil 
        FP_LOOT_TARGET = nil 
        POS_BUFFER = nil 
        BLIZZARD_CASTING_TIME = 0 
        FP_PREPARE:Reset() 
        print("重置。。。。。。。。。。。。。14");
        FP_TREE:Reset() 
        print("重置。。。。。。。。。。。。。15");
        FP_INSIDE:Reset() 
        print("重置。。。。。。。。。。。。。16");
        FP_COMBAT:Reset() 
        print("重置。。。。。。。。。。。。。17");
        FM_LURE:Reset() 
        print("重置。。。。。。。。。。。。。18");
        FM_LURE_EX:Reset() 
        print("重置。。。。。。。。。。。。。19");
        FM_LOOT:Reset() 
        print("重置。。。。。。。。。。。。。20");
        CURRENT_STATE = SOLO_STATE.PREPARE 
        CATCH_BLIZZARD_TIME = nil 
        APT_LAST_BLIZZARD_POSITION = nil 
        ATP_NEED_RESET = false 
        NEXT_LOOT_NODE = true 
        ATP_SPELL_BLIZZARD_COUNT = 0 
        OPEN_PACK_TIMER = 10 
        GATHER_STEP = 1 
        COMBAT_STEP = 1 
        FIRST_COMBAT = true 
        
        print("test =");
        print(ATP.Settings.Mode);
        if ATP.Settings.Mode == 1 then 
            print( "当前模式:紫门一波") 
        else 
            print( "当前模式:紫门瀑布一波") 
            if not IsHackEnabled("multijump") then 
                SetHackEnabled("multijump", true) 
            end 
        end 
    end 
    
    local function Task_Prepare() 
        if Player.Combat then 
            if Buff.IceBarrier:Remain() < 20 and Spell.IceBarrier:IsReady() and Stand() and Spell.IceBarrier:Cast() then 
                print( "释放寒冰护体成功") 
                Delay(1500) 
            end 
            
            local Count, Table = NearPlayer(2, true) 
            if Count > 0 then 
                StopMove() 
                if Spell.ArcaneExplosion:IsReady() and Spell.ArcaneExplosion:Cast(Player) then 
                    print( "释放魔爆术") 
                end 
            else 
                Player:AutoTarget(30) 
                if Target then 
                    MoveTo(Target.PosX, Target.PosY, Target.PosZ) 
                end 
            end 
        
        else if FP_PREPARE:Move() and not Player.Moving then 
            if PREPARE_STEP == 0 then 
                local FoodCount, WaterCount = 0, 0 
                for _, v in pairs(Bag.Items) do 
                    if v.Name == ATP.Settings.FoodName then 
                        FoodCount = FoodCount + v.Count 
                    end 
                    if v.Name == ATP.Settings.WaterName then 
                        WaterCount = WaterCount + v.Count 
                    end 
                    if v.Name == "耐力卷轴 III" then 
                        RunMacroText("/use " .. v.Name) 
                        Delay(1000) 
                    end 
                    if v.Name == "保护卷轴 III" then 
                        RunMacroText("/use " .. v.Name) 
                        Delay(1000) 
                    end 
                    if v.Name == "精神卷轴 III" then 
                        RunMacroText("/use " .. v.Name) 
                        Delay(1000) 
                    end 
                end 
                
                if FoodCount < 12 then 
                    if Player.Power >= Spell.ConjureFood:Cost() and Spell.ConjureFood:Cast() then 
                        Delay(3500) 
                        return true 
                    end 
                end 
                
                if WaterCount < 12 then 
                    if Player.Power >= Spell.ConjureWater:Cost() and Spell.ConjureWater:Cast() then 
                        Delay(3500) 
                        return true 
                    end 
                end 
                if FoodCount >= 12 and WaterCount >= 12 then 
                    PREPARE_STEP = 1 
                end 
            elseif PREPARE_STEP == 1 then 
                if not Buff.Drink:Exist() or Player.PowerPct > 95 then 
                    if Buff.ArcaneIntellect:Remain() < 1200 and Spell.ArcaneIntellect:IsReady() and Stand() and Spell.ArcaneIntellect:Cast() then 
                        print( "释放奥术智慧成功") 
                        Delay(1600) 
                    end 
                    
                    if Buff.IceArmor:Remain() < 1200 and Spell.IceArmor:IsReady() and Stand() and Spell.IceArmor:Cast() then 
                        print( "释放冰甲术成功") 
                        Delay(1600) 
                    end 
                    
                    if Buff.DampenMagic:Remain() < 360 and Spell.DampenMagic:IsReady() and Stand() and Spell.DampenMagic:Cast() then 
                        print( "释放魔法抑制成功") 
                        Delay(1600) 
                    end 
                    
                    if not Item.ManaRuby:InBag() and Spell.ConjureManaRuby:Known() and Stand() and Spell.ConjureManaRuby:Cast() then 
                        print( "制作法力红宝石") 
                        Delay(3500) 
                    end 
                    
                    if not Item.ManaCitrine:InBag() and Spell.ConjureManaCitrine:Known() and Stand() and Spell.ConjureManaCitrine:Cast() then 
                        print( "制作法力黄水晶") 
                        Delay(3500) 
                    end 
                    
                    if Player.HP > 90 and Player.PowerPct > 95 then 
                        if Buff.IceBarrier:Remain() < 40 and Spell.IceBarrier:IsReady() and Stand() and Spell.IceBarrier:Cast() then 
                            print( "释放寒冰护体成功") 
                            Delay(1600) 
                        end 
                        if Buff.ManaShield:Remain() < 30 and Spell.ManaShield:IsReady() and Stand() and Spell.ManaShield:Cast() then 
                            Delay(1600) 
                            print( "释放法力盾成功") 
                        end 
                    end
    end 
    if not Buff.Food:Exist() and Player.HP < 99 then 
        RunMacroText("/use " .. ATP.Settings.FoodName) 
        Delay(1500) 
    end 
    
    if not Buff.Drink:Exist() and Player.PowerPct < 95 then 
        RunMacroText("/use " .. ATP.Settings.WaterName) 
        Delay(1500) 
    end 
    
    if Player.HP > 98 and Player.PowerPct > 95 and (not Spell.ConjureManaRuby:Known() or Item.ManaRuby:InBag()) and (not Spell.ConjureManaCitrine:Known() or Item.ManaCitrine:InBag()) and Buff.ManaShield:Exist() and Buff.IceBarrier:Exist() and Buff.IceBarrier:Remain() > 40 then 
        if ATP.Settings.Mode == 1 then 
            ChangeTask(SOLO_STATE.LURE) 
        else ChangeTask(SOLO_STATE.LURE_EX) 
        end 
    end
    end 
else if FP_PREPARE.Index == 4 then 
    FP_PREPARE:Facing(5) FP_PREPARE.Index = 5 
    if not Spell.Blink:LastCast() and Spell.Blink:IsReady() and Spell.Blink:Cast(Player) then 
        print( "释放闪现") 
    end end
    end
    end
    end

    local function Task_Lure() 
        if not FM_LURE.Moved then 
            PATROL_TARGET = GetPatrolTarget() 
            if PATROL_TARGET and ATP.IsInRegion(PATROL_TARGET.PosX, PATROL_TARGET.PosY, Areas[4]) then 
                print( "等待巡逻-1") 
                Delay(2000) 
            else 
                FM_LURE:Move() 
            end 
        else if FM_LURE:Move() then 
            ChangeTask(SOLO_STATE.GATHER_1) 
        end 
    end 
end

    local function Task_Lure_ex() if FM_LURE_EX:Move() then ChangeTask(SOLO_STATE.GATHER_1) else end end

    local function Task_Gather_1() 
        if GATHER_STEP == 1 then 
            if FP_START_SOLO then 
                if FP_START_SOLO:Move() then 
                    GATHER_STEP = 2 
                end 
            else if MoveToLocation.Run() then 
                GATHER_STEP = 2 
            end 
        end 
    end 
    if GATHER_STEP == 2 then 
        if not Player.Moving and Player.Power < 3000 and not Player.Casting and Buff.IceBarrier:Exist() and Spell.Evocation:IsReady() and Spell.Evocation:Cast(Player) then 
        end 
        if NearPosition(POS_BLIZZARD_GATHER_1[1], 13) > 0 then 
            if Player.Power < 3000 then 
                if Bag:ItemExist("强效法力药水") and ItemCooldown("强效法力药水") == 0 then 
                    RunMacroText("/use 强效法力药水") 
                end 
                if Bag:ItemExist("法力药水") and ItemCooldown("法力药水") == 0 then 
                    RunMacroText("/use 法力药水") 
                end 
            end 
            GATHER_STEP = 3 
        end 
    end 
    if GATHER_STEP == 3 then 
        if ATP_BLIZZARD_START == 0 then 
            CastBlizzard(POS_BLIZZARD_GATHER_1[1], ATP.Settings.BlizzardLevel_1) 
        end 
        if ATP_BLIZZARD_START ~= 0 and APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_GATHER_1[1] then 
            print( "位置1") 
            GATHER_STEP = 4 
        end 
    end 
    if GATHER_STEP == 4 then 
        if not Player.Moving and ATP_BLIZZARD_START == 0 then 
            CastBlizzard(POS_BLIZZARD_GATHER_1[2], ATP.Settings.BlizzardLevel_2) 
        end 
        if ATP_BLIZZARD_START ~= 0 and APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_GATHER_1[2] then 
            print( "位置2") 
            FaceDirection(POS_INSIDE.x, POS_INSIDE.y, true) 
            GATHER_STEP = 5 
        end 
    end 
    if GATHER_STEP == 5 then 
        if ATP_BLIZZARD_START == 0 or ATP_BLIZZARD_TIME > 6060 then 
            if ImpAreaCount(779.618408, -519.725342, -51.705383, 15) >= 7 then 
                if FP_INSIDE:Move() then 
                    print( "距离:%0.3f", FP_INSIDE.CurrentNodeDistance) GATHER_STEP = 6 
                end 
            else 
                GATHER_STEP = 6 
            end 
        end 
    end 
    if GATHER_STEP == 6 then 
        if not Player.Moving and (ATP_BLIZZARD_START == 0 or ATP_BLIZZARD_TIME > 6060) then 
            CastBlizzard(POS_BLIZZARD_GATHER_1[3], ATP.Settings.BlizzardLevel_3) 
        end 
        if ATP_BLIZZARD_START ~= 0 and APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_GATHER_1[3] then 
            print( "位置3") GATHER_STEP = 7 
        end 
    end 
    if GATHER_STEP == 7 then 
        local count, table = NearPosition(Position(801.803650, -510.820557, -41.347656), 3, true) 
        local remain = 999 
        if count > 0 then 
            remain = ChilledRemain(table[1]) 
        end 
        if not Player.Moving and (ATP_BLIZZARD_START == 0 or (remain < 1.5 and ATP_BLIZZARD_TIME > 5000)) then 
            CastBlizzard(POS_BLIZZARD_GATHER_1[4], ATP.Settings.BlizzardLevel_4) 
        end 
        if ATP_BLIZZARD_START ~= 0 and APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_GATHER_1[4] then 
            print( "位置4") 
            GATHER_STEP = 8 
        end 
    end 
    if GATHER_STEP == 8 then 
        if ATP_BLIZZARD_START == 0 or (UnitsChilledLess(1) < 2 and ATP_BLIZZARD_TIME > 5060) then 
            FaceDirection(4.35123062, true) 
            if NearPlayer(15) > 0 then 
                GATHER_STEP = 10 
            else 
                GATHER_STEP = 9 
            end 
        end 
    end 
    if GATHER_STEP == 9 then 
        if not Player.Moving and APT_LAST_BLIZZARD_POSITION ~= POS_BLIZZARD_GATHER_1[5] then 
            CastBlizzard(POS_BLIZZARD_GATHER_1[5], 1) 
        end 
        if ATP_BLIZZARD_START ~= 0 and APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_GATHER_1[5] then 
            print( "缓冲-1") 
            GATHER_STEP = 10 
        end 
    end 
    if GATHER_STEP == 10 then 
        if ATP_BLIZZARD_START == 0 or NearPlayer(10) > 0 then 
            POS_BUFFER = LastTarget() 
            if POS_BUFFER then 
                print( "动态位置") 
                CastBlizzard(POS_BUFFER, 1) 
            else 
                CastBlizzard(POS_BLIZZARD_GATHER_1[6], 1) 
            end 
        end 
        if ATP_BLIZZARD_START ~= 0 and (POS_BUFFER or APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_GATHER_1[6]) then 
            print( "缓冲-2") 
            GATHER_STEP = 11 
        end 
    end 
    if GATHER_STEP == 11 then 
        if ATP_BLIZZARD_START == 0 or ((POS_BUFFER or APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_GATHER_1[6]) and ATP_BLIZZARD_TIME > 1200) or NearPlayer(9) > 0 then 
            if FP_TREE:Move() then 
                FP_TREE:Reset() 
                ChangeTask(SOLO_STATE.COMBAT) 
            else 
                if not Spell.IceBarrier:LastCast() and Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
                end 
            end 
        end 
    end 
    if GATHER_STEP > 3 then 
        if not ATP_NEED_RESET then 
            if ATP.Settings.Mode == 1 then 
                if ImpCount(40) < 8 then 
                    print( "小鬼数量小于5,如翻车重置副本") 
                    ATP_NEED_RESET = true 
                end 
            else if ImpCount(40) < 15 then 
                print( "小鬼数量小于10,如翻车重置副本") 
                ATP_NEED_RESET = true 
            end end end end
    end

    local function Task_ReGather() if FM_REAATHER:Move() then GATHER_STEP = 1 ChangeTask(SOLO_STATE.GATHER_1) end end

    local function Task_Combat() 
        if not ATP_NEED_RESET then 
            if not ATP_NEED_RESET then 
                if ATP.Settings.Mode == 1 then 
                    if ImpCount(40) < 8 then 
                        print( "小鬼数量小于5,如翻车重置副本") 
                        ATP_NEED_RESET = true 
                    end 
                else if ImpCount(40) < 15 then 
                    print( "小鬼数量小于10,如翻车重置副本") 
                    ATP_NEED_RESET = true 
                end 
            end 
        end 
    end 
    
    local Count, Table = NearPlayer(50) 
    if Count > 1 then 
        if COMBAT_STEP == 1 then 
            if not Player.Moving and ATP_BLIZZARD_START == 0 then 
                local Pos = KillImp(8) 
                if Pos then 
                    CastBlizzard(Position(Pos.x, Pos.y, Pos.z)) 
                else 
                    CastBlizzard(POS_BLIZZARD_COMBAT[1]) 
                end 
            end 
            
            if ATP_BLIZZARD_START ~= 0 then 
                print( "小鬼数量:%d", ImpCount(40)) 
                FaceDirection(1.017054438591, true) 
                COMBAT_STEP = 2 
            end 
        end 
        
        if COMBAT_STEP == 2 then  
            if ATP_BLIZZARD_START == 0 or (FIRST_COMBAT and ATP_BLIZZARD_TIME > 5060) or ATP_BLIZZARD_TIME > 6060 then 
                if (Buff.IceBarrier:Remain() > 10 or not Spell.IceBarrier:IsReady()) and Buff.ManaShield:Remain() < 20 and Spell.ManaShield:IsReady() and Spell.ManaShield:Cast() then 
                    return true 
                end 
                
                if not Spell.IceBarrier:LastCast() and Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
                    return true 
                end 
                
                MoveToStep() 
                COMBAT_STEP = 3 
            end 
        end 
        
        if COMBAT_STEP == 3 then 
            if not Player.Moving and ATP_BLIZZARD_START == 0 then 
                if FIRST_COMBAT then 
                    if CastBlizzard(POS_BLIZZARD_COMBAT[2], 1) then 
                        FIRST_COMBAT = false 
                    end 
                else 
                    CastBlizzard(POS_BLIZZARD_COMBAT[2]) 
                end 
            end 
            
            if ATP_BLIZZARD_START ~= 0 and APT_LAST_BLIZZARD_POSITION == POS_BLIZZARD_COMBAT[2] then 
                FaceDirection(4.35123062, true) 
                COMBAT_STEP = 4 
            end 
        end 
        if COMBAT_STEP == 4 then 
            if ATP_BLIZZARD_START == 0 or NearPlayer(7) > 0 then 
                if MoveToTree() then 
                    COMBAT_STEP = 1 
                else 
                    if not Spell.IceBarrier:LastCast() and Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
                        return true 
                    end 
                end 
            end 
        end
    end 
    
    if Count == 1 then 
        local unit = Table[1] 
        if COMBAT_STEP < 3 and (unit.ReachDistance < 15 or unit.PosZ < -49) and unit.PosZ < -48 then 
            if (Buff.IceBarrier:Remain() > 10 or not Spell.IceBarrier:IsReady()) and Buff.ManaShield:Remain() < 20 and Spell.ManaShield:IsReady() and Spell.ManaShield:Cast() then 
                return true 
            end 
            
            if not Spell.IceBarrier:LastCast() and Buff.IceBarrier:Remain() < 10 and Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
                return true 
            end 
            MoveToStep() 
            COMBAT_STEP = 3 
        elseif COMBAT_STEP > 2 and unit.ReachDistance < 15 and unit.PosZ > -41 then 
            if MoveToTree() then 
                COMBAT_STEP = 1 
            else if not Spell.IceBarrier:LastCast() and Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
                return true 
            end 
        end 
    end 
    
    if not Player.Moving then 
        local rank = BestRank("Frostbolt") 
        if Spell.Frostbolt:IsReady(rank) and FacingTarget(unit) and Spell.Frostbolt:Cast(unit, rank) then 
            Delay(550) 
            while Player.Casting do 
                Delay(100) 
            end 
        end 
    end 
end 

if Count == 0 then 
    if (Buff.IceBarrier:Remain() > 10 or not Spell.IceBarrier:IsReady()) and Buff.ManaShield:Remain() < 20 and Spell.ManaShield:IsReady() and Spell.ManaShield:Cast() then 
        return true 
    end 
    
    if not Spell.IceBarrier:LastCast() and Buff.IceBarrier:Remain() < 10 and Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
        return true 
    end 
    
    Count, Table = NearPlayer(4, true) 
    if Count == 0 and FP_COMBAT:Move() then 
        if not Player.Combat then 
            local count = 0 for _, v in pairs(DMW.Units) do 
                if v.Dead then 
                    count = count + 1 
                end 
            end 
            print( "本轮击杀怪物%d", count) 
            ChangeTask(SOLO_STATE.LOOT) 
        end 
    else if Count > 0 then 
        StopMove() 
        if Spell.ArcaneExplosion:IsReady() and Spell.ArcaneExplosion:Cast(Player) then end 
    end 
end 
end  
end

    local function Task_Loot() 
        if ATP.Settings.NotLoot then 
            print( "禁止拾取") 
            ChangeProcess(PROCESS_STATE.EXIT_INSTANCE) 
            return true 
        end 
        
        if FM_LOOT:Move() then 
            if Player:GetFreeBagSlots() == 0 then 
                if not Bag:GeForceDestroyItems(1) then 
                    print( "背包满无灰/白色物品可销毁,放弃使用浮渣覆盖的袋子") ChangeProcess(PROCESS_STATE.EXIT_INSTANCE) 
                    return true 
                end 
            end 
            
            if OPEN_PACK_TIMER > 0 and Bag:ItemExist("浮渣覆盖的袋子") then 
                for _, k in pairs(Bag.Items) do 
                    if k.Name == "浮渣覆盖的袋子" then 
                        OPEN_PACK_TIMER = OPEN_PACK_TIMER - 1 
                        RunMacroText("/use 浮渣覆盖的袋子") 
                        print( "剩余开袋子机会:%d", OPEN_PACK_TIMER) 
                        Delay(2000) 
                        CloseAllWindows() 
                    end 
                end 
            else 
                ChangeProcess(PROCESS_STATE.EXIT_INSTANCE) 
            end 
        end 
    end

    SOLO_ROUTE = { 
        PREPARE = Task_Prepare, 
        LURE = Task_Lure, 
        LURE_EX = Task_Lure_ex, 
        GATHER_1 = Task_Gather_1, 
        REGATHER = Task_ReGather, 
        COMBAT = Task_Combat, 
        LOOT = Task_Loot 
    } 
    
    out.Run = function() 
        if Player:AuraByID(9080) or Player:AuraByID(11876) or Player:AuraByID(15593) or Player:AuraByID(21331) then 
            if Spell.IceBlock:IsReady() and Spell.IceBlock:Cast(Player) then 
                print( "DEBUFF，释放寒冰屏障解除") 
            end 
        end 
        
        if Buff.IceBlock:Exist() then 
            RunMacroText("/cancelAura " .. GetSpellInfo(Spell.IceBlock.SpellID)) 
            
            while Player:HasFlag(DMW.Enums.UnitFlags.Stunned) do 
                Delay(10) 
            end 
        end 
        
        if Player.HP < 50 and Item.SuperiorHealingPotion:IsReady() and Item.SuperiorHealingPotion:InBag() and Item.SuperiorHealingPotion:Use() then 
            print( "使用强效治疗药水") 
        end 
        
        if CURRENT_STATE == SOLO_STATE.COMBAT then 
            if not Player.Casting and ATP_ICE_BARRIER_AMOUNT < 100 and Spell.IceBarrier:CD() > 5 and Spell.ColdSnap:IsReady() then 
                if Spell.ColdSnap:Cast() then 
                    print( "释放急速冷却成功") 
                end 
            end 
        end 
        
        if CURRENT_STATE == SOLO_STATE.GATHER_1 then 
            ATP.Pulse = ATP.Settings.UpdateDelay_1 
        elseif CURRENT_STATE == SOLO_STATE.GATHER_1 then 
            ATP.Pulse = ATP.Settings.UpdateDelay_2 
        elseif CURRENT_STATE == SOLO_STATE.COMBAT then 
            ATP.Pulse = ATP.Settings.UpdateDelay_3 
        else ATP.Pulse = 0 
        end 
        SOLO_ROUTE[CURRENT_STATE]()
    end 
    return out
end

local function Supply() local out = {} local FP_EXIT = FixedPath({ { x = 753.90783691406, y = -621.14678955078, z = -32.990432739258, node = 0 }, }, 1.5, true) local FP_CAVE = FixedPath({
    { x = -1197.228515625, y = 2889.9743652344, z = 86.030281066895, node = 0 }, { x = -1216.5825195313, y = 2899.8178710938, z = 86.167465209961, node = 1 }, { x = -1233.1459960938, y = 2907.8173828125, z = 87.286987304688, node = 2 }, { x = -1274.4450683594, y = 2908.8369140625, z = 87.862754821777, node = 3 }, { x = -1286.3272705078, y = 2926.0964355469, z = 88.115928649902, node = 4 }, { x = -1295.7532958984, y = 2923.4853515625, z = 88.285163879395, node = 5 }, { x = -1307.3150634766, y = 2900.9851074219, z = 88.667488098145, node = 6 }, { x = -1324.4398193359, y = 2879.4995117188, z = 88.587532043457, node = 7 }, { x = -1345.1585693359, y = 2855.1015625, z = 87.541046142578, node = 8 }, { x = -1358.2370605469, y = 2852.0109863281, z = 87.064292907715, node = 9 }, { x = -1373.8304443359, y = 2873.7976074219, z = 90.728591918945, node = 10 }, { x = -1380.7648925781, y = 2901.0192871094, z = 89.043975830078, node = 11 }, { x = -1384.5135498047, y = 2919.6860351563, z = 92.695182800293, node = 12 }, { x = -1411.1411132813, y = 2932.8293457031, z = 95.166351318359, node = 13 }, { x = -1424.0966796875, y = 2955.1362304688, z = 96.200889587402, node = 14 }, { x = -1427.8107910156, y = 2977.5673828125, z = 100.45086669922, node = 15 }, { x = -1413.5487060547, y = 2979.3686523438, z = 101.58306884766, node = 16 }, { x = -1398.7265625, y = 2981.2595214844, z = 106.06832885742, node = 17 }, { x = -1398.435546875, y = 2989.2724609375, z = 106.35871887207, node = 18 }, { x = -1428.43359375, y = 2990.7514648438, z = 115.14781188965, node = 19 }, { x = -1438.0081787109, y = 3000.2275390625, z = 115.28770446777, node = 20 }, { x = -1451.3765869141, y = 2992.8625488281, z = 114.92600250244, node = 21 }, { x = -1487.73828125, y = 2971.4838867188, z = 119.02870178223, node = 22 }, { x = -1490.3297119141, y = 2960.1918945313, z = 120.94134521484, node = 23 }, { x = -1487.7290039063, y = 2952.8566894531, z = 121.35816955566, node = 24 }, { x = -1466.7634277344, y = 2953.4704589844, z = 122.16088104248, node = 25 }, { x = -1440.8970947266, y = 2958.4270019531, z = 124.19808197021, node = 26 }, { x = -1414.7874755859, y = 2960.0571289063, z = 124.5036315918, node = 27 }, { x = -1405.0040283203, y = 2965.962890625, z = 126.87750244141, node = 28 }, { x = -1402.8516845703, y = 2978.0622558594, z = 129.84881591797, node = 29 }, { x = -1416.2529296875, y = 2986.1127929688, z = 131.84045410156, node = 30 }, { x = -1421.62890625, y = 2983.4929199219, z = 133.15423583984, node = 31 }, { x = -1425.5311279297, y = 2963.4387207031, z = 134.55429077148, node = 32 }, { x = -1424.3782958984, y = 2935.2036132813, z = 135.35877990723, node = 33 }, { x = -1422.7427978516, y = 2919.3811035156, z = 136.20347595215, node = 34 }, { x = -1420.4649658203, y = 2889.5544433594, z = 132.89823913574, node = 35 }, { x = -1420.6968994141, y = 2881.9189453125, z = 132.56176757813, node = 36 },
}, 1.5, true) local FP_HORDE_TOWN = FixedPath({ { x = -1559.964233, y = 2893.920410, z = 113.094894, node = 3 }, { x = -1665.7062988281, y = 3084.3530273438, z = 30.447952270508, node = 3 }, }, 2, true) local FP_ALLIANCE_TOWN = FixedPath({ { x = -1184.601440, y = 2781.319092, z = 111.180641, node = 0 }, { x = -1175.635620, y = 2729.212646, z = 111.479103, node = 0 }, { x = -1376.672974, y = 2457.328857, z = 88.859634, node = 0 }, { x = -29.915306, y = 1198.095825, z = 100.082611, node = 0 }, }, 2, true) local FP_ALLIANCE_SUPPLY_NPC = FixedPath({ { x = 246.1639251709, y = 1262.2932128906, z = 192.16372680664, node = 1 }, { x = 226.16812133789, y = 1289.2593994141, z = 190.0341796875, node = 2 }, { x = 208.48878479004, y = 1274.1743164063, z = 190.52438354492, node = 3 }, { x = 192.77297973633, y = 1249.5145263672, z = 178.85913085938, node = 4 }, { x = 169.71820068359, y = 1206.5511474609, z = 166.18746948242, node = 5 }, { x = 181.10084533691, y = 1182.4008789063, z = 166.09317016602, node = 6 }, { x = 201.6139831543, y = 1179.1303710938, z = 167.99867248535, node = 7 }, }, 2) local FP_HORDE_SUPPLY_NPC = FixedPath({ { x = -1605.4113769531, y = 3130.6186523438, z = 47.071521759033, node = 0 }, { x = -1617.180420, y = 3113.745850, z = 42.740662, node = 1 }, { x = -1627.4135742188, y = 3099.8742675781, z = 36.071754455566, node = 2 }, { x = -1665.7062988281, y = 3084.3530273438, z = 30.447952270508, node = 3 }, { x = -1675.480835, y = 3074.993896, z = 34.536400, node = 4 }, }, 2, true) 

local FP_ALLIANCE_STUCK = FixedPath({ { x = 255.293350, y = 1259.861694, z = 192.139221 } }, 0.5) 

local TOWN = nil 
local SUPPLY_ZONE = nil 
local SUPPLY_NPC_NAME = nil 
local SUPPLY_NPC_PATH = nil 
local IsRepaired = false 

local function IsSell(TempItem) 
    if TempItem.NoValue then 
        return false 
    end 
    if TempItem.Name == ATP.Settings.WaterName then 
        if TempItem.BagID ~= 0 or TempItem.Slot > 4 then 
            return true 
        end 
        return false 
    end 
    
    if TempItem.Name == ATP.Settings.FoodName then 
        if TempItem.BagID ~= 0 or TempItem.Slot > 6 then 
            return true 
        end 
        return false 
    end 
    
    if ATP.Settings.BagItems then 
        for _, v in pairs(ATP.Settings.BagItems) do 
            if string.find(TempItem.Name, v) then 
                return false 
            end 
        end 
    end 
    
    if ATP.Settings.MailItems then 
        for _, v in pairs(ATP.Settings.MailItems) do 
            if string.find(TempItem.Name, v) then 
                return false 
            end 
        end 
    end 
    
    if not IsSoulBound(TempItem.BagID, TempItem.Slot) and ((ATP.Settings.Rarity3 and TempItem.Rarity == 3) or (ATP.Settings.Rarity4 and TempItem.Rarity == 4)) then 
        return false 
    end 
    return true 
end

    out.Reset = function() 
        print("重置。。。。。。。。。。。。。2");
        TOWN = nil 
        SUPPLY_ZONE = nil 
        SUPPLY_NPC_NAME = nil 
        SUPPLY_NPC_PATH = nil 
        IsRepaired = false 
        FP_EXIT:Reset() 
        FP_CAVE:Reset() 
        FP_ALLIANCE_TOWN:Reset() 
        FP_HORDE_TOWN:Reset() 
        FP_ALLIANCE_SUPPLY_NPC:Reset() 
        FP_HORDE_SUPPLY_NPC:Reset() 
        FP_ALLIANCE_STUCK:Reset() 
    end 
    
    out.Run = function() 
        if not TOWN then 
            if Player.Faction == "Horde" then 
                SUPPLY_NPC_PATH = FP_HORDE_SUPPLY_NPC 
                TOWN = FP_HORDE_TOWN 
                SUPPLY_ZONE = CONST_STRING.HordeSupplyZoneText 
                SUPPLY_NPC_NAME = CONST_STRING.HordeSupplyNpcName 
            else 
                SUPPLY_NPC_PATH = FP_ALLIANCE_SUPPLY_NPC 
                TOWN = FP_ALLIANCE_TOWN 
                SUPPLY_ZONE = CONST_STRING.AllianceSupplyZoneText 
                SUPPLY_NPC_NAME = CONST_STRING.AllianceSupplyNpcName 
            end 
            
            local CD = GetHearthstoneCD() 
            if CD < 60 then 
                print( "炉石冷却%d秒，等待", CD) 
                Delay(CD * 1010) 
                RunMacroText("/use " .. CONST_STRING.Hearthstone) 
                Delay(1000) 
                
                while Player.Casting do 
                    Delay(500) 
                end 
            end 
        else if not IsMounted() then 
            if Buff.IceArmor:Remain() < 1200 and Spell.IceArmor:IsReady() and Spell.IceArmor:Cast() then 
                print( "释放冰甲术成功") 
            end if not Buff.IceBarrier:Exist() and Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
                print( "释放寒冰护体") 
            end 
        end 
        
        if PLAYER_ENTERING_WORLD then 
            PLAYER_ENTERING_WORLD = false 
            print( "场景切换等待2秒") Delay(2000) 
        end 
        
        if CONST_STRING.ZoneInstanceText == GetZoneText() then 
            if Player.Instance == "party" then 
                if FP_EXIT:NavMove() then 
                    MoveForwardStart() 
                    Delay(2000) 
                    MoveForwardStop() 
                    Delay(1000) 
                end 
            else 
                FP_CAVE:NavMove() 
                if FP_CAVE.Index == 34 or FP_CAVE.Index == 35 then 
                    for _, k in pairs(DMW.GameObjects) do 
                        if k.Distance < 5 and ObjectDisplayID(k.Pointer) == 4791 then 
                            ObjectInteract(k.Pointer) 
                            break 
                        end 
                    end 
                end 
            end 
        elseif SUPPLY_ZONE == GetSubZoneText() then 
            if ATP.IsInRegion(Player.PosX, Player.PosY, { { x = 257.697, y = 1262.587, z = 193.027 }, { x = 252.404, y = 1260.991, z = 192.141 }, { x = 251.742, y = 1259.401, z = 192.143 }, { x = 252.660, y = 1254.243, z = 192.148 }, { x = 254.181, y = 1249.283, z = 192.142 }, { x = 255.417, y = 1248.162, z = 192.141 }, { x = 260.918, y = 1249.101, z = 192.914 } }) then 
                if FP_ALLIANCE_STUCK:Move() then 
                    FaceDirection(1.86796, true) 
                    MoveForwardStart() 
                    Delay(150) 
                    JumpOrAscendStart() 
                    AscendStop() 
                    Delay(1000) 
                    MoveForwardStop() 
                end 
            
            else if SUPPLY_NPC_PATH:NavMove() then 
                if not Target or Target.Name ~= SUPPLY_NPC_NAME then 
                    for _, TempUnit in pairs(DMW.Units) do 
                        if TempUnit.Name == SUPPLY_NPC_NAME then 
                            TargetUnit(TempUnit.Pointer) 
                            break 
                        end 
                    end 
                else if not MerchantFrame:IsShown() then 
                    ObjectInteract(Target.Pointer) 
                    Delay(1000) 
                else 
                    local count = 0 for _, v in pairs(Bag.Items) do 
                        if IsSell(v) then 
                            count = count + 1 
                            UseContainerItem(v.BagID, v.Slot) Delay(100) 
                            if count > 9 then 
                                break 
                            end 
                        end 
                    end 
                    
                    if count == 0 then 
                        if not IsRepaired then 
                            RepairAllItems() 
                            IsRepaired = true 
                            Delay(500) 
                        end 
                        CloseMerchant() 
                        
                        if ATP.Settings.EnableMail then 
                            ChangeProcess(PROCESS_STATE.MAIL) 
                        else 
                            ChangeProcess(PROCESS_STATE.GOTO_INSTANCE) 
                        end 
                    end 
                end 
            end 
        else if SUPPLY_NPC_PATH.Index > 2 and SUPPLY_NPC_PATH.Index < 6 then 
            Mount() 
        end 
    end
    end else 
        TOWN:NavMove() 
        Mount()
    end
    end
    end return out
end

local function Mail() local out = {} local FP_ALLIANCE_MAIL = FixedPath({ { x = 175.786591, y = 1181.954590, z = 166.206955, node = 1 }, { x = 171.66279602051, y = 1226.8649902344, z = 167.50204467773, node = 2 }, { x = 195.74557495117, y = 1242.3563232422, z = 180.27439880371, node = 3 }, { x = 207.22557067871, y = 1265.0812988281, z = 190.48210144043, node = 4 }, { x = 219.95957946777, y = 1289.0776367188, z = 190.39556884766, node = 5 }, { x = 247.01016235352, y = 1291.7928466797, z = 190.5594329834, node = 6 }, }, 2, true) local FP_HORDE_MAIL = FixedPath({ { x = -1667.3774414063, y = 3084.8557128906, z = 30.538818359375, node = 0 }, { x = -1647.2806396484, y = 3089.8220214844, z = 30.878978729248, node = 1 }, { x = -1622.4598388672, y = 3103.5979003906, z = 38.59907913208, node = 2 }, { x = -1609.7840576172, y = 3117.9523925781, z = 44.717292785645, node = 3 }, }, 2, true) 
    
    local MAIL = nil 
    local MailBox = nil 
    local TaskDone = false 
    
    local function IsMail(TempItem)
        if TempItem.Name == ATP.Settings.FoodName then 
            return false 
        end 
        if TempItem.Name == ATP.Settings.WaterName then 
            return false 
        end 
        if TempItem.Name == ATP.Settings.MountName then 
            return false 
        end 
        if ATP.Settings.BagItems then 
            for _, v in pairs(ATP.Settings.BagItems) do 
                if string.find(TempItem.Name, v) then 
                    return false 
                end 
            end 
        end 
        if IsSoulBound(TempItem.BagID, TempItem.Slot) then 
            return false 
        end 
        return true 
    end

    local function SendGold() 
        if not ATP.Settings.GoldUpperLimit or ATP.Settings.GoldUpperLimit < 0 then 
            ATP.Settings.GoldUpperLimit = 0 
        end 
        local money = GetMoney() 
        local limit = (ATP.Settings.RemainGold + ATP.Settings.GoldUpperLimit) * 10000 if money > limit then 
            SetSendMailMoney(money - ATP.Settings.RemainGold * 10000) 
            print("ffffff", "邮寄金币" .. GetCoinTextureString(money - ATP.Settings.RemainGold * 10000)) 
        end 
        Delay(2000) 
        SendMail(ATP.Settings.Addressee, "gold", "") 
    end

    out.Reset = function() 
        print("重置。。。。。。。。。。。。。3");
        MAIL = nil 
        MailBox = nil 
        TaskDone = false 
        FP_ALLIANCE_MAIL:Reset() 
        FP_HORDE_MAIL:Reset() 
    end 
    
    out.Run = function() 
        if not MAIL then 
            if Player.Faction == "Horde" then 
                MAIL = FP_HORDE_MAIL 
            else 
                MAIL = FP_ALLIANCE_MAIL 
            end 
        end 
        
        if not ATP.Settings.Addressee or ATP.Settings.Addressee == "" then 
            print( "未设置收件人") 
            ChangeProcess(PROCESS_STATE.TAXI) 
        else if MAIL.Index > 1 then 
            Mount() 
        end 
        
        if MAIL:NavMove() then 
            if not MailBox then 
                for _, TempUnit in pairs(DMW.GameObjects) do 
                    if TempUnit.Name == CONST_STRING.Mailbox then 
                        MailBox = TempUnit 
                        break 
                    end 
                end 
            else if not MailFrame:IsShown() then 
                ObjectInteract(MailBox.Pointer) 
                Delay(1000) 
            else if MailFrame.selectedTab == 1 then 
                MailFrameTab2:Click() 
            end 
            local count = 0 for _, v in pairs(Bag.Items) do 
                if IsMail(v) then 
                    count = count + 1 
                    UseContainerItem(v.BagID, v.Slot) 
                    Delay(500) 
                    if count == 12 then 
                        break 
                    end 
                end 
            end 
            local total = 0 for i = 1, ATTACHMENTS_MAX_SEND do 
                if GetSendMailItemLink(i) then 
                    total = total + 1 
                end 
            end 
            if total == ATTACHMENTS_MAX_SEND then 
                if GetMoney() >= total * 30 then 
                    SendMail(ATP.Settings.Addressee, GetSendMailItem(1), "") 
                    print( "邮寄%d个物品", total) 
                    Delay(1000) 
                else 
                    print("ff000", "邮寄费用不够") 
                    TaskDone = true 
                end 
            elseif total > 0 and total < ATTACHMENTS_MAX_SEND then 
                if GetMoney() >= total * 30 then 
                    SendMail(ATP.Settings.Addressee, GetSendMailItem(1), "") 
                    print( "邮寄%d个物品", total) 
                    Delay(1000) 
                end 
                
                TaskDone = true 
            else 
                TaskDone = true 
            end 
            if TaskDone then 
                if ATP.Settings.SendGold then 
                    Delay(math.random(2000, 5000)) 
                    SendGold() 
                end 
                CloseMail() 
                print( "邮寄完成") 
                ChangeProcess(PROCESS_STATE.GOTO_INSTANCE) 
            end
    end
    end
    end
    end
    end return out
end

local function GotoInstance() 
    local out = {} 
    local FP_TO_INSTANCE_CAVE = FixedPath({
    { x = -1422.8962401094, y = 2923.56982420313, z = 136.36808814453, node = 0 }, { x = -1425.0974121094, y = 2937.9340820313, z = 135.11309814453, node = 0 }, { x = -1430.2399902344, y = 2947.3159179688, z = 134.59143066406, node = 1 }, { x = -1448.5903320313, y = 2956.8503417969, z = 124.08094787598, node = 2 }, { x = -1472.0059814453, y = 2960.0764160156, z = 121.7999420166, node = 3 }, { x = -1474.4381103516, y = 2981.1130371094, z = 117.2380065918, node = 4 }, { x = -1440.1779785156, y = 2999.2492675781, z = 115.26843261719, node = 5 }, { x = -1429.9906005859, y = 2984.33203125, z = 115.15277099609, node = 6 }, { x = -1429.7142333984, y = 2970.9208984375, z = 99.914321899414, node = 7 }, { x = -1414.5109863281, y = 2936.0322265625, z = 95.258407592773, node = 8 }, { x = -1383.6011962891, y = 2915.7229003906, z = 92.062576293945, node = 9 }, { x = -1375.1783447266, y = 2880.4116210938, z = 90.423522949219, node = 10 }, { x = -1361.2800292969, y = 2857.5556640625, z = 88.29061126709, node = 11 }, { x = -1351.0166015625, y = 2850.3894042969, z = 87.236480712891, node = 12 }, { x = -1334.8046875, y = 2864.7707519531, z = 87.817695617676, node = 13 }, { x = -1308.2789306641, y = 2899.30859375, z = 88.706748962402, node = 14 }, { x = -1295.5952148438, y = 2920.7302246094, z = 88.361763000488, node = 15 }, { x = -1288.9558105469, y = 2925.4123535156, z = 88.201721191406, node = 16 }, { x = -1278.8754882813, y = 2918.2045898438, z = 87.928436279297, node = 17 }, { x = -1270.0025634766, y = 2905.0349121094, z = 87.78995513916, node = 18 }, { x = -1242.8426513672, y = 2904.4689941406, z = 86.826309204102, node = 19 }, { x = -1214.0223388672, y = 2898.732421875, z = 86.045944213867, node = 20 }, { x = -1196.7885742188, y = 2886.1545410156, z = 85.983383178711, node = 21 }, { x = -1188.8582763672, y = 2878.8071289063, z = 85.751510620117, node = 22 },
}, 1.5, true) 

local FP_ALLIANCE_TO_INSTANCE = FixedPath({ 
    { x = -1175.635620, y = 2729.212646, z = 111.479103, node = 0 }, 
    { x = -1190.241699, y = 2797.076660, z = 112.030327, node = 0 }, 
    { x = -1420.571411, y = 2890.588379, z = 132.912918, node = 0 }, }, 2, true) 
    
    local FP_HORDE_TO_INSTANCE = FixedPath({ 
        { x = -1420.571411, y = 2890.588379, z = 132.912918, node = 0 }, }, 2, true) 
        
        local FP_TO_INSTANCE = nil 
        out.Reset = function() 
            print("重置。。。。。。。。。。。。。4");
            FP_TO_INSTANCE = nil 
            FP_ALLIANCE_TO_INSTANCE:Reset() 
            FP_HORDE_TO_INSTANCE:Reset() 
            FP_TO_INSTANCE_CAVE:Reset() 
        end 
        
        out.Run = function() 
            if not FP_TO_INSTANCE then 
                if Player.Faction == "Horde" then 
                    FP_TO_INSTANCE = FP_HORDE_TO_INSTANCE 
                else 
                    FP_TO_INSTANCE = FP_ALLIANCE_TO_INSTANCE 
                end 
            
            else if not IsMounted() then 
                if Buff.IceArmor:Remain() < 1200 and Spell.IceArmor:IsReady() and Spell.IceArmor:Cast() then 
                    print( "释放冰甲术成功") 
                end 
                
                if not Buff.IceBarrier:Exist() and Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
                end 
            end 
            
            if CONST_STRING.ZoneInstanceText == GetZoneText() or FP_TO_INSTANCE:NavMove() then 
                if FP_TO_INSTANCE_CAVE:Move() then 
                    ChangeProcess(PROCESS_STATE.RESET_INSTANCE) 
                else if FP_TO_INSTANCE_CAVE.Index == 1 or FP_TO_INSTANCE_CAVE.Index == 2 then 
                    for _, k in pairs(DMW.GameObjects) do if k.Distance < 5 and ObjectDisplayID(k.Pointer) == 4791 then 
                        Dismount() ObjectInteract(k.Pointer) 
                        break 
                    end 
                end 
            end 
        end 
    else if FP_TO_INSTANCE.Index == 1 then 
        Mount() 
    end end end end 
    return out
end

local function TownToInstance() local out = {} local FP_ALLIANCE_GOTO_INSTANCE = FixedPath({
    { x = -5377.42578125, y = -2972.5124511719, z = 323.16845703125, node = 0 }, { x = -5365.0043945313, y = -2969.1716308594, z = 326.77969360352, node = 1 }, { x = -5369.5961914063, y = -2953.3505859375, z = 323.67135620117, node = 2 }, { x = -5385.0673828125, y = -2927, z = 332.92776489258, node = 3 }, { x = -5400.9736328125, y = -2923.4992675781, z = 339.54806518555, node = 4 }, { x = -5424.578125, y = -2951.5642089844, z = 345.95294189453, node = 5 }, { x = -5437.87109375, y = -2991.3254394531, z = 355.42987060547, node = 6 }, { x = -5453.376953125, y = -3022.8894042969, z = 356.60565185547, node = 7 }, { x = -5464.9111328125, y = -3059.1833496094, z = 352.05017089844, node = 8 }, { x = -5481.1171875, y = -3077.4206542969, z = 350.80032348633, node = 9 }, { x = -5508.5590820313, y = -3106.2612304688, z = 345.82238769531, node = 10 }, { x = -5580.611328125, y = -3158.8542480469, z = 330.48812866211, node = 11 }, { x = -5646.513671875, y = -3204.8505859375, z = 325.73205566406, node = 12 }, { x = -5711.56640625, y = -3242.0153808594, z = 313.3424987793, node = 13 }, { x = -5745.0610351563, y = -3259.0432128906, z = 309.71276855469, node = 14 }, { x = -5791.15234375, y = -3271.6765136719, z = 299.01388549805, node = 15 }, { x = -5843.935546875, y = -3277.3669433594, z = 295.05892944336, node = 16 }, { x = -5901.673828125, y = -3285.3525390625, z = 287.63687133789, node = 17 }, { x = -5968.4897460938, y = -3293.533203125, z = 272.79830932617, node = 18 }, { x = -6041.6982421875, y = -3312.4260253906, z = 257.74719238281, node = 19 }, { x = -6102.0390625, y = -3338.28515625, z = 253.49481201172, node = 20 }, { x = -6160.9331054688, y = -3383.3037109375, z = 243.10452270508, node = 21 }, { x = -6237.2680664063, y = -3461.0432128906, z = 240.25871276855, node = 22 }, { x = -6263.3466796875, y = -3482.0270996094, z = 251.26318359375, node = 23 }, { x = -6304.7797851563, y = -3499.7346191406, z = 249.24169921875, node = 24 }, { x = -6334.5815429688, y = -3539.2646484375, z = 241.6809387207, node = 25 }, { x = -6349.9956054688, y = -3585.7517089844, z = 241.67155456543, node = 26 }, { x = -6383.7275390625, y = -3636.0070800781, z = 242.01200866699, node = 27 }, { x = -6451.8227539063, y = -3658.6145019531, z = 243.0505065918, node = 28 }, { x = -6552.5844726563, y = -3640.8684082031, z = 244.39126586914, node = 29 }, { x = -6581.4501953125, y = -3654.0952148438, z = 253.70764160156, node = 30 }, { x = -6593.3208007813, y = -3673.5236816406, z = 262.4089050293, node = 31 }, { x = -6612.6733398438, y = -3709.8972167969, z = 267.65869140625, node = 32 }, { x = -6616.4599609375, y = -3718.0268554688, z = 268.80313110352, node = 33 }, { x = -6630.791015625, y = -3723.9497070313, z = 267.37048339844, node = 34 }, { x = -6636.9477539063, y = -3739.93359375, z = 265.20349121094, node = 35 }, { x = -6634.9033203125, y = -3758.9440917969, z = 266.06521606445, node = 36 }, { x = -6624.4809570313, y = -3765.7458496094, z = 266.22201538086, node = 37 },
}, 3, true) local FP_HORDE_GOTO_INSTANCE = FixedPath({
    { x = -6666.9838867188, y = -2172.1479492188, z = 245.3729095459, node = 0 }, { x = -6672.60546875, y = -2180.3791503906, z = 243.90158081055, node = 1 }, { x = -6627.052734375, y = -2224.3923339844, z = 244.14366149902, node = 2 }, { x = -6606.669921875, y = -2299.0612792969, z = 244.14366149902, node = 3 }, { x = -6598.3940429688, y = -2347.5578613281, z = 244.25566101074, node = 4 }, { x = -6615.0776367188, y = -2369.3444824219, z = 244.24868774414, node = 5 }, { x = -6616.2998046875, y = -2410.5375976563, z = 245.37187194824, node = 6 }, { x = -6645.6015625, y = -2473.4775390625, z = 244.49658203125, node = 7 }, { x = -6774.1508789063, y = -2757.5119628906, z = 241.97062683105, node = 8 }, { x = -6807.6362304688, y = -2819.029296875, z = 242.24906921387, node = 9 }, { x = -6815.83203125, y = -2843.2287597656, z = 241.66667175293, node = 10 }, { x = -6826.4399414063, y = -2966.7192382813, z = 246.39083862305, node = 11 }, { x = -6780.6220703125, y = -3076.8774414063, z = 244.48320007324, node = 12 }, { x = -6759.5390625, y = -3122.8352050781, z = 243.48783874512, node = 13 }, { x = -6749.5546875, y = -3173.5380859375, z = 246.61152648926, node = 14 }, { x = -6722.0087890625, y = -3217.2587890625, z = 244.25843811035, node = 15 }, { x = -6704.576171875, y = -3261.8891601563, z = 240.74365234375, node = 16 }, { x = -6703.57421875, y = -3339.2546386719, z = 241.18878173828, node = 17 }, { x = -6683.0185546875, y = -3485.2824707031, z = 253.74125671387, node = 18 }, { x = -6648.0141601563, y = -3581.9658203125, z = 241.66725158691, node = 19 }, { x = -6614.4916992188, y = -3646.5693359375, z = 251.05111694336, node = 20 }, { x = -6606.2734375, y = -3658.568359375, z = 255.40629577637, node = 21 }, { x = -6607.8564453125, y = -3679.6123046875, z = 264.49731445313, node = 22 }, { x = -6610.6235351563, y = -3706.2702636719, z = 267.51919555664, node = 23 }, { x = -6619.7407226563, y = -3718.9780273438, z = 268.73266601563, node = 24 }, { x = -6631.1684570313, y = -3725.7795410156, z = 267.29138183594, node = 25 }, { x = -6636.1684570313, y = -3735.3447265625, z = 265.6462097168, node = 26 }, { x = -6635.4868164063, y = -3754.8657226563, z = 266.39651489258, node = 27 }, { x = -6624.2084960938, y = -3765.9350585938, z = 266.30606079102, node = 28 },
}, 3, true) 

local GOTO_INSTANCE = nil 

out.Reset = function() 
    print("重置。。。。。。。。。。。。。6");
    GOTO_INSTANCE = nil 
    FP_ALLIANCE_GOTO_INSTANCE:Reset() 
    FP_HORDE_GOTO_INSTANCE:Reset() 
end 

out.Run = function() 
    if Player.Faction == "Horde" then 
        GOTO_INSTANCE = FP_HORDE_GOTO_INSTANCE 
    else 
        GOTO_INSTANCE = FP_ALLIANCE_GOTO_INSTANCE 
    end 
    
    if GOTO_INSTANCE:UnStuckMove() then 
        ChangeProcess(PROCESS_STATE.RESET_INSTANCE) 
    else if not IsMounted() then 
        if not Buff.IceBarrier:Exist() and Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
            return true  
        end 
    end 
    Mount() 
end end return out
end

local function EnterInstance() 
    local out = {} 
    local IsSendMsg = false 
    local FP_ENTER = FixedPath({ { x = -1183.4114990234, y = 2875.0837402344, z = 85.824409484863, node = 0 }, { x = -1182.9838867188, y = 2865.9333496094, z = 85.434700012207, node = 1 }, }, 1.5) 
    
    out.Reset = function() 
        print("重置。。。。。。。。。。。。。7");
        FP_ENTER:Reset() 
        IsSendMsg = false 
        print("ffffff", "当前资产:%s", GetCoinTextureString(Assets())) 
    end 
    
    out.Run = function() 
        if TOO_MANY_INSTANCES then 
            TOO_MANY_INSTANCES = false 
            print( "爆本，30秒后尝试进本.") 
            RunMacroText("/sit") 
            for i = 1, 30 do 
                Delay(1000) 
                if Player.Combat then 
                    break 
                end 
            end 
        elseif PLAYER_ENTERING_WORLD then 
            PLAYER_ENTERING_WORLD = false 
            print( "场景切换等待2秒") 
            Delay(2000) 
        else if Player.Instance == "none" then 
            if not IsSendMsg then 
                SendPartyMessage(ATP.Settings.EnterFollow) 
                IsSendMsg = true 
            end 
            
            if FP_ENTER:Move() then 
                MoveForwardStart() 
                Delay(500) 
                MoveForwardStop() 
                Delay(1000) 
                FP_ENTER:Reset() 
            end 
        else 
            ChangeProcess(PROCESS_STATE.START_SOLO) 
        end 
    end 
end 
return out 
end

local function ExitInstance() 
    local out = {} 
    local EXIT_STEP = 0 
    local IsSendMsg = false 
    local FP_EXIT = FixedPath({ { x = 753.90783691406, y = -621.14678955078, z = -32.990432739258, node = 0 }, }, 1.5, true) 
    
    out.Reset = function() 
        print("重置。。。。。。。。。。。。。8");
        EXIT_STEP = 0 
        IsSendMsg = false 
        FP_EXIT:Reset() 
        print("ffffff", "当前资产:%s", GetCoinTextureString(Assets())) 
    end 
    
    out.Run = function() 
        if PLAYER_ENTERING_WORLD then 
            PLAYER_ENTERING_WORLD = false 
            print( "场景切换等待2秒") 
            Delay(2000) 
        else if Player.Instance == "none" then 
            ChangeProcess(PROCESS_STATE.RESET_INSTANCE) 
        else if Buff.IceArmor:Remain() < 1200 and Spell.IceArmor:IsReady() and Spell.IceArmor:Cast() then 
            print( "释放冰甲术成功") 
        end 
        
        if FP_EXIT:NavMove() then 
            local to = InstanceTimer.Timeout(4) 
            if Player:GetFreeBagSlots() > ATP.Settings.FreeBagSlots then 
                if to > 60 and to < 600 then 
                    ChangeProcess(PROCESS_STATE.TIMEOUT) 
                    return true 
                elseif to < 60 then 
                    print( "爆本等待%d秒", to) Delay(to * 1000) 
                end 
            end 
            
            if not IsSendMsg then 
                SendPartyMessage(ATP.Settings.ExitFollow) 
                IsSendMsg = true 
            end 
            MoveForwardStart() 
            Delay(2000) 
            MoveForwardStop() 
            Delay(1000) 
        else if not Buff.IceBarrier:Exist() and Spell.IceBarrier:IsReady() and Spell.IceBarrier:Cast() then 
            print( "释放寒冰护体成功") 
            return true 
        end end end end end return out
end

local function ResetInstance() 
    local out = {} 
    local FP_ENTER = FixedPath({ 
        { x = -1183.4114990234, y = 2875.0837402344, z = 85.824409484863, node = 0 }, { x = -1182.9838867188, y = 2865.9333496094, z = 85.434700012207, node = 1 }, }, 1.5, true) 
        
        local IsReset = false 
        out.Reset = function() 
            print("重置。。。。。。。。。。。。。9");
            IsReset = false 
            FP_ENTER:Reset() 
        end 
        
        out.Run = function() 
            if Player.Instance == "none" then 
                if IsReset then 
                    if PLAYER_ENTERING_WORLD then 
                        PLAYER_ENTERING_WORLD = false 
                        print( "场景切换等待2秒") 
                        Delay(2000) 
                    else 
                        ChangeProcess(PROCESS_STATE.ENTER_INSTANCE) 
                    end 
                else if NeedRepair(25) then 
                    print( "持久不足维修,副本将本重置") 
                    ChangeProcess(PROCESS_STATE.SUPPLY) 
                else 
                    local to = InstanceTimer.Timeout(4) 
                    if to < 20 then 
                        if Player:GetFreeBagSlots() < ATP.Settings.FreeBagSlots then 
                            print( "背包空格小于%d，售卖", ATP.Settings.FreeBagSlots) ChangeProcess(PROCESS_STATE.SUPPLY) 
                        else 
                            IsReset = true 
                            ResetInstances() 
                            if to > 0 then 
                                print( "距离下次副本刷新%s秒,等待", to) 
                                Delay(to * 1000) 
                            end 
                        end 
                    
                    elseif to > 600 then 
                        ChangeProcess(PROCESS_STATE.SUPPLY) 
                    else 
                        ChangeProcess(PROCESS_STATE.TIMEOUT) 
                    end end end end end return out
end

local function Timeout() 
    local out = {} 
    local FP_WAIT = FixedPath({ 
        { x = 759.63513183594, y = -610.75122070313, z = -32.592868804932, node = 0 }, { x = 751.60797119141, y = -598.09271240234, z = -33.233413696289, node = 1 }, { x = 748.93121337891, y = -609.42797851563, z = -33.218963623047, node = 2 }, }, 1.5) 
        
    local FP_ENTER = FixedPath({ 
        { x = -1183.4114990234, y = 2875.0837402344, z = 85.824409484863, node = 0 }, { x = -1182.9838867188, y = 2865.9333496094, z = 85.434700012207, node = 1 }, }, 1.5, true) 
        
    local POS_CENTER = Position(752.319397, -604.496216, -33.250015) 
    local time = 0 
    local doBandage = true 
    local IsSendMsg = false 
    
    out.Reset = function() 
        print("重置。。。。。。。。。。。。。10");
        time = 0 
        FP_WAIT:Reset() 
        doBandage = true 
        IsSendMsg = true 
    end 
    
    out.Run = function() 
        if PLAYER_ENTERING_WORLD then 
            PLAYER_ENTERING_WORLD = false 
            print( "场景切换等待2秒") 
            Delay(2000) 
        end 
        if Player.Instance == "none" then 
            if not IsSendMsg then 
                SendPartyMessage(ATP.Settings.EnterFollow) 
                IsSendMsg = true 
            end 
            if FP_ENTER:NavMove() then 
                MoveForwardStart() 
                Delay(500) 
                MoveForwardStop() 
                Delay(1000) 
                FP_ENTER:Reset() 
            end 
        else 
            local to = InstanceTimer.Timeout(4) 
            if to ~= 0 then 
                local x, y, z = ATP.RandomPoint(POS_CENTER.X, POS_CENTER.Y, POS_CENTER.Z, 12) 
                if x and y and z then 
                    MoveTo(x, y, z) 
                    local m = math.random(1, 3) 
                    if m == 1 then 
                        JumpOrAscendStart() 
                        AscendStop() 
                    elseif m == 2 then 
                        if Spell.ArcaneExplosion:IsReady(1) and Spell.ArcaneExplosion:Cast(Player, 1) then 
                        end 
                    else if not Spell.FrostNova:LastCast() and Spell.FrostNova:IsReady() and Spell.FrostNova:Cast(Player, 1) then 
                    end 
                end 
                print( "爆本等待%s秒", to) 
                local r = math.random(10, 30) 
                Delay(r * 1000) 
            end 
        else 
            ChangeProcess(PROCESS_STATE.EXIT_INSTANCE) 
        end end end return out
end

local function Resurrection() 
    local out = {} 
    local CORPSE_PATH = { 
        { x = -1175.731567, y = 2736.417236, z = 111.752739 }, 
        { x = -1416.323242, y = 2887.026367, z = 132.790710 }, 
        { x = -1416.323242, y = 2887.026367, z = 132.790710 }, 
        { x = -1182.9838867188, y = 2865.9333496094, z = 85.434700012207, node = 1 }, 
    } 
    local DeadZone = 0 
    local CorpsePaths = nil 
    local CorpsePosX, CorpsePosY, CorpsePosZ 
    local IsReset = false 
    
    out.Reset = function() 
        print("重置。。。。。。。。。。。。。11");
        DeadZone = 0 
        CorpsePaths = nil 
        CorpsePosX, CorpsePosY, CorpsePosZ = nil, nil, nil 
        IsReset = false 
    end 
    
    out.Run = function() 
        if UnitIsDead("player") then 
            Delay(2000) Scorpio.Next() 
            
            if DeadZone == 0 then 
                if Player.Instance == "party" then 
                    DeadZone = 1 
                else 
                    DeadZone = 2 
                end 
            end 
            
            print( "等待释放,复活路线-%d", DeadZone) 
            Delay(3000) 
            RepopMe() 
            Delay(5000) 
        end 
        
        if not CorpsePaths and UnitIsGhost("player") then 
            if DeadZone == 0 or DeadZone == 1 then 
                CorpsePaths = FixedPath(CORPSE_PATH, 2, true) 
            elseif DeadZone == 2 then 
                CorpsePosX, CorpsePosY, CorpsePosZ = GetCorpsePosition() 
                local newPath = CalculatePath(GetMapId(), Player.PosX, Player.PosY, Player.PosZ, CorpsePosX, CorpsePosY, CorpsePosZ, true, false, 0) 
                
                local temp = {} for i = 1, #newPath do table.insert(temp, { x = newPath[i][1], y = newPath[i][2], z = newPath[i][3] }) 
                end 
                
                CorpsePaths = FixedPath(temp, 2, true) 
            end 
        
        end 
        
        if CorpsePaths then 
            if PLAYER_ENTERING_WORLD then 
                PLAYER_ENTERING_WORLD = false 
                print( "场景切换等待2秒") 
                Delay(2000) 
            end 
            
            if Player.Health > 100 then 
                StopMove() 
                if Player.Instance == "party" then 
                    if NeedRepair(25) then 
                        ChangeProcess(PROCESS_STATE.EXIT_INSTANCE) 
                    else 
                        if ATP_NEED_RESET then 
                            ChangeProcess(PROCESS_STATE.EXIT_INSTANCE) 
                        else 
                            ChangeProcess(PROCESS_STATE.START_SOLO) 
                        end 
                    end 
                
                else 
                    ChangeProcess(LAST_PROCESS) 
                end 
            elseif Player.Instance == "none" and UnitIsGhost("player") then 
                if CorpsePaths:NavMove() then 
                    MoveForwardStart() 
                    Delay(500) 
                    MoveForwardStop() 
                    Delay(1000) 
                    CorpsePaths:Reset() 
                end 
                
                if not CorpsePosX then 
                    CorpsePosX, CorpsePosY, CorpsePosZ = GetCorpsePosition() 
                end 
                
                if StaticPopup1 and StaticPopup1:IsVisible() and (StaticPopup1.which == "DEATH" or StaticPopup1.which == "RECOVER_CORPSE") and StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() and Position(CorpsePosX, CorpsePosY, CorpsePosZ):Distance2D(Player) < 20 then 
                    StaticPopup1Button1:Click() Delay(1000) 
                end 
            end 
        end
end 
return out
end

local EventFrame = CreateFrame("Frame") 
EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") 
EventFrame:RegisterEvent("UI_ERROR_MESSAGE") 
EventFrame:RegisterEvent("CHAT_MSG_SYSTEM") 
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD") 
EventFrame:RegisterEvent("LOOT_BIND_CONFIRM") 
EventFrame:RegisterEvent("UNIT_SPELLCAST_START") 
EventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED") 
EventFrame:RegisterEvent("UNIT_SPELLCAST_STOP") 
EventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START") 
EventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP") 
EventFrame:RegisterEvent("PLAYER_LEAVING_WORLD") 
EventFrame:RegisterEvent("PLAYER_DEAD") 
EventFrame:RegisterEvent("BAG_UPDATE_DELAYED") 
EventFrame:SetScript("OnEvent", function(self, event, ...) 
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then 
        EventFrame[event](CombatLogGetCurrentEventInfo()) 
    else 
        EventFrame[event](...) 
    end 
end) 

function EventFrame.PLAYER_LEAVING_WORLD(...) InstanceTimer.UpdatePlayed(true) end
function EventFrame.UNIT_SPELLCAST_CHANNEL_START(...) end
function EventFrame.UNIT_SPELLCAST_CHANNEL_STOP(...) end

function EventFrame.COMBAT_LOG_EVENT_UNFILTERED(...) if GetObjectWithGUID then local eventName = select(2, ...) if eventName == "SPELL_CAST_SUCCESS" then local destination = select(8, ...) local spellName = select(13, ...) ATP_SPELL_CAST_SUCCESS.Time = DMW.Time ATP_SPELL_CAST_SUCCESS.SpellName = spellName ATP_SPELL_CAST_SUCCESS.Destination = destination end end end

function EventFrame.UI_ERROR_MESSAGE(...) if select(2, ...) == COMBAT_TEXT_RESIST then print( "假死抵抗") FEIGN_DEATH_RESIST = true elseif select(2, ...) == ERR_PET_SPELL_DEAD then PET_DEAD = true end end

function EventFrame.CHAT_MSG_SYSTEM(...) if select(1, ...) == TRANSFER_ABORT_TOO_MANY_INSTANCES then TOO_MANY_INSTANCES = true elseif string.find(select(1, ...), "已被重置") or string.find(select(1, ...), "has been reset") then InstanceTimer.SaveTimer() end end

function EventFrame.PLAYER_ENTERING_WORLD(...) if not select(2, ...) then print( "进出副本场景切换") PLAYER_ENTERING_WORLD = true end end

function EventFrame.LOOT_BIND_CONFIRM() end

function EventFrame.UNIT_SPELLCAST_START(...) end

function EventFrame.UNIT_SPELLCAST_SUCCEEDED(...) end

function EventFrame.UNIT_SPELLCAST_STOP(...) end

function EventFrame.PLAYER_DEAD(...) InstanceTimer.PlayerDead() end

function EventFrame.BAG_UPDATE_DELAYED(...) Bag:UpdateItems() end

local SystemStop = false 


local ATP_CMD = function(CMD) 
    CMD = string.upper(CMD) 
    if PROCESS_STATE[CMD] then 
        if not ATP_START_TASK then 
            print( "开始运行") 
            ChangeProcess(PROCESS_STATE[CMD]) 
            print( "开始运行................................") 
            SystemStop = false 
            ATP_START_TASK = true 
            print("测试2--------------")
            Scorpio.Continue(ATP_ProcessRun) end 
        elseif CMD == "STOP" then 
            print( "停止运行") 
            ATP_START_TASK = false 
        else 
            print( "命令错误") 
        end 
    end 
local WebApi = (function() 
    local root = "https://www.wowatp.com/api" 
    local char, head, count, salt = nil, 0, 0, time() + 2518 for i = 1, #root do char = string.sub(root, i, i) head = head + string.byte(char) 
        
    if tonumber(char) then 
        count = count + 1 
    end 
    end 
    
    if count == 0 and head + time() == salt then 
        x3G2G9GcUbLcXkSMKsdR4NEavg8PmSfNArR = count 
    end 
    
    local function urlEncode(s) s = string.gsub(s, "([^%w%.%- ])", function(c) 
        return string.format("%%%02X", string.byte(c)) end) 
        return string.gsub(s, " ", "+") end

    local function urlDecode(s) s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end) return s end

    local function SendHTTPRequest(url, params, success, error) if _G.SendHTTPRequest then _G.SendHTTPRequest(url, params, function(body, code, req, res, err) if code == "200" then if ATP.StartWidth(body, "{") then body = ATP.luaJson.json2lua(urlDecode(body)) end if body then success(body) end else error(code, err) end end, "User-Agent:ATP2.0.0\r\nContent-Type:application/json\r\n") end end

    local function Post(resources, params, success, error) local data = ATP.luaJson.table2json(params) SendHTTPRequest(root .. resources, data, success, error) end

    local function Get(resources, params, success, error) local url local data = "" if params then for k, v in pairs(params) do if data == "" then data = string.format("%s=%s", k, urlEncode(v)) else data = data .. string.format("&%s=%s", k, urlEncode(v)) end end url = root .. resources .. "?" .. data else url = root .. resources end SendHTTPRequest(url, nil, success, error) end

    local out = {} out.Post = Post out.Get = Get return out
end)() 

local ATPResponse = { 
    [1] = "请求方法错误", 
    [2] = "参数错误", 
    [3] = "卡密不支持此应用", 
    [4] = "权限不足", 
    [5] = "授权成功", 
    [6] = "非法请求", 
    [7] = "授权失效", 
    [8] = "授权到期", 
    [9] = "正常" 
} 

local Session 
local frame = CreateFrame("FRAME") 
frame.Loaded = false 
frame.Total = 0 
frame:SetScript("OnUpdate", function(self, elapsed) 
    LibDraw.clearCanvas() 
    
    ATP_TIME = GetTime() 
    
    if wmbapi and wmbapi.GetObjectWithGUID then 
        if not frame.Loaded then 
            frame.Loaded = true Locals() 
            if WindowsHeight == 0 or WindowsWidth == 0 then 
                WindowsHeight = 3000 WindowsWidth = 3000 
            end 
            
            layerFrame:SetWidth(WindowsWidth) 
            
            layerFrame:SetHeight(WindowsHeight) 
            
            local texture = layerFrame:CreateTexture(nil, "BACKGROUND") texture:SetColorTexture(0, 0.66, 0.46) 
            texture:SetAllPoints(layerFrame) 
            layerFrame.texture = texture 
            layerFrame:SetPoint("CENTER", 0, 0) 
            layerFrame:Hide() InstanceTimer.LoadTimer() 
            
            if ATP.Settings.Relogin then 
                if not IsHackEnabled("relog") then 
                    SetHackEnabled("relog", true) 
                end 
                
                ATP_CMD(PROCESS_STATE.SUPPLY) 
            end
            
            if not Session and ATP_RESPONSE then 
                
                Session = ATP_RESPONSE.session 
            end 
            
            if GetCVar("maxFPSBk") ~= 50 then 
                SetCVar("maxFPSBk", 50) 
            end 
            
            if GetCVar("maxFPS") ~= 50 then 
                
                SetCVar("maxFPS", 50) 
            end 
            Bag:UpdateItems() 
            
            ATP.Pulse = 0 
        end 
        
        UpdateBlizzardTime(elapsed) 
        LootBind() 
        
        if aaa222 then 
            frame.Total = frame.Total + elapsed 
            
            if frame.Total >= 1 then 
                frame.Total = frame.Total - 1 InstanceTimer.UpdatePlayed() 
            end 
        end 
        Bag:Destroy()
end
end) 

PROCESS_ROUTER[PROCESS_STATE.START_SOLO] = StartSolo() 
PROCESS_ROUTER[PROCESS_STATE.SUPPLY] = Supply() 
PROCESS_ROUTER[PROCESS_STATE.MAIL] = Mail() 
PROCESS_ROUTER[PROCESS_STATE.GOTO_INSTANCE] = GotoInstance() 
PROCESS_ROUTER[PROCESS_STATE.TOWN_TO_INSTANCE] = TownToInstance() 
PROCESS_ROUTER[PROCESS_STATE.ENTER_INSTANCE] = EnterInstance() 
PROCESS_ROUTER[PROCESS_STATE.EXIT_INSTANCE] = ExitInstance() 
PROCESS_ROUTER[PROCESS_STATE.RESET_INSTANCE] = ResetInstance() 
PROCESS_ROUTER[PROCESS_STATE.RESURRECTION] = Resurrection() 
PROCESS_ROUTER[PROCESS_STATE.TIMEOUT] = Timeout() 


local LastCheckTokenTime 
local CheckTokenTimeout 

function ATP_ProcessRun() 
    UIErrorsFrame:Show() 
    if ATP.Settings.Mode == 2 then 
        if not IsHackEnabled("multijump") then 
            SetHackEnabled("multijump", true) 
        end 
    end 
    
    if not IsHackEnabled("AntiAfk") then 
        SetHackEnabled("AntiAfk", true) 
    end 
    
    if UnitRace("player") == "侏儒" and not IsHackEnabled("waterwalk") then 
        SetHackEnabled("waterwalk", true) 
    end 
    
    if GetCVar("autoLootDefault") == "0" then 
        SetCVar("autoLootDefault", 1); 
    end 
    
    if GetCVar("scriptErrors") == "0" then 
        SetCVar("scriptErrors", 1); 
    end 
    
    if ATP.Settings.Relogin then 
        print( "5秒后自动运行，可STOP取消") 
        for i = 1, 5 do Delay(1000) 
            if not ATP_START_TASK then 
                print( "终止自动运行") break 
            end 
        end 
    end


    LastCheckTokenTime = DMW.Time
    CheckTokenTimeout = GetTime()
    while ATP_START_TASK do
        Locals()
        if DMW.Time - LastCheckTokenTime >= 300 then
            LastCheckTokenTime = DMW.Time
            --WebApi.Post("/v1/auth",{accountId=ATP.AccountId(),appId=202005,session=Session},
            --	function(body)
            --		if body.code==1000 then
            CheckTokenTimeout = GetTime()
            --			ATP_RESPONSE.state=body.state
            --		else
            --			print(body.msg)
            --		end
            --	end,function(code,error)
            --		CheckTokenTimeout=GetTime()
            --		print("code:%d msg:%s",code,error)
            --	end
            --)
        end
        --if not SystemStop and GetTime()-CheckTokenTimeout>60*15 then
        --	SystemStop=true
        --	print("网络异常,与服务器断开.")
        --end

        if CURRENT_PROCESS ~= PROCESS_STATE.RESURRECTION and UnitIsDeadOrGhost("player") and not UnitIsFeignDeath("player") then
            SetHackEnabled("hover", false)
            ChangeProcess(PROCESS_STATE.RESURRECTION)
        end
        PROCESS_ROUTER[CURRENT_PROCESS].Run()
        if SystemStop and not Player.Combat then
            print( "网络异常,与服务器断开,停止脚本.")
            ATP_START_TASK = false
        end
        Scorpio.Next()
    end

    SetHackEnabled("AntiAfk", false) SetHackEnabled("multijump", false) SetHackEnabled("waterwalk", false) ATP.Pulse = 0
end

SLASH_ATP1 = "/ATP" 
SlashCmdList["ATP"] = ATP_CMD 

print( "==添加紫门瀑布路线==") 
print( "==支持侏儒双门路线==") 
print( AddonName .. " Version v1.2.16.2")

SLASH_ATPA1 = "/ATPA" 
SlashCmdList["ATPA"] = function(msg)
    message(msg) 
end