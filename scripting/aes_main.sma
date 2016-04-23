/*
*	Advanced Experience System	     v. 0.5
*	by serfreeman1337	    http://1337.uz/
*/

#include <amxmodx>
#include <amxmisc>
#include <sqlx>

#define PLUGIN "Advanced Experience System"
#define VERSION "0.5 Vega"
#define AUTHOR "serfreeman1337"
#define LASTUPDATE "23, April (04), 2016"

//
// Основано на CSstatsX SQL
// http://1337.uz/csstatsx-sql/
//

// -- КОНСТАНТЫ -- //

enum _:sql_que_type	// тип sql запроса
{
	SQL_DUMMY,
	SQL_LOAD,	// загрузка статистики
	SQL_UPDATE,	// обновление
	SQL_INSERT,	// внесение новой записи
	SQL_UPDATERANK,	// получение ранков игроков,
	SQL_GETSTATS	// потоквый запрос на get_stats
}

enum _:load_state_type	// состояние получение статистики
{
	LOAD_NO,	// данных нет
	LOAD_WAIT,	// ожидание данных
	LOAD_OK,	// есть данные
	LOAD_NEW,	// новая запись
	LOAD_NEWWAIT,	// новая запись, ждем ответа
	LOAD_UPDATE	// перезагрузить после обновления
}

enum _:cvars
{
	CVAR_SQL_TYPE,
	CVAR_SQL_HOST,
	CVAR_SQL_USER,
	CVAR_SQL_PASS,
	CVAR_SQL_DB,
	CVAR_SQL_TABLE,
	CVAR_SQL_CREATE_DB,
	
	CVAR_RANK,
	CVAR_RANKBOTS,
	
	CVAR_LEVELS
}

enum _:player_data_struct
{
	PLAYER_ID,				// id игрока БД
	PLAYER_LOADSTATE,			// состояние загрузки статистики игрока
	
	Float:PLAYER_EXP,			// тек. опыт игрока	
	Float:PLAYER_EXPLAST,			// последний опыт игрока
	PLAYER_BONUS,				// бонусы игрока
	PLAYER_BONUSLAST,			// последнее кол-во бонусов
	
	PLAYER_NAME[MAX_NAME_LENGTH * 3],	// ник игрока
	PLAYER_STEAMID[30],			// steamid игрока
	PLAYER_IP[16],				// ip игрока
	
	PLAYER_LEVEL,				// уровень игрока
	Float:PLAYER_LEVELEXP,			// опыт для уровня
	Float:PLAYER_EXP_TO_NEXT		// требуемое кол-во опыта для сл. уровня игроку
}

enum _:row_ids		// столбцы таблицы
{
	ROW_ID,
	ROW_NAME,
	ROW_STEAMID,
	ROW_IP,
	ROW_EXP,
	ROW_BONUS,
	ROW_LASTUPDATE
}

enum _:
{
	RT_FAIL,
	RT_OK,
	RT_LEVEL_DOWN,
	RT_LEVEL_UP
}

new const row_names[row_ids][] = // имена столбцов
{
	"id",
	"name",
	"steamid",
	"ip",
	"exp",
	"bonus_count",
	"last_update"
}

const QUERY_LENGTH =	1472

// -- ПЕРЕМЕННЫЕ --
new player_data[MAX_PLAYERS + 1][player_data_struct]
new cvar[cvars]

new tbl_name[32]
new Handle:sql

new Array:levels_list
new levels_count
new Float:max_exp

new FW_LevelUp,FW_LevelDown
new dummy

public plugin_init()
{
	register_plugin(PLUGIN,VERSION,AUTHOR)
	
	server_print("")
	server_print("   %s Copyright (c) 2016 %s",PLUGIN,AUTHOR)
	server_print("   Version %s build on %s", VERSION, LASTUPDATE)
	server_print("")
	
	//
	// Квары настройки подключения
	//
	cvar[CVAR_SQL_TYPE] = register_cvar("aes_sql_driver","sqlite")
	cvar[CVAR_SQL_HOST] = register_cvar("aes_sql_host","",FCVAR_UNLOGGED|FCVAR_PROTECTED)
	cvar[CVAR_SQL_USER] = register_cvar("aes_sql_user","",FCVAR_UNLOGGED|FCVAR_PROTECTED)
	cvar[CVAR_SQL_PASS] = register_cvar("aes_sql_pass","",FCVAR_UNLOGGED|FCVAR_PROTECTED)
	cvar[CVAR_SQL_DB] = register_cvar("aes_sql_name","amxx",FCVAR_UNLOGGED|FCVAR_PROTECTED)
	cvar[CVAR_SQL_TABLE] = register_cvar("aes_sql_table","aes_stats",FCVAR_UNLOGGED|FCVAR_PROTECTED)
	
	cvar[CVAR_SQL_CREATE_DB] = register_cvar("aes_sql_create_db","1")
	
	cvar[CVAR_RANK] = register_cvar("aes_track_mode","1")
	cvar[CVAR_RANKBOTS] = register_cvar("aes_track_bots","1")
	
	cvar[CVAR_LEVELS] = register_cvar("aes_level","0 20 40 60 100 150 200 300 400 600 1000 1500 2100 2700 3400 4200 5100 5900 7000 10000")

	FW_LevelUp = CreateMultiForward("aes_player_levelup",ET_IGNORE,FP_CELL,FP_CELL,FP_CELL)
	FW_LevelDown = CreateMultiForward("aes_player_leveldown",ET_IGNORE,FP_CELL,FP_CELL,FP_CELL)
	
	register_dictionary("aes.txt")
}

public plugin_cfg()
{
	new cfg_path[256]
	get_configsdir(cfg_path,charsmax(cfg_path))
	
	server_cmd("exec %s/aes/aes.cfg",cfg_path)
	server_exec()
	
	new db_type[12]
	get_pcvar_string(cvar[CVAR_SQL_TYPE],db_type,charsmax(db_type))
	
	new host[128],user[64],pass[64],db[64],type[10]
	get_pcvar_string(cvar[CVAR_SQL_HOST],host,charsmax(host))
	get_pcvar_string(cvar[CVAR_SQL_USER],user,charsmax(user))
	get_pcvar_string(cvar[CVAR_SQL_PASS],pass,charsmax(pass))
	get_pcvar_string(cvar[CVAR_SQL_DB],db,charsmax(db))
	get_pcvar_string(cvar[CVAR_SQL_TABLE],tbl_name,charsmax(tbl_name))
	get_pcvar_string(cvar[CVAR_SQL_TYPE],type,charsmax(type))
	
	new query[QUERY_LENGTH]
	
	if(strcmp(db_type,"sqlite") == 0)
	{
		SQL_SetAffinity(db_type)
		
		// формируем запрос на создание таблицы
		formatex(query,charsmax(query),"\
				CREATE TABLE IF NOT EXISTS `%s` (\
					`%s`	INTEGER PRIMARY KEY AUTOINCREMENT,\
					`%s`	TEXT,\
					`%s`	TEXT,\
					`%s`	TEXT,\
					`%s`	REAL NOT NULL DEFAULT 0.0,\
					`%s`	INTEGER NOT NULL DEFAULT 0,\
					`%s`	TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP\
				);",
				
				tbl_name,
				
				row_names[ROW_ID],
				row_names[ROW_NAME],
				row_names[ROW_STEAMID],
				row_names[ROW_IP],
				row_names[ROW_EXP],
				row_names[ROW_BONUS],
				row_names[ROW_LASTUPDATE]
		)
	}
	else // привет wopox
	{
		set_fail_state("invalid ^"aes_sql_driver^" cvar value")
	}
	
	sql = SQL_MakeDbTuple(host,user,pass,db)
	
	// отправляем запрос на создание таблицы
	if(get_pcvar_num(cvar[CVAR_SQL_CREATE_DB]))
	{
		new sql_data[1]
		sql_data[0] = SQL_DUMMY
		
		SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
	}
	
	
	new levels_string[512],level_str[10]
	get_pcvar_string(cvar[CVAR_LEVELS],levels_string,charsmax(levels_string))
	
	while((argbreak(levels_string,level_str,charsmax(level_str),levels_string,charsmax(levels_string))) != -1)
	{
		if(!levels_list)
		{
			levels_list = ArrayCreate(1)
		}
		
		ArrayPushCell(levels_list,floatstr(level_str))
		max_exp = floatstr(level_str)
	}
	
	if(levels_list)
		levels_count = ArraySize(levels_list)
	
	register_clcmd("t1","t1")
	register_clcmd("t2","t2")
	register_clcmd("t3","t3")
	register_clcmd("t4","t4")
	register_clcmd("t5","t5")
	register_clcmd("t6","t6")
	register_clcmd("t7","t7")
}

public t1(id)
{
	DB_SavePlayerData(id)
}

public t2(id)
{
	Player_SetExp(id,player_data[id][PLAYER_EXP] + 0.01)
}

public t3(id)
{
	Player_SetExp(id,player_data[id][PLAYER_EXP] + 1.0)
}

public t4(id)
{
	player_data[id][PLAYER_EXP] -= 0.01
}

public t5(id)
{
	player_data[id][PLAYER_EXP] -= 1.01
}

public t6(id)
{
	Player_SetExp(id,1337.0)
}

public t7(id)
{
	Player_SetExp(id,322.0)
}

//
// Загружаем статистику из БД при подключении игрока
//
public client_putinserver(id)
{
	arrayset(player_data[id],0,player_data_struct)
	DB_LoadPlayerData(id)
}

//
// Сохраняем данные на дисконнекте
//
public client_disconnect(id)
{
	DB_SavePlayerData(id)
}

//
// Смена ника игрока
//
public client_infochanged(id)
{
	new cur_name[MAX_NAME_LENGTH],new_name[MAX_NAME_LENGTH]
	get_user_name(id,cur_name,charsmax(cur_name))
	get_user_info(id,"name",new_name,charsmax(new_name))
	
	if(strcmp(cur_name,new_name) != 0)
	{
		copy(player_data[id][PLAYER_NAME],charsmax(player_data[][PLAYER_NAME]),new_name)
		mysql_escape_string(player_data[id][PLAYER_NAME],charsmax(player_data[][PLAYER_NAME]))
		
		if(get_pcvar_num(cvar[CVAR_RANK]) == 0)
		{
			DB_SavePlayerData(id,true)
		}
	}
}

//
// Задаем опыт игроку
//
Player_SetExp(id,Float:new_exp,bool:no_forward = false,bool:force = false)
{
	// опыт не может быть отрицательным
	if(new_exp < 0.0)
		new_exp = 0.0
	
	player_data[id][PLAYER_EXP] = new_exp
	new rt = RT_OK
	
	// понижение по уровню
	if(new_exp < player_data[id][PLAYER_EXP_TO_NEXT])
	{
		rt = RT_LEVEL_DOWN
	}
	// повышение по уровню
	else if(new_exp >= player_data[id][PLAYER_EXP_TO_NEXT])
	{
		rt = RT_LEVEL_UP
	}
	
	// расчитываем новый уровень
	if(rt != RT_OK)
	{
		new old_level = player_data[id][PLAYER_LEVEL]
		new level = player_data[id][PLAYER_LEVEL] = Level_GetByExp(new_exp)
		player_data[id][PLAYER_LEVELEXP] = Level_GetExp(player_data[id][PLAYER_LEVEL])
		player_data[id][PLAYER_EXP_TO_NEXT] = Level_GetExpToNext(player_data[id][PLAYER_LEVEL])
		
		if(!no_forward)
		{
			new fw
			
			if(level > old_level)
			{
				fw = FW_LevelUp
			}
			else if(level < old_level)
			{
				fw = FW_LevelDown
			}
			
			if(fw)
			{
				ExecuteForward(fw,dummy,id,level,old_level)
			}
		}
	}
	
	log_amx("SET PLAYER LEVEL %.2f %d %.2f <--",
		player_data[id][PLAYER_EXP],
		player_data[id][PLAYER_LEVEL],
		player_data[id][PLAYER_EXP_TO_NEXT]
	)
	
	return rt
}

//
// Задаем бонусы игрока
//
Player_SetBonus(id,bonus,bool:force = false)
{
	player_data[id][PLAYER_BONUS] = bonus
	return true
}

//
// Задаем уровень игроку
//
Player_SetLevel(id,level,bool:force = false)
{
	new Float:exp = Level_GetExp(level)
	
	if(exp == -1.0)
	{
		return false
	}
	
	player_data[id][PLAYER_EXP] = exp
	player_data[id][PLAYER_LEVEL] = level
	player_data[id][PLAYER_LEVELEXP] = Level_GetExp(player_data[id][PLAYER_LEVEL])
	player_data[id][PLAYER_EXP_TO_NEXT] = Level_GetExpToNext(player_data[id][PLAYER_LEVEL])
	
	return true
}

//
// Функция возвращается текущий уровень по значению опыта
//
Level_GetByExp(Float:exp)
{
	for(new i ; i < levels_count ; i++)
	{
		// ищем уровень по опыту
		if(exp < ArrayGetCell(levels_list,i))
		{
			server_print("--> [LIST] %d %d %.2f",
				i,exp,ArrayGetCell(levels_list,i)
			)
			
			return clamp(i  - 1,0,levels_count - 1)
		}
	}
	
	// возвращаем максимальный уровень
	return levels_count - 1
}

//
// Функция возвращает необходимый опыт до сл. уровня
//
Float:Level_GetExpToNext(level)
{
	level ++
	
	// достигнут максимальный уровень
	if(level >= levels_count)
	{
		return -1.0
	}

	// TODO: проверки
	level = clamp(level,0,levels_count - 1)
	
	return ArrayGetCell(levels_list,level)
}

//
// Функция возвращает опыт для указанного уровня
//
Float:Level_GetExp(level)
{
	if(!(0 <= level < levels_count))
		return -1.0
	
	return ArrayGetCell(levels_list,level)
}

//
// Загрузка статистики игрока из базы данных
//
DB_LoadPlayerData(id)
{
	// пропускаем HLTV
	if(is_user_hltv(id))
	{
		return false
	}
	
	// пропускаем ботов, если отключена запись статистики ботов
	if(!get_pcvar_num(cvar[CVAR_RANKBOTS]) && is_user_bot(id))
	{
		return false
	}
	
	get_user_info(id,"name",player_data[id][PLAYER_NAME],charsmax(player_data[][PLAYER_NAME]))
	mysql_escape_string(player_data[id][PLAYER_NAME],charsmax(player_data[][PLAYER_NAME]))
	
	get_user_authid(id,player_data[id][PLAYER_STEAMID],charsmax(player_data[][PLAYER_STEAMID]))
	get_user_ip(id,player_data[id][PLAYER_IP],charsmax(player_data[][PLAYER_IP]),true)
	
	// формируем SQL запрос
	new query[QUERY_LENGTH],len,sql_data[2]
	
	sql_data[0] = SQL_LOAD
	sql_data[1] = id
	player_data[id][PLAYER_LOADSTATE] = LOAD_WAIT
	
	len += formatex(query[len],charsmax(query)-len,"SELECT *")
	
	switch(get_pcvar_num(cvar[CVAR_RANK]))
	{
		case 0: // статистика по нику
		{
			len += formatex(query[len],charsmax(query)-len," FROM `%s` WHERE `name` = '%s'",
				tbl_name,player_data[id][PLAYER_NAME]
			)
		}
		case 1: // статистика по steamid
		{
			len += formatex(query[len],charsmax(query)-len," FROM `%s` WHERE `steamid` = '%s'",
				tbl_name,player_data[id][PLAYER_STEAMID]
			)
		}
		case 2: // статистика по ip
		{
			len += formatex(query[len],charsmax(query)-len," FROM `%s` WHERE `ip` = '%s'",
				tbl_name,player_data[id][PLAYER_IP]
			)
		}
		default:
		{
			return false
		}
	}
	
	// отправка потокового запроса
	SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
	
	return true
}

//
// Сохранение статистики игрока
//
DB_SavePlayerData(id,bool:reload = false)
{
	if(player_data[id][PLAYER_LOADSTATE] < LOAD_OK) // игрок не загрузился
	{
		return false
	}
	
	new query[QUERY_LENGTH]
	
	new sql_data[2]
	sql_data[1] = id
	
	switch(player_data[id][PLAYER_LOADSTATE])
	{
		case LOAD_OK: // обновление данных
		{
			if(reload)
			{
				player_data[id][PLAYER_LOADSTATE] = LOAD_UPDATE
			}
			
			sql_data[0] = SQL_UPDATE
			
			new len,to_save
			
			len += formatex(query[len],charsmax(query) - len,"UPDATE `%s` SET",tbl_name)
			
			new Float:diffexp = player_data[id][PLAYER_EXP] - player_data[id][PLAYER_EXPLAST]
			new diffbonus = player_data[id][PLAYER_BONUS] - player_data[id][PLAYER_BONUSLAST]
			
			
			if(diffexp != 0.0)
			{
				len += formatex(query[len],charsmax(query) - len,"`%s` = `%s` + '%.2f'",
					row_names[ROW_EXP],
					row_names[ROW_EXP],
					_:diffexp >= 0 ? diffexp + 0.005 : diffexp - 0.005
				)
				
				player_data[id][PLAYER_EXPLAST] = player_data[id][PLAYER_EXP]
				
				to_save ++
			}
			
			if(diffbonus != 0)
			{
				len += formatex(query[len],charsmax(query) - len,"%s`%s` = `%s` + '%d'",
					to_save ? "," : "",
					row_names[ROW_BONUS],
					row_names[ROW_BONUS],
					diffbonus
				)
				
				player_data[id][PLAYER_BONUSLAST] = player_data[id][PLAYER_BONUS]
				
				to_save ++
			}
			
			// обновляем время последнего подключения, ник, ип и steamid
			len += formatex(query[len],charsmax(query) - len,",\
				`%s` = CURRENT_TIMESTAMP,\
				`%s` = '%s',\
				`%s` = '%s'",
				
				row_names[ROW_LASTUPDATE],
				row_names[ROW_STEAMID],player_data[id][PLAYER_STEAMID],
				row_names[ROW_IP],player_data[id][PLAYER_IP]
			)
			
			if(!reload) // не обновляем ник при его смене
			{
				len += formatex(query[len],charsmax(query) - len,",`%s` = '%s'",
					row_names[ROW_NAME],player_data[id][PLAYER_NAME]
				)
			}
			
			len += formatex(query[len],charsmax(query) - len,"WHERE `%s` = '%d'",row_names[ROW_ID],player_data[id][PLAYER_ID])
			
			if(!to_save) // нечего сохранять
			{
				// я обманул. азазаза
				if(player_data[id][PLAYER_LOADSTATE] == LOAD_UPDATE)
				{
					player_data[id][PLAYER_LOADSTATE] = LOAD_NO
					DB_LoadPlayerData(id)
				}
				
				return false
			}
		}
		case LOAD_NEW: // запрос на добавление новой записи
		{
			sql_data[0] = SQL_INSERT
			
			formatex(query,charsmax(query),"INSERT INTO `%s` \
							(`%s`,`%s`,`%s`,`%s`,`%s`)\
							VALUES('%s','%s','%s','%.2f','%d')\
							",tbl_name,
							
					row_names[ROW_NAME],
					row_names[ROW_STEAMID],
					row_names[ROW_IP],
					row_names[ROW_EXP],
					row_names[ROW_BONUS],
					
					player_data[id][PLAYER_NAME],
					player_data[id][PLAYER_STEAMID],
					player_data[id][PLAYER_IP],
					
					player_data[id][PLAYER_EXP],
					player_data[id][PLAYER_BONUS]	
			)
			
			if(reload)
			{
				player_data[id][PLAYER_LOADSTATE] = LOAD_UPDATE
			}
			else
			{
				player_data[id][PLAYER_LOADSTATE] = LOAD_NEWWAIT
			}
		}
	}
	
	if(query[0])
	{
		log_amx("[%s]",query)
		SQL_ThreadQuery(sql,"SQL_Handler",query,sql_data,sizeof sql_data)
	}
	
	return true
}

//
// Хандлер SQL ответа
//
public SQL_Handler(failstate,Handle:sqlQue,err[],errNum,data[],dataSize){
	switch(failstate)
	{
		case TQUERY_CONNECT_FAILED: 
		{
			log_amx("SQL connection failed")
			log_amx("[ %d ] %s",errNum,err)
			
			return PLUGIN_HANDLED
		}
		case TQUERY_QUERY_FAILED:
		{
			new lastQue[QUERY_LENGTH]
			SQL_GetQueryString(sqlQue,lastQue,charsmax(lastQue)) // узнаем запрос
			
			log_amx("SQL query failed")
			log_amx("[ %d ] %s",errNum,err)
			log_amx("[ SQL ] [%s]",lastQue)
			
			return PLUGIN_HANDLED
		}
	}
	
	switch(data[0])
	{
		case SQL_LOAD: // загрзука статистики игрока
		{
			new id = data[1]
		
			if(!is_user_connected(id))
			{
				return PLUGIN_HANDLED
			}
			
			if(SQL_NumResults(sqlQue)) // считываем статистику
			{
				player_data[id][PLAYER_LOADSTATE] = LOAD_OK
				player_data[id][PLAYER_ID] = SQL_ReadResult(sqlQue,ROW_ID)
				
				new Float:exp
				
				SQL_ReadResult(sqlQue,ROW_EXP,exp)
				Player_SetExp(id,exp,true)
				
				player_data[id][PLAYER_EXPLAST] = player_data[id][PLAYER_EXP]
				
				player_data[id][PLAYER_BONUS] = player_data[id][PLAYER_BONUSLAST] = SQL_ReadResult(sqlQue,ROW_BONUS)
				
				log_amx("SELECT id: %d, exp: %.2f, bonus: %d",
					SQL_ReadResult(sqlQue,ROW_ID),
					player_data[id][PLAYER_EXPLAST],
					player_data[id][PLAYER_BONUS]
				)
			}
			else // помечаем как нового игрока
			{
				player_data[id][PLAYER_LOADSTATE] = LOAD_NEW
				
				DB_SavePlayerData(id) // добавляем запись в базу данных
				
				log_amx("SELECT NEW")
			}
		}
		case SQL_INSERT:	// запись новых данных
		{
			new id = data[1]
			
			if(is_user_connected(id))
			{
				if(player_data[id][PLAYER_LOADSTATE] == LOAD_UPDATE)
				{
					player_data[id][PLAYER_LOADSTATE] = LOAD_NO
					DB_LoadPlayerData(id)
					
					return PLUGIN_HANDLED
				}
				
				player_data[id][PLAYER_ID] = SQL_GetInsertId(sqlQue)	// первичный ключ
				player_data[id][PLAYER_LOADSTATE] = LOAD_OK		// данные загружены
				
				// я упрлся 0)0)0
				
				log_amx("INSERT id: %d, exp: %.2f, bonus: %d",
					player_data[id][PLAYER_ID],
					player_data[id][PLAYER_EXPLAST],
					player_data[id][PLAYER_BONUSLAST]
				)
			}
		}
		case SQL_UPDATE: // обновление данных
		{
			new id = data[1]
			
			if(is_user_connected(id))
			{	
				if(player_data[id][PLAYER_LOADSTATE] == LOAD_UPDATE)
				{
					player_data[id][PLAYER_LOADSTATE] = LOAD_NO
					DB_LoadPlayerData(id)
				}
				
				log_amx("UPDATE id: %d, exp: %.2f, bonus: %d",
					player_data[id][PLAYER_ID],
					player_data[id][PLAYER_EXPLAST],
					player_data[id][PLAYER_BONUSLAST]
				)
			}
		}
	}
	
	return PLUGIN_HANDLED
}

//
// API
//

#define CHECK_PLAYER(%1) \
if (!(0 < %1 <= MaxClients)) \
{ \
	log_error(AMX_ERR_NATIVE, "player out of range (%d)", %1); \
	return 0; \
}

public plugin_natives()
{
	/*
		aes_set_player_exp
		aes_get_player_exp
		
		aes_get_player_bonus
		aes_set_player_bonus
	*/
	
	register_library("aes")
	
	register_native("aes_set_player_exp","_aes_set_player_exp",true)
	register_native("aes_get_player_exp","_aes_get_player_exp",true)
	register_native("aes_get_player_reqexp","_aes_get_player_reqexp",true)
	register_native("aes_set_player_bonus","_aes_set_player_bonus",true)
	register_native("aes_get_player_bonus","_aes_get_player_bonus",true)
	register_native("aes_set_player_level","_aes_set_player_level",true)
	register_native("aes_get_player_level","_aes_get_player_level",true)
	register_native("aes_get_max_level","_aes_get_max_level",true)
	register_native("aes_get_level_name","_aes_get_level_name")
	
	// 0.4 DEPRECATED
	register_library("aes_main")
	register_native("aes_add_player_exp","_aes_add_player_exp",true)
	register_native("aes_add_player_bonus","_aes_add_player_bonus",true)
	register_native("aes_get_stats","_aes_get_stats")
	register_native("aes_get_player_stats","_aes_get_player_stats")
	register_native("aes_set_player_stats","_aes_set_player_stats")
	register_native("aes_set_level_exp","_aes_set_level_exp")
	register_native("aes_get_level_name","_aes_get_level_name")
	register_native("aes_get_level_for_exp","_aes_get_level_for_exp",true)
	register_native("aes_get_exp_to_next_level","_aes_get_exp_to_next_level",true)
}

public _aes_set_player_exp(id,Float:exp,bool:no_forward,bool:force)
{
	CHECK_PLAYER(id)
	return Player_SetExp(id,exp,no_forward,force)
}

public _aes_get_player_exp(id)
{
	CHECK_PLAYER(id)
	return _:player_data[id][PLAYER_EXP]
}

public _aes_get_player_reqexp(id)
{
	CHECK_PLAYER(id)
	return _:player_data[id][PLAYER_EXP_TO_NEXT]
}

public _aes_set_player_bonus(id,bonus,bool:force)
{
	CHECK_PLAYER(id)
	return Player_SetBonus(id,bonus,force)
}

public _aes_get_player_bonus(id)
{
	CHECK_PLAYER(id)
	return player_data[id][PLAYER_BONUS]
}

public _aes_set_player_level(id,level,bool:force)
{
	CHECK_PLAYER(id)
	return Player_SetLevel(id,level,force)
}

public _aes_get_player_level(id)
{
	CHECK_PLAYER(id)
	return player_data[id][PLAYER_LEVEL]
}

public _aes_get_max_level()
{
	return levels_count
}

public _aes_get_level_name(plugin,params)
{
	new level = get_param(1)
	new len = get_param(3)
	new idLang = get_param(4)
	
	if(level > levels_count)
		level = levels_count - 1
		
	new LangKey[10],levelName[64]
	
	formatex(LangKey,charsmax(LangKey),"LVL_%d",level + 1)
	len = formatex(levelName,len,"%L",idLang,LangKey)
	
	set_string(2,levelName,len)
	
	return len
}

//
// ОБРАТНАЯ СОВМЕСТИМОСТЬ С 0.4
//
public _aes_get_stats()
{
	return false
}

public _aes_add_player_exp(id,exp){
	CHECK_PLAYER(id)
	
	if(!exp)
		return 0
	
	return Player_SetExp(id,player_data[id][PLAYER_EXP] + float(exp))
}

public _aes_add_player_bonus(id,bonus)
{
	CHECK_PLAYER(id)
	
	if(!bonus)
		return 0
	
	return Player_SetBonus(id,player_data[id][PLAYER_BONUS] +bonus)
}

public _aes_get_player_stats(plugin,params){
	new id = get_param(1)
	
	CHECK_PLAYER(id)
	
	if(player_data[id][PLAYER_LOADSTATE] == LOAD_NO)
		return 0
	
	new ret[4]
	
	ret[0] = floatround(player_data[id][PLAYER_EXP])
	ret[1] = player_data[id][PLAYER_LEVEL]
	ret[2] = player_data[id][PLAYER_BONUS]
	ret[3] = floatround(player_data[id][PLAYER_EXP_TO_NEXT])
	
	set_array(2,ret,sizeof ret)
	
	return 1
}

public _aes_set_player_stats(plugin,params){
	if(params < 2){
		log_error(AMX_ERR_NATIVE,"bad arguments num, expected 2, passed %d", params)
		
		return 0
	}
	
	new id = get_param(1)
	
	CHECK_PLAYER(id)
	
	new st[3]
	get_array(2,st,3)
	
	if(st[0] > -1)
		Player_SetExp(id,float(st[0]),true,true)
	
	if(st[1] > -1)
		Player_SetLevel(id,st[1])
		
	if(st[2] > -1)
		Player_SetBonus(id,st[2])
	
	return 1
}

// что это за херня D:
public _aes_set_level_exp()
{
	return false
}

public _aes_get_level_for_exp(exp)
{
	return Level_GetByExp(float(exp))
}

public _aes_get_exp_to_next_level(lvl)
{
	return floatround(Level_GetExpToNext(lvl))
}

/*********    mysql escape functions     ************/
mysql_escape_string(dest[],len)
{
	//copy(dest, len, source);
	replace_all(dest,len,"\\","\\\\");
	replace_all(dest,len,"\0","\\0");
	replace_all(dest,len,"\n","\\n");
	replace_all(dest,len,"\r","\\r");
	replace_all(dest,len,"\x1a","\Z");
	replace_all(dest,len,"'","''");
	replace_all(dest,len,"^"","^"^"");
}
