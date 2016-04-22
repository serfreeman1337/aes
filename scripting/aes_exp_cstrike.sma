/* 
	Advanced Experience System
	by serfreeman1337		http://gf.hldm.org/
*/

/*
	Experience Collector (CSTRIKE)
*/

#include <amxmodx>

#include <cstrike>
#include <csstats>
#include <csx>

#include <colorchat>
#include <aes_main>

#define PLUGIN "AES: Exp CSTRIKE"
#define VERSION "0.3"
#define AUTHOR "serfreeman1337"

/* - CVARS - */

enum _:cvars_num {
	CVAR_XP_KILL,
	CVAR_XP_HS,
	CVAR_XP_C4_PLANT,
	CVAR_XP_C4_EXPLODE,
	CVAR_XP_C4_DEFUSED,
	CVAR_XP_FFA,
	CVAR_XP_HOST_GOT,
	CVAR_XP_HOST_RESCUE,
	CVAR_XP_VIP_ESCAPED,
	CVAR_XP_VIP_KILLED,
	CVAR_XP_GOAL_MIN_PLAYERS,
	CVAR_XP_DEATH,
	CVAR_ANEW_FRAGS,
	CVAR_ANEW_HS,
	CVAR_ANEW_KNIFE,
	CVAR_ANEW_HE,
	CVAR_ANEW_REST,
	CVAR_LEVEL_BONUS
}

new cvar[cvars_num],bool:isFFA

/* - ADD BONUS - */

enum _:Arrays{
	Array:FRAG_ARRAY,
	Array:HS_ARRAY,
	Array:KNIFE_ARRAY,
	Array:HE_ARRAY
}

new Array: g_BonusCvars[Arrays]
new frArrSize,hsArrSize,kfArrSize,heArrSize

new iResetOn,g_maxplayers,g_Players[33][4],bool:isAsMap

new iDbType,iBonusPointer

new map[32]

public plugin_init(){
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_dictionary_colored("aes.txt")
	
	cvar[CVAR_XP_KILL] = register_cvar("aes_xp_frag","1")
	cvar[CVAR_XP_HS] = register_cvar("aes_xp_hs","2")
	cvar[CVAR_XP_C4_PLANT] = register_cvar("aes_xp_c4_plant","1")
	cvar[CVAR_XP_C4_EXPLODE] = register_cvar("aes_xp_c4_explode","3")
	cvar[CVAR_XP_C4_DEFUSED] = register_cvar("aes_xp_c4_defused","4")
	cvar[CVAR_XP_HOST_GOT] = register_cvar("aes_xp_hostage_got","1")
	cvar[CVAR_XP_HOST_RESCUE] = register_cvar("aes_xp_hostage_rescue","1")
	cvar[CVAR_XP_VIP_ESCAPED] = register_cvar("aes_xp_vip_escaped","4")
	cvar[CVAR_XP_VIP_KILLED] = register_cvar("aes_xp_vip_killed","4")
	cvar[CVAR_XP_GOAL_MIN_PLAYERS] = register_cvar("aes_xp_goal_min_players","4")
	
	cvar[CVAR_XP_FFA] = register_cvar("aes_xp_ffa","0")
	
	cvar[CVAR_ANEW_FRAGS] = register_cvar("aes_anew_frags","10 1 20 2 30 3 40 5")
	cvar[CVAR_ANEW_HS] = register_cvar("aes_anew_hs","7 1 14 2 20 3 30 4")
	cvar[CVAR_ANEW_KNIFE] = register_cvar("aes_anew_knife","1 1 2 1 3 1 4 1")
	cvar[CVAR_ANEW_HE] = register_cvar("aes_anew_he","4 1 5 1 6 1 7 2")
	cvar[CVAR_ANEW_REST] = register_cvar("aes_anew_reset","1")
	
	cvar[CVAR_LEVEL_BONUS] = register_cvar("aes_bonus_levelup","3")
	cvar[CVAR_XP_DEATH] = register_cvar("aes_xp_death","0")
	
	g_maxplayers = get_maxplayers()
}

public plugin_cfg(){
	iDbType = get_cvar_num("aes_db_type")
	
	get_mapname(map,31)
	
	if(iDbType > 0){
		if(containi(map,"cs_") == 0){
			register_logevent("client_touched_a_hostage",3,"1=triggered","2=Touched_A_Hostage")
			register_logevent("client_rescued_a_hostage",3,"1=triggered","2=Rescued_A_Hostage")
		}else if(containi(map,"as_") == 0){
			isAsMap = true
			
			register_logevent("client_escaped_as_vip",3,"1=triggered","2=Escaped_As_VIP")
		}
	}
	
	isFFA = get_pcvar_num(cvar[CVAR_XP_FFA]) == 1 ? true : false
	
	iBonusPointer = get_cvar_pointer("aes_bonus_enable")
	
	if(!iBonusPointer)
		return

	g_BonusCvars[FRAG_ARRAY] = ArrayCreate(2)
	g_BonusCvars[HS_ARRAY] = ArrayCreate(2)
	g_BonusCvars[KNIFE_ARRAY] = ArrayCreate(2)
	g_BonusCvars[HE_ARRAY] = ArrayCreate(2)
	
	new levelString[512]
	
	get_pcvar_string(cvar[CVAR_ANEW_FRAGS],levelString,511)
	frArrSize = parse_aes_bonus_values(g_BonusCvars[FRAG_ARRAY],levelString)
	
	get_pcvar_string(cvar[CVAR_ANEW_HS],levelString,511)
	hsArrSize = parse_aes_bonus_values(g_BonusCvars[HS_ARRAY],levelString)
	
	get_pcvar_string(cvar[CVAR_ANEW_KNIFE],levelString,511)
	kfArrSize = parse_aes_bonus_values(g_BonusCvars[KNIFE_ARRAY],levelString)
	
	get_pcvar_string(cvar[CVAR_ANEW_HE],levelString,511)
	heArrSize = parse_aes_bonus_values(g_BonusCvars[HE_ARRAY],levelString)
	
	iResetOn = get_pcvar_num(cvar[CVAR_ANEW_REST])
}

public client_putinserver(id)
	if(!iDbType)
		set_task(0.1,"loadUserStats",id)	// статистика не сразу инициализируется

public loadUserStats(id){
	if(!is_user_connected(id))
		return
		
	new stats[8],bprelated[4],bh[8]
		
	get_user_stats(id,stats,bh)
	get_user_stats2(id,bprelated)
	
	new exp = get_exp_for_stats(stats,bprelated)
	
	new st[3]
	
	st[0] = exp
	st[1] = aes_get_level_for_exp(exp)
	st[2] = 0
	
	aes_set_player_stats(id,st)
}

get_exp_for_stats(stats[8],bprelated[4]){
	stats[0] = stats[0] - stats[2]
	
	new exp = (stats[0] * get_pcvar_num(cvar[CVAR_XP_KILL])) + (stats[2] * get_pcvar_num(cvar[CVAR_XP_HS]))
	exp += (bprelated[2] * get_pcvar_num(cvar[CVAR_XP_C4_PLANT])) + (bprelated[3] * get_pcvar_num(cvar[CVAR_XP_C4_EXPLODE]))
	exp += bprelated[1] * get_pcvar_num(cvar[CVAR_XP_C4_DEFUSED])
	
	return exp
	
}

public client_disconnect(id)
	if(iBonusPointer)
		arrayset(g_Players[id],0,4)

public client_death(killer,victim,wpn,hit,TK){
	if(!killer && killer > g_maxplayers || killer == victim)
		return
	
	if(TK && !isFFA)
		return

	aes_add_player_exp(killer,hit != HIT_HEAD ? get_pcvar_num(cvar[CVAR_XP_KILL]) : get_pcvar_num(cvar[CVAR_XP_HS]))
	aes_add_player_exp(victim,get_pcvar_num(cvar[CVAR_XP_DEATH]))
	
	// игрок убил VIP
	if(isAsMap && cs_get_user_vip(victim)){
		if(get_playersnum() >= get_pcvar_num(cvar[CVAR_XP_GOAL_MIN_PLAYERS]))
			aes_add_player_exp(killer,get_pcvar_num(cvar[CVAR_XP_VIP_KILLED]))
	}
		
	
	// бонусы не включены или временно не работают
	if(!iBonusPointer || !get_pcvar_num(iBonusPointer))
		return

	g_Players[killer][0] ++
	
	new bonusPoints = 0
	
	bonusPoints += get_current_player_bonuses(killer,frArrSize,0,g_BonusCvars[FRAG_ARRAY])
	
	if(hit == HIT_HEAD){
		g_Players[killer][1] ++
		
		bonusPoints += get_current_player_bonuses(killer,hsArrSize,1,g_BonusCvars[HS_ARRAY])
	}
	
	if(wpn == CSW_KNIFE){
		g_Players[killer][2] ++
		
		bonusPoints += get_current_player_bonuses(killer,kfArrSize,2,g_BonusCvars[KNIFE_ARRAY])
	}
		
	if(wpn == CSW_HEGRENADE){
		g_Players[killer][3] ++
		
		bonusPoints += get_current_player_bonuses(killer,heArrSize,3,g_BonusCvars[HE_ARRAY])
	}
		
	if(iResetOn == 1)
		arrayset(g_Players[victim],0,4)
	
	if(bonusPoints){
		client_print_color(killer,0,"%L %L",killer,"AES_TAG",killer,"AES_ANEW_GAIN",bonusPoints)
		aes_add_player_bonus(killer,bonusPoints)
	}
}


// бонусы при получении нового звания
public aes_player_levelup(id){
	if(!iBonusPointer || !get_pcvar_num(cvar[CVAR_LEVEL_BONUS]))
		return
		
	aes_add_player_bonus(id,get_pcvar_num(cvar[CVAR_LEVEL_BONUS]))
}

public bomb_planted(id){
	if(get_playersnum() < get_pcvar_num(cvar[CVAR_XP_GOAL_MIN_PLAYERS]))
		return
	
	aes_add_player_exp(id,get_pcvar_num(cvar[CVAR_XP_C4_PLANT]))
}
	
	
public bomb_explode(id){
	if(get_playersnum() < get_pcvar_num(cvar[CVAR_XP_GOAL_MIN_PLAYERS]))
		return
		
	aes_add_player_exp(id,get_pcvar_num(cvar[CVAR_XP_C4_EXPLODE]))
}
	
public bomb_defused(id){
	if(get_playersnum() < get_pcvar_num(cvar[CVAR_XP_GOAL_MIN_PLAYERS]))
		return
		
	aes_add_player_exp(id,get_pcvar_num(cvar[CVAR_XP_C4_DEFUSED]))
}

public client_escaped_as_vip(){
	if(get_playersnum() < get_pcvar_num(cvar[CVAR_XP_GOAL_MIN_PLAYERS]))
		return
	
	new arg[64],nn[2],userid
	
	read_logargv(0,arg,64)
	parse_loguser(arg,nn,1,userid)

	userid = find_player("k",userid)
	
	if(userid == 0)
		return

	aes_add_player_exp(userid,get_pcvar_num(cvar[CVAR_XP_VIP_ESCAPED]))
}

public client_touched_a_hostage(){
	if(get_playersnum() < get_pcvar_num(cvar[CVAR_XP_GOAL_MIN_PLAYERS]))
		return
		
	new arg[64],nn[2],userid
	
	read_logargv(0,arg,64)
	parse_loguser(arg,nn,1,userid)

	userid = find_player("k",userid)
	
	if(userid == 0)
		return
		
	aes_add_player_exp(userid,get_pcvar_num(cvar[CVAR_XP_HOST_GOT]))
}

public client_rescued_a_hostage(){
	if(get_playersnum() < get_pcvar_num(cvar[CVAR_XP_GOAL_MIN_PLAYERS]))
		return
		
	new arg[64],nn[2],userid
	
	read_logargv(0,arg,64)
	parse_loguser(arg,nn,1,userid)

	userid = find_player("k",userid)
	
	if(userid == 0)
		return
		
	aes_add_player_exp(userid,get_pcvar_num(cvar[CVAR_XP_HOST_RESCUE]))
}

// проверка на кол-во бонусных очков игрока
// cmpr - какой параметр проверяем
// Array:which - по какому массиву
public get_current_player_bonuses(id,size,cmpr,Array:which){
	new bonusPoints,rt[2],i
	
	for(i = 0 ; i < size ; ++i){
		ArrayGetArray(which,i,rt)
		
		if(g_Players[id][cmpr] == rt[0])
			bonusPoints += rt[1]
	}
	
	return bonusPoints
}

// парсер значений бонусов в массив
public parse_aes_bonus_values(Array:which,levelString[]){
	new stPos,ePos,rawPoint[20],rawVals[2],stState
	
	// значение не задано
	if(!strlen(levelString))
		return 0
	
	do {
		// ищем пробел
		ePos = strfind(levelString[stPos]," ")
		
		// узнаем значение с позиции stPos и длинной ePos
		formatex(rawPoint,ePos,levelString[stPos])
		rawVals[stState] = str_to_num(rawPoint)
		
		stPos += ePos + 1
		
		// указатель 2ой пары
		stState ++
		
		// два значения были найдены
		// записываем их в массив и сбрасываем указатель
		if(stState == 2){
			ArrayPushArray(which,rawVals)
			stState = 0
		}
	} while(ePos != -1)
	
	// возвращает кол-во 2ых пар
	return ArraySize(which)
}

public plugin_natives()
	register_native("aes_get_exp_for_stats","_aes_get_exp_for_stats")

/*
	Returns exp value for given stats.
	
	stats[8] = get_user_stats
	bprelated[4] = get_user_stats2
	
	@return - exp for given stats
	
	native aes_get_exp_for_stats(stats[8],stats2[4])
*/
	
public _aes_get_exp_for_stats(plugin,params){
	if(params < 2){
		log_error(AMX_ERR_NATIVE,"bad arguments num, expected 2, passed %d", params)
		
		return 0
	}
	
	new stats[8],bprelated[4]
	
	get_array(1,stats,8)
	get_array(2,bprelated,4)
	
	return get_exp_for_stats(stats,bprelated)
}
