-- Dejunk: koKR (Korean) localization file.

local AddonName = ...
local L = _G.LibStub('AceLocale-3.0'):NewLocale(AddonName, 'koKR')
if not L then return end

L["AUTO_DESTROY_TEXT"] = "자동 파괴"
L["AUTO_DESTROY_TOOLTIP"] = "이 창이 닫혀 있는 동안 주기적으로 정크 아이템을 파괴하십시오."
L["AUTO_REPAIR_TEXT"] = "자동 수리"
L["AUTO_REPAIR_TOOLTIP"] = "상점창 열리면 자동으로 아이템 수리."
L["AUTO_SELL_TEXT"] = "자동 판매"
L["AUTO_SELL_TOOLTIP"] = "상인 창 오픈 시 정크 아이템 자동 판매"
L["BINDINGS_REMOVE_FROM_LIST_TEXT"] = "%s 제거"
L["BY_CATEGORY_TEXT"] = "범주 별"
L["BY_QUALITY_TEXT"] = "품질 별"
L["BY_TYPE_TEXT"] = "종류 별"
L["CANNOT_DEJUNK_WHILE_DESTROYING"] = "아이템이 파괴 된 상태에서 분리 할 수 없습니다."
L["CANNOT_DEJUNK_WHILE_LISTS_UPDATING"] = "%s , %s 업데이트하는 동안 분리 할 수 없습니다."
L["CANNOT_DESTROY_WHILE_DEJUNKING"] = "아이템이 분리 된 상태에서는 파괴 할 수 없습니다."
L["CANNOT_DESTROY_WHILE_LIST_UPDATING"] = "%s 업데이트하는 동안 파괴 할 수 없습니다."
L["CHAT_TEXT"] = "채팅"
L["COMMON_TEXT"] = "흰색템 "
L["DEJUNK_BUTTON_TOOLTIP"] = "우클릭 - 토글 옵션"
L["DEJUNKING_IN_PROGRESS"] = "Dejunking 작업중."
L["DELETE_PROFILE_POPUP"] = "%s 프로필을 삭제하겠습니까?"
L["DELETE_TEXT"] = "삭제"
L["DESTROY_ALL_TOOLTIP"] = "이 등급의 모든 아이템을 파괴하라."
L["DESTROY_BELOW_PRICE_TEXT"] = "가격보다 낮은 아이템 파괴"
L["DESTROY_BELOW_PRICE_TOOLTIP"] = "정크 아이템 또는 정해진 가격 미만의 정크 아이템  파괴하십시오."
L["DESTROY_IGNORE_LIST_TOOLTIP"] = "%s 목록의 모든 아이템을 무시하십시오."
L["DESTROY_LIST_TOOLTIP"] = "%s 목록의 모든 아이템 삭제."
L["DESTROY_TEXT"] = "파괴"
L["DESTROYABLES_HELP_BELOW_PRICE_TEXT"] = "%s 미만의 이 목록의 아이템은 삭제된다."
L["EPIC_TEXT"] = "에픽"
L["EXCLUSIONS_HELP_TEXT"] = "이 목록의 아이템은 절대 판매되지 않을 것이다."
L["EXPORT_TEXT"] = "수출"
L["GENERAL_TEXT"] = "일반"
L["GLOBAL_TEXT"] = "전체"
L["IGNORE_BOE_TEXT"] = "착용시 귀속"
L["IGNORE_BOE_TOOLTIP"] = "착용시 귀속 아이템을 무시합니다.|n|n등급이 좋지 않은 아이템에는 적용되지 않습니다."
L["IGNORE_CONSUMABLES_TEXT"] = "소모품"
L["IGNORE_CONSUMABLES_TOOLTIP"] = "음식 및 물약과 같은 소모품을 무시하십시오."
L["IGNORE_COSMETIC_TEXT"] = "치장"
L["IGNORE_COSMETIC_TOOLTIP"] = "휘장, 셔츠와 같은 외관적이고 일반적인 갑옷은 무시하십시오."
L["IGNORE_ITEM_ENHANCEMENTS_TEXT"] = "인첸트 아이템"
L["IGNORE_ITEM_ENHANCEMENTS_TOOLTIP"] = "무기와 갑옷 강화에 사용되는 아이템은 무시하십시오."
L["IGNORE_READABLE_TEXT"] = "문서"
L["IGNORE_READABLE_TOOLTIP"] = "읽을 수 있는 아이템은 무시하십시오."
L["IGNORE_RECIPES_TEXT"] = "레시피"
L["IGNORE_RECIPES_TOOLTIP"] = "레시피 무시하십시오."
L["IGNORE_SOULBOUND_TEXT"] = "귀환석"
L["IGNORE_SOULBOUND_TOOLTIP"] = "귀환석은 무시하십시오..|n|n 등급이 좋지 않은 아이템에는 적용되지 않습니다."
L["IGNORE_TEXT"] = "제외"
L["IGNORE_TRADE_GOODS_TEXT"] = "직업용품"
L["IGNORE_TRADE_GOODS_TOOLTIP"] = "직업용품과 관련된 아이템은 무시하십시오."
L["IGNORING_ITEMS_INCOMPLETE_TOOLTIPS"] = "불완전한 툴팁이 있는 항목 무시."
L["INCLUSIONS_HELP_TEXT"] = "이 목록의 아이템은 항상 판매됩니다."
L["INCLUSIONS_TEXT"] = "포함"
L["ITEM_ALREADY_ON_LIST"] = "%s 이미 %s에 있다"
L["ITEM_CANNOT_BE_DESTROYED"] = "%s 파괴할 수 없다."
L["ITEM_CANNOT_BE_SOLD"] = "%s 팔 수 없다."
L["ITEM_LEVELS_TEXT"] = "아이템 레벨"
L["ITEM_NOT_ON_LIST"] = "%s 는 %s 에 없다"
L["ITEM_TOOLTIP_TOOLTIP"] = "아이템의 툴팁에 판매 여부를 나타내는 Dejunk 메시지를 표시합니다. <Shift> 키를 누르고 있으면 파괴되는지 나타냅니다.|n|n<Alt> 또는 <Shift + Alt>를 길게 눌러 이유를 표시하십시오..|n|n이 툴팁은 가방에있는 아이템 위로 마우스를 가져가는 경우에만 적용됩니다."
L["ITEM_WILL_BE_DESTROYED"] = "이 아이템은 파괴됩니다."
L["ITEM_WILL_BE_SOLD"] = "이 아이템은 판매합니다."
L["ITEM_WILL_NOT_BE_DESTROYED"] = "이 아이템은 파괴되지 않습니다."
L["ITEM_WILL_NOT_BE_SOLD"] = "이 아이템은 판매되지 않습니다."
L["LIST_ADD_REMOVE_HELP_TEXT"] = "아이템을 추가하려면 아래 창에 놓으십시오. 아이템을 제거하려면 항목을 강조 표시하고 마우스 오른쪽 버튼을 클릭하십시오."
L["MAY_NOT_HAVE_DESTROYED_ITEM"] = "%s 파괴하지 않았을 수도 있습니다."
L["MAY_NOT_HAVE_SOLD_ITEM"] = "%s 판매하지 않았을 수 있습니다"
L["MINIMAP_CHECKBUTTON_TOOLTIP"] = "미니맵에 아이콘을 표시"
L["MINIMAP_ICON_TOOLTIP_1"] = "좌클릭 - 옵션"
L["MINIMAP_ICON_TOOLTIP_2"] = "우클릭 - 파괴"
L["MINIMAP_ICON_TOOLTIP_3"] = "드래그해서 아이콘 이동"
L["NO_CACHED_DESTROYABLE_ITEMS"] = "파괴 가능한 정크 아이템을 검색 할 수 없습니다. 나중에 다시 시도하십시오."
L["NO_CACHED_JUNK_ITEMS"] = "정크 아이템을 검색 할 수 없습니다. 나중에 다시 시도하십시오."
L["NO_DESTROYABLE_ITEMS"] = "파괴할 정크 아이템이 없음."
L["NO_JUNK_ITEMS"] = "판매할 정크 아이템이 없음"
L["ONLY_DESTROYING_CACHED"] = "일부 아이템을 검색할 수 없다. 캐시된 정크 아이템만 파괴."
L["ONLY_SELLING_CACHED"] = "일부 아이템을 검색할 수 없다. 캐시된 정크 아이템만 판매"
L["POOR_TEXT"] = "회색템"
L["RARE_TEXT"] = "파란템"
L["REASON_DESTROY_BY_QUALITY_TEXT"] = "이런 등급의 아이템들이 파괴되고 있다."
L["REASON_DESTROY_IGNORE_EXCLUSIONS_TEXT"] = "제외 항목은 무시됩니다."
L["REASON_DESTROY_INCLUSIONS_TEXT"] = "포함목록 아이템이 파괴되고 있습니다."
L["REASON_IGNORE_BOE_TEXT"] = "장착시 귀속 아이템은 무시됩니다."
L["REASON_IGNORE_CONSUMABLES_TEXT"] = "소모품은 무시됩니다."
L["REASON_IGNORE_COSMETIC_TEXT"] = "치장 아이템은 무시됩니다."
L["REASON_IGNORE_ITEM_ENHANCEMENTS_TEXT"] = "인챈트 아이템은 무시됩니다."
L["REASON_IGNORE_READABLE_TEXT"] = "문서 아이템은 무시됩니다."
L["REASON_IGNORE_RECIPES_TEXT"] = "레시피 아이템은 무시됩니다."
L["REASON_IGNORE_SOULBOUND_TEXT"] = "귀환석 무시됩니다."
L["REASON_IGNORE_TRADE_GOODS_TEXT"] = "직업용품은 무시됩니다"
L["REASON_ITEM_IS_LOCKED_TEXT"] = "잠겨 있습니다."
L["REASON_ITEM_NOT_FILTERED_TEXT"] = "이 아이템은 걸러지지 않는다."
L["REASON_ITEM_ON_LIST_TEXT"] = "이 아이템은 %s 에 있다."
L["REASON_SELL_BY_QUALITY_TEXT"] = "이 등급의 아이템들 판매하고 있습니다."
L["REASON_SELL_UNSUITABLE_TEXT"] = "착용불가 장비를 판매 중입니다."
L["REMOVE_ALL_POPUP"] = "%s 에서 모든 아이템을 제거하시겠습니까?"
L["REMOVE_ALL_TEXT"] = "모두 제거"
L["REMOVED_ALL_FROM_LIST"] = "%s 에서 모든 아이템을 제거했습니다."
L["REMOVED_ITEM_FROM_LIST"] = "%s 에서 %s 제거했습니다."
L["REPAIRED_ALL_ITEMS"] = "%s 에 대한 모든 아이템을 수리하십시오."
L["REPAIRED_NO_ITEMS"] = "수리비가 모자르다"
L["REPAIRING_TEXT"] = "수리중"
L["SAFE_MODE_MESSAGE"] = "안전 모드 사용: %s 아이템만 판매"
L["SAFE_MODE_TEXT"] = "안전 모드"
L["SAFE_MODE_TOOLTIP"] = "한 번에 최대 %s 아이템만 판매."
L["SELL_ALL_TOOLTIP"] = "이 등급의 모든 아이템을 판매하십시오."
L["SELL_TEXT"] = "판매"
L["SELL_UNSUITABLE_TEXT"] = "착용불가 장비"
L["SELL_UNSUITABLE_TOOLTIP"] = "직업에서 사용하거나 훈련 할 수없는 모든 무기와 갑옷을 판매합니다."
L["SILENT_MODE_TOOLTIP"] = "채팅 창 메시지 비활성화."
L["SOLD_ITEM_VERBOSE"] = "판매: %s."
L["SOLD_ITEMS_VERBOSE"] = "판매: %sx%s."
L["SOLD_YOUR_JUNK"] = "%s 에 정크 판매."
L["UNCOMMON_TEXT"] = "초록템"
L["VENDOR_DOESNT_BUY"] = "그 NPC에게 팔 수 없다."
L["VERBOSE_MODE_TEXT"] = "상세 모드"
L["VERBOSE_MODE_TOOLTIP"] = "아이템을 판매 및 삭제할 때 채팅창에 메세지 표시"

