class_name CardEffectResolver
extends RefCounted

const Stocks = preload("res://scripts/StockSystem.gd")
const Economy = preload("res://scripts/EconomyMath.gd")
const Talents = preload("res://scripts/TalentSystem.gd")
const TimedEffects = preload("res://scripts/TimedEffectSystem.gd")
const DrawPolicy = preload("res://scripts/CardDrawPolicy.gd")
const Districts = preload("res://scripts/DistrictSystem.gd")
const Risks = preload("res://scripts/RiskSystem.gd")
const Rewards = preload("res://scripts/CardRewardSystem.gd")
const CompanyRules = preload("res://scripts/CompanyAbilityEngine.gd")
const ListedMarket = preload("res://scripts/ListedCompanyMarketSystem.gd")

const SUPPORTED_EFFECTS: Array[String] = [
	"price_war", "public_opinion_strike", "supply_disruption", "channel_takeover", "poach_talent", 
	"viral_marketing", "membership_growth", "service_upgrade", "cost_optimization", 
	"bargain_buy", "market_rally", "hedged_exit", "market_rumor", 
	"construction_accelerate", "construction_delay", "rent_collection", "account_freeze", 
	"district_ad_screen", "district_joint_operation", "block_entrance", "district_festival", 
	"news_clarification", "talent_discount", "auction_bid_bonus", "startup_success_bonus", 
	"land_discount", "portfolio_dividend", "bank_interest_relief", "talent_capacity", 
	"startup_accelerate", "build_discount", "debt_restructure", "auction_payment_credit", 
	"executive_search", "startup_portfolio_boost", "land_acquisition", "auction_takeover", 
	"land_grant", "strategy_draw", "red_strategy_draft", 
	"gilded_gold_vault", "gilded_royal_privilege", "gilded_chosen_talent", 
	"gilded_total_blockade", "gilded_business_storm", "gilded_golden_wave", 
	"west_cross_border_network", "west_roadshow_window", "west_data_rights", "west_audit_sandbox",
	"west_smart_bridge", "west_institutional_placement", "west_hq_alliance", "west_liquidity_reserve",
]


static func supports(effect: String) -> bool:
	return effect in SUPPORTED_EFFECTS or effect.begins_with("west_program_")


static func resolve(player: Dictionary, card: Dictionary, target_id: String) -> Dictionary:
	if str(card.get("effect", "")).begins_with("west_program_"):
		return _resolve_west_program(player, card, target_id)
	var target_player: = GameState.player(_target_owner(target_id))
	match str(card.effect):
		"price_war":
			var affected: = 0
			for business_id: String in target_player.business_ids:
				var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
				if str(business.get("state", "")) in ["operating", "loss_watch", "mortgaged"]:
					TimedEffects.add_business_effect(business_id, "income_multiplier", float(card.value), int(card.duration), str(player.id), str(card.id))
					affected += 1
			return _ok("价格战已影响%d家企业" % affected, "目标%d家企业本轮收入降至%d%%" % [affected, roundi(float(card.value) * 100.0)], {"affected": affected})
		"public_opinion_strike":
			var risk_before: = int(target_player.risk)
			var opinion_multiplier: = CompanyRules.public_opinion_penalty_multiplier(str(target_player.get("company_id", "")))
			var risk_add: = maxi(1, roundi(float(card.value) * opinion_multiplier))
			Risks.adjust(str(target_player.id), risk_add, str(card.name), "策略攻击")
			var affected: = 0
			var base_income_multiplier: = float(card.get("secondary_value", 0.82))
			var applied_income_multiplier: = clampf(1.0 - (1.0 - base_income_multiplier) * opinion_multiplier, 0.55, 1.0)
			for business_id: String in target_player.business_ids:
				var business: Dictionary = GameState.game_data.businesses.get(business_id, {})
				if str(business.get("state", "")) in ["operating", "loss_watch", "mortgaged"]:
					TimedEffects.add_business_effect(business_id, "income_multiplier", applied_income_multiplier, int(card.duration), str(player.id), str(card.id))
					affected += 1
			return _ok("舆论打击已生效", "风险 %d → %d；%d家企业收入降至%d%%" % [risk_before, int(target_player.risk), affected, roundi(applied_income_multiplier * 100.0)])
		"supply_disruption":
			TimedEffects.add_business_effect(target_id, "cost_multiplier", float(card.value), int(card.duration), str(player.id), str(card.id))
			return _ok("供应链干扰已生效", "目标企业本轮固定成本提高%d%%" % roundi((float(card.value) - 1.0) * 100.0))
		"channel_takeover":
			var paid: = _transfer_cash(str(target_player.id), str(player.id), int(card.value), "抢占渠道")
			return _ok("已截取%d万渠道收益" % paid, "现金即时转移：对手 -%d 万，你 +%d 万" % [paid, paid], {"cash_transferred": paid})
		"poach_talent":
			var business: Dictionary = GameState.game_data.businesses.get(target_id, {})
			var talent_id: = _best_assigned_talent(business)
			if talent_id.is_empty():
				return _fail("目标企业没有可挖角人才")
			if player.talent_ids.has(talent_id):
				return _fail("己方已拥有该人才，不能重复挖角")
			if player.talent_ids.size() >= Talents.roster_limit(str(player.id)):
				return _fail("员工库已满，请先裁员后再挖角")
			business.employees[business.employees.find(talent_id)] = ""
			target_player.talent_ids.erase(talent_id)
			player.talent_ids.append(talent_id)
			var risk_before: = int(target_player.risk)
			Risks.adjust(str(target_player.id), int(card.get("secondary_value", 0)), str(card.name), "人才争夺")
			var talent_name: = str(GameConfig.by_id("talents", talent_id).get("name", talent_id))
			return _ok("已挖角%s" % talent_name, "人才所有权已转移；对手风险 %d → %d" % [risk_before, int(target_player.risk)], {"talent_id": talent_id})
		"viral_marketing":
			TimedEffects.add_player_effect(str(player.id), "all_income_multiplier", float(card.value), int(card.duration), str(card.id))
			return _ok("现象级营销已启动", "己方全部企业收入 +%d%%，持续%d回合" % [roundi((float(card.value) - 1.0) * 100.0), int(card.duration)])
		"membership_growth", "service_upgrade":
			TimedEffects.add_business_effect(target_id, "income_multiplier", float(card.value), int(card.duration), str(player.id), str(card.id))
			var risk_before: = int(player.risk)
			Risks.adjust(str(player.id), - int(card.get("secondary_value", 0)), str(card.name), "经营治理")
			return _ok("%s已生效" % str(card.name), "目标企业收入 +%d%%，持续%d回合；风险 %d → %d" % [roundi((float(card.value) - 1.0) * 100.0), int(card.duration), risk_before, int(player.risk)])
		"cost_optimization":
			TimedEffects.add_business_effect(target_id, "cost_multiplier", float(card.value), int(card.duration), str(player.id), str(card.id))
			return _ok("成本优化已生效", "目标企业固定成本 -%d%%，持续%d回合" % [roundi((1.0 - float(card.value)) * 100.0), int(card.duration)])
		"bargain_buy":
			return _bargain_buy(player, target_id, int(card.value), float(card.get("discount", 0.95)))
		"market_rally", "market_rumor":
			return _move_stock_price(target_id, float(card.value))
		"hedged_exit":
			var holding: Dictionary = player.stocks.get(target_id, {"shares": 0, "avg": 0.0})
			var shares: = int(holding.get("shares", 0))
			if shares <= 0:
				return _fail("目标证券没有可卖持仓")
			var cash_before: = int(player.cash)
			var risk_before: = int(player.risk)
			var trade: = Stocks.trade(str(player.id), target_id, shares, false)
			if not bool(trade.get("ok", false)):
				return trade
			var proceeds: = int(trade.get("cash", 0))
			var hedge_bonus: = mini(int(card.get("cap", 30)), maxi(0, roundi(float(proceeds) * float(card.get("value", 0.08)))))
			if hedge_bonus > 0:
				GameState.apply_cash(str(player.id), hedge_bonus, "证券对冲补偿")
			Risks.adjust(str(player.id), - int(card.get("secondary_value", 4)), str(card.name), "证券风险对冲")
			return _ok("对冲退出已完成", "卖出%d股 + 对冲补偿%d万；现金 %d → %d 万；风险 %d → %d" % [shares, hedge_bonus, cash_before, int(player.cash), risk_before, int(player.risk)], {"shares": shares, "sale_proceeds": proceeds, "hedge_bonus": hedge_bonus, "risk_reduced": risk_before - int(player.risk)})
		"construction_accelerate", "construction_delay":
			return _change_construction(player, card, target_id)
		"rent_collection":
			var paid: = _transfer_cash(str(target_player.id), str(player.id), int(card.value), "地租催缴")
			return _ok("已收取%d万地租" % paid, "对手现金 -%d 万，你的现金 +%d 万" % [paid, paid], {"cash_transferred": paid})
		"account_freeze":
			var freeze: = TimedEffects.lock_cash(str(target_player.id), int(card.value), int(card.duration), str(player.id))
			if not bool(freeze.get("ok", false)):
				return _fail(str(freeze.get("message", "目标没有可冻结资金")))
			var risk_before: = int(target_player.risk)
			Risks.adjust(str(target_player.id), int(card.get("secondary_value", 8)), str(card.name), "金融攻击")
			return _ok("账户冻结已生效", "冻结%d万至本回合结算；风险 %d → %d" % [int(freeze.amount), risk_before, int(target_player.risk)], {"cash_frozen": int(freeze.amount)})
		"block_entrance":
			var business: Dictionary = GameState.game_data.businesses.get(target_id, {})
			if business.is_empty() or target_player.is_empty():
				return _fail("目标对手企业不存在")
			TimedEffects.add_business_effect(target_id, "income_multiplier", float(card.value), int(card.duration), str(player.id), str(card.id))
			var paid: = _transfer_cash(str(target_player.id), str(player.id), int(card.get("secondary_value", 30)), "商圈入口封锁改道费")
			return _ok("%s入口已被封锁" % str(business.get("name", "目标企业")), "指定企业本轮收入降至%d%%；%s向你支付%d万渠道改道费" % [roundi(float(card.value) * 100.0), str(target_player.get("name", "对手")), paid], {"cash_transferred": paid, "income_multiplier": float(card.value), "business_id": target_id})
		"district_ad_screen", "district_festival":
			var added: = TimedEffects.add_district_effect(target_id, "heat_delta", float(card.value), int(card.duration), str(card.id))
			if not bool(added.get("ok", false)):
				return _fail(str(added.get("message", "街区不存在")))
			return _ok("%s已部署" % str(card.name), "目标街区热度 %+d，持续%d回合" % [roundi(float(card.value)), int(card.duration)])
		"district_joint_operation":
			var added: = TimedEffects.add_district_effect(target_id, "joint_operation", float(card.value), int(card.duration), str(card.id), {
				"source_player_id": str(player.id), 
				"per_rival_business": int(card.get("secondary_value", 20)), 
				"dividend_cap": int(card.get("cap", 80)), 
				"name": str(card.name), 
			})
			if not bool(added.get("ok", false)):
				return _fail(str(added.get("message", "街区不存在")))
			return _ok("核心商圈联营权已生效", "己方企业收入 +%d%%；每家对手营业企业分成%d万（每回合最多%d万），持续%d回合" % [roundi((float(card.value) - 1.0) * 100.0), int(card.get("secondary_value", 20)), int(card.get("cap", 80)), int(card.duration)])
		"news_clarification":
			var before: = int(player.risk)
			Risks.adjust(str(player.id), - int(card.value), str(card.name), "风险治理")
			return _ok("新闻澄清完成", "风险 %d → %d" % [before, int(player.risk)])
		"talent_discount":
			TimedEffects.add_player_effect(str(player.id), "talent_discount", float(card.value), int(card.duration), str(card.id))
			return _ok("招聘优惠已登记", "本回合下一次人才抽取费用降低%d%%" % roundi((1.0 - float(card.value)) * 100.0))
		"auction_bid_bonus":
			TimedEffects.add_player_effect(str(player.id), "auction_bid_bonus", int(card.value), int(card.duration), str(card.id), {"uses": 1})
			return _ok("拍卖额度已登记", "下一次拍卖比较金额 +%d 万；中标后只支付输入金额" % int(card.value))
		"auction_payment_credit":
			TimedEffects.add_player_effect(str(player.id), "auction_payment_credit", int(card.value), int(card.duration), str(card.id), {"uses": 1})
			return _ok("成交补贴已登记", "下次拍卖中标时少支付%d万，最低支付0万" % int(card.value))
		"auction_takeover":
			TimedEffects.add_player_effect(str(player.id), "auction_bid_bonus", int(card.value), int(card.duration), str(card.id), {"uses": 1})
			TimedEffects.add_player_effect(str(player.id), "auction_payment_credit", int(card.get("secondary_value", 0)), int(card.duration), str(card.id), {"uses": 1})
			return _ok("收购战备额度已启用", "下一次拍卖比较金额 +%d 万；中标少付%d万" % [int(card.value), int(card.get("secondary_value", 0))])
		"startup_success_bonus":
			var before: = float(player.get("next_project_bonus", 0.0))
			player.next_project_bonus = minf(0.4, before + float(card.value))
			return _ok("创投尽调已完成", "下一次创投成功率额外 +%d%%" % roundi((float(player.next_project_bonus) - before) * 100.0))
		"startup_accelerate":
			return _accelerate_startups(player, int(card.value), 0.0, 0)
		"startup_portfolio_boost":
			return _accelerate_startups(player, int(card.get("round_delta", 1)), float(card.value), int(card.get("valuation_bonus", 0)))
		"land_discount":
			TimedEffects.add_player_effect(str(player.id), "land_discount", float(card.value), int(card.duration), str(card.id), {"uses": 1})
			return _ok("土地测绘批复已登记", "本回合下一次购地价格降低%d%%" % roundi((1.0 - float(card.value)) * 100.0))
		"build_discount":
			TimedEffects.add_player_effect(str(player.id), "build_discount", float(card.value), int(card.duration), str(card.id), {"uses": 1})
			return _ok("建设补贴已登记", "本回合下一次建设投资降低%d%%" % roundi((1.0 - float(card.value)) * 100.0))
		"portfolio_dividend":
			var market_value: = Stocks.market_value(str(player.id))
			if market_value <= 0:
				return _fail("当前没有证券持仓，无法获得股息")
			var paid: = mini(int(card.get("cap", 60)), maxi(1, roundi(float(market_value) * float(card.value))))
			var before: = int(player.cash)
			GameState.apply_cash(str(player.id), paid, "组合股息到账")
			return _ok("股息到账%d万" % paid, "证券市值%d万；现金 %d → %d 万" % [market_value, before, int(player.cash)], {"cash": paid})
		"bank_interest_relief":
			TimedEffects.add_player_effect(str(player.id), "bank_interest_multiplier", float(card.value), int(card.duration), str(card.id))
			return _ok("利息减免函已生效", "本回合贷款利息降低%d%%" % roundi((1.0 - float(card.value)) * 100.0))
		"talent_capacity":
			var before: = int(player.get("talent_capacity_bonus", 0))
			player.talent_capacity_bonus = before + int(card.value)
			return _ok("人才编制已扩充", "员工库上限 %d → %d" % [Talents.ROSTER_LIMIT + before, Talents.roster_limit(str(player.id))])
		"debt_restructure":
			return _reduce_debt(player, int(card.value), int(card.get("secondary_value", 0)))
		"executive_search":
			return _recruit_executive(player)
		"land_acquisition":
			return _acquire_land(player, target_id, float(card.value), str(card.name))
		"land_grant":
			return _acquire_land(player, target_id, 0.0, str(card.name))
		"strategy_draw":
			var draw: = DrawPolicy.draw_many(str(player.id), int(card.value), "card_reward", false)
			return _ok("策略补给已到账", "随机补充%d张策略卡" % int(draw.get("count", 0)), {
				"draw_count": int(draw.get("count", 0)), 
				"draws": draw.get("draws", []), 
			})
		"red_strategy_draft":
			var reward: = Rewards.create_red_offer(str(player.id), str(card.id))
			if not bool(reward.get("ok", false)):
				return _fail(str(reward.get("message", "红色卡池暂不可用")))
			return _ok("红色机密档案已开启", "从三张红色明牌中选择两张", {
				"requires_card_choice": true, 
				"reward_offer": reward.get("offer", []).duplicate(), 
				"reward_required": 2, 
			})
		"gilded_gold_vault":
			var before: = int(player.cash)
			GameState.apply_cash(str(player.id), int(card.get("value", 350)), str(card.name))
			return _ok("黄金宝库已经开启", "现金 %d → %d 万" % [before, int(player.cash)], {"cash_grant": int(card.get("value", 350))})
		"gilded_royal_privilege":
			return _gilded_royal_privilege(player)
		"gilded_chosen_talent":
			return _gilded_chosen_talent(player)
		"gilded_total_blockade":
			TimedEffects.add_player_effect(str(target_player.id), "gilded_action_block", 1.0, 1, str(card.id))
			return _ok("全面封锁已经生效", "%s下回合不能买地或建设" % str(target_player.name), {"target_id": str(target_player.id), "blocked_actions": ["land", "build"]})
		"gilded_business_storm":
			TimedEffects.add_player_effect(str(target_player.id), "all_income_multiplier", float(card.get("value", 0.4)), 1, str(card.id))
			return _ok("停业风暴已经生效", "%s下一次结算的企业收入降低60%%" % str(target_player.name), {"target_id": str(target_player.id), "income_multiplier": float(card.get("value", 0.4))})
		"gilded_golden_wave":
			return _gilded_golden_wave(player, int(card.get("value", 240)), int(card.get("secondary_value", 40)))
		"west_cross_border_network":
			var operating_count := _premium_business_ids(player, true).size()
			var settlement := mini(int(card.get("cap", 136)), int(card.get("value", 48)) + operating_count * int(card.get("secondary_value", 22)))
			var cash_before := int(player.cash)
			GameState.apply_cash(str(player.id), settlement, str(card.name))
			Risks.adjust(str(player.id), 2, str(card.name), "跨境清算监管")
			return _ok("跨境清算完成", "西岸营业企业%d家；现金 %d → %d 万；风险 +2" % [operating_count, cash_before, int(player.cash)], {"cash": settlement, "premium_businesses": operating_count})
		"west_roadshow_window":
			var record: Dictionary = GameState.game_data.get("ipo_records", {}).get(str(player.id), {})
			if record.is_empty():
				player.ipo_roadshow_bonus = clampf(float(player.get("ipo_roadshow_bonus", 0.0)) + float(card.get("value", 8)) / 100.0, 0.0, 0.12)
				Risks.adjust(str(player.id), int(card.get("secondary_value", 1)), str(card.name), "路演承诺")
				return _ok("路演窗口已预约", "下一次上市审核通过率 +%d个百分点；风险 +%d" % [int(card.get("value", 8)), int(card.get("secondary_value", 1))])
			record.market_confidence = mini(100, int(record.get("market_confidence", 60)) + int(card.get("value", 8)))
			Risks.adjust(str(player.id), int(card.get("secondary_value", 1)), str(card.name), "路演承诺")
			return _ok("机构路演完成", "市场信心提升至%d；风险 +%d" % [int(record.market_confidence), int(card.get("secondary_value", 1))])
		"west_data_rights":
			var cash_before := int(player.cash)
			var risk_before := int(player.risk)
			GameState.apply_cash(str(player.id), int(card.get("value", 72)), str(card.name))
			Risks.adjust(str(player.id), -int(card.get("secondary_value", 4)), str(card.name), "数据合规")
			return _ok("数据资产确权完成", "许可收益 +%d 万；现金 %d → %d；风险 %d → %d" % [int(card.get("value", 72)), cash_before, int(player.cash), risk_before, int(player.risk)])
		"west_audit_sandbox":
			var record: Dictionary = GameState.game_data.get("ipo_records", {}).get(str(player.id), {})
			if record.is_empty():
				var risk_before := int(player.risk)
				Risks.adjust(str(player.id), -int(card.get("secondary_value", 6)), str(card.name), "上市审计准备")
				player.ipo_audit_prepared = true
				return _ok("审计准备已登记", "风险 %d → %d；下次上市申请披露缺口额外降低8个百分点" % [risk_before, int(player.risk)])
			var before_gap := float(record.get("disclosure_gap", 0.0))
			record.disclosure_gap = maxf(0.0, before_gap - float(card.get("value", 0.10)))
			return _ok("监管审计沙盒完成", "披露缺口 %.0f%% → %.0f%%" % [before_gap * 100.0, float(record.disclosure_gap) * 100.0])
		"west_smart_bridge":
			var business: Dictionary = GameState.game_data.get("businesses", {}).get(target_id, {})
			var land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
			if business.is_empty() or not bool(land.get("premium_zone", false)) or str(business.get("state", "")) not in ["operating", "loss_watch", "mortgaged"]:
				return _fail("智桥物流只能连接一家正在营业的西岸企业")
			TimedEffects.add_business_effect(target_id, "income_multiplier", float(card.get("value", 1.18)), int(card.get("duration", 1)), str(player.id), str(card.id))
			TimedEffects.add_business_effect(target_id, "cost_multiplier", float(card.get("secondary_value", 0.90)), int(card.get("duration", 1)), str(player.id), str(card.id))
			return _ok("智桥物流线路已接通", "%s下次结算收入 +18%%、固定成本 -10%%" % str(business.get("name", "西岸企业")))
		"west_institutional_placement":
			var record: Dictionary = GameState.game_data.get("ipo_records", {}).get(str(player.id), {})
			if record.is_empty() or str(record.get("status", "")) != "listed":
				player.ipo_placement_confidence_bonus = mini(12, int(player.get("ipo_placement_confidence_bonus", 0)) + 6)
				return _ok("机构配售预约已锁定", "上市成功时初始市场信心额外 +6")
			var confidence_before := int(record.get("market_confidence", 60))
			GameState.apply_cash(str(player.id), int(card.get("value", 110)), str(card.name))
			record.market_confidence = maxi(0, confidence_before - int(card.get("secondary_value", 5)))
			record.dilution_ratio = minf(0.49, float(record.get("dilution_ratio", 0.2)) + 0.01)
			return _ok("小额机构配售完成", "融资 +%d 万；市场信心 %d → %d；稀释率增加1个百分点" % [int(card.get("value", 110)), confidence_before, int(record.market_confidence)])
		"west_hq_alliance":
			var premium_ids := _premium_business_ids(player, true)
			if premium_ids.is_empty():
				GameState.apply_cash(str(player.id), 55, "滨水总部联盟选址补助")
				return _ok("总部联盟完成预签", "尚无西岸营业企业，改为获得55万选址补助")
			for business_id: String in premium_ids:
				TimedEffects.add_business_effect(business_id, "income_multiplier", float(card.get("value", 1.12)), int(card.get("duration", 2)), str(player.id), str(card.id))
			Risks.adjust(str(player.id), int(card.get("secondary_value", 2)), str(card.name), "总部联盟协调")
			return _ok("滨水总部联盟成立", "%d家西岸企业收入 +12%%，持续2回合；风险 +2" % premium_ids.size())
		"west_liquidity_reserve":
			TimedEffects.add_player_effect(str(player.id), "west_liquidity_reserve", int(card.get("value", 95)), int(card.get("duration", 2)), str(card.id), {"uses": 1})
			var risk_before := int(player.risk)
			Risks.adjust(str(player.id), -int(card.get("secondary_value", 3)), str(card.name), "流动性治理")
			return _ok("流动性储备舱已启用", "未来2回合首次经营亏损最多补偿95万；风险 %d → %d" % [risk_before, int(player.risk)])
	return _fail("卡牌效果尚未实现")


static func _resolve_west_program(player: Dictionary, card: Dictionary, target_id: String) -> Dictionary:
	var player_id := str(player.get("id", ""))
	var program := str(card.get("program", ""))
	match program:
		"single_income_next", "single_income_timed":
			var business := _west_business(target_id, ["operating", "loss_watch", "mortgaged"])
			if business.is_empty():
				return _fail("请选择一家正在营业的西岸企业")
			TimedEffects.add_business_effect(target_id, "income_multiplier", float(card.get("value", 1.0)), int(card.get("duration", 1)), player_id, str(card.id))
			return _ok("%s已获得增收支持" % str(business.get("name", "西岸企业")), "收入 +%d%%，持续%d回合" % [roundi((float(card.get("value", 1.0)) - 1.0) * 100.0), int(card.get("duration", 1))])
		"cash_per_west_business":
			var count := _premium_business_ids(player, true).size()
			var gain := mini(int(card.get("cap", 100)), count * int(card.get("value", 20)))
			GameState.apply_cash(player_id, gain, str(card.name))
			return _ok("夜航订单已结算", "%d家西岸企业，共获得%d万" % [count, gain], {"cash_grant": gain})
		"single_cost_next":
			var business := _west_business(target_id, ["operating", "loss_watch", "mortgaged"])
			if business.is_empty():
				return _fail("请选择一家正在营业的西岸企业")
			TimedEffects.add_business_effect(target_id, "cost_multiplier", float(card.get("value", 1.0)), int(card.get("duration", 1)), player_id, str(card.id))
			return _ok("智能仓配已启用", "%s下次固定成本 -%d%%" % [str(business.get("name", "西岸企业")), roundi((1.0 - float(card.get("value", 1.0))) * 100.0)])
		"all_cost_timed":
			var ids := _premium_business_ids(player, true)
			for business_id: String in ids:
				TimedEffects.add_business_effect(business_id, "cost_multiplier", float(card.get("value", 1.0)), int(card.get("duration", 1)), player_id, str(card.id))
			return _ok("绿色电网已经接通", "%d家西岸企业固定成本 -%d%%，持续%d回合" % [ids.size(), roundi((1.0 - float(card.get("value", 1.0))) * 100.0), int(card.get("duration", 1))])
		"safe_cash":
			var gain := int(card.get("value", 0))
			var safe_bonus := int(card.get("secondary_value", 0)) if int(player.get("risk", 0)) <= int(card.get("cap", 25)) else 0
			gain += safe_bonus
			GameState.apply_cash(player_id, gain, str(card.name))
			return _ok("临港补给已到账", "获得%d万%s" % [gain, "（含稳健奖励）" if safe_bonus > 0 else ""], {"cash_grant": gain})
		"talent_capacity_timed":
			player.talent_capacity_bonus = int(player.get("talent_capacity_bonus", 0)) + int(card.get("value", 1))
			TimedEffects.add_player_effect(player_id, "temporary_talent_capacity", int(card.get("value", 1)), int(card.get("duration", 3)), str(card.id))
			return _ok("人才班车开始运行", "人才容量 +%d，持续%d回合" % [int(card.get("value", 1)), int(card.get("duration", 3))])
		"construction_accelerate":
			var business := _west_business(target_id, ["constructing"])
			if business.is_empty():
				return _fail("请选择一个西岸在建项目")
			var before := int(business.get("remaining_rounds", 0))
			ConstructionProgressService.apply_delta(business, -int(card.get("value", 1)), str(card.id), int(GameState.game_data.get("round", 0)))
			if int(business.get("remaining_rounds", 0)) <= 0:
				_complete_business(business)
			return _ok("工地夜班已经完成", "剩余工期 %d → %d 回合" % [before, maxi(0, int(business.get("remaining_rounds", 0)))])
		"construction_subsidy":
			var business := _west_business(target_id, ["constructing"])
			if business.is_empty():
				return _fail("请选择一个西岸在建项目")
			GameState.apply_cash(player_id, int(card.get("value", 50)), str(card.name))
			Risks.adjust(player_id, int(card.get("secondary_value", 1)), str(card.name), "建设提速")
			return _ok("建设补助已经到账", "%s获得%d万；风险 +%d" % [str(business.get("name", "西岸项目")), int(card.get("value", 50)), int(card.get("secondary_value", 1))])
		"restore_build_action":
			if int(player.get("actions", {}).get("build", 0)) > 0:
				player.actions.build = int(player.actions.build) - 1
				return _ok("施工通行证已生效", "本回合恢复1次建设机会")
			GameState.apply_cash(player_id, int(card.get("value", 30)), str(card.name))
			return _ok("施工通行证改为补贴", "尚未使用建设机会，获得%d万" % int(card.get("value", 30)))
		"west_land_discount":
			TimedEffects.add_player_effect(player_id, "west_land_discount", float(card.get("value", 0.9)), int(card.get("duration", 3)), str(card.id), {"uses": 1})
			return _ok("土地测绘已经完成", "下一块西岸土地价格 -%d%%" % roundi((1.0 - float(card.get("value", 0.9))) * 100.0))
		"empty_land_cash":
			var count := 0
			for land_id: String in player.get("land_ids", []):
				var land: Dictionary = GameState.game_data.get("lands", {}).get(land_id, {})
				if bool(land.get("premium_zone", false)) and str(land.get("state", "")) == "owned_empty":
					count += 1
			var gain := mini(int(card.get("cap", 90)), count * int(card.get("value", 30)))
			GameState.apply_cash(player_id, gain, str(card.name))
			return _ok("滨水补贴已结算", "%d块西岸空地，共获得%d万" % [count, gain], {"cash_grant": gain})
		"business_value":
			var business := _west_business(target_id, ["constructing", "operating", "loss_watch", "mortgaged"])
			if business.is_empty():
				return _fail("请选择一家西岸企业")
			var before := int(business.get("value", 0))
			business.value = before + int(card.get("value", 60))
			return _ok("资产点亮完成", "%s价值 %d → %d 万" % [str(business.get("name", "西岸企业")), before, int(business.value)])
		"risk_reduce":
			var before := int(player.get("risk", 0))
			Risks.adjust(player_id, -int(card.get("value", 6)), str(card.name), "西岸安全")
			return _ok("安全巡检完成", "风险 %d → %d" % [before, int(player.risk)])
		"attack_shield":
			TimedEffects.add_player_effect(player_id, "west_attack_shield", 1, int(card.get("duration", 2)), str(card.id), {"uses": int(card.get("value", 1))})
			return _ok("数据备份护盾已启动", "未来%d回合抵挡下一次对手卡牌负面效果" % int(card.get("duration", 2)))
		"loss_watch_recover":
			var business := _west_business(target_id, ["loss_watch"])
			if business.is_empty():
				return _fail("请选择一家处于亏损观察的西岸企业")
			business.state = "operating"
			business.loss_rounds = 0
			return _ok("应急灯塔已经响应", "%s恢复正常经营" % str(business.get("name", "西岸企业")))
		"ipo_rehearsal":
			var record: Dictionary = GameState.game_data.get("ipo_records", {}).get(player_id, {})
			if str(record.get("status", "")) == "listed":
				var before := int(record.get("market_confidence", 60))
				record.market_confidence = mini(100, before + int(card.get("value", 6)))
				return _ok("上市彩排转为市场展示", "市场信心 %d → %d" % [before, int(record.market_confidence)])
			player.ipo_roadshow_bonus = minf(0.12, float(player.get("ipo_roadshow_bonus", 0.0)) + float(card.get("value", 6)) / 100.0)
			return _ok("上市彩排完成", "下次上市成功率 +%d%%" % int(card.get("value", 6)))
		"shareholder_day":
			var record: Dictionary = GameState.game_data.get("ipo_records", {}).get(player_id, {})
			if str(record.get("status", "")) == "listed":
				GameState.apply_cash(player_id, int(card.get("value", 30)), str(card.name))
				var before := int(record.get("market_confidence", 60))
				record.market_confidence = mini(100, before + int(card.get("secondary_value", 5)))
				return _ok("股东开放日完成", "获得%d万；市场信心 %d → %d" % [int(card.get("value", 30)), before, int(record.market_confidence)])
			var before := int(player.get("risk", 0))
			Risks.adjust(player_id, -int(card.get("cap", 4)), str(card.name), "公众沟通")
			return _ok("开放日转为公众参观", "风险 %d → %d" % [before, int(player.risk)])
		"stock_price_move":
			return _move_stock_price(target_id, float(card.get("value", 0.04)))
		"listed_buyback":
			var record: Dictionary = GameState.game_data.get("ipo_records", {}).get(player_id, {})
			if str(record.get("status", "")) != "listed":
				return _fail("小额回购仅在上市后可用")
			var cost := int(card.get("value", 60))
			if int(player.get("cash", 0)) < cost:
				return _fail("现金不足，需要%d万" % cost)
			GameState.apply_cash(player_id, -cost, str(card.name))
			var before := int(record.get("market_confidence", 60))
			record.market_confidence = mini(100, before + int(card.get("secondary_value", 8)))
			ListedMarket.queue_impulse(player_id, float(card.get("cap", 0.03)), str(card.name))
			return _ok("小额回购已提交", "花费%d万；市场信心 %d → %d；自家股价获得上行动力" % [cost, before, int(record.market_confidence)])
		"dual_city_order":
			var has_west := not _premium_business_ids(player, true).is_empty()
			var has_original := false
			for business_id: String in player.get("business_ids", []):
				var business: Dictionary = GameState.game_data.get("businesses", {}).get(business_id, {})
				var land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
				if not bool(land.get("premium_zone", false)) and str(business.get("state", "")) in ["operating", "loss_watch", "mortgaged"]:
					has_original = true
					break
			var gain := int(card.get("value", 90)) if has_west and has_original else int(card.get("secondary_value", 35))
			GameState.apply_cash(player_id, gain, str(card.name))
			return _ok("双城联单已结算", "获得%d万%s" % [gain, "（双城条件达成）" if has_west and has_original else ""])
		"restore_sp":
			return _ok("策略充能已经准备", "本张卡结算后恢复%d SP" % int(card.get("value", 2)), {"restore_sp": int(card.get("value", 2))})
		"draw_west_ordinary":
			var pool: Array = GameConfig.list("cards").filter(func(item: Dictionary) -> bool:
				return str(item.get("series", "")) == "west_bank" and str(item.get("rarity", "")) == "west_bank" and str(item.get("id", "")) != str(card.id))
			if pool.is_empty():
				return _fail("当前没有可抽取的西岸普通卡")
			var chosen: Dictionary = pool[GameState.rng.randi_range(0, pool.size() - 1)]
			var result := DrawPolicy.acquire_specific(player_id, str(chosen.id), "west_bank_bonus", false)
			return _ok("西岸加抽完成", "%s%s" % [str(chosen.name), "已转为卡牌积分" if bool(result.get("discarded", false)) else "已收入手牌"], {"drawn_card_id": str(chosen.id)})
		"construction_cash":
			var count := _premium_business_ids_by_state(player, ["constructing"]).size()
			var gain := mini(int(card.get("cap", 100)), count * int(card.get("value", 25)))
			GameState.apply_cash(player_id, gain, str(card.name))
			return _ok("工程返款已结算", "%d个西岸在建项目，共返还%d万" % [count, gain])
		"cash_for_risk":
			GameState.apply_cash(player_id, int(card.get("value", 100)), str(card.name))
			Risks.adjust(player_id, int(card.get("secondary_value", 4)), str(card.name), "灵活周转")
			return _ok("灵活周转完成", "获得%d万；风险 +%d" % [int(card.get("value", 100)), int(card.get("secondary_value", 4))])
		"debt_buffer":
			if player.get("loans", []).is_empty():
				var before := int(player.get("risk", 0))
				Risks.adjust(player_id, -int(card.get("cap", 5)), str(card.name), "无债奖励")
				return _ok("债务缓冲转为稳健奖励", "没有贷款；风险 %d → %d" % [before, int(player.risk)])
			return _reduce_debt(player, int(card.get("value", 90)), int(card.get("secondary_value", 2)))
		"brand_upgrade":
			var business := _west_business(target_id, ["operating", "loss_watch", "mortgaged"])
			if business.is_empty():
				return _fail("请选择一家正在营业的西岸企业")
			business.value = int(business.get("value", 0)) + int(card.get("value", 35))
			TimedEffects.add_business_effect(target_id, "income_multiplier", float(card.get("secondary_value", 1.08)), int(card.get("duration", 1)), player_id, str(card.id))
			return _ok("品牌升级完成", "%s价值 +%d万；下次收入 +%d%%" % [str(business.get("name", "西岸企业")), int(card.get("value", 35)), roundi((float(card.get("secondary_value", 1.08)) - 1.0) * 100.0)])
		"partner_procurement":
			var rival := GameState.player(target_id)
			if rival.is_empty() or target_id == player_id:
				return _fail("请选择一名对手")
			GameState.apply_cash(player_id, int(card.get("value", 65)), str(card.name))
			GameState.apply_cash(target_id, int(card.get("secondary_value", 20)), str(card.name))
			return _ok("伙伴采购已经签约", "你获得%d万；%s获得%d万" % [int(card.get("value", 65)), str(rival.name), int(card.get("secondary_value", 20))])
		"friendly_escort":
			var rival := GameState.player(target_id)
			if rival.is_empty() or target_id == player_id:
				return _fail("请选择一名对手")
			Risks.adjust(player_id, -int(card.get("value", 5)), str(card.name), "友好护航")
			Risks.adjust(target_id, -int(card.get("secondary_value", 2)), str(card.name), "友好护航")
			GameState.apply_cash(player_id, int(card.get("cap", 25)), str(card.name))
			return _ok("友好护航已经完成", "你的风险 -%d、现金 +%d万；%s风险 -%d" % [int(card.get("value", 5)), int(card.get("cap", 25)), str(rival.name), int(card.get("secondary_value", 2))])
		"stock_hint_subsidy":
			if not GameState.game_data.get("stocks", {}).has(target_id):
				return _fail("请选择一只证券")
			TimedEffects.add_player_effect(player_id, "stock_hint", 1, int(card.get("duration", 1)), str(card.id), {"target_id": target_id})
			GameState.apply_cash(player_id, int(card.get("value", 25)), str(card.name))
			return _ok("趋势屏已经锁定", "获得%d万信息补助；已显示该证券走势提示" % int(card.get("value", 25)))
		"west_festival":
			var ids := _premium_business_ids(player, true)
			for business_id: String in ids:
				TimedEffects.add_business_effect(business_id, "income_multiplier", float(card.get("value", 1.10)), int(card.get("duration", 1)), player_id, str(card.id))
			var record: Dictionary = GameState.game_data.get("ipo_records", {}).get(player_id, {})
			var confidence_gain := 0
			if str(record.get("status", "")) == "listed":
				confidence_gain = int(card.get("secondary_value", 3))
				record.market_confidence = mini(100, int(record.get("market_confidence", 60)) + confidence_gain)
			return _ok("湾区庆典已经开幕", "%d家西岸企业下次收入 +%d%%%s" % [ids.size(), roundi((float(card.get("value", 1.10)) - 1.0) * 100.0), "；市场信心 +%d" % confidence_gain if confidence_gain > 0 else ""])
		"advanced_quantum_matrix":
			GameState.apply_cash(player_id, int(card.get("value", 160)), str(card.name))
			Risks.adjust(player_id, -int(card.get("secondary_value", 6)), str(card.name), "量子资本")
			return _ok("量子资本矩阵已经展开", "获得%d万；风险 -%d；结算后恢复%d SP" % [int(card.get("value", 160)), int(card.get("secondary_value", 6)), int(card.get("cap", 1))], {"restore_sp": int(card.get("cap", 1))})
		"advanced_enterprise_leap":
			var business := _west_business(target_id, ["constructing", "operating", "loss_watch", "mortgaged"])
			if business.is_empty():
				return _fail("请选择一家西岸企业")
			if str(business.get("state", "")) == "constructing":
				business.remaining_rounds = 0
				_complete_business(business)
				return _ok("星环跃迁完成", "%s立即完工并进入经营" % str(business.get("name", "西岸项目")))
			business.value = int(business.get("value", 0)) + int(card.get("secondary_value", 80))
			TimedEffects.add_business_effect(target_id, "income_multiplier", float(card.get("value", 1.35)), int(card.get("duration", 2)), player_id, str(card.id))
			return _ok("星环企业跃迁完成", "%s价值 +%d万；收入 +%d%%，持续%d回合" % [str(business.get("name", "西岸企业")), int(card.get("secondary_value", 80)), roundi((float(card.get("value", 1.35)) - 1.0) * 100.0), int(card.get("duration", 2))])
		"advanced_time_shield":
			var before := int(player.get("risk", 0))
			Risks.adjust(player_id, -int(card.get("value", 12)), str(card.name), "时空护盾")
			TimedEffects.add_player_effect(player_id, "west_attack_shield", 1, int(card.get("duration", 2)), str(card.id), {"uses": 1})
			TimedEffects.add_player_effect(player_id, "west_liquidity_reserve", int(card.get("secondary_value", 120)), int(card.get("duration", 2)), str(card.id), {"uses": 1})
			return _ok("湾区时空护盾已经展开", "风险 %d → %d；获得卡牌防护和%d万亏损保护" % [before, int(player.risk), int(card.get("secondary_value", 120))])
	return _fail("西岸卡牌程序不存在：%s" % program)


static func _west_business(target_id: String, states: Array) -> Dictionary:
	var business: Dictionary = GameState.game_data.get("businesses", {}).get(target_id, {})
	var land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
	if business.is_empty() or not bool(land.get("premium_zone", false)) or str(business.get("state", "")) not in states:
		return {}
	return business


static func _premium_business_ids_by_state(player: Dictionary, states: Array) -> Array[String]:
	var result: Array[String] = []
	for business_id: String in player.get("business_ids", []):
		if not _west_business(business_id, states).is_empty():
			result.append(business_id)
	return result


static func _complete_business(business: Dictionary) -> void:
	business.state = "operating"
	business.remaining_rounds = 0
	business.operating_since_round = int(GameState.game_data.get("round", 0))
	var land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
	if not land.is_empty():
		land.state = "operating"


static func _premium_business_ids(player: Dictionary, operating_only: bool) -> Array[String]:
	var result: Array[String] = []
	for business_id: String in player.get("business_ids", []):
		var business: Dictionary = GameState.game_data.get("businesses", {}).get(business_id, {})
		var land: Dictionary = GameState.game_data.get("lands", {}).get(str(business.get("land_id", "")), {})
		if not bool(land.get("premium_zone", false)):
			continue
		if operating_only and str(business.get("state", "")) not in ["operating", "loss_watch", "mortgaged"]:
			continue
		result.append(business_id)
	return result


static func _gilded_royal_privilege(player: Dictionary) -> Dictionary:
	var restored: Array[String] = []
	for action_name in ["land", "build"]:
		if int(player.actions.get(action_name, 0)) > 0:
			player.actions[action_name] = int(player.actions.get(action_name, 0)) - 1
			restored.append("购地" if action_name == "land" else "建设")
	if restored.is_empty():
		return _fail("本回合还没有用掉买地或建设机会")
	return _ok("王者特权已经生效", "%s机会已恢复" % "和".join(restored), {"restored_actions": restored})


static func _gilded_chosen_talent(player: Dictionary) -> Dictionary:
	if player.get("talent_ids", []).size() >= Talents.roster_limit(str(player.id)):
		return _fail("人才名额已满，请先安排或替换人才")
	var owned: Dictionary = {}
	for rival: Dictionary in GameState.game_data.get("players", []):
		for talent_id: String in rival.get("talent_ids", []):
			owned[talent_id] = true
	var candidates: Array = GameConfig.list("talents").filter( func(talent: Dictionary) -> bool:
		return str(talent.get("quality", "")) == "red" and not owned.has(str(talent.id)))
	if candidates.is_empty():
		return _fail("本局顶级人才已经全部被招募")
	var talent: Dictionary = candidates[GameState.rng.randi_range(0, candidates.size() - 1)]
	player.talent_ids.append(str(talent.id))
	GameState._record(str(player.id), "gilded_talent_acquired", {"talent_id": str(talent.id), "talent_name": str(talent.name)})
	return _ok("天选英才已经加入", "免费获得顶级人才：%s  %s" % [str(talent.name), str(talent.effect)], {"talent_id": str(talent.id), "talent_name": str(talent.name)})


static func _gilded_golden_wave(player: Dictionary, gain: int, rival_loss: int) -> Dictionary:
	var before: = int(player.cash)
	GameState.apply_cash(str(player.id), gain, "金色浪潮")
	var losses: Array[String] = []
	for rival: Dictionary in GameState.game_data.get("players", []):
		if str(rival.id) == str(player.id) or bool(rival.get("eliminated", false)):
			continue
		var paid: = mini(rival_loss, maxi(0, int(rival.cash)))
		if paid > 0:
			GameState.apply_cash(str(rival.id), - paid, "金色浪潮")
		losses.append("%s -%d万" % [str(rival.name), paid])
		GameState.game_data.get_or_add("card_notifications", []).append({"recipient_id": str(rival.id), "acknowledged": false, "headline": "金色浪潮席卷全场", "body": "%s发动《金色浪潮》，你损失%d万现金。" % [str(player.name), paid]})
	return _ok("金色浪潮席卷全场", "你的现金 %d → %d 万；%s" % [before, int(player.cash), "、".join(losses)], {"cash_grant": gain, "rival_losses": losses})


static func _change_construction(player: Dictionary, card: Dictionary, target_id: String) -> Dictionary:
	var business: Dictionary = GameState.game_data.businesses.get(target_id, {})
	var before: = int(business.get("remaining_rounds", 0))
	if str(business.get("state", "")) == "constructing":
		var delta: = int(card.value) if str(card.effect) == "construction_delay" else - int(card.value)
		ConstructionProgressService.apply_delta(business, delta, str(card.id), int(GameState.game_data.round))
		if int(business.remaining_rounds) <= 0:
			business.state = "operating"
			business.operating_since_round = int(GameState.game_data.round)
			GameState.game_data.lands[str(business.land_id)].state = "operating"
		return _ok("%s已完工" % str(business.name), "剩余工期 %d → 0 回合，立即进入经营" % before)
		return _ok("项目工期已调整", "剩余工期 %d → %d 回合" % [before, int(business.remaining_rounds)])
	var multiplier: = float(card.get("secondary_value", 0.7 if str(card.effect) == "construction_delay" else 1.4))
	TimedEffects.add_business_effect(target_id, "income_multiplier", multiplier, 1, str(player.id), str(card.id))
	return _ok("营业企业经营状态已调整", "本轮收入%s%d%%" % ["降低" if multiplier < 1.0 else "提高", roundi(absf(multiplier - 1.0) * 100.0)])


static func _bargain_buy(player: Dictionary, stock_id: String, shares: int, discount: float) -> Dictionary:
	var stock: Dictionary = GameState.game_data.stocks.get(stock_id, {})
	var cost: = Economy.stock_trade_value(float(stock.price), shares, discount)
	if int(player.cash) < cost:
		return _fail("现金不足，无法完成价值买入")
	var before: = int(player.cash)
	GameState.apply_cash(str(player.id), - cost, "价值买入")
	var holding: Dictionary = player.stocks.get(stock_id, {"shares": 0, "avg": 0.0})
	var old_shares: = int(holding.get("shares", 0))
	var old_cost: = float(holding.get("avg", 0.0)) * float(old_shares)
	holding.shares = old_shares + shares
	holding.avg = (old_cost + float(stock.price) * discount * float(shares)) / float(holding.shares)
	player.stocks[stock_id] = holding
	return _ok("价值买入完成", "买入%d股，价格%.0f折；现金 %d → %d 万" % [shares, discount * 10.0, before, int(player.cash)], {"cost": cost, "shares": shares, "discount": discount})


static func _move_stock_price(stock_id: String, change: float) -> Dictionary:
	var stock: Dictionary = GameState.game_data.stocks.get(stock_id, {})
	if stock.is_empty():
		return _fail("目标证券不存在")
	var before: = float(stock.get("price", 0.0))
	var applied: = clampf(change, -0.18, 0.18)
	var after: = snappedf(maxf(50.0, before * (1.0 + applied)), 0.01)
	var history: Array = stock.get("history", []).duplicate()
	if history.is_empty():
		history.append(before)
	history.append(after)
	stock.history = history.slice(maxi(0, history.size() - 7))
	stock.price = after
	stock.last_change = snappedf(applied, 0.0001)
	stock.risk_label = "异常波动" if absf(applied) >= 0.15 else "高波动" if absf(applied) >= 0.08 else "正常"
	return _ok("证券价格已更新", "%s价格 %.2f → %.2f（%+d%%）" % [str(stock.get("name", stock_id)), before, after, roundi(applied * 100.0)], {"stock_id": stock_id, "price_before": before, "price_after": after, "change": applied})


static func _accelerate_startups(player: Dictionary, round_delta: int, success_bonus: float, valuation_bonus: int) -> Dictionary:
	var active: Array = player.get("active_projects", []).filter( func(item: Dictionary) -> bool:
		return str(item.get("status", "")) == "active" and not bool(item.get("resolved", false)))
	if active.is_empty():
		return _fail("当前没有进行中的创投项目")
	for project: Dictionary in active:
		project.remaining_rounds = maxi(1, int(project.get("remaining_rounds", 1)) - round_delta)
		project.success_rate = minf(0.95, float(project.get("success_rate", 0.0)) + success_bonus)
		project.current_valuation = int(project.get("current_valuation", 0)) + valuation_bonus
	return _ok("已强化%d个创投项目" % active.size(), "全部项目工期 -%d 回合、成功率 +%d%%、当前估值 +%d 万" % [round_delta, roundi(success_bonus * 100.0), valuation_bonus], {"affected": active.size()})


static func _reduce_debt(player: Dictionary, requested: int, risk_reduction: int) -> Dictionary:
	var remaining: = requested
	var reduced: = 0
	for loan: Dictionary in player.get("loans", []).duplicate():
		if remaining <= 0:
			break
		var principal: = int(loan.get("principal", 0))
		var applied: = mini(principal, remaining)
		loan.principal = principal - applied
		loan.unpaid_principal = mini(int(loan.get("unpaid_principal", 0)), int(loan.principal))
		player.debt = maxi(0, int(player.debt) - applied)
		reduced += applied
		remaining -= applied
		if int(loan.principal) <= 0 and int(loan.get("unpaid_interest", 0)) <= 0 and int(loan.get("overdue_fee", 0)) <= 0:
			if str(loan.get("kind", "")) == "mortgage":
				var land_id: = str(loan.get("asset_id", ""))
				if GameState.game_data.get("lands", {}).has(land_id):
					GameState.game_data.lands[land_id].mortgaged = false
			player.loans.erase(loan)
	var risk_before: = int(player.risk)
	Risks.adjust(str(player.id), - risk_reduction, "债务重组", "银行治理")
	if reduced <= 0:
		return _fail("当前没有可重组贷款本金")
	return _ok("已重组%d万贷款本金" % reduced, "负债本金 -%d 万；风险 %d → %d" % [reduced, risk_before, int(player.risk)], {"principal_reduced": reduced})


static func _recruit_executive(player: Dictionary) -> Dictionary:
	if player.talent_ids.size() >= Talents.roster_limit(str(player.id)):
		return _fail("员工库已满，请先裁员")
	for quality in ["gold", "platinum"]:
		for talent: Dictionary in GameConfig.list("talents"):
			if str(talent.get("quality", "")) == quality and not player.talent_ids.has(str(talent.id)):
				player.talent_ids.append(str(talent.id))
				return _ok("已签约%s" % str(talent.name), "免费获得1名%s人才；员工库 %d/%d" % ["金色" if quality == "gold" else "铂金", player.talent_ids.size(), Talents.roster_limit(str(player.id))], {"talent_id": str(talent.id)})
	return _fail("没有可签约的高级人才")


static func _acquire_land(player: Dictionary, land_id: String, multiplier: float, reason: String) -> Dictionary:
	var land: Dictionary = GameState.game_data.lands.get(land_id, {})
	if land.is_empty() or str(land.get("state", "")) != "available":
		return _fail("目标土地不可购买")
	var limits: Dictionary = GameConfig.dict_value("balance").get("land_limits", {})
	var limit: = int(limits.get(str(GameState.game_data.round_limit), 7))
	if player.land_ids.size() >= limit:
		return _fail("已达到土地上限")
	if int(player.actions.get("land", 0)) >= 1:
		return _fail("本轮已使用购地行动")
	var cost: = roundi(float(land.price) * multiplier)
	if int(player.cash) < cost:
		return _fail("现金不足，需要%d万" % cost)
	var cash_before: = int(player.cash)
	if cost > 0:
		GameState.apply_cash(str(player.id), - cost, reason)
	land.owner_id = str(player.id)
	land.state = "owned_empty"
	land.mortgaged = false
	player.land_ids.append(land_id)
	player.actions.land = int(player.actions.get("land", 0)) + 1
	Districts.recalculate()
	return _ok("已取得%s" % land_id, "土地价格%d万，实际支付%d万；现金 %d → %d 万" % [int(land.price), cost, cash_before, int(player.cash)], {"land_id": land_id, "cost": cost})


static func _transfer_cash(from_id: String, to_id: String, requested: int, reason: String) -> int:
	var source: = GameState.player(from_id)
	var paid: = mini(GameState.available_cash(from_id), requested)
	if paid > 0:
		GameState.apply_cash(from_id, - paid, reason)
		GameState.apply_cash(to_id, paid, reason)
	return paid


static func _target_owner(target_id: String) -> String:
	if not GameState.player(target_id).is_empty():
		return target_id
	return str(GameState.game_data.businesses.get(target_id, {}).get("owner_id", ""))


static func _best_assigned_talent(business: Dictionary) -> String:
	var best_id: = ""
	var best_rank: = -1
	for talent_id: String in business.get("employees", []):
		if talent_id.is_empty():
			continue
		var talent: Dictionary = GameConfig.by_id("talents", talent_id)
		var rank: = Talents.quality_rank(str(talent.get("quality", "blue")))
		if rank > best_rank:
			best_rank = rank
			best_id = talent_id
	return best_id


static func _ok(message: String, receipt: String, details: = {}) -> Dictionary:
	var result: = {"ok": true, "message": message, "receipt": receipt}
	result.merge(details, true)
	return result


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}
