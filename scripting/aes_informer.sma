/* 
	Advanced Experience System
	by serfreeman1337		http://gf.hldm.org/
*/

/*
	HUD Informer
*/

#include <amxmodx>
#include <amxmisc>

#include <fakemeta>

#define USE_COLORCHAT

#if defined USE_COLORCHAT
	#include <colorchat>
#endif

#include <aes_main>

#define PLUGIN "AES: Informer"
#define VERSION "0.2"
#define AUTHOR "serfreeman1337"

#define PLAYER_HUD_OFFSET	86444

/* - CVARS - */

enum _:cvars_num {
	CVAR_HUD_UPDATE,
	CVAR_HUD_INFO_DEFAULT,
	CVAR_HUD_INFO_TYPE,
	CVAR_HUD_INFO_COLOR,
	CVAR_HUD_INFO_POS,
	CVAR_HUD_INFO_TYPE_D,
	CVAR_HUD_INFO_COLOR_D,
	CVAR_HUD_INFO_POS_D,
	CVAR_TPL_MODE,
	CVAR_HUD_ANEW_TYPE,
	CVAR_HUD_ANEW_POS,
	CVAR_HUD_ANEW_COLOR,
	CVAR_CHAT_NEW_LEVEL
}

new cvar[cvars_num]

/* - CACHED VALUES - */
new Float:hudUpdateInterval
new bool:hudInfoOn, Float:hudInfoxPos,Float:hudInfoyPos,hudInfoColor[3],bool:hudInfoColorRandom
new bool:hudDeadOn, Float:hudDeadxPos, Float:hudDeadyPos,hudDeadColor[3],bool:hudDeadColorRandom
new bool:hudaNewOn, Float:hudaNewxPos,Float:hudaNewyPos,hudaNewColor[3]
new chatLvlUpStyle,bonusEnabledPointer,bool:isTplMode,aesMaxLevel,g_trackmode

/* - SYNC HUD OBJ - */
new informerSyncObj,aNewSyncObj

/* - FILE STORAGE - */

new Trie:g_DisabledInformer,Array:g_ADisabledInformer

public plugin_init(){
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	cvar[CVAR_TPL_MODE] = register_cvar("aes_informer_tpl","0")
	cvar[CVAR_HUD_UPDATE] = register_cvar("aes_hud_update","1.5")
	cvar[CVAR_HUD_INFO_DEFAULT] = register_cvar("aes_hud_info_default","1")
	cvar[CVAR_HUD_INFO_TYPE] = register_cvar("aes_hud_info_type","1")
	cvar[CVAR_HUD_INFO_COLOR] = register_cvar("aes_hud_info_color","100 100 100")
	cvar[CVAR_HUD_INFO_POS] = register_cvar("aes_hud_info_pos","0.01 0.13")
	cvar[CVAR_HUD_ANEW_TYPE] = register_cvar("aes_hud_anew_type","1")
	cvar[CVAR_HUD_ANEW_COLOR] = register_cvar("aes_hud_anew_color","100 100 100")
	cvar[CVAR_HUD_ANEW_POS] = register_cvar("aes_hud_anew_pos","-1.0 0.90")
	cvar[CVAR_CHAT_NEW_LEVEL] = register_cvar("aes_newlevel_chat","2")
	
	cvar[CVAR_HUD_INFO_TYPE_D] = register_cvar("aes_hud_info_default_d","1")
	cvar[CVAR_HUD_INFO_COLOR_D] = register_cvar("aes_hud_info_color_d","60 60 60")
	cvar[CVAR_HUD_INFO_POS_D] = register_cvar("aes_hud_info_pos_d","0.01 0.15")
	
	register_clcmd("say /aenable","Informer_Switch",0,"- switch experience informer on/off")
}

public plugin_cfg(){
	bonusEnabledPointer = get_cvar_pointer("aes_bonus_enable")
	
	hudUpdateInterval = get_pcvar_float(cvar[CVAR_HUD_UPDATE])
	hudInfoOn = get_pcvar_num(cvar[CVAR_HUD_INFO_DEFAULT]) > 0 ? true : false
	hudDeadOn = get_pcvar_num(cvar[CVAR_HUD_INFO_TYPE_D]) > 0 ? true : false
	hudaNewOn = get_pcvar_num(cvar[CVAR_HUD_ANEW_TYPE]) > 0 ? true : false
	chatLvlUpStyle = get_pcvar_num(cvar[CVAR_CHAT_NEW_LEVEL])
	isTplMode = get_pcvar_num(cvar[CVAR_TPL_MODE]) > 0 ? true : false
	
	if(!bonusEnabledPointer)
		hudaNewOn = false
	
	new temp[15],sColor[3][6]
	
	if(hudInfoOn){
		get_pcvar_string(cvar[CVAR_HUD_INFO_COLOR],temp,14)
		
		if(strcmp(temp,"random") != 0){
			parse(temp,sColor[0],3,sColor[1],3,sColor[2],3)
		
			hudInfoColor[0] = str_to_num(sColor[0])
			hudInfoColor[1] = str_to_num(sColor[1])
			hudInfoColor[2] = str_to_num(sColor[2])
		}else
			hudInfoColorRandom = true
		
		get_pcvar_string(cvar[CVAR_HUD_INFO_POS],temp,14)
		parse(temp,sColor[0],5,sColor[1],5)
		
		hudInfoxPos = str_to_float(sColor[0])
		hudInfoyPos = str_to_float(sColor[1])
		
		informerSyncObj = CreateHudSyncObj()
	}
	
	if(hudDeadOn){
		get_pcvar_string(cvar[CVAR_HUD_INFO_COLOR_D],temp,14)
		
		if(strcmp(temp,"random") != 0){
			parse(temp,sColor[0],3,sColor[1],3,sColor[2],3)
		
			hudDeadColor[0] = str_to_num(sColor[0])
			hudDeadColor[1] = str_to_num(sColor[1])
			hudDeadColor[2] = str_to_num(sColor[2])
		}else
			hudDeadColorRandom = true
		
		get_pcvar_string(cvar[CVAR_HUD_INFO_POS_D],temp,14)
		parse(temp,sColor[0],5,sColor[1],5)
		
		hudDeadxPos = str_to_float(sColor[0])
		hudDeadyPos = str_to_float(sColor[1])
		
		if(!informerSyncObj)
			informerSyncObj = CreateHudSyncObj()
	}
	
	if(hudaNewOn){
		get_pcvar_string(cvar[CVAR_HUD_ANEW_COLOR],temp,14)
		parse(temp,sColor[0],3,sColor[1],3,sColor[2],3)
		
		hudaNewColor[0] = str_to_num(sColor[0])
		hudaNewColor[1] = str_to_num(sColor[1])
		hudaNewColor[2] = str_to_num(sColor[2])
		
		get_pcvar_string(cvar[CVAR_HUD_ANEW_POS],temp,14)
		parse(temp,sColor[0],5,sColor[1],5)
		
		hudaNewxPos = str_to_float(sColor[0])
		hudaNewyPos = str_to_float(sColor[1])
		
		aNewSyncObj = CreateHudSyncObj()
	}
	
	aesMaxLevel = aes_get_max_level() - 1
	
	g_trackmode = get_cvar_num("aes_track_mode")
	
	g_ADisabledInformer = ArrayCreate(36)
	g_DisabledInformer = TrieCreate()
	
	new fPath[256]
	get_datadir(fPath,255)
	
	add(fPath,255,"/aes/informer.ini")
	
	new f = fopen(fPath,"r")
	
	if(f){
		new buffer[512]
		
		while(!feof(f)){
			fgets(f,buffer,511)
			trim(buffer)
			
			if(!strlen(buffer) || buffer[0] == ';')
				continue
				
			remove_quotes(buffer)
			
			ArrayPushArray(g_ADisabledInformer,buffer)
			TrieSetCell(g_DisabledInformer,buffer,1)
		}
		
		fclose(f)
		
	}
}

public plugin_end(){
	new fPath[256]
	get_datadir(fPath,255)
		
	add(fPath,255,"/aes/informer.ini")
		
	if(ArraySize(g_ADisabledInformer)){
		new f = fopen(fPath,"w+")
		
		fprintf(f,"; %s^n; by %s^n^n; Disable informer for SteamID^n",PLUGIN,AUTHOR)
		
		new trackId[36]
		
		for(new i ; i < ArraySize(g_ADisabledInformer) ; ++i){
			ArrayGetString(g_ADisabledInformer,i,trackId,35)
			
			if(!TrieKeyExists(g_DisabledInformer,trackId))
				continue
				
			fprintf(f,"^n^"%s^"",trackId)
		}
		
		fclose(f)
	}else{
		if(file_exists(fPath))
			delete_file(fPath)
	}
}

public Informer_Switch(id){
	if(!hudInfoOn)
		return 0
	
	new trackId[36]
	
	if(!get_player_trackid(id,trackId,35))
		return 0
	
	if(!TrieKeyExists(g_DisabledInformer,trackId)){
		TrieSetCell(g_DisabledInformer,trackId,1)
		
		if(!CheckStringInArray(g_ADisabledInformer,trackId))
			ArrayPushArray(g_ADisabledInformer,trackId)
			
		#if defined USE_COLORCHAT
			client_print_color(id,Red,"%L %L",
				id,"AES_TAG",id,"AES_INFORMER_DISABLED")
		#else
			client_print(id,print_chat,"%L %L",
				id,"AES_TAG",id,"AES_INFORMER_DISABLED")
		#endif
		
		remove_task(PLAYER_HUD_OFFSET + id)
		
		return 1
	}else{
		TrieDeleteKey(g_DisabledInformer,trackId)
		set_task(hudUpdateInterval,"Show_Hud_Informer",PLAYER_HUD_OFFSET + id,.flags="b")
		
		#if defined USE_COLORCHAT
			client_print_color(id,Blue,"%L %L",
				id,"AES_TAG",id,"AES_INFORMER_ENABLED")
		#else
			client_print(id,print_chat,"%L %L",
				id,"AES_TAG",id,"AES_INFORMER_ENABLED")
		#endif
		
		return 2
	}
	
	
	
	return 0
}

CheckStringInArray(Array:which,string[]){
	new str[64]
	
	for(new i ; i < ArraySize(which) ; ++i){
		ArrayGetString(which,i,str,63)
		
		if(!strcmp(string,str))
			return true
	}
	
	return false
}

public client_putinserver(id){
	if(hudInfoOn || hudaNewOn){
		new trackId[36]
		get_player_trackid(id,trackId,35)
		
		if(!TrieKeyExists(g_DisabledInformer,trackId))
			set_task(hudUpdateInterval,"Show_Hud_Informer",PLAYER_HUD_OFFSET + id,.flags="b")
	}
}

public client_disconnect(id){
	if(hudInfoOn || hudaNewOn){
		remove_task(PLAYER_HUD_OFFSET + id)
	}
}

public aes_player_levelup(id,newlevel,oldlevel){
	new levelName[32]
	
	switch(chatLvlUpStyle){
		case 1: {
			aes_get_level_name(newlevel,levelName,31,id)
			
			#if defined USE_COLORCHAT
				if(!isTplMode){
					client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_NEWLEVEL_ID",levelName)
				}else{
					new msg[191],len
					tplFormatNewLevel(id,msg,len,"AES_NEWLEVEL_TPL",id)
					
					client_print_color(id,0,msg)
				}
			#else
				if(!isTplMode){
					client_print(id,print_chat,"%L %L",id,"AES_TAG",id,"AES_NEWLEVEL_ID",levelName)
				}else{
					new msg[191],len
					tplFormatNewLevel(id,msg,len,"AES_NEWLEVEL_TPL",id)
					
					client_print(id,print_chat,msg)
				}
			#endif
		}
		case 2:{
			new pls[32],pnum,name[32]
			get_players(pls,pnum)
			get_user_name(id,name,31)
			
			for(new i; i < pnum ; ++i){
				aes_get_level_name(newlevel,levelName,31,pls[i])
				
				if(pls[i] != id){
					#if defined USE_COLORCHAT
						if(!isTplMode){
							client_print_color(pls[i],0,"%L %L",pls[i],"AES_TAG",pls[i],"AES_NEWLEVEL_ALL",name,levelName)
						}else{
							new msg[191],len
							tplFormatNewLevel(id,msg,len,"AES_NEWLEVEL_ALL_TPL",pls[i])
							
							client_print_color(pls[i],0,msg)
						}
					#else
						if(!isTplMode){
							client_print(pls[i],print_chat,"%L %L",pls[i],"AES_TAG",pls[i],"AES_NEWLEVEL_ALL",name,levelName)
						}else{
							new msg[191],len
							tplFormatNewLevel(id,msg,len,"AES_NEWLEVEL_ALL_TPL")
							
							client_print(pls[i],print_chat,msg)
						}
						
					#endif
				}else{
					#if defined USE_COLORCHAT
						if(!isTplMode){
							client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_NEWLEVEL_ID",levelName)
						}else{
							new msg[191],len
							tplFormatNewLevel(id,msg,len,"AES_NEWLEVEL_TPL",id)
							
							client_print_color(id,0,msg)
						}
					#else
						if(!isTplMode){
							client_print(id,print_chat,"%L %L",id,"AES_TAG",id,"AES_NEWLEVEL_ID",levelName)
						}else{
							new msg[191],len
							tplFormatNewLevel(id,msg,len,"AES_NEWLEVEL_TPL")
							
							client_print(id,print_chat,msg)
						}
						
					#endif
				}
			}
		}
		default: return
	}
}

public tplFormatNewLevel(id,msg[],len,tplKey[],idLang){
	new rt[4]
	aes_get_player_stats(id,rt)
	
	rt[AES_ST_LEVEL] ++
	rt[AES_ST_NEXTEXP] =  aes_get_exp_to_next_level(rt[AES_ST_LEVEL])
	
	len = formatex(msg[len],190-len,"%L ",idLang,"AES_TAG")
	len += parse_informer_tpl(id,id,rt,msg,len,190,tplKey,idLang)
					
	return len
}

public Show_Hud_Informer(taskId){
	new id = taskId - PLAYER_HUD_OFFSET
	new watchId = id
	new isAlive = is_user_alive(id)
	
	if(!is_user_connected(id)){
		remove_task(taskId)
		
		return
	}

	if(informerSyncObj != 0)
		ClearSyncHud(id,informerSyncObj)

	if(!isAlive){
		watchId = pev(id,pev_iuser2)
		
		if(!watchId)
			return
	}
		
	new hudMessage[128],len,levelName[32],rt[4]
	new bool:status = aes_get_player_stats(watchId,rt) != 0 ? true : false
		
	if(hudInfoOn){
		ClearSyncHud(id,informerSyncObj)
		
		if(status){
			if(!isTplMode){
				aes_get_level_name(rt[AES_ST_LEVEL],levelName,31)
			
				if(watchId != id){
					new watchName[32]
					get_user_name(watchId,watchName,31)
					
					len += formatex(hudMessage[len],128 - len,"%L^n",id,"AES_INFORMER0",watchName)
				}
				
				len += formatex(hudMessage[len],128 - len,"%L^n",id,"AES_INFORMER1",levelName)
				
				if(rt[AES_ST_NEXTEXP] != -1){
					len += formatex(hudMessage[len],128 - len,"%L",id,"AES_INFORMER2",rt[AES_ST_EXP],rt[AES_ST_NEXTEXP])
				}else
					len += formatex(hudMessage[len],128 - len,"%L",id,"AES_PLAYER_XP_MAX")
			}else{
				if(isAlive)
					len += parse_informer_tpl(id,watchId,rt,hudMessage,len,127,"AES_HUD_TPL",id)
				else if(!isAlive && hudDeadOn)
					len += parse_informer_tpl(id,watchId,rt,hudMessage,len,127,"AES_HUD_TPL_D",id)
			}
			
		}else
			len += formatex(hudMessage[len],128 - len,"%L",id,"AES_INFORMER_FAIL")
		
		if(isAlive){
			if(hudInfoColorRandom){
				// рандом такой рандом
				hudInfoColor[0] = random(12800) / 100
				hudInfoColor[1] = random(12800) / 100
				hudInfoColor[2] = random(12800) / 100
			}
			
			set_hudmessage(hudInfoColor[0], hudInfoColor[1], hudInfoColor[2], hudInfoxPos , hudInfoyPos,.holdtime = hudUpdateInterval,.channel = 3)
		}else if(!isAlive && hudDeadOn){
			if(hudDeadColorRandom){
				hudDeadColor[0] = random(12800) / 100
				hudDeadColor[1] = random(12800) / 100
				hudDeadColor[2] = random(12800) / 100
			}
			
			set_hudmessage(hudDeadColor[0],hudDeadColor[1],hudDeadColor[2],hudDeadxPos,hudDeadyPos,0,.holdtime = hudUpdateInterval,.channel = 3)
		}
		
		replace_all(hudMessage,127,"\n","^n")
		ShowSyncHudMsg(id,informerSyncObj,hudMessage)
		
		len = 0
		hudMessage[0] = 0
	}
	
	if(hudaNewOn && get_pcvar_num(bonusEnabledPointer) == 1 && rt[AES_ST_BONUSES] > 0 && watchId == id){
		ClearSyncHud(id,aNewSyncObj)
		
		len += formatex(hudMessage[len],128 - len,"%L",id,"AES_ANEW_HUD",rt[AES_ST_BONUSES])
		replace_all(hudMessage,127,"\n","^n")
		
		set_hudmessage(hudaNewColor[0],hudaNewColor[1],hudaNewColor[2],hudaNewxPos,hudaNewyPos,0,.holdtime = hudUpdateInterval)
		ShowSyncHudMsg(id,aNewSyncObj,hudMessage)
	}
}

public parse_informer_tpl(id,watchId,stats[AES_ST_END],string[],len,maxLen,tplKey[],idLang){
	static tpl[256],tmp[32]
	
	tpl[0] = 0
	tmp[0] = 0
	
	formatex(tpl,255,"%L",id,tplKey)
	
	if(strfind(tpl,"<exp>") != -1){
		formatex(tmp,31,"%d",stats[AES_ST_EXP])
		
		replace_all(tpl,255,"<exp>",tmp)
	}
	
	if(strfind(tpl,"<levelexp>") != -1){
		formatex(tmp,31,"%d",stats[AES_ST_NEXTEXP])
		
		replace_all(tpl,255,"<levelexp>",tmp)
	}
	
	if(strfind(tpl,"<needexp>") != -1){
		formatex(tmp,31,"%d",stats[AES_ST_NEXTEXP] - stats[AES_ST_EXP])
		
		replace_all(tpl,255,"<needexp>",tmp)
	}
	
	if(strfind(tpl,"<level>") != -1){
		formatex(tmp,31,"%d",stats[AES_ST_LEVEL])
		
		replace_all(tpl,255,"<level>",tmp)
	}
	
	if(strfind(tpl,"<maxlevel>") != -1){
		formatex(tmp,31,"%d",aesMaxLevel)
		
		replace_all(tpl,255,"<maxlevel>",tmp)
	}
	
	if(strfind(tpl,"<rank>") != -1){
		aes_get_level_name(stats[AES_ST_LEVEL],tmp,31,idLang)
		
		replace_all(tpl,255,"<rank>" ,tmp)
	}
	
	if(strfind(tpl,"<name>") != -1){
		get_user_name(watchId,tmp,31)
		
		replace_all(tpl,255,"<name>",tmp)
	}
	
	if(strfind(tpl,"<steamid>") != -1){
		get_user_authid(watchId,tmp,31)
		
		replace_all(tpl,255,"<steamid>",tmp)
	}
	
	len += formatex(string[len],maxLen-len,tpl)
	
	return len
}

get_player_trackid(id,trackId[],trackLen){
	switch(g_trackmode){
		case 0: get_user_name(id,trackId,trackLen)
		case 1: {
			get_user_authid(id,trackId,trackLen)
			
			if(!strcmp(trackId,"STEAM_ID_LAN") || !strcmp(trackId,"VALVE_ID_LAN") || !strcmp(trackId,"BOT")
				|| !strcmp(trackId,"HLTV"))
				return 0
		}
		case 2: get_user_ip(id,trackId,trackLen,1)
	}
	
	return 1
}
