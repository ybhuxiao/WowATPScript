
local _EventHandler = CreateFrame("Frame");
local function PLAYER_ENTERING_WORLD()
    _EventHandler:UnregisterEvent("PLAYER_ENTERING_WORLD");
    if not boomTimeSv then
        
        boomTimeSv = {
            instance_timer_sv = { on = true, locked = false, },
            target_warn_sv = {  },
        };
    else
        boomTimeSv.instance_timer_sv.on=true;
    end
    
    boomTimeSv.target_warn_sv[UnitGUID('player')] = boomTimeSv.target_warn_sv[UnitGUID('player')] or { on = true, locked = false, };
end

_EventHandler:RegisterEvent("PLAYER_ENTERING_WORLD");
_EventHandler:SetScript("OnEvent", PLAYER_ENTERING_WORLD);

function alam_GetConfig(misc, key)
    if misc == "instance_timer" then
        return boomTimeSv.instance_timer_sv[key];
    elseif misc == "target_warn" then
        return boomTimeSv.target_warn_sv[UnitGUID('player')][key];
    end
end


