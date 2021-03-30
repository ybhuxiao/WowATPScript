
local function _noop_()
	return true;
end
local instance_reset_failed_pattern = gsub(INSTANCE_RESET_FAILED, "%%s", "(.+)");
local instance_reset_success_pattern = gsub(INSTANCE_RESET_SUCCESS, "%%s", "(.+)");
-- RESET_FAILED_NOTIFY

local func = {  };
local var = {
    prev_area = nil,
    prev_in_instance = nil,
    next_reset_count_in = nil,
    next_reset_out_instance = nil,
};
instance_timer_sv = nil;


local board = CreateFrame("Frame", nil, UIParent);
board:SetSize(140, 80);
board:SetBackdrop({
    bgFile = "Interface/ChatFrame/ChatFrameBackground",
    edgeFile = "Interface/ChatFrame/ChatFrameBackground",
    tile = true,
    edgeSize = 1,
    tileSize = 5,
});
board:SetPoint("TOP");
board:Show();
board:SetMovable(true);
-- board:EnableMouse(true);
-- board:RegisterForDrag("LeftButton");

function func.lock()
    board:EnableMouse(false);
    board:SetBackdropColor(0.0, 0.0, 0.0, 0.0);
    board:SetBackdropBorderColor(0.0, 0.0, 0.0, 0.0);
    instance_timer_sv.locked = true;
end
function func.unlock()
    board:EnableMouse(true);
    board:SetBackdropColor(0.0, 0.0, 0.0, 0.5);
    board:SetBackdropBorderColor(0.0, 0.0, 0.0, 0.5);
    instance_timer_sv.locked = false;
end
function func.on()
    board:Show();
    instance_timer_sv.on = true;
end
function func.off()
    board:Hide();
    instance_timer_sv.on = false;
end

local drop_menu_table = {
    handler = _noop_,
    elements = {
        {
            handler = func.lock,
            para = {  },
            text = "锁定",
        },
        {
            handler = func.off,
            para = {  },
            text = "关闭",
        }
    },
};

board:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self:StartMoving();
    else
        ALADROP(board, "BOTTOMLEFT", drop_menu_table);
    end
end);
board:SetScript("OnMouseUp", function(self, button)
    self:StopMovingOrSizing();
    instance_timer_sv.pos = { self:GetPoint(), };
    for i, v in ipairs(instance_timer_sv.pos) do
        if type(v) == 'table' then
            instance_timer_sv.pos[i] = v:GetName();
        end
    end
end);
local lines = {  };
for i = 1, 30 do
    local left = board:CreateFontString(nil, "OVERLAY");
    left:SetFont(GameFontNormal:GetFont(), 12);
    left:SetPoint("TOPLEFT", board, "TOPLEFT", 0, - 16 * (i - 1));
    left:Show();
    left:SetText("\124cffffff00副本次数" .. i .. "\124r: ");
    local line = board:CreateFontString(nil, "OVERLAY");
    line:SetFont(GameFontNormal:GetFont(), 12);
    line:SetPoint("LEFT", left, "RIGHT", 0, 0);
    line:Show();
    line:SetText("\124cff00ff00 可用\124r");
    line.id = i;
    lines[i] = line;
end

function func.update_table()
    local TIME = time();
    for i = #instance_timer_sv, 1, -1 do
        if instance_timer_sv[i] < TIME then
            tremove(instance_timer_sv, i);
            -- print("可用重置次数+1， 目前已用：", #instance_timer_sv, "次");
        end
    end
    for i = 1, 30 do
        if instance_timer_sv[i] then
            -- 时间戳开始时间1970-01-01 08:00:00    加上 57600 是为了把时间部分取整 1970-01-02 00:00:00
            -- 减1就是为了计时

            lines[i]:SetText(date("\124cffff0000[%H:%M:%S]\124r", instance_timer_sv[i] - TIME + 57600 - 1));
        else
            lines[i]:SetText("\124cff00ff00 可用\124r");
        end
    end
end

function func.CHAT_MSG_SYSTEM(msg)
    if strfind(msg, instance_reset_failed_pattern) or strfind(msg, instance_reset_success_pattern) then
        tinsert(instance_timer_sv, time() + 86400);
        SendChatMessage("{rt1}副本已重置，请进入副本！{rt1}" , "PARTY", nil);
    elseif msg == RESET_FAILED_NOTIFY then
        -- print('next');
        var.next_reset_out_instance = true;
    end
end

function func.ZONE_CHANGED_NEW_AREA()
    local is_in_instance, instance_type = IsInInstance();
    -- print('func.ZONE_CHANGED_NEW_AREA')
    -- print(is_in_instance);
    -- if var.prev_in_instance and not is_in_instance then
    --     var.next_reset_count_in = true;
    -- else
    --     var.next_reset_count_in = false;
    -- end
    if is_in_instance and (instance_type == 'party' or instance_type == 'raid') then
    --     var.prev_in_instance = true;
    -- else
    --     var.prev_in_instance = false;
        if var.next_reset_out_instance then
            var.next_reset_out_instance = nil;
            tinsert(instance_timer_sv, time() + 86400);
        end
    end
    -- print(GetZoneText(), GetRealZoneText());
    -- print(var.prev_in_instance, is_in_instance, var.next_reset_count_in)
end

function func.init()
    -- board:UnregisterEvent("PLAYER_ENTERING_WORLD");
    func.PLAYER_ENTERING_WORLD = func.ZONE_CHANGED_NEW_AREA;
    func.PLAYER_ENTERING_WORLD();
    instance_timer_sv = boomTimeSv.instance_timer_sv;
    if instance_timer_sv.locked then
        func.lock();
    else
        func.unlock();
    end
    if instance_timer_sv.on then
        func.on();
    else
        func.off();
    end
    if instance_timer_sv.pos then
        board:ClearAllPoints();
        board:SetPoint(instance_timer_sv.pos[1], instance_timer_sv.pos[2], instance_timer_sv.pos[3], instance_timer_sv.pos[4], instance_timer_sv.pos[5]);
    end
    -- hooksecurefunc("ResetInstances", function()
    --     if var.next_reset_count_in then
    --         var.next_reset_count_in = false;
    --         tinsert(instance_timer_sv, time() + 86400);
    --     end
    -- end);
    C_Timer.NewTicker(1.0, func.update_table);
end
func.PLAYER_ENTERING_WORLD = func.init;

board:RegisterEvent("PLAYER_ENTERING_WORLD");
-- board:RegisterEvent("ZONE_CHANGED_NEW_AREA");
board:RegisterEvent("CHAT_MSG_SYSTEM");
function func.OnEvent(self, event, ...)
	func[event](...);
end
board:SetScript("OnEvent", func.OnEvent);

SLASH_ALAINSTANCETIMER1 = "/bt";
SlashCmdList["ALAINSTANCETIMER"] = function(msg)
    if strfind(msg, "^lock") then
        func.lock();
    elseif strfind(msg, "^unlock") then
        func.unlock();
    elseif strfind(msg, "^on") then
        func.on();
    elseif strfind(msg, "^off") then
        func.off();
    elseif strfind(msg, "^toggle_lock") then
        if instance_timer_sv.locked then
            func.unlock();
        else
            func.lock();
        end
    else
        if boomTimeSv.instance_timer_sv.on then
            func.off();
        else
            func.on();
        end
    end
end