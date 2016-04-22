/* 
	Advanced Experience System
	by serfreeman1337		http://gf.hldm.org/
*/

/*
	Bonus System
*/


#include <amxmodx>
#include <amxmisc>

#include <hamsandwich>
#include <fakemeta_util>

#include <colorchat>
#include <aes_main>

#define PLUGIN "AES: Bonus System"
#define VERSION "0.2"
#define AUTHOR "serfreeman1337"

enum _:stCfgs {
	ST_BONUS_SPAWN,
	ST_BOUNS_POINTS
}

enum _:itemType {
	ST_TYPE_GIVE,
	ST_TYPE_CALL
}

enum _:itemCfgFields{
	ST_TYPE,
	ST_WHAT,
	ST_PARAM1[128],
	ST_PARAM2[128],
	ST_NAME[128],
	ST_LEVELS[256],
	
	ST_END
}

// мы передали тебе массив в массив
// чтобы ты мог работать с массивом пока работаешь  с массивом

enum _:itemFields {
	IB_TYPE,
	IB_NAME[32],
	IB_ITEM[32],
	IB_PLUGIN_ID,
	IB_FUNCTION_ID,
	IB_CNT,
	Array:IB_LEVELS,
	
	IB_END
}

// Мастер массивов 80 лвл

new Array:g_SpawnBonusItems
new Array:g_PointsBonusItems

// some random stuff
new bool:isLocked,iaNewForward

// cvars

enum _:cvars_num {
	CVAR_BONUS_ENABLED
}

new cvar[cvars_num]

public plugin_init(){
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	RegisterHam(Ham_Spawn,"player","On_Player_Spawn",1)
	
	register_clcmd("say /anew","aNew_Cmd")
	register_clcmd("say_team /anew","aNew_Cmd")
	
	cvar[CVAR_BONUS_ENABLED] = register_cvar("aes_bonus_enable","1")
	
	register_srvcmd("aes_lockmap","Check_LockMap")
	
	register_dictionary_colored("aes.txt")
	
	iaNewForward = CreateMultiForward("aes_on_anew_command",ET_STOP,FP_CELL)
}

public Check_LockMap(){
	new getmap[32],map[32]
	read_args(getmap,31)
	remove_quotes(getmap)
	
	get_mapname(map,31)
	
	if(!strcmp(getmap,map)){
		isLocked = true
		
		set_pcvar_num(cvar[CVAR_BONUS_ENABLED],0)
	}
}

public aNew_Cmd(id){
	if(isLocked){
		client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_BLOCKED")
		
		return PLUGIN_CONTINUE
	}
	
	new temp[128],len,rt[AES_ST_END]
	
	aes_get_player_stats(id,rt)
	
	if(rt[AES_ST_BONUSES] <= 0){
		client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_NOT")
		
		return PLUGIN_CONTINUE
	}
	
	new ret
	
	ExecuteForward(iaNewForward,ret,id)
	
	if(ret == PLUGIN_HANDLED)
		return PLUGIN_HANDLED
	
	len += formatex(temp[len],128-len,"%L",id,"AES_TAG_MENU")
	len += formatex(temp[len],128-len," %L",id,"AES_BONUS_MENU")
	
	new m = menu_create(temp,"aNew_MenuHandler")
	
	new itemData[IB_END],stNum[4]
	
	for(new i;i < ArraySize(g_PointsBonusItems) ; ++i){
		ArrayGetArray(g_PointsBonusItems,i,itemData)
		
		aes_get_item_name(itemData[IB_NAME],temp,127,id)
		num_to_str(i,stNum,3)
		
		menu_additem(m,temp,stNum)
	}
	
	menu_display(id,m)
	
	return PLUGIN_CONTINUE
}

public aNew_MenuHandler(id,m,item){
	if(item == MENU_EXIT)
		return PLUGIN_HANDLED
		
	new rt[AES_ST_END]
	
	if(!aes_get_player_stats(id,rt))
		return PLUGIN_HANDLED
	
	new data[6],name[64]
	new access,callback
	menu_item_getinfo(m,item,access,data,5,name,63,callback)
	
	new key = str_to_num(data)
	
	new itemData[IB_END]
	ArrayGetArray(g_PointsBonusItems,key,itemData)
	
	if(itemData[IB_CNT] > rt[AES_ST_BONUSES]){
		client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_NOTENG")
		
		return PLUGIN_HANDLED
	}
	
	switch(itemData[IB_TYPE]){
		case ST_TYPE_GIVE:{
			fm_give_item(id,itemData[IB_ITEM])
		}
		case ST_TYPE_CALL:{
			if(itemData[IB_FUNCTION_ID] < 0){
				client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_CALL_PROBLEM")
				
				return PLUGIN_HANDLED
			}
				
			callfunc_begin_i(itemData[IB_FUNCTION_ID],itemData[IB_PLUGIN_ID])
			callfunc_push_int(id)
			
			if(!callfunc_end()){
				return PLUGIN_HANDLED
			}
		}
	}
	
	aes_add_player_bonus(id,-itemData[IB_CNT])
	client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_GIVE")
	
	return PLUGIN_HANDLED
}

public On_Player_Spawn(id){
	if(isLocked)
		return HAM_IGNORED
		
	if(!get_pcvar_num(cvar[CVAR_BONUS_ENABLED]))
		return HAM_IGNORED
	
	if(!is_user_connected(id))
		return HAM_IGNORED
	
	new rt[4]
	
	if(!aes_get_player_stats(id,rt))
		return HAM_IGNORED
	
	new itemData[IB_END]
	
	for(new i;i < ArraySize(g_SpawnBonusItems) ; ++i){
		ArrayGetArray(g_SpawnBonusItems,i,itemData)
		
		new maxLevel = ArraySize(itemData[IB_LEVELS])
		
		if(rt[1] >= maxLevel)
			rt[1] = maxLevel - 1
		
		new cnt = ArrayGetCell(itemData[IB_LEVELS],rt[1])
			
		switch(itemData[IB_TYPE]){
			case ST_TYPE_GIVE:{
				if(!cnt)
					continue
					
				for(new z; z < cnt ; z++)
					fm_give_item(id,itemData[IB_ITEM])
			}
			case ST_TYPE_CALL:{
				if(cnt < 0  || itemData[IB_FUNCTION_ID] < 0)
					continue
					
				callfunc_begin_i(itemData[IB_FUNCTION_ID],itemData[IB_PLUGIN_ID])
				callfunc_push_int(id)
				callfunc_push_int(cnt)
				callfunc_end()
			}
		}
	}
		
	return HAM_IGNORED
}

// слишком мощный код
public plugin_cfg(){
	new fPath[256]
	get_configsdir(fPath,255)
	
	formatex(fPath,255,"%s/aes/bonus.ini",fPath)
	
	new f = fopen(fPath,"r")
	
	if(!f){
		log_amx("configuration file not found")
		set_fail_state("configuration file not found")
		
		return
	}
		
	g_SpawnBonusItems = ArrayCreate(IB_END)
	g_PointsBonusItems = ArrayCreate(IB_END)
	
	new buffer[512],stCfg = -1,key[32],value[256]
	new stKey[6],stNumber
	
	new stTemp[itemCfgFields],itemData[itemFields],bool:isEol
	stTemp[ST_WHAT] = -1
	
	while(!feof(f)){
		fgets(f,buffer,511)
		
		if(buffer[0] == 0)
			isEol = true
		
		trim(buffer)
		
		if(!strlen(buffer) &~ isEol)
			continue
		
		if(buffer[0] == ';')
			continue
			
		if(!strcmp(buffer,"[spawn]")){
			stCfg = ST_BONUS_SPAWN

			continue
		}
		
		if(!strcmp(buffer,"[bonus_menu]")){
			stCfg = ST_BOUNS_POINTS
			
			continue
		}
		
		if(!strcmp(buffer,"<give>") || isEol){
			if(strlen(stTemp[ST_NAME])){
				// я не наркоман если что
				itemData[IB_TYPE] = stTemp[ST_TYPE]
				copy(itemData[IB_NAME],127,stTemp[ST_NAME])
				
				if(stTemp[ST_TYPE] == ST_TYPE_CALL){
					itemData[IB_PLUGIN_ID] = find_plugin_byfile(stTemp[ST_PARAM1])
				
					if(itemData[IB_FUNCTION_ID] != INVALID_PLUGIN_ID){
						itemData[IB_FUNCTION_ID] = get_func_id(stTemp[ST_PARAM2],itemData[IB_PLUGIN_ID])
					}
				}else{
					copy(itemData[IB_ITEM],31,stTemp[ST_PARAM1])
				}
				
				if(stTemp[ST_WHAT] == ST_BONUS_SPAWN){
					itemData[IB_LEVELS] = _:ArrayCreate(10)
					parse_levels(stTemp[ST_LEVELS],itemData[IB_LEVELS])
				}else if(stTemp[ST_WHAT] == ST_BOUNS_POINTS){
					itemData[IB_CNT] = str_to_num(stTemp[ST_LEVELS])
				}
				
				ArrayPushArray(stTemp[ST_WHAT] == ST_BONUS_SPAWN ? g_SpawnBonusItems : g_PointsBonusItems ,itemData)
					
				arrayset(stTemp,0,ST_END)
				arrayset(itemData,0,IB_END)
				
				stTemp[ST_WHAT] = -1
					
				stNumber ++
			}
				
			num_to_str(stNumber,stKey,5)
			stTemp[ST_TYPE] = ST_TYPE_GIVE
				
			continue
		}else if(!strcmp(buffer,"<call>")){
			if(strlen(stTemp[ST_NAME])){
				itemData[IB_TYPE] = stTemp[ST_TYPE]
				copy(itemData[IB_NAME],127,stTemp[ST_NAME])
	
				if(stTemp[ST_TYPE] == ST_TYPE_GIVE){
					copy(itemData[IB_ITEM],31,stTemp[ST_PARAM1])
				}else{
					itemData[IB_PLUGIN_ID] = find_plugin_byfile(stTemp[ST_PARAM1])
					
					if(itemData[IB_FUNCTION_ID] != INVALID_PLUGIN_ID){
						itemData[IB_FUNCTION_ID] = get_func_id(stTemp[ST_PARAM2],itemData[IB_PLUGIN_ID])
					}
				}
				
				if(stTemp[ST_WHAT] == ST_BONUS_SPAWN){
					itemData[IB_LEVELS] = _:ArrayCreate(10)
					parse_levels(stTemp[ST_LEVELS],itemData[IB_LEVELS])
				}else if(stTemp[ST_WHAT] == ST_BOUNS_POINTS){
					itemData[IB_CNT] = str_to_num(stTemp[ST_LEVELS])
				}
				
				ArrayPushArray(stTemp[ST_WHAT] == ST_BONUS_SPAWN ? g_SpawnBonusItems : g_PointsBonusItems ,itemData)
				
				arrayset(stTemp,0,ST_END)
				arrayset(itemData,0,IB_END)
				
				stTemp[ST_WHAT] = -1
				
				stNumber ++
			}
				
			num_to_str(stNumber,stKey,5)
			stTemp[ST_TYPE] = ST_TYPE_CALL
				
			continue
		}
				
				
		strtok(buffer,key,31,value,255,'=',1)
		replace(value,254,"= ","") // oppa govno kod
		
		if(stTemp[ST_WHAT] < 0)
			stTemp[ST_WHAT] = stCfg
		
		if(!strcmp(key,"item")){
			copy(stTemp[ST_PARAM1],127,value)
			continue
		}
		
		if(!strcmp(key,"plugin")){
			copy(stTemp[ST_PARAM1],127,value)
			continue
		}
		
		if(!strcmp(key,"function")){
			copy(stTemp[ST_PARAM2],127,value)
			continue
		}
		
		if(!strcmp(key,"name")){
			copy(stTemp[ST_NAME],127,value)
			continue
		}
		
		if(stCfg == ST_BONUS_SPAWN){
			if(!strcmp(key,"levels")){
				copy(stTemp[ST_LEVELS],127,value)
				continue
			}
		}else if(stCfg == ST_BOUNS_POINTS){
			if(!strcmp(key,"points")){
				copy(stTemp[ST_LEVELS],127,value)
				continue
			}
		}
				
	}
}

public parse_levels(levelString[],Array:which){
	new stPos,ePos,rawPoint[20]
	
	// parse levels entry
	do {
		ePos = strfind(levelString[stPos]," ")
		
		formatex(rawPoint,ePos,levelString[stPos])
		ArrayPushCell(which,str_to_num(rawPoint))
		
		stPos += ePos + 1
	} while (ePos != -1)
}

public aes_get_item_name(itemString[],out[],len,id){
	if(strfind(itemString,"LANG_") == 0){
		replace(itemString,strlen(itemString),"LANG_","")
		
		formatex(out,len,"%L",id,itemString)
	}else{
		copy(out,len,itemString)
	}
}
