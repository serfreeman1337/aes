/* 
	Advanced Experience System
	by serfreeman1337		http://gf.hldm.org/
*/

/*
	Random CSTRIKE Bonuses
*/

#include <amxmodx>

#if AMXX_VERSION_NUM < 183
	#include <colorchat>
	
	#define print_team_default DontChange
	#define print_team_grey Grey
	#define print_team_red Red
	#define print_team_blue Blue
	
	#define MAX_NAME_LENGTH	32
	#define MAX_PLAYERS 32
	
	#define client_disconnected client_disconnect
#endif

#include <aes_v>

#include <cstrike>
#include <fakemeta>
#include <fun>
#include <hamsandwich>

#define PLUGIN "AES: Bonus CSTRIKE"
#define VERSION "0.5 Vega"
#define AUTHOR "serfreeman1337"

// биты? да это же круто!
enum _:
{
	SUPER_NICHEGO,
	SUPER_NADE,
	SUPER_DEAGLE
}

new g_players[MAX_PLAYERS + 1],g_maxplayers

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	RegisterHam(Ham_Killed,"player","On_Player_Killed")
	RegisterHam(Ham_TakeDamage,"player","On_Player_TakeDamage")
}

public client_disconnected(id)
{
	g_players[id] = SUPER_NICHEGO // сбрасываем возможности на дисконнекте
}

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
		{
			SetHamParamFloat(4,damage * 2.0)
		}
		else
		{
			new classname[32]
			pev(idinflictor,pev_classname,classname,31)
			
			if(!strcmp(classname,"grenade") && (g_players[idattacker] & (1 << SUPER_NADE))){
				set_task(0.5,"deSetNade",idattacker)
				
				SetHamParamFloat(4,damage * 3.0)
			}
		}
	}
	
	return HAM_IGNORED
}

// сбарсываем множитель урона гранаты
public deSetNade(id)
	g_players[id] &= ~(1<<SUPER_NADE)

public roundBonus_GiveDefuser(id,cnt){
	if(!cnt)
		return false
	
	if(cs_get_user_team(id) == CS_TEAM_CT)
	{
		cs_set_user_defuse(id)
	}
	
	return true
}

public roundBonus_GiveNV(id,cnt){
	if(!cnt)
	{
		return false
	}
	
	cs_set_user_nvg(id)
	
	return true
}

public roundBonus_GiveArmor(id,cnt){
	if(!cnt)
	{
		return false
	}
	
	switch(cnt)
	{
		case 1:
		{
			cs_set_user_armor(id,100,CS_ARMOR_KEVLAR)
		}
		case 2: 
		{
			cs_set_user_armor(id,100,CS_ARMOR_VESTHELM)
		}
		default:
		{
			cs_set_user_armor(id,cnt,CS_ARMOR_VESTHELM)
		}
	}
	
	return true
}

public roundBonus_GiveHP(id,cnt){
	if(!cnt)
		return false
	
	set_user_health(id,(get_user_health(id) + cnt))
	return true
}

#define CHECK_ALIVE(%1) \
if(!is_user_alive(%1)){\
	client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_ALIVE"); \
	return 0; \
}

public pointBonus_GiveM4a1(id)
{
	CHECK_ALIVE(id)
	
	DropWeaponSlot(id,1)
	
	give_item(id,"weapon_m4a1")
	cs_set_user_bpammo(id,CSW_M4A1,90)
	
	return true
}

public pointBonus_GiveAk47(id)
{
	CHECK_ALIVE(id)
	
	DropWeaponSlot(id,1)
	
	give_item(id,"weapon_ak47")
	cs_set_user_bpammo(id,CSW_AK47,90)
	
	return true
}

public pointBonus_GiveAWP(id)
{
	CHECK_ALIVE(id)
	
	DropWeaponSlot(id,1)
	
	give_item(id,"weapon_awp")
	cs_set_user_bpammo(id,CSW_AWP,30)
	
	return true
}

public pointBonus_Give10000M(id)
{
	CHECK_ALIVE(id)
	
	new money = cs_get_user_money(id) + 10000
	money = clamp(money,0,16000)
	cs_set_user_money(id,money)
	
	return true
}

public pointBonus_Set200HP(id)
{
	CHECK_ALIVE(id)
	
	set_user_health(id,200)
	
	return true
}

public pointBonus_GiveMegaGrenade(id)
{
	CHECK_ALIVE(id)
	
	if(!user_has_weapon(id,CSW_HEGRENADE))
	{
		give_item(id,"weapon_hegrenade")
	}
	
	g_players[id] |= (1<<SUPER_NADE)
	
	client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_BONUS_GET_MEGAGRENADE")
	
	return true
}

public pointBonus_GiveMegaDeagle(id){
	CHECK_ALIVE(id)
	
	DropWeaponSlot(id,2)
	
	give_item(id,"weapon_deagle")
	cs_set_user_bpammo(id,CSW_DEAGLE,35) // какой максимум?
	
	g_players[id] |= (1<<SUPER_DEAGLE)
	
	client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_BONUS_GET_MEGADEAGLE")
	
	return true
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
