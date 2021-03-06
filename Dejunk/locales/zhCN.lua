-- Dejunk: zhCN (Chinese) localization file.

local AddonName = ...
local L = _G.LibStub('AceLocale-3.0'):NewLocale(AddonName, 'zhCN')
if not L then return end

L["ADDED_ITEM_TO_LIST"] = "新增%s到%s。"
L["AUTO_DESTROY_TEXT"] = "自动销毁"
L["AUTO_DESTROY_TOOLTIP"] = "当此视窗关闭时定期销毁垃圾物品"
L["AUTO_REPAIR_TEXT"] = "自动修理"
L["AUTO_REPAIR_TOOLTIP"] = "当开启商店视窗界面时自动修理物品。"
L["AUTO_SELL_TEXT"] = "自动卖出"
L["AUTO_SELL_TOOLTIP"] = "当开启商店视窗界面时自动卖出垃圾物品。"
L["BINDINGS_ADD_TO_LIST_TEXT"] = "新增到%s"
L["BINDINGS_REMOVE_FROM_LIST_TEXT"] = "从%s移除"
L["BINDINGS_TOGGLE_OPTIONS_TEXT"] = "切换选项"
L["SELL_BELOW_PRICE_TEXT"] = "出售低价物品"
L["SELL_BELOW_PRICE_TOOLTIP"] = "只出售价值低于规定价格的垃圾物品"
L["BY_CATEGORY_TEXT"] = "依据类别"
L["BY_QUALITY_TEXT"] = "依据质量"
L["BY_TYPE_TEXT"] = "依据类型"
L["CANNOT_DEJUNK_WHILE_DESTROYING"] = "无法消除垃圾当物品已被销毁。"
L["CANNOT_DEJUNK_WHILE_LISTS_UPDATING"] = "无法消除垃圾当%s与%s已经更新。"
L["CANNOT_DESTROY_WHILE_DEJUNKING"] = "无法销毁当物品已经被清除。"
L["CANNOT_DESTROY_WHILE_LIST_UPDATING"] = "无法销毁当%s已经更新。"
L["CHAT_TEXT"] = "聊天视窗"
L["COMMON_TEXT"] = "普通"
L["COPY_TEXT"] = "复制"
L["DEJUNK_BUTTON_TOOLTIP"] = "右键点击来切换选项。"
L["DEJUNKING_IN_PROGRESS"] = "垃圾已经在处理中。"
L["DELETE_TEXT"] = "删除"
L["DESTROY_ALL_TOOLTIP"] = "销毁所有此质量的物品。"
L["DESTROY_IGNORE_LIST_TOOLTIP"] = "忽略所有在%s清单的物品。"
L["DESTROY_LIST_TOOLTIP"] = "销毁所有在%s清单的物品。"
L["DESTROY_TEXT"] = "销毁"
L["DESTROYABLES_TEXT"] = "可销毁"
L["DESTROYED_ITEM"] = "销毁1个垃圾物品。"
L["DESTROYED_ITEM_VERBOSE"] = "销毁：%s。"
L["DESTROYED_ITEMS"] = "销毁%s个垃圾物品。"
L["DESTROYED_ITEMS_VERBOSE"] = "销毁：%sx%s。"
L["DESTROYING_IN_PROGRESS"] = "销毁已在处理中。"
L["EPIC_TEXT"] = "史诗"
L["EXCLUSIONS_TEXT"] = "排除"
L["EXPORT_HELPER_TEXT"] = "当高亮时，使用<Ctrl+C>或<Cmd+C>来复制上面的汇出字符串。"
L["EXPORT_PROFILE_TEXT"] = "汇出设定档"
L["EXPORT_TEXT"] = "汇出"
L["FAILED_TO_PARSE_ITEM_ID"] = "物品ID %s 解析失败，可能不存在。"
L["GENERAL_TEXT"] = "一般"
L["GLOBAL_TEXT"] = "泛用"
L["IGNORE_BOE_TEXT"] = "装备后绑定"
L["IGNORE_BOE_TOOLTIP"] = "忽略装备后绑定物品。|n|n不适用于粗糙质量的物品。"
L["IGNORE_CONSUMABLES_TEXT"] = "消耗品"
L["IGNORE_CONSUMABLES_TOOLTIP"] = "忽略消耗品例如食物、药水以及神兵之力。"
L["IGNORE_COSMETIC_TEXT"] = "装饰品"
L["IGNORE_COSMETIC_TOOLTIP"] = "忽略装饰品以及通用装甲象是外袍、衬衣以及握在副手的物品。"
L["IGNORE_ITEM_ENHANCEMENTS_TEXT"] = "物品增强"
L["IGNORE_ITEM_ENHANCEMENTS_TOOLTIP"] = "忽略用于增强武器与装甲的物品。"
L["IGNORE_READABLE_TEXT"] = "可阅读的文件"
L["IGNORE_READABLE_TOOLTIP"] = "忽略可阅读的文件"
L["IGNORE_RECIPES_TEXT"] = "图纸"
L["IGNORE_RECIPES_TOOLTIP"] = "忽略专业技能图纸"
L["IGNORE_SOULBOUND_TEXT"] = "灵魂绑定"
L["IGNORE_SOULBOUND_TOOLTIP"] = "忽略灵魂绑定物品。|n|n不适用于粗糙质量的物品。"
L["IGNORE_TEXT"] = "忽略"
L["IGNORE_TRADE_GOODS_TEXT"] = "交易商品"
L["IGNORE_TRADE_GOODS_TOOLTIP"] = "忽略制造专业相关的物品。"
L["IGNORING_ITEMS_INCOMPLETE_TOOLTIPS"] = "忽略不完整的组合式零件"
L["IMPORT_HELPER_TEXT"] = "输入物品ID并以分号分隔（例如：4983;58907;67410）。"
L["IMPORT_PROFILE_HELPER_TEXT"] = "以<Ctrl+V>的方式将字符串贴入上方框架"
L["IMPORT_PROFILE_TEXT"] = "汇入设定档 "
L["IMPORT_TEXT"] = "汇入"
L["INCLUSIONS_TEXT"] = "出售"
L["ITEM_ALREADY_ON_LIST"] = "%s 已存在于 %s 中."
L["ITEM_CANNOT_BE_DESTROYED"] = "无法丢弃 %s ."
L["ITEM_CANNOT_BE_SOLD"] = "无法出售 %s"
L["ITEM_NOT_ON_LIST"] = "%s 不存在于 %s  中."
L["ITEM_TOOLTIP_TEXT"] = "鼠标提示"
L["DESTROY_BELOW_PRICE_TEXT"] = "低于价格销毁"
L["EXCLUSIONS_HELP_TEXT"] = "此列表中的物品永不会被出售"
L["INCLUSIONS_HELP_TEXT"] = "此列表中的物品总是被出售"
L["DESTROYABLES_HELP_TEXT"] = "此列表中的物品总是被摧毁"
L["LIST_ADD_REMOVE_HELP_TEXT"] = "想要添加物品, 把它拖放到下面的框架里。若要移除项目，请突出显示一个项目，然后右键单击."
L["DESTROY_EXCESS_SOUL_SHARDS_TOOLTIP"] = "摧毁超过设定上限的灵魂碎片.|n|n做作用于 |cFF8787ED术士|r."
L["DESTROY_EXCESS_SOUL_SHARDS_TEXT"] = "过量灵魂碎片"
L["ITEM_TOOLTIP_TOOLTIP"] = "在物品提示中显示待出售提示。按下<Shift>显示待丢弃提示。|n|n按下<Alt> 或 <Shift+Alt> 显示原因。|n|n此提示仅对背包中物品有效."
L["ITEM_WILL_BE_DESTROYED"] = "此物品将会被丢弃."
L["ITEM_WILL_BE_SOLD"] = "此物品将会被出售."
L["ITEM_WILL_NOT_BE_DESTROYED"] = "此物品将不会被丢弃."
L["ITEM_WILL_NOT_BE_SOLD"] = "此物品将不会被出售."
L["MAY_NOT_HAVE_DESTROYED_ITEM"] = "无法丢弃 %s"
L["MAY_NOT_HAVE_SOLD_ITEM"] = "无法出售 %s."
L["MINIMAP_CHECKBUTTON_TEXT"] = "小地图图示 "
L["MINIMAP_CHECKBUTTON_TOOLTIP"] = "在小地图上显示Dejunk的图示"
L["MINIMAP_ICON_TOOLTIP_1"] = "左键点击可开启设定选项"
L["MINIMAP_ICON_TOOLTIP_2"] = "右键点击可执行丢弃物品"
L["MINIMAP_ICON_TOOLTIP_3"] = "拖曳可移动图示位置"
L["NO_CACHED_DESTROYABLE_ITEMS"] = "没有需要丢弃的物品。请稍后再尝试。"
L["NO_CACHED_JUNK_ITEMS"] = "没有需要丢弃的杂物，请稍后再尝试."
L["NO_DESTROYABLE_ITEMS"] = "没有可丢弃的杂物."
L["NO_ITEMS_TEXT"] = "没有物品."
L["NO_JUNK_ITEMS"] = "没有可出售的杂物."
L["ONLY_DESTROYING_CACHED"] = "某些物品无相关设定，仅丢弃清单已指定的杂物"
L["ONLY_SELLING_CACHED"] = "某些物品无法直接出售，仅出售清单已指定的杂物"
L["POOR_TEXT"] = "粗糙"
L["PROFILE_ACTIVATED_TEXT"] = "已启用设定档 %s "
L["PROFILE_COPIED_TEXT"] = "已复制设定档 %s"
L["PROFILE_DELETED_TEXT"] = "已删除设定档 %s"
L["PROFILE_EXISTS_TEXT"] = "设定档 %s 已存在"
L["PROFILE_INVALID_IMPORT_TEXT"] = "汇入字符串为无效字符串"
L["PROFILES_TEXT"] = "设定档"
L["RARE_TEXT"] = "精良"
L["REASON_DESTROY_BY_QUALITY_TEXT"] = "待丢弃:质量过低."
L["REASON_DESTROY_IGNORE_EXCLUSIONS_TEXT"] = "保留物品:保留清单指定物品"
L["REASON_DESTROY_INCLUSIONS_TEXT"] = "待丢弃:待售清单指定物品."
L["REASON_IGNORE_BOE_TEXT"] = "保留物品:装备绑定 "
L["REASON_IGNORE_CONSUMABLES_TEXT"] = "保留物品:消耗品 "
L["REASON_IGNORE_COSMETIC_TEXT"] = "保留物品:变身物品 "
L["REASON_IGNORE_ITEM_ENHANCEMENTS_TEXT"] = "保留物品:附魔用品 "
L["REASON_IGNORE_READABLE_TEXT"] = "保留物品:可阅读的物品。"
L["REASON_IGNORE_RECIPES_TEXT"] = "保留物品:配方 "
L["REASON_IGNORE_SOULBOUND_TEXT"] = "保留物品:灵魂绑定 "
L["REASON_IGNORE_TRADE_GOODS_TEXT"] = "保留物品:高单价 "
L["REASON_ITEM_IS_LOCKED_TEXT"] = "物品已锁定"
L["REASON_ITEM_NOT_FILTERED_TEXT"] = "无相关处理设定"
L["REASON_ITEM_ON_LIST_TEXT"] = "出售原因 已纪录于 %s中"
L["REASON_SELL_BY_QUALITY_TEXT"] = "出售原因 指定出售的质量"
L["REASON_SELL_UNSUITABLE_TEXT"] = "出售原因:无法使用的装备"
L["REMOVED_ALL_FROM_LIST"] = "将 %s清空"
L["REMOVED_ITEM_FROM_LIST"] = "已将%s从%s中移除"
L["REPAIRED_ALL_ITEMS"] = "花费 %s 修复所有装备"
L["REPAIRED_NO_ITEMS"] = "无足够金币修理装备 "
L["REPAIRING_TEXT"] = "修理装备 "
L["SAFE_MODE_MESSAGE"] = "安全模式启用:仅出售 %s 件物品"
L["SAFE_MODE_TEXT"] = "安全模式 "
L["SAFE_MODE_TOOLTIP"] = "限制每次出售物品为 %s 件"
L["SELL_ALL_TOOLTIP"] = "卖出所有此质量的物品。"
L["SELL_TEXT"] = "卖出"
L["SELL_UNSUITABLE_TEXT"] = "不适当装备"
L["SELL_UNSUITABLE_TOOLTIP"] = "卖出无法装备的武器与不符合的护甲种类"
L["SILENT_MODE_TEXT"] = "静默模式"
L["SILENT_MODE_TOOLTIP"] = "停用聊天视窗的Dejunk讯息。"
L["SOLD_ITEM_VERBOSE"] = "卖出：%s。"
L["SOLD_ITEMS_VERBOSE"] = "卖出：%sx%s。"
L["SOLD_YOUR_JUNK"] = "卖出杂物后获得%s。"
L["START_DESTROYING_BUTTON_TEXT"] = "开始销毁"
L["UNCOMMON_TEXT"] = "优秀"
L["VENDOR_DOESNT_BUY"] = "无法卖到此商店。"
L["VERBOSE_MODE_TEXT"] = "详列模式 "
L["VERBOSE_MODE_TOOLTIP"] = "在聊天视窗中详细列出Dejunk所卖掉或丢弃的物品"
