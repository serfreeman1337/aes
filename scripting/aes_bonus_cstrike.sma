/* 
	Advanced Experience System
	by serfreeman1337		http://gf.hldm.org/
*/

/*
	Random CSTRIKE Bonuses
*/

#include <amxmodx>
#include <cstrike>
#include <hamsandwich>
#include <fakemeta_util>

#include <colorchat>

#include <aes_main>

#define PLUGIN "AES: Bonus CSTRIKE"
#define VERSION "0.4"
#define AUTHOR "serfreeman1337"

// биты? да это же круто!
enum _:{
	SUPER_NICHEGO,
	SUPER_NADE,
	SUPER_DEAGLE
}

new g_players[33],g_maxplayers
new bonusEnablePointer,firstRoundPointer,aNewUseTime,buyTimePointer
new bool:st

new HamHook: hamSpawn

new iRound
new Float:g_fBuyTime[33]

public plugin_init(){
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	hamSpawn = RegisterHam(Ham_Spawn,"player","On_Player_Spawn")
	RegisterHam(Ham_Killed,"player","On_Player_Killed")
	RegisterHam(Ham_TakeDamage,"player","On_Player_TakeDamage")
	
	firstRoundPointer = register_cvar("aes_bonus_firstround","3")
	aNewUseTime = register_cvar("aes_bonus_time","-1.0")
	
	register_logevent("RoundStart",2,"0=World triggered","1=Round_Start")
	register_logevent("RoundRestart",2,"0=World triggered","1=Game_Commencing")
	register_event("TextMsg","RoundRestart","a","2&#Game_will_restart_in")
	
	g_maxplayers = get_maxplayers()
}

public RoundRestart(){
	if(!st)
		return
		
	iRound = 0
	
	set_pcvar_num(bonusEnablePointer,0)
}

public RoundStart(){
	if(!st)
		return
		
	iRound ++
	
	if(iRound < get_pcvar_num(firstRoundPointer))
		set_pcvar_num(bonusEnablePointer,0)
	else{
		set_pcvar_num(bonusEnablePointer,1)
	}
}

public plugin_cfg(){
	bonusEnablePointer = get_cvar_pointer("aes_bonus_enable")
	buyTimePointer = get_cvar_pointer("mp_buytime")
	
	if(get_pcvar_float(aNewUseTime) > 0.0)
		buyTimePointer = aNewUseTime
	else if(get_pcvar_float(aNewUseTime) == 0.0){
		buyTimePointer = 0
		DisableHamForward(hamSpawn)
	}
	
	if(!bonusEnablePointer){
		log_amx("get cvar pointer fail for ^"aes_bonus_enable^"")
		set_fail_state("get cvar pointer fail")
	}
	
	st = get_pcvar_num(bonusEnablePointer) == 1 ? true : false
}

public aes_on_anew_command(id){
	if(iRound < get_pcvar_num(firstRoundPointer)){
		client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_ROUND",get_pcvar_num(firstRoundPointer))
		
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public client_disconnect(id){
	g_fBuyTime[id] = 0.0
	g_players[id] = SUPER_NICHEGO // сбрасываем возможности на дисконнекте
}

public On_Player_Spawn(id)
	g_fBuyTime[id] = get_gametime() + 60 * get_pcvar_float(buyTimePointer)

public On_Player_Killed(id)
	g_players[id] = SUPER_NICHEGO // сбрасываем возможности при смерти

public On_Player_TakeDamage(victim,idinflictor,idattacker,Float:damage,damagebits){
	if(!idattacker || idattacker > g_maxplayers)
		return HAM_IGNORED
	
	if(!g_players[idattacker])
		return HAM_IGNORED
	
	if(0 < idinflictor <= g_maxplayers){
		new wp = get_user_weapon(idattacker)
		
		if(wp == CSW_DEAGLE && (g_players[idattacker] & (1 << SUPER_DEAGLE)))
			SetHamParamFloat(4,damage * 2.0)
		}else{
		new classname[32]
		pev(idinflictor,pev_classname,classname,31)
		
		if(!strcmp(classname,"grenade") && (g_players[idattacker] & (1 << SUPER_NADE))){
			set_task(0.5,"deSetNade",idattacker)
			
			SetHamParamFloat(4,damage * 3.0)
		}
	}
	
	return HAM_IGNORED
}

// сбарсываем множитель урона гранаты
public deSetNade(id)
	g_players[id] &= ~(1<<SUPER_NADE)

public roundBonus_GiveDefuser(id,cnt){
	if(!cnt)
		return
	
	if(cs_get_user_team(id) == CS_TEAM_CT)
		cs_set_user_defuse(id)
}

public roundBonus_GiveNV(id,cnt){
	if(!cnt)
		return
	
	cs_set_user_nvg(id)
}

public roundBonus_GiveArmor(id,cnt){
	if(!cnt)
		return
	
	switch(cnt){
		case 1: cs_set_user_armor(id,100,CS_ARMOR_KEVLAR)
			case 2: cs_set_user_armor(id,100,CS_ARMOR_VESTHELM)
			default: cs_set_user_armor(id,cnt,CS_ARMOR_VESTHELM)
	}
}

public roundBonus_GiveHP(id,cnt){
	if(!cnt)
		return
	
	fm_set_user_health(id,(get_user_health(id) + cnt))
}

#define CHECK_ALIVE(%1) \
if(!is_user_alive(%1)){\
	client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_ALIVE"); \
	return 0; \
}

#define CHECK_ROUNDTIME(%1) \
if(get_gametime() > g_fBuyTime[id] && buyTimePointer){\
	client_print(id,print_center,"%L",id,"AES_ANEW_BUYTIME",floatround(60.0 * get_pcvar_float(buyTimePointer))); \
	return 0; \
}

public pointBonus_GiveM4a1(id){
	CHECK_ALIVE(id)
	CHECK_ROUNDTIME(id)
	
	DropWeaponSlot(id,1)
	
	fm_give_item(id,"weapon_m4a1")
	cs_set_user_bpammo(id,CSW_M4A1,90)
	
	return 1
}

public pointBonus_GiveAk47(id){
	CHECK_ALIVE(id)
	CHECK_ROUNDTIME(id)
	
	DropWeaponSlot(id,1)
	
	fm_give_item(id,"weapon_ak47")
	cs_set_user_bpammo(id,CSW_AK47,90)
	
	return 1
}

public pointBonus_GiveAWP(id){
	CHECK_ALIVE(id)
	CHECK_ROUNDTIME(id)
	
	DropWeaponSlot(id,1)
	
	fm_give_item(id,"weapon_awp")
	cs_set_user_bpammo(id,CSW_AWP,30)
	
	return 1
}

public pointBonus_Give10000M(id){
	CHECK_ALIVE(id)
	CHECK_ROUNDTIME(id)
	
	new money = cs_get_user_money(id) + 10000
	money = clamp(money,0,16000)
	cs_set_user_money(id,money)
	
	return 1
}

public pointBonus_Set200HP(id){
	CHECK_ALIVE(id)
	CHECK_ROUNDTIME(id)
	
	fm_set_user_health(id,200)
	
	return 1
}

public pointBonus_GiveMegaGrenade(id){
	CHECK_ALIVE(id)
	CHECK_ROUNDTIME(id)
	
	if(!user_has_weapon(id,CSW_HEGRENADE))
		fm_give_item(id,"weapon_hegrenade")
	
	g_players[id] |= (1<<SUPER_NADE)
	
	client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_BONUS_GET_MEGAGRENADE")
	
	return 1
}

public pointBonus_GiveMegaDeagle(id){
	CHECK_ALIVE(id)
	CHECK_ROUNDTIME(id)
	
	DropWeaponSlot(id,2)
	
	fm_give_item(id,"weapon_deagle")
	cs_set_user_bpammo(id,CSW_DEAGLE,35) // какой максимум?
	
	g_players[id] |= (1<<SUPER_DEAGLE)
	
	client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_BONUS_GET_MEGADEAGLE")
	
	return 1
}

DropWeaponSlot( iPlayer, iSlot ){
	static const m_rpgPlayerItems = 367; // player
	static const m_pNext = 42; // weapon_*
	static const m_iId = 43; // weapon_*
	
	if( !( 1 <= iSlot <= 2 ) )	{
		return 0;
	}
	
	new iCount;
	
	new iEntity = get_pdata_cbase( iPlayer, ( m_rpgPlayerItems + iSlot ), 5 );
	if( iEntity > 0 )	{
		new iNext;
		new szWeaponName[ 32 ];
		
		do	{
			iNext = get_pdata_cbase( iEntity, m_pNext, 4 );
			
			if( get_weaponname( get_pdata_int( iEntity, m_iId, 4 ), szWeaponName, charsmax( szWeaponName ) ) )		{
				engclient_cmd( iPlayer, "drop", szWeaponName );
				
				iCount++;
			}
		}	while( ( iEntity = iNext ) > 0 );
	}
	
	return iCount;
}
