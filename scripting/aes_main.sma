/* 
	Advanced Experience System
	by serfreeman1337		http://gf.hldm.org/
*/

/*
	- Main Plugin
	- Storage Engine
*/

#include <amxmodx>
#include <fakemeta>
#include <amxmisc>
#include <sqlx>

#define PLUGIN		"Advanced Experience System"
#define VERSION		"0.4.1"
#define AUTHOR		"serfreeman1337"
#define LASTUPDATE "6, February (02), 2014"

/* - CVARS - */

enum _:cvars_num {
	CVAR_DB_TYPE,
	CVAR_TRACK_MODE,
	CVAR_LEVELS,
	CVAR_SAVE_BONUS,
	
	CVAR_LOAD_DELAY,
	
	CVAR_SQL_DRIVER,
	CVAR_SQL_HOST,
	CVAR_SQL_USER,
	CVAR_SQL_PASSWORD,
	CVAR_SQL_DB,
	CVAR_SQL_TBL,
	CVAR_SQL_MAXFAIL,
	
	CVAR_DB_PRUNE
}

new cvar[cvars_num]

/* - CACHED CVARS - */

new g_storagetype,g_trackmode,g_savebonus
new Float:loadDelay

/* - FILE STORAGE ENGINE - */
new const stDir[] = "/aes/"
new const stFile[] = "stats.ini"

/*new const fSVersion = 1337

enum _:StreamData {
	DATA_UNIQUE[36],
	DATA_NAME[32],
	DATA_EXP,
	DATA_LEVEL,
	DATA_BONUSES,
	DATA_LAST_CONNECT,
	
	DATA_END
}
*/

new Trie:g_PlayerStats, Trie:g_PlayerNames, Array:g_PlayerStatsId	// all players data info

/* - SQL STORAGE ENGINE - */
new Handle:g_sql,g_query[512],sqlTable[64],sqlFailCount,bool:sqlFail

enum _:SQL_STATE {
	LOAD_STATS,
	SAVE_STATS,
	DROP_STATS
}

/* - PLAYER STATS - */
enum _:player_info {
	EXP,
	LEVEL,
	BONUSES,
	LAST_CONNECT,
	LOADED,
	EXP_TO_NEXT_LEVEL
}

new g_players[33][player_info],g_maxplayers

/* - LEVELS - */
new Array:g_Levels,g_maxLevel
new Trie:g_LevelNames

/* - FORWARDS - */
new g_LevelUpForward,g_LevelDownForward

public plugin_init(){
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_cvar("aes",VERSION,FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	
	// Select storage type
	// 0 - dont save
	// 1 - save info into file
	// 2 - user sql database
	cvar[CVAR_DB_TYPE] = register_cvar("aes_db_type","1")
	
	// How users tracking
	// 0 - Name
	// 1 - SteamID
	// 2 - IP
	cvar[CVAR_TRACK_MODE] = register_cvar("aes_track_mode","1")
	
	// blablaba 22
	cvar[CVAR_LEVELS] = register_cvar("aes_level","0 20 40 60 100 150 200 300 400 600 1000 1500 2100 2700 3400 4200 5100 5900 7000 10000")
	
	cvar[CVAR_SAVE_BONUS] = register_cvar("aes_save_bonus","1")
	cvar[CVAR_LOAD_DELAY] = register_cvar("aes_load_delay","0.0")
	
	cvar[CVAR_SQL_DRIVER] = register_cvar("aes_sql_driver","mysql")
	cvar[CVAR_SQL_HOST] = register_cvar("aes_sql_host","localhost")
	cvar[CVAR_SQL_USER] = register_cvar("aes_sql_user","root")
	cvar[CVAR_SQL_PASSWORD] = register_cvar("aes_sql_password","")
	cvar[CVAR_SQL_DB] = register_cvar("aes_sql_db","amxx")
	cvar[CVAR_SQL_TBL] = register_cvar("aes_sql_table","aes_stats")
	cvar[CVAR_SQL_MAXFAIL] = register_cvar("aes_sql_maxfail","10")
	
	cvar[CVAR_DB_PRUNE] = register_cvar("aes_db_prune_days","0")
	
	g_maxplayers = get_maxplayers()
	
	// id | new level | old level
	g_LevelUpForward = CreateMultiForward("aes_player_levelup",ET_IGNORE,FP_CELL,FP_CELL,FP_CELL)
	g_LevelDownForward = CreateMultiForward("aes_player_leveldown",ET_IGNORE,FP_CELL,FP_CELL,FP_CELL)
	
	g_Levels = ArrayCreate(10)
	g_LevelNames = TrieCreate()
	
	register_concmd("aes_recalc","Start_ReCalc",ADMIN_RCON," - recalc players levels for their experice")
	
	register_forward(FM_Sys_Error,"Server_BSOD")
}

public plugin_cfg(){
	new fPath[256]
	get_configsdir(fPath,255)
	
	server_cmd("exec %s/aes/aes.cfg",fPath)
	server_exec()
	
	g_storagetype = get_pcvar_num(cvar[CVAR_DB_TYPE])
	g_trackmode = get_pcvar_num(cvar[CVAR_TRACK_MODE])
	loadDelay = get_pcvar_float(cvar[CVAR_LOAD_DELAY])
	
	switch(g_storagetype){
		case 1:{
			g_PlayerStats = TrieCreate()
			g_PlayerNames = TrieCreate()
			g_PlayerStatsId = ArrayCreate(36)
			
			LoadDataFromFile()
		}
		case 2:{
			InitSQLDB()
		}
	}
	
	g_savebonus = get_pcvar_num(cvar[CVAR_SAVE_BONUS])
	
	if(g_trackmode == 0){
		register_forward(FM_ClientUserInfoChanged,"fw_ClientUserInfoChanged")
	}
	
	new levelString[512],stPos,ePos,rawPoint[20]
	get_pcvar_string(cvar[CVAR_LEVELS],levelString,511)
	
	// parse levels entry
	
	if(strlen(levelString)){
		do {
			ePos = strfind(levelString[stPos]," ")
			
			formatex(rawPoint,ePos,levelString[stPos])
			ArrayPushCell(g_Levels,str_to_num(rawPoint))
			
			stPos += ePos + 1
		} while (ePos != -1)
	}
	
	// get total levels
	g_maxLevel = ArraySize(g_Levels)
	
	server_print("")
	server_print("   %s Copyright (c) 2014 %s",PLUGIN,AUTHOR)
	server_print("   Version %s build on %s", VERSION, LASTUPDATE)
	server_print("")
}

public InitSQLDB(){
	new hostname[64],user[64],password[64],db[64],driver[10]
	
	get_pcvar_string(cvar[CVAR_SQL_HOST],hostname,63)
	get_pcvar_string(cvar[CVAR_SQL_USER],user,63)
	get_pcvar_string(cvar[CVAR_SQL_PASSWORD],password,63)
	get_pcvar_string(cvar[CVAR_SQL_DB],db,63)
	get_pcvar_string(cvar[CVAR_SQL_TBL],sqlTable,63)
	get_pcvar_string(cvar[CVAR_SQL_DRIVER],driver,9)
	
	SQL_SetAffinity(driver)
	g_sql = SQL_MakeDbTuple(hostname,user,password,db)
	
	if(g_sql == Empty_Handle){
		log_amx("failed to initialize database")
		
		sqlFail = true
	}
	
	formatex(g_query,511,"CREATE TABLE IF NOT EXISTS `%s` (\
  `id` int(11) NOT NULL AUTO_INCREMENT,\
  `trackId` varchar(36) NOT NULL,\
  `name` varchar(32) NOT NULL,\
  `experience` int(11) NOT NULL,\
  `level` int(11) NOT NULL,\
  `bonus` int(11) NOT NULL,\
  `lastJoin` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,\
  PRIMARY KEY (`id`))",sqlTable)
  
	new data[2]
	data[1] = -1
	
	SQL_ThreadQuery(g_sql,"SQL_Handler",g_query,data,2)
	
	if(get_pcvar_num(cvar[CVAR_DB_PRUNE]) > 0){
		new data[2]
		data[1] = DROP_STATS
		formatex(g_query,511,"SELECT `id` FROM `%s` WHERE DATE_ADD(`lastJoin`, INTERVAL %d DAY) <= NOW()",
			sqlTable,get_pcvar_num(cvar[CVAR_DB_PRUNE]))
		SQL_ThreadQuery(g_sql,"SQL_Handler",g_query,data,2)
	}
}

public plugin_end(){
	switch(g_storagetype){
		case 1:{
			SaveDataToFile()
		}
	}
}

public Start_ReCalc(id,level,cid){
	if(!cmd_access(id,level,cid,0))
		return PLUGIN_HANDLED
	
	new admName[32],admAuthid[36]
	
	get_user_name(id,admName,31)
	get_user_authid(id,admAuthid,35)
		
	switch(g_storagetype){
		case 1:{
			client_print(id,print_console,"%L %L",id,"AES_TAG_CON",id,"AES_RECALC_START")
			log_amx("[RECALC] ^"%s<%d><%s><>^" starts level recalculation process",admName,get_user_index(admName),admAuthid)
			
			new trackId[36],pStats[player_info - 1],expLevel,tCnt
			
			for(new i ; i < ArraySize(g_PlayerStatsId) ; ++i){
				ArrayGetString(g_PlayerStatsId,i,trackId,35)
				
				if(!TrieGetArray(g_PlayerStats,trackId,pStats,player_info - 1))
					continue
					
				expLevel = get_level_for_exp(pStats[EXP])
				
				if(pStats[LEVEL] != expLevel){
					pStats[LEVEL] = expLevel
					TrieSetArray(g_PlayerStats,trackId,pStats,player_info - 1)
					
					tCnt++
				}
			}
			
			client_print(id,print_console,"%L %L",id,"AES_TAG_CON",id,"AES_RECALC_END",tCnt)
			log_amx("[RECALC] Total %d entries updated",tCnt)
		}
		case 2:{
			client_print(id,print_console,"%L %L",id,"AES_TAG_CON",id,"AES_RECALC_START")
			log_amx("[RECALC] ^"%s<%d><%s><>^" starts level recalculation process",admName,get_user_index(admName),admAuthid)
			
			new err,error[256]
			
			new Handle:sqlConnection = SQL_Connect(g_sql,err,error,255)
			
			if(sqlConnection == Empty_Handle){
				client_print(id,print_console,"%L %L",id,"AES_TAG_CON",id,"SQL_CANT_CON",sqlTable)
				
				log_amx("[RECALC] SQL Connection failed")
				log_amx("[RECALC] %s [%d]",error,err)
				
				return PLUGIN_HANDLED
			}
			
			new Handle:que = SQL_PrepareQuery(sqlConnection,"SELECT `id`,`experience`,`level` FROM `%s`",
				sqlTable)
			
			if(!SQL_Execute(que)){
				client_print(id,print_console,"%L %L",id,"AES_TAG_CON",id,"SQL_CANT_CON",sqlTable)
				
				SQL_QueryError(que,error,255)
				
				log_amx("[RECALC] Query failed")
				log_amx("[RECALC] %s",error)
			}else{
				new exp,level,expLevel,pK,tCnt
				while(SQL_MoreResults(que)){
					pK = SQL_ReadResult(que,0)
					exp = SQL_ReadResult(que,1)
					level = SQL_ReadResult(que,2)
					
					expLevel = get_level_for_exp(exp)
					
					if(level != expLevel){
						SQL_QueryAndIgnore(sqlConnection,"UPDATE `%s` SET `level` = '%d' WHERE `id` = '%d'",
							sqlTable,expLevel,pK)
							
						tCnt ++
					}

					SQL_NextRow(que)					
				}
				
				client_print(id,print_console,"%L %L",id,"AES_TAG_CON",id,"AES_RECALC_END",tCnt)
				log_amx("[RECALC] Total %d entries updated",tCnt)
			}
			
			SQL_FreeHandle(que)
			SQL_FreeHandle(sqlConnection)
		}
		default: client_print(id,print_console,"%L %L",id,"AES_TAG_CON",id,"AES_RECALC_NODB")
	}
	
	new players[32],pCount
	get_players(players,pCount)
	
	for(new i ; i < pCount ; ++i){
		new id = players[i]
		g_players[id][LEVEL] = get_level_for_exp(g_players[id][EXP])
	}
		
	return PLUGIN_HANDLED
}

public client_putinserver(id){
	if(g_storagetype>0)
		set_task(loadDelay,"LoadPlayerStats",id)	// 4to sa hu..
		
}

public client_disconnect(id){
	if(g_storagetype>0)
		SavePlayerStats(id)
}

public LoadPlayerStats(id){
	if(!is_user_connected(id))
		return
	
	new trackId[72]
	
	if(!get_player_trackid(id,trackId,35))
		return
	
	switch(g_storagetype){
		case 1:{
			if(TrieKeyExists(g_PlayerStats,trackId)){
				TrieGetArray(g_PlayerStats,trackId,g_players[id],player_info - 1)
				g_players[id][LOADED] = 1
			}else{
				// mark new player
				g_players[id][LOADED] = 2
			}
		}
		case 2:{
			if(sqlFail)
				return
			
			new data[2]
			
			data[0] = id
			data[1] = LOAD_STATS
			
			replace_all(trackId,72,"'","\'")
			replace_all(trackId,72,"`","\`")
			
			formatex(g_query,511,"SELECT `experience`,`level`,`bonus`,`trackId`,`name`,`id` FROM `%s` WHERE `trackId` = '%s'",
				sqlTable,trackId)
			SQL_ThreadQuery(g_sql,"SQL_Handler",g_query,data,2)
		}
	}
	
	g_players[id][LAST_CONNECT] = get_systime()
	g_players[id][EXP_TO_NEXT_LEVEL]  = get_exp_to_next_level(g_players[id][LEVEL])			
}

// Save for the sunshine.
public SavePlayerStats(id){
	// Save for the rain.
	if(g_players[id][LOADED] <= 0)
		return
	
	new trackId[72],name[64]
	
	// We will now believe.
	if(!get_player_trackid(id,trackId,35))
		return
	
	get_user_name(id,name,31)
	
	// We just want to stay.
	if(!g_savebonus)
		g_players[id][BONUSES] = 0
		
	g_players[id][LAST_CONNECT] = get_systime()
		
	switch(g_storagetype){
		case 1:{ // Hold it in the sunshine.
			TrieSetArray(g_PlayerStats,trackId,g_players[id],player_info - 1)
			TrieSetString(g_PlayerNames,trackId,name)
			
			if(g_players[id][LOADED] == 2){
				ArrayPushString(g_PlayerStatsId,trackId)
			}
		}
		case 2:{ // Hold it in the rain.
			if(sqlFail)
				return
			
			new data[2]
			
			data[0] = id
			data[1] = SAVE_STATS
			
			// Bring back the save from back in the day.
			replace_all(trackId,72,"'","\'")
			replace_all(trackId,72,"`","\`")
			
			replace_all(name,64,"'","\'")
			replace_all(name,64,"`","\`")
			
			// Select time to do the save AMXX want to play.
			if(g_players[id][LOADED] == 1){
				formatex(g_query,511,"UPDATE `%s` SET `name` = '%s',`experience` = '%d',`level` = '%d',\
						`bonus` = '%d',`lastJoin` = NOW() WHERE `trackId` = '%s'",sqlTable,name,g_players[id][EXP],
						g_players[id][LEVEL],g_players[id][BONUSES],trackId)
				SQL_ThreadQuery(g_sql,"SQL_Handler",g_query,data,2) // Bring back the day when save was saw.
			}else if(g_players[id][LOADED] == 2){ 
				formatex(g_query,511,"INSERT INTO `%s`  (`trackId`,`name`,`experience`,`level`,`bonus`)\
						VALUES('%s','%s','%d','%d','%d')",sqlTable,trackId,name,g_players[id][EXP],
						g_players[id][LEVEL],g_players[id][BONUSES])
				SQL_ThreadQuery(g_sql,"SQL_Handler",g_query,data,2) // And the trust will use to play.
			}
		}
	}
	
	// When sun need to shine or reign the rain
	g_players[id][EXP] = 0
	g_players[id][LEVEL] = 0
	g_players[id][BONUSES] = 0
	g_players[id][LAST_CONNECT] = 0
	g_players[id][LOADED] = 0
	g_players[id][EXP_TO_NEXT_LEVEL] = 0
	// We just still belive to save.
}

public SQL_Handler(failstate,Handle:que,err[],errcode,data[],datasize){
	if(sqlFailCount >= get_pcvar_num(cvar[CVAR_SQL_MAXFAIL])){
		log_amx("max sql fail reached")
		
		sqlFail = true
		
		//set_fail_state("max sql failure reached")
		
		return PLUGIN_HANDLED
	}
	
	switch(failstate){
		case TQUERY_CONNECT_FAILED: {
			log_amx("MySQL connection failed")
			log_amx("[ %d ] %s",errcode,err)
			log_amx("Query state: %d",data[1])
			
			sqlFailCount ++
			
			return PLUGIN_CONTINUE
		}
		case TQUERY_QUERY_FAILED: {
			log_amx("MySQL query failed")
			log_amx("[ %d ] %s",errcode,err)
			log_amx("Query state: %d",data[1])
			
			sqlFailCount ++
			
			return PLUGIN_CONTINUE
		}
	}
	
	new id = data[0]
	
	switch(data[1]){
		case LOAD_STATS:{
			new numRes = SQL_NumResults(que)
			if(numRes <= 0){
				g_players[id][LOADED] = 2	// mark as new player
				
				return PLUGIN_HANDLED
			}else if(numRes > 1){	// проверка на наличие дублей
				new trackId[36],name[32],pK = -1
				
				while(SQL_MoreResults(que)){
					SQL_ReadResult(que,3,trackId,35)
					SQL_ReadResult(que,4,name,31)
					
					// удал€ем последнюю запись, если опыт у новой записи больше последней
					if(SQL_ReadResult(que,0) >= g_players[id][EXP]){
						if(pK > -1){
							data[1] = SAVE_STATS // save XD
							
							log_amx("[DB] Merge duplicate trackId %s [ %d %d ]",trackId,
								SQL_ReadResult(que,0),g_players[id][EXP])
							
							formatex(g_query,511,"DELETE FROM `%s` WHERE `id` = '%d'",
								sqlTable,pK)
							SQL_ThreadQuery(g_sql,"SQL_Handler",g_query,data,2)
						}
					}else{ // значение совпадает, всЄ равно удалем еЄ
						data[1] = SAVE_STATS // save XD
						
						log_amx("[DB] Skip duplicate trackId %s",trackId)
							
						formatex(g_query,511,"DELETE FROM `%s` WHERE `id` = '%d'",
							sqlTable,SQL_ReadResult(que,5))
						SQL_ThreadQuery(g_sql,"SQL_Handler",g_query,data,2)
					}
					
					// запоминаем primaryKey последней записи
					pK = SQL_ReadResult(que,5)
					
					if(g_players[id][EXP] < SQL_ReadResult(que,0))
						g_players[id][EXP] = SQL_ReadResult(que,0)
					
					g_players[id][LEVEL] = SQL_ReadResult(que,1)
					g_players[id][BONUSES] = SQL_ReadResult(que,2)
					
					g_players[id][EXP_TO_NEXT_LEVEL] = get_exp_to_next_level(g_players[id][LEVEL])
			
					SQL_NextRow(que)
				}
				
				g_players[id][LOADED] = 1
				
				return PLUGIN_HANDLED
			}
			
			g_players[id][EXP] = SQL_ReadResult(que,0)
			g_players[id][LEVEL] = SQL_ReadResult(que,1)
			g_players[id][BONUSES] = SQL_ReadResult(que,2)
			g_players[id][EXP_TO_NEXT_LEVEL] = get_exp_to_next_level(g_players[id][LEVEL])
			
			g_players[id][LOADED] = 1
		}
		case SAVE_STATS:{
			// dont care about stats save
		}
		case DROP_STATS:{
			while(SQL_MoreResults(que)){
				new pk = SQL_ReadResult(que,0)
				
				new dd[2]
				dd[1] = -1
				
				formatex(g_query,511,"DELETE FROM `%s` WHERE `id` = '%d'",
					sqlTable,pk)
				SQL_ThreadQuery(g_sql,"SQL_Handler",g_query,dd,2)
				
				SQL_NextRow(que)
			}
			
			if(SQL_NumResults(que))
				log_amx("%d ranks pruned",SQL_NumResults(que))
		}
	}
	
	return PLUGIN_HANDLED
	
}

public fw_ClientUserInfoChanged(id, buffer) {
	if(!is_user_connected(id))
		return FMRES_IGNORED

	new name[32],val[32]
	get_user_name(id,name,31)
	engfunc(EngFunc_InfoKeyValue,buffer,"name",val,31)
	
	if(equal(val,name))
		return FMRES_IGNORED
	else{	
		SavePlayerStats(id)
		LoadPlayerStatsByName(id,val)
	}

	return FMRES_IGNORED
}

public LoadPlayerStatsByName(id,name[]){
	new trackId[72]
	
	copy(trackId,72,name)
	
	switch(g_storagetype){
		case 1:{
			if(TrieKeyExists(g_PlayerStats,trackId)){
				TrieGetArray(g_PlayerStats,trackId,g_players[id],player_info - 1)
				g_players[id][LOADED] = 1
			}else{
				// mark new player
				g_players[id][LOADED] = 2
			}
		}
		case 2:{
			if(sqlFail)
				return
			
			new data[2]
			
			data[0] = id
			data[1] = LOAD_STATS
			
			replace_all(trackId,72,"'","\'")
			replace_all(trackId,72,"`","\`")
			
			formatex(g_query,511,"SELECT `experience`,`level`,`bonus`,`trackId`,`name`,`id` FROM `%s` WHERE `trackId` = '%s'",
				sqlTable,trackId)
			SQL_ThreadQuery(g_sql,"SQL_Handler",g_query,data,2)
		}
	}
	
	g_players[id][LAST_CONNECT] = get_systime()
	g_players[id][EXP_TO_NEXT_LEVEL]  = get_exp_to_next_level(g_players[id][LEVEL])	
}

public LoadDataFromFile(){
	new fPath[256]//,streamBlocks[StreamData]
	get_datadir(fPath,255)
	formatex(fPath,255,"%s%s",fPath,stDir)
	
	if(!dir_exists(fPath))
		mkdir(fPath)
		
	formatex(fPath,255,"%s%s",fPath,stFile)
	
	new f = fopen(fPath,"r")
	
	if(!f)
		return
		
	/*new statsInfo[2],pStats[player_info - 1]

	fread_raw(f,statsInfo[0],2,BLOCK_INT)
	
	for(new i;i < statsInfo[1] ; ++i){
		fread_raw(f,streamBlocks[0],DATA_END,BLOCK_INT)
		
		pStats[EXP] = streamBlocks[DATA_EXP]
		pStats[LEVEL] = streamBlocks[DATA_LEVEL]
		pStats[BONUSES] = streamBlocks[DATA_BONUSES]
		pStats[LAST_CONNECT] = streamBlocks[DATA_LAST_CONNECT]
		
		TrieSetArray(g_PlayerStats,streamBlocks[DATA_UNIQUE],pStats,player_info - 1)
		TrieSetString(g_PlayerNames,streamBlocks[DATA_UNIQUE],streamBlocks[DATA_NAME])
		ArrayPushString(g_PlayerStatsId,streamBlocks[DATA_UNIQUE])
	}*/
	
	new buffer[512],pruneTime,curTime,prunedEntries
	
	if(get_pcvar_num(cvar[CVAR_DB_PRUNE]) > 0){
		pruneTime = get_pcvar_num(cvar[CVAR_DB_PRUNE])  * 24 * 60 * 60
		curTime = get_systime()
	}
		
	while(!feof(f)){
		fgets(f,buffer,511)
		trim(buffer)
		
		if(!strlen(buffer))
			continue
		
		if(buffer[0] == ';')
			continue
			
		new trackId[36],userName[32],sStats[player_info - 1][12],pStats[player_info - 1]
		parse(buffer,trackId,35,userName,31,sStats[EXP],11,sStats[LEVEL],11,sStats[BONUSES],11,sStats[LAST_CONNECT],11)
		
		// бывает :)
		if(!trackId[0]){
			log_amx("[DB] Skip empty trackid for %s",userName)
			
			continue
		}
			
		// проверка на дубли. Ќу кривой € скриптер, извините :(
		if(TrieKeyExists(g_PlayerStats,trackId)){
			new tStats[player_info - 1]
			TrieGetArray(g_PlayerStats,trackId,tStats,player_info - 1)
			
			if(str_to_num(sStats[EXP]) > tStats[EXP]){
				log_amx("[DB] Merge stats for duplicate trackid: %s [ %d %d ]",trackId,
					str_to_num(sStats[EXP]),tStats[EXP])
					
				pStats[EXP] = str_to_num(sStats[EXP])
				pStats[LEVEL] = str_to_num(sStats[LEVEL])
				pStats[BONUSES] = str_to_num(sStats[BONUSES])
				pStats[LAST_CONNECT] = str_to_num(sStats[LAST_CONNECT])
				
				TrieSetArray(g_PlayerStats,trackId,pStats,player_info - 1)
				TrieSetString(g_PlayerNames,trackId,userName)
				
				continue
			}
				
			log_amx("[DB] Skip duplicate trackid %s",trackId)
			
			continue
		}
		
		if(pruneTime){
			if(str_to_num(sStats[LAST_CONNECT]) + pruneTime < curTime){
				prunedEntries ++
				
				continue
			}
		}
		
		pStats[EXP] = str_to_num(sStats[EXP])
		pStats[LEVEL] = str_to_num(sStats[LEVEL])
		pStats[BONUSES] = str_to_num(sStats[BONUSES])
		pStats[LAST_CONNECT] = str_to_num(sStats[LAST_CONNECT])
		
		TrieSetArray(g_PlayerStats,trackId,pStats,player_info - 1)
		TrieSetString(g_PlayerNames,trackId,userName)
		ArrayPushString(g_PlayerStatsId,trackId)
	}
	
	if(prunedEntries)
		log_amx("%d ranks pruned",prunedEntries)
	
	fclose(f)
}

public SaveDataToFile(){
	new fPath[256]
	get_datadir(fPath,255)
	formatex(fPath,255,"%s%s%s",fPath,stDir,stFile)
	
	new f = fopen(fPath,"w+")
	
	if(!f)
		return
		
	/*new statsInfo[2]
	
	statsInfo[0] = fSVersion
	statsInfo[1] = ArraySize(g_PlayerStatsId)
	
	fwrite_raw(f,statsInfo[0],2,BLOCK_INT)
	*/
	
	fprintf(f,";^n; %s v.%s^n; File Storage Engine^n; by %s^n;^n",
		PLUGIN,VERSION,AUTHOR)
	fprintf(f,"; TrackID | Name | EXP | Level | Bonuses | Last Connect ^n^n")
	
	new playerInfo[player_info - 1]//,streamBlocks[StreamData]
	
	for(new i; i < ArraySize(g_PlayerStatsId); ++i){
		new trackId[36],name[32]
		ArrayGetString(g_PlayerStatsId,i,trackId,35)
		
		TrieGetArray(g_PlayerStats,trackId,playerInfo,player_info - 1)
		TrieGetString(g_PlayerNames,trackId,name,31)
		
		/*streamBlocks[DATA_EXP] = playerInfo[EXP]
		streamBlocks[DATA_LEVEL] = playerInfo[LEVEL]
		streamBlocks[DATA_BONUSES] = playerInfo[BONUSES]
		streamBlocks[DATA_LAST_CONNECT] = playerInfo[LAST_CONNECT]
		*/
		//fwrite_raw(f,streamBlocks[0],DATA_END,BLOCK_INT)	// da ya je pro
		
		//	  TrackID | Name | EXP | Level | Bonuses | Last Connect |
		fprintf(f,"^"%s^" ^"%s^" ^"%d^" ^"%d^" ^"%d^" ^"%d^"^n",trackId,
		name,playerInfo[EXP],playerInfo[LEVEL],playerInfo[BONUSES],playerInfo[LAST_CONNECT])
		
	}
	
	new ftime[256]
	format_time(ftime,255,"%m/%d/%Y - %H:%M:%S",get_systime())
	fprintf(f,"^n; Last update: %s",ftime)
	
	fclose(f)
}

// попытаемс€ сохранить что-то при краше
public Server_BSOD(){
	new players[32],pCount
	get_players(players,pCount)
	
	for(new i ; i < pCount ; ++i)
		client_disconnect(players[i]) // вызываем функцию отключени€ дл€ сохранени€
		
	if(g_storagetype == 1) // сохран€ем файл статистики
		SaveDataToFile()
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

// returns experinece count for next level
get_exp_to_next_level(lvl){
	lvl ++
	
	if(lvl > g_maxLevel -1)
		return -1
		
	lvl = clamp(lvl,0,g_maxLevel - 1)
		
	return ArrayGetCell(g_Levels,lvl)
}

// возвращает уровень опыта
get_level_for_exp(exp){
	for(new i; i < g_maxLevel; ++i){
		if(exp < ArrayGetCell(g_Levels,i)){
			return clamp(i - 1,0)
		}else if(i + 1 >= g_maxLevel){
			return g_maxLevel - 1
		}
	}
	
	return 0
}

public plugin_natives(){
	register_library("aes_main")
	
	register_native("aes_add_player_exp","_aes_add_player_exp")
	register_native("aes_add_player_bonus","_aes_add_player_bonus")
	
	register_native("aes_get_stats","_aes_get_stats")
	
	register_native("aes_get_player_stats","_aes_get_player_stats")
	register_native("aes_set_player_stats","_aes_set_player_stats")
	
	register_native("aes_set_level_exp","_aes_set_level_exp")
	register_native("aes_get_level_name","_aes_get_level_name")
	register_native("aes_get_level_for_exp","_aes_get_level_for_exp")
	register_native("aes_get_max_level","_aes_get_max_level")
	register_native("aes_get_exp_to_next_level","_aes_get_exp_to_next_level")
}

#define CHECK_PLAYER(%1) \
if (!(1 <= %1 <= g_maxplayers)) \
{ \
	log_error(AMX_ERR_NATIVE, "player out of range (%d)", %1); \
	return 0; \
}

/*
	@id - player id
	@exp - experience value
	@override
	
	@return - 
		0 on fail
		1 on success
		2 on level up
		3 on max
		4 on level down
	
	native aes_add_player_exp(id,exp)
*/
public _aes_add_player_exp(plugin,params){
	if(params < 2){
		log_error(AMX_ERR_NATIVE,"bad arguments num, expected 2, passed %d", params)
		
		return 0
	}
	
	new id = get_param(1)
	new exp = get_param(2)
	
	if(!exp)
		return 0
	
	CHECK_PLAYER(id)
	
	if(g_players[id][LOADED] <= 0)
		return 0
		
	if(params < 3 || !get_param(3)){
		if(g_players[id][LEVEL] >= g_maxLevel - 1){
			return 3
		}
	}
	
	// узнаем опыт последнего уровн€
	new lastExp = get_exp_to_next_level(g_players[id][LEVEL] - 1)
	new oldLevel = g_players[id][LEVEL]
	
	g_players[id][EXP] += exp
	
	if(g_players[id][EXP] < 0)
		g_players[id][EXP] = 0
	
	if(g_players[id][EXP] >= g_players[id][EXP_TO_NEXT_LEVEL] && g_players[id][LEVEL] < g_maxLevel - 1){ // уровень вверх
		new ret
		
		g_players[id][LEVEL] = get_level_for_exp(g_players[id][EXP])
		g_players[id][EXP_TO_NEXT_LEVEL] = get_exp_to_next_level(g_players[id][LEVEL])
		
		ExecuteForward(g_LevelUpForward,ret,id,g_players[id][LEVEL],oldLevel)
		
		return 2
	}else if(g_players[id][EXP] < lastExp){ // уровень вниз :)
		new ret
		
		g_players[id][LEVEL] = get_level_for_exp(g_players[id][EXP])
		g_players[id][EXP_TO_NEXT_LEVEL] = get_exp_to_next_level(g_players[id][LEVEL])
		
		ExecuteForward(g_LevelDownForward,ret,id,g_players[id][LEVEL],oldLevel)
		
		return 4
	}
	
	return 1
}

/*
	@id - player id
	@bonus - bonus points to add
	
	@return -
		0 - on fail
		1 - on success
		2 - on overset
		
	native aes_add_player_bonus(id,bonus)
*/
public _aes_add_player_bonus(plugin,params){
	if(params < 2){
		log_error(AMX_ERR_NATIVE,"bad arguments num, expected 2, passed %d", params)
		
		return 0
	}
	
	new id = get_param(1)
	new bonus = get_param(2)
	
	CHECK_PLAYER(id)
	
	if(g_players[id][LOADED] <= 0)
		return 0
		
	g_players[id][BONUSES] += bonus
	
	if(g_players[id][BONUSES] < 0){
		g_players[id][BONUSES] = 0
		
		return 2
	}
	
	return 1
}

/*
	@id - player id
	@data - array with player stats
		data[0] - player experience
		data[1] - player level
		data[2] - player bonuses
		data[3] - player next level experience
	
	@return - 
		0 on fail
		1 on success
	
	native aes_get_player_stats(id,data[4])
*/
public _aes_get_player_stats(plugin,params){
	if(params < 2){
		log_error(AMX_ERR_NATIVE,"bad arguments num, expected 2, passed %d", params)
		
		return 0
	}
	
	new id = get_param(1)
	
	CHECK_PLAYER(id)
	
	if(g_players[id][LOADED] <= 0)
		return 0
	
	new ret[4]
	
	ret[0] = g_players[id][EXP]
	ret[1] = g_players[id][LEVEL]
	ret[2] = g_players[id][BONUSES]
	ret[3] = get_exp_to_next_level(ret[1])
	
	set_array(2,ret,4)
	
	return 1
}

/*
	@id - player id
	@stats - stats array
		[0] - experience
		[1] - level
		[2] - bonuses
		
	native aes_set_player_stats(id,stats[3])
*/
public _aes_set_player_stats(plugin,params){
	if(params < 2){
		log_error(AMX_ERR_NATIVE,"bad arguments num, expected 2, passed %d", params)
		
		return 0
	}
	
	new id = get_param(1)
	
	CHECK_PLAYER(id)
	
	new st[3]
	get_array(2,st,3)
	
	if(st[1] >= g_maxLevel)
		st[1] = g_maxLevel - 1
	
	if(st[0] >= 0)
		g_players[id][EXP] = st[0]
	else if(st[0] < 0 && g_players[id][LEVEL] != st[1] && st[1] > -1){ // рассчитываем опыт дл€ заданного уровн€
		g_players[id][EXP] = get_exp_to_next_level(st[1] - 1)
	}
		
	if(st[1] >= 0)
		g_players[id][LEVEL] = st[1]
	else if(st[1] < 0 && st[0] > -1){ // рассчитываем уровень дл€ заданного опыта
		g_players[id][LEVEL] = get_level_for_exp(st[0])
	}
	
	if(st[2] > -1)
		g_players[id][BONUSES] = st[2]
		
	g_players[id][EXP_TO_NEXT_LEVEL] = get_exp_to_next_level(g_players[id][LEVEL])
	
	if(!g_players[id][LOADED])
		g_players[id][LOADED] = 1
	
	return 1
}

public _aes_set_level_exp(plugin,params){
	if(params < 2){
		log_error(AMX_ERR_NATIVE,"bad agruments num, expected 2, passed %d", params)
	
		return 0
	}
	
	new lvl = get_param(1)
	
	if(lvl == -1){
		ArrayPushCell(g_Levels,get_param(2))
		
		if(params == 3){
			new levelName[32],key[10]
			get_string(3,levelName,31)
			
			if(strlen(levelName)){
				formatex(key,9,"%d",g_maxLevel)
				TrieSetString(g_LevelNames,key,levelName)
			}
		}
		
		g_maxLevel ++
		
		return g_maxLevel - 1
	}else{
		if(lvl > g_maxLevel - 1 || lvl < 0)
			return -1
			
		ArraySetCell(g_Levels,lvl,get_param(2))
	}
	
	return -1
}

/*
	@lvlnum - player id
	@level[] - level name output
	@len - len
	
	#idLang - return level name in idLang player language
	
	@return -
		0 - on fail
		1 - on success
		
	native aes_get_level_name(lvlnum,level[],len,idLang = 0)
*/
public _aes_get_level_name(plugin,params){
	if(params < 3){
		log_error(AMX_ERR_NATIVE,"bad arguments num, expected 2, passed %d", params)
		
		return 0
	}
	
	new level = get_param(1)
	new idLang = get_param(4)
	
	if(level > g_maxLevel)
		level = g_maxLevel
		
	new LangKey[10],levelName[64]
	
	formatex(LangKey,9,"%d",level)
	
	if(!TrieGetString(g_LevelNames,LangKey,levelName,31)){
		level ++
		
		if(level > g_maxLevel)
			level = g_maxLevel
		
		formatex(LangKey,9,"LVL_%d",level)
		formatex(levelName,63,"%L",idLang,LangKey)
	}
	
	set_string(2,levelName,get_param(3))
	
	return 1
}

/*
	@exp - exeprience
	@return - level num
	
	native aes_get_level_for_exp(exp)
*/

public _aes_get_level_for_exp(plugin,params){
	if(params < 1){
		log_error(AMX_ERR_NATIVE,"bad arguments num, expected 1, passed %d", params)
		
		return 0
	}
	
	return get_level_for_exp(get_param(1))
}

/*
	@trackIds - dynamic array with trackId
	
	@return - dynamic array with stats
	
	native aes_get_stats(Array:trackIds)
*/
public _aes_get_stats(plugin,params){
	if(params < 1){
		log_error(AMX_ERR_NATIVE,"bad arguments num, expected 1, passed %d", params)
		
		return 0
	}
		
	new Array:arrHandler = Array:get_param(1)
	new Array:retArray = ArrayCreate(4)
	
	switch(g_storagetype){
		case 1:{
			new temp2[4]
			
			for(new i;i < ArraySize(arrHandler); ++i){
				new trackId[36]
				ArrayGetString(arrHandler,i,trackId,35)
				
				if(TrieKeyExists(g_PlayerStats,trackId)){
					new pStats[player_info - 1]
					TrieGetArray(g_PlayerStats,trackId,pStats,player_info - 1)
					
					temp2[0] = pStats[EXP]
					temp2[1] = pStats[LEVEL]
					temp2[2] = pStats[BONUSES]
					temp2[3] = get_exp_to_next_level(temp2[1])
				}
				
				ArrayPushArray(retArray,temp2)
				arrayset(temp2,-1,4)
			}
		}
		case 2:{
			if(sqlFail){
				ArrayDestroy(arrHandler)
				
				return 0
			}
			
			if(sqlFailCount >= get_pcvar_num(cvar[CVAR_SQL_MAXFAIL])){
				log_amx("max sql fail reached")

				sqlFail = true
				
				ArrayDestroy(arrHandler)
				
				return 0
			}
			
			new errcode,err[256],len
	
			new Handle:sqlConnection = SQL_Connect(g_sql,errcode,err,255)
			
			if(errcode){
				log_amx("[ aes_get_stats ] MySQL connection failed")
				log_amx("[ %d ] %s",errcode,err)
				
				sqlFailCount ++
				
				ArrayDestroy(arrHandler)
				
				return 0
			}
			
			new Trie:temp = TrieCreate()
			new temp2[4]
			
			arrayset(temp2,-1,4)
			
			len += formatex(g_query[len],512 - len,"SELECT * FROM `%s` WHERE `trackId` IN(",sqlTable)
			
			for(new i;i < ArraySize(arrHandler) ; ++i){
				new trackId[72]
				ArrayGetString(arrHandler,i,trackId,36)
				TrieSetCell(temp,trackId,i)
				SQL_QuoteString(sqlConnection,trackId,72,trackId)
				
				len += formatex(g_query[len],512 - len,"'%s'",trackId)
				
				if(ArraySize(arrHandler) - 1 != i){
					len += formatex(g_query[len],512 - len,",")
				}
				
				ArrayPushArray(retArray,temp2)
			}
			
			len += formatex(g_query[len],512 - len,")")
			
			new Handle:que = SQL_PrepareQuery(sqlConnection,g_query)
			
			if(!SQL_Execute(que)){
				SQL_QueryError(que,err,256)
				
				log_amx("[ aes_get_stats ] Query failed")
				log_amx("%s",err)
				
				sqlFailCount ++
			}else{
				while(SQL_MoreResults(que)){
					new trackId[36],aid
					
					SQL_ReadResult(que,1,trackId,35)
					temp2[0] = SQL_ReadResult(que,3)
					temp2[1] = SQL_ReadResult(que,4)
					temp2[2] = SQL_ReadResult(que,5)
					temp2[3] = get_exp_to_next_level(temp2[0])
					
					TrieGetCell(temp,trackId,aid)
					ArraySetArray(retArray,aid,temp2)
					arrayset(temp2,-1,4)
					
					SQL_NextRow(que)
				}
			}
			
			TrieDestroy(temp)
			
			SQL_FreeHandle(que)
			SQL_FreeHandle(sqlConnection)
		}
	}
	
	ArrayDestroy(arrHandler)
	
	new arrStr[12]
	formatex(arrStr,11,"%d",retArray)
	
	return str_to_num(arrStr)
}

public _aes_get_max_level(plugin,params){
	return g_maxLevel
}

public _aes_get_exp_to_next_level(plugin,params){
	if(params < 1){
		log_error(AMX_ERR_NATIVE,"bad arguments num, expected 1, passed %d", params)
		
		return -1
	}
	
	new lvl = get_param(1)
	
	if(lvl < 0 || lvl > g_maxLevel){
		log_error(AMX_ERR_NATIVE,"level out of bounds (%d)",lvl)
		return -1
	}
	
	return get_exp_to_next_level(lvl)
}
