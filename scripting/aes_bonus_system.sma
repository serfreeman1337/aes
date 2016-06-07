/* 
*	AES: Bonus System			      v. 0.5
*	by serfreeman1337		http://gf.hldm.org/
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
#endif

#include <amxmisc>
#include <aes_main>
#include <hamsandwich>
#include <fun>

#define PLUGIN "AES: Bonus System"
#define VERSION "0.5 Vega"
#define AUTHOR "serfreeman1337"

enum _:itemTypeStruct {
	ITEM_GIVE = 1,
	ITEM_CALL,
	ITEM_MENU,
	ITEM_FORWARD
}

enum _: {
	BONUS_ITEM_SPAWN,
	BONUS_ITEM_MENU,
	BONUS_MENUS
}

// мы передали тебе массив в массив
// чтобы ты мог работать с массивом пока работаешь  с массивом

enum _:itemFieldsStruct {
	IB_TYPE,
	IB_NAME[64],
	IB_ITEM[30],
	IB_PLUGIN_ID,
	IB_FUNCTION_ID,
	IB_POINTS,
	Array:IB_LEVELS,
	Array:IB_CHANCE,
	bool:IB_SUMCHANCE,
	
	Float:IB_EXP,
	IB_LEVEL,
	IB_ROUND,
	Float:IB_TIME
}

enum _:menuFieldsStruct {
	MENU_TITLE[64],
	MENU_SAYCMD[30],
	MENU_CONCMD[30],
	Array: MENU_LIST
}

// Мастер массивов 80 лвл

new Array:g_SpawnBonusItems
new Array:g_PointsBonusItems
new Array:g_BonusMenus
new Trie:g_MenuCommandsValid

//

new g_SpawnBonusCount
new g_PointsBonusCount

// some random stuff
new bool:isLocked,iaNewForward
new bool:player_already_spawned[MAX_PLAYERS + 1]
new Float:player_spawn_time[MAX_PLAYERS + 1]

// Менюшки
new itemName[128],itemInfo[10]
new Trie:callCmds

// cvars

enum _:cvars_num {
	CVAR_BONUS_ENABLED,
	CVAR_BONUS_SPAWN,
}

new cvar[cvars_num]
new items_CB

new iRound

public plugin_init(){
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	//
	// Вкл/выкл системы бонусов
	//
	cvar[CVAR_BONUS_ENABLED] = register_cvar("aes_bonus_enable","1",FCVAR_SERVER)
	
	//
	// Выдача бонусов на спавне
	//	0 - нет бонусов на спавне
	//	1 - выдавать всегда
	//	2 - выдать только один раз за раунд
	cvar[CVAR_BONUS_SPAWN] = register_cvar("aes_bonus_spawn","1")
	
	register_srvcmd("aes_lockmap","Check_LockMap")
	register_dictionary("aes.txt")
	
	iaNewForward = CreateMultiForward("aes_on_anew_command",ET_STOP,FP_CELL)
	
	RegisterHam(Ham_Spawn,"player","On_Player_Spawn",true)
}

// слишком мощный код
public plugin_cfg(){
	items_CB = menu_makecallback("Format_ItemsCallback")
	
	new fPath[256],len
	len += get_configsdir(fPath,charsmax(fPath))
	len += formatex(fPath[len],charsmax(fPath) - len,"/aes/bonus.ini",fPath)
	
	// читаем файл конфигурации
	new f = fopen(fPath,"r")
	
	if(!f){
		log_amx("[ERROR] configuration file not found")
		set_fail_state("configuration file not found")
		
		return
	}
	
	new buffer[1024],cfgBlock = -1,itemType,key[32],value[sizeof buffer - sizeof key],keyId,line
	new itemData[itemFieldsStruct],menuData[menuFieldsStruct] 
	
	// карта ключей параметров
	enum _:{
		KEY_NAME = 1,
		KEY_LEVELMAP,
		KEY_ITEM,
		KEY_CHANCE,
		KEY_PLUGIN,
		KEY_FUNCTION,
		KEY_POINTS,
		KEY_SUMLEVELS,
		
		KEY_MENU_TITLE,
		KEY_MENU_SAY,
		KEY_MENU_CONSOLE,
		KEY_MENU_ITEMS,
		
		KEY_EXP,
		KEY_LEVEL,
		KEY_ROUND,
		KEY_TIME
	}
	
	new Trie:keyMap = TrieCreate()
	
	TrieSetCell(keyMap,"name",KEY_NAME)
	TrieSetCell(keyMap,"levels",KEY_LEVELMAP)
	TrieSetCell(keyMap,"item",KEY_ITEM)
	TrieSetCell(keyMap,"plugin",KEY_PLUGIN)
	TrieSetCell(keyMap,"function",KEY_FUNCTION)
	TrieSetCell(keyMap,"points",KEY_POINTS)
	TrieSetCell(keyMap,"chance",KEY_CHANCE)
	TrieSetCell(keyMap,"sumlevels",KEY_SUMLEVELS)
	
	TrieSetCell(keyMap,"title",KEY_MENU_TITLE)
	TrieSetCell(keyMap,"say",KEY_MENU_SAY)
	TrieSetCell(keyMap,"console",KEY_MENU_CONSOLE)
	TrieSetCell(keyMap,"list",KEY_MENU_ITEMS)
	
	TrieSetCell(keyMap,"exp",KEY_EXP)
	TrieSetCell(keyMap,"level",KEY_LEVEL)
	TrieSetCell(keyMap,"round",KEY_ROUND)
	TrieSetCell(keyMap,"time",KEY_TIME)
	
	// читаем содержимое файла конфигурации
	while(!feof(f))
	{
		fgets(f,buffer,charsmax(buffer))
		trim(buffer)
		
		line ++
		
		if(!buffer[0] || buffer[0] == ';')
			continue
			
		if(buffer[0] == '['){	// проверяем какой блок конфигурации сейчас читаем
			switch(cfgBlock){
				case BONUS_ITEM_SPAWN,BONUS_ITEM_MENU: {
					if(RegisterBonusItem(itemData,cfgBlock,line))
						arrayset(itemData,0,itemFieldsStruct)
				}
				case BONUS_MENUS: {
					if(RegisterMenuItem(menuData,line) >= 0)
						arrayset(menuData,0,menuFieldsStruct)
				}
			}
			
			if(strcmp(buffer,"[spawn]") == 0)		// бонусы на спавне
				cfgBlock = BONUS_ITEM_SPAWN
			else if(strcmp(buffer,"[items]") == 0)	// бонусы в меню
				cfgBlock = BONUS_ITEM_MENU
			else if(strcmp(buffer,"[menu]") == 0)	// менюшки	
				cfgBlock = BONUS_MENUS
	
			continue
		}
	
		// парсинг предметов
		if(cfgBlock == -1)
			continue
			
		if(buffer[0] == '<'){	// новый бонус
			if(cfgBlock != BONUS_MENUS){
				if(RegisterBonusItem(itemData,cfgBlock,line))
					arrayset(itemData,0,itemFieldsStruct)
			
				if(strcmp(buffer,"<give>") == 0)	// узнаем тип бонуса
					itemType = ITEM_GIVE
				else if(strcmp(buffer,"<call>") == 0)
					itemType = ITEM_CALL
				else{
					itemType = -1
					continue
				}
				
				itemData[IB_TYPE] = itemType
			}else{ // менюшки
				if(RegisterMenuItem(menuData,line) >= 0)
					arrayset(menuData,0,menuFieldsStruct)
				
				if(strcmp(buffer,"<menu>") == 0)
					itemType = ITEM_MENU
				else
					itemType = -1
			}
					
			continue
		}
		
		if(!itemType)
			continue
		
		// парсим ключи
		#if AMXX_VERSION_NUM >= 183
			strtok2(buffer,key,charsmax(key),value,charsmax(value),'=',TRIM_FULL)
		#else
			strtok(buffer,key,charsmax(key),value,charsmax(value),'=',1)
			replace(value,charsmax(value),"= ","")
		#endif	
		
		if(!TrieGetCell(keyMap,key,keyId) || (cfgBlock == BONUS_MENUS && keyId < KEY_MENU_TITLE)){ // узнаем ID ключа
			log_amx("[WARNING] unknown key ^"%s^" on line %d",
				key,line)
				
			continue
		}
		
		// парсинг значений ключей
		switch(keyId){
			//
			// Бонус предметы
			//
			
			// название бонуса
			case KEY_NAME: copy(itemData[IB_NAME],charsmax(itemData[IB_NAME]),value)
			// бонусы по уровням
			case KEY_LEVELMAP: itemData[IB_LEVELS] = _:parse_levels(value)
			// предмет для конструкции <give>
			case KEY_ITEM: copy(itemData[IB_ITEM],charsmax(itemData[IB_ITEM]),value)
			// шанс бонуса
			case KEY_CHANCE: itemData[IB_CHANCE] = _:parse_levels(value)
			// id плагина для конструкции <call>
			case KEY_PLUGIN:{
				itemData[IB_PLUGIN_ID] = find_plugin_byfile(value)
				
				if(itemData[IB_PLUGIN_ID] == INVALID_PLUGIN_ID){
					log_amx("[ERROR] can't find plugin ^"%s^" on line %d",value,line)
					
					// убираем этот бонус из меню
					itemData[IB_TYPE] = -1
					itemType = -1
				}
			}
			// id функции для конструкции <call>
			case KEY_FUNCTION:{
				if(itemData[IB_PLUGIN_ID] == -1){ // плагин не найден
					log_amx("[ERROR] plugin not found on line %d",line)
					
					itemData[IB_TYPE] = -1
					itemType = -1
				}else{
					itemData[IB_FUNCTION_ID] = get_func_id(value,itemData[IB_PLUGIN_ID])
					
					if(itemData[IB_FUNCTION_ID] == -1){ // проверка на валидность функции
						log_amx("[ERROR] can't find function ^"%s^" on line %d",value,line)
						
						itemData[IB_TYPE] = -1
						itemType = -1
					}
				}
			}
			// кол-во очков для этого бонуса в меню
			case KEY_POINTS: itemData[IB_POINTS] = str_to_num(value)
			// сумирование шанса за все уровни
			case KEY_SUMLEVELS: itemData[IB_SUMCHANCE] = str_to_num(value) ? false : true
			
			//
			// Меню
			//
			
			// название меню
			case KEY_MENU_TITLE: copy(menuData[MENU_TITLE],charsmax(menuData[MENU_TITLE]),value)
			// команда в чат для вызова меню
			case KEY_MENU_SAY: copy(menuData[MENU_SAYCMD],charsmax(menuData[MENU_SAYCMD]),value)
			// команда в консоли для вызова этого меню
			case KEY_MENU_CONSOLE: copy(menuData[MENU_CONCMD],charsmax(menuData[MENU_CONCMD]),value)
			// список предметов в меню
			case KEY_MENU_ITEMS: menuData[MENU_LIST] = _:parse_levels(value)
			
			case KEY_EXP: itemData[IB_EXP] = _:str_to_float(value)
			case KEY_LEVEL: itemData[IB_LEVEL] = str_to_num(value)
			case KEY_ROUND: itemData[IB_ROUND] = str_to_num(value)
			case KEY_TIME: itemData[IB_TIME]  = _:str_to_float(value)
		}
	}
	
	switch(cfgBlock){	// разбираем последний предмет, если есть
		case BONUS_ITEM_SPAWN,BONUS_ITEM_MENU: 
			if(RegisterBonusItem(itemData,cfgBlock,line))
				arrayset(itemData,0,itemFieldsStruct)
		case BONUS_MENUS: {
			if(RegisterMenuItem(menuData,line) >= 0)
				arrayset(menuData,0,menuFieldsStruct)
		}
	}
	
	TrieDestroy(keyMap)
	
	// бонусы на спавне
	if(g_SpawnBonusItems)
	{ 
		g_SpawnBonusCount = ArraySize(g_SpawnBonusItems)
	}
	
	if(g_PointsBonusItems){
		g_PointsBonusCount = ArraySize(g_PointsBonusItems)
		
		// регистрация бонус менюшек
		if(g_PointsBonusCount){
			if(g_BonusMenus){
				for(new i,length = ArraySize(g_BonusMenus) ; i < length ; i++){
					ArrayGetArray(g_BonusMenus,i,menuData)
					
					if(!callCmds)
						callCmds = TrieCreate()
					
					if(menuData[MENU_SAYCMD][0]){
						if(!TrieKeyExists(callCmds,menuData[MENU_SAYCMD])){
							new sayCmd[128]
							formatex(sayCmd,charsmax(sayCmd),"say %s",menuData[MENU_SAYCMD])
							register_clcmd(sayCmd,"Forward_CallCommand")
							
							TrieSetCell(callCmds,menuData[MENU_SAYCMD],i)
						}else{
							log_amx("WARNING! ^"%s^" say command already in use on line %d!",menuData[MENU_CONCMD],line)
						}
					}
					
					if(menuData[MENU_CONCMD][0]){
						if(!TrieKeyExists(callCmds,menuData[MENU_CONCMD])){
							register_clcmd(menuData[MENU_CONCMD],"Forward_CallCommand")
							TrieSetCell(callCmds,menuData[MENU_CONCMD],i)
						}else
							log_amx("WARNING ^"%s^" console command already in use on line %d!",menuData[MENU_CONCMD],line)
					}
				}
			}else{	// дефолтное меню /anew
				register_clcmd("say /anew","Forward_CallCommand")
				register_clcmd("anew","Forward_CallCommand")
			}
		}
	}
	
	if(get_pcvar_num(cvar[CVAR_BONUS_SPAWN]) == 2){
		if(cstrike_running()){
			register_logevent("ResetSpawn",2,"1=Round_End")
			
			register_logevent("RoundStart",2,"0=World triggered","1=Round_Start")
			register_logevent("RoundRestart",2,"0=World triggered","1=Game_Commencing")
			register_event("TextMsg","RoundRestart","a","2&#Game_will_restart_in")
			
			server_print("--> registred")
		}
	}
}

public RoundRestart()
{
	iRound = 0
}

public RoundStart()
{
	iRound ++
}


public Check_LockMap()
{
	new getmap[32],map[32]
	read_args(getmap,charsmax(getmap))
	remove_quotes(getmap)
	
	get_mapname(map,charsmax(map))
	
	if(!strcmp(getmap,map))
	{
		isLocked = true
		
		set_pcvar_num(cvar[CVAR_BONUS_ENABLED],0)
	}
}

public client_disconnected(id)
{
	if(get_pcvar_num(cvar[CVAR_BONUS_SPAWN]) == 2)
	{
		player_already_spawned[id] = false
	}
}

//
// Обработчик консольных команд
//
public Forward_ConsoleCommand(id){
	if(!g_BonusMenus)
		return Format_BonusMenu(id,-1)
	
	new consoleCmd[128]
	read_argv(0,consoleCmd,127)
	
	new cmdId
	
	// проверяем что сообщение содержит команду и узнаем её ID
	if(!TrieGetCell(g_MenuCommandsValid,consoleCmd,cmdId))
		return PLUGIN_HANDLED
		
	Format_BonusMenu(id,cmdId)
		
	return PLUGIN_HANDLED
}

//
// Обработчик say комманд
//
public Forward_CallCommand(id){
	if(!g_BonusMenus)
		return Format_BonusMenu(id,-1)
	
	new cmd[128]
	read_args(cmd,charsmax(cmd))
	
	if(!cmd[0])
		read_argv(0,cmd,charsmax(cmd))
	
	trim(cmd)
	remove_quotes(cmd)
	
	new cmdId
	
	if(!TrieGetCell(callCmds,cmd,cmdId))
		return PLUGIN_CONTINUE
	
	Format_BonusMenu(id,cmdId)
		
	return PLUGIN_CONTINUE
}

//
// Форматирование менюшек
//
public Format_BonusMenu(id,cmdId){
	if(isLocked){	// проверка возможности использования бонусов на этой карте
		client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_BLOCKED")
		
		return PLUGIN_CONTINUE
	}
	
	new player_bonus = aes_get_player_bonus(id)
	
	new player_bonus_str[10]
	num_to_str(player_bonus,player_bonus_str,charsmax(player_bonus_str))
	
	if(player_bonus <= 0){ // еще какая-то проверка
		client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_NOT")
		
		return PLUGIN_CONTINUE
	}
	
	new ret
	ExecuteForward(iaNewForward,ret,id)
	
	if(ret == PLUGIN_HANDLED) // блок вызова в другом плагине
		return PLUGIN_HANDLED
	
	new m,itemData[itemFieldsStruct]
	
	if(cmdId == -1){ // строим дефолтное меню anew со списком всех предметов
		formatex(itemName,charsmax(itemName),"%L %L",id,"AES_TAG_MENU",id,"AES_BONUS_MENU",player_bonus)
		m = menu_create(itemName,"aNew_MenuHandler")
		
		for(new i ; i < g_PointsBonusCount ; i++){
			ArrayGetArray(g_PointsBonusItems,i,itemData)
			
			num_to_str(i,itemInfo,charsmax(itemInfo))
			aes_get_item_name(itemData[IB_NAME],itemName,charsmax(itemName),id)
			
			menu_additem(m,itemName,itemInfo,.callback = items_CB)
		}
	}else{
		new menuData[menuFieldsStruct],itemIndex
		ArrayGetArray(g_BonusMenus,cmdId,menuData)

		new len = formatex(itemName,charsmax(itemName),"%L ",id,"AES_TAG_MENU")
		len += aes_get_item_name(menuData[MENU_TITLE],itemName[len],charsmax(itemName) - len,id)
		
		replace_all(itemName,charsmax(itemName),"\n","^n")
		replace_all(itemName,charsmax(itemName),"<p>",player_bonus_str)
		
		m = menu_create(itemName,"aNew_MenuHandler")
		
		for(new i,length = ArraySize(menuData[MENU_LIST]) ; i < length ; i++){
			itemIndex = ArrayGetCell(menuData[MENU_LIST],i) - 1
			
			if(!(0 <=itemIndex < g_PointsBonusCount)) // что ты мне подсунул, блеать
				continue
				
			ArrayGetArray(g_PointsBonusItems,i,itemData)
			num_to_str(i,itemInfo,charsmax(itemInfo))
			aes_get_item_name(itemData[IB_NAME],itemName,charsmax(itemName),id)
			
			menu_additem(m,itemName,itemInfo,.callback = items_CB)
		}
	}
	
	
	if(m != -1)
	{
		F_Format_NavButtons(id,m)
		menu_display(id,m)
	}
	
	return PLUGIN_CONTINUE
}

//
// Хандлер итемов в меню
//
public Format_ItemsCallback(id,menu,item)
{
	new info[10],item_name[256],dummy
	menu_item_getinfo(menu,item,dummy,info,charsmax(info),item_name,charsmax(item_name),dummy)
	
	new itemData[itemFieldsStruct]
	ArrayGetArray(g_PointsBonusItems,str_to_num(info),itemData)
	
	// проверяем доступность по бонусам
	if(itemData[IB_POINTS])
	{
		new player_bonus = aes_get_player_bonus(id)
		
		if(itemData[IB_POINTS] > player_bonus)
		{
			new tmpLang[128]
			formatex(tmpLang,charsmax(tmpLang)," %L",id,"AES_ANEW_INFO1",itemData[IB_POINTS])
			add(item_name,charsmax(item_name),tmpLang)
			
			menu_item_setname(menu,item,item_name)
			
			return ITEM_DISABLED
		}
	}
	
	// проверяем доступность по опыту
	if(itemData[IB_EXP])
	{
		new Float:player_exp = aes_get_player_exp(id)
	
		if(itemData[IB_EXP] > player_exp)
		{
			new tmpLang[128]
			formatex(tmpLang,charsmax(tmpLang)," %L",id,"AES_ANEW_INFO2",itemData[IB_EXP])
			add(item_name,charsmax(item_name),tmpLang)
			
			menu_item_setname(menu,item,item_name)
			
			return ITEM_DISABLED
		}
	}
	
	// проверяем доступность по уровню
	if(itemData[IB_LEVEL])
	{
		new player_level = aes_get_player_level(id) + 1
	
		if(itemData[IB_LEVEL] > player_level)
		{
			new tmpLang[128]
			formatex(tmpLang,charsmax(tmpLang)," %L",id,"AES_ANEW_INFO3",itemData[IB_LEVEL])
			add(item_name,charsmax(item_name),tmpLang)
			
			menu_item_setname(menu,item,item_name)
			
			return ITEM_DISABLED
		}
	}
	
	// проверяем доступность по раунду
	if(itemData[IB_ROUND])
	{
		if(itemData[IB_ROUND] > iRound)
		{
			new tmpLang[128]
			formatex(tmpLang,charsmax(tmpLang)," %L",id,"AES_ANEW_INFO4",itemData[IB_ROUND])
			add(item_name,charsmax(item_name),tmpLang)
			
			menu_item_setname(menu,item,item_name)
			
			return ITEM_DISABLED
		}
	}

	// проверяем на доступность по времени
	if(itemData[IB_TIME])
	{
		if(itemData[IB_TIME] < (get_gametime() - player_spawn_time[id]))
		{
			new tmpLang[128]
			formatex(tmpLang,charsmax(tmpLang)," %L",id,"AES_ANEW_INFO5",itemData[IB_TIME])
			add(item_name,charsmax(item_name),tmpLang)
			
			menu_item_setname(menu,item,item_name)
			
			return ITEM_DISABLED
		}
	}
	
	return ITEM_ENABLED
}

public F_Format_NavButtons(id,menu){
	new tmpLang[20]
	
	formatex(tmpLang,charsmax(tmpLang),"%L",id,"BACK")
	menu_setprop(menu,MPROP_BACKNAME,tmpLang)
	
	formatex(tmpLang,charsmax(tmpLang),"%L",id,"EXIT")
	menu_setprop(menu,MPROP_EXITNAME,tmpLang)
	
	formatex(tmpLang,charsmax(tmpLang),"%L",id,"MORE")
	menu_setprop(menu,MPROP_NEXTNAME,tmpLang)
}

//
// Хандлер бонус меню
//
public aNew_MenuHandler(id,m,item){
	if(item == MENU_EXIT)
	{
		menu_destroy(m)
		return PLUGIN_HANDLED
	}
	
	if(Format_ItemsCallback(id,m,item) != ITEM_ENABLED)
	{
		menu_destroy(m)
		return PLUGIN_HANDLED
	}
	
	new player_bonus = aes_get_player_bonus(id)
	
	if(!player_bonus){ // какая-то проверка
		menu_destroy(m)
		return PLUGIN_HANDLED
	}
	
	menu_item_getinfo(m,item,itemName[0],itemInfo,charsmax(itemInfo),itemName,1,itemName[0])
	new itemKey = str_to_num(itemInfo)
	
	menu_destroy(m)
	
	new itemData[itemFieldsStruct]
	ArrayGetArray(g_PointsBonusItems,itemKey,itemData)
	
	if(player_bonus < itemData[IB_POINTS]){ // недостаточно бонус очков
		client_print_color(id,print_team_default,"%L %L",id,"AES_TAG",id,"AES_ANEW_NOTENG")
		return PLUGIN_HANDLED
	}
	
	if(GiveBonus(itemData,id)){
		aes_add_player_bonus_f(id,-itemData[IB_POINTS])
		
		aes_get_item_name(itemData[IB_NAME],itemName,charsmax(itemName),id)
		strip_menu_codes(itemName,charsmax(itemName))
		
		client_print_color(id,0,"%L %L",id,"AES_TAG",id,"AES_ANEW_GIVE",itemName,itemData[IB_POINTS])
	}
	
	return PLUGIN_HANDLED
}

//
// Назначение бонус предметов
//	itemData- данные бонуса
//	id - игрок
//	count - кол-во бонусов
//	psh - пшш парень, значение в функцию передать не хочешь?
//
GiveBonus(itemData[itemFieldsStruct],id,count = 1,psh = 0){
	switch(itemData[IB_TYPE]){
		case ITEM_GIVE:{
			
			server_print("--> ALLLO")
			
			for(new i ; i < count ; i++){
				if(!give_item(id,itemData[IB_ITEM])){
					client_print_color(id,print_team_default,"%L %L",id,"AES_TAG",id,"AES_ANEW_CALL_PROBLEM")
					return false
				}
			}
		}
		case ITEM_CALL:{
			server_print("--> ALLLO2")
			
			if(callfunc_begin_i(itemData[IB_FUNCTION_ID],itemData[IB_PLUGIN_ID])){
				callfunc_push_int(id)
				callfunc_push_int(count)
					
				if(psh)
					callfunc_push_int(psh)
					
				return callfunc_end()
			}else{
				client_print_color(id,print_team_default,"%L %L",id,"AES_TAG",id,"AES_ANEW_CALL_PROBLEM")
				return false
			}
		}
	}
	
	return true
}

//
// Очищение строки от символов меню
//
strip_menu_codes(itemName[],len){
	replace_all(itemName,len,"\r","")
	replace_all(itemName,len,"\y","")
	replace_all(itemName,len,"\R","")
	replace_all(itemName,len,"\w","")
}

//
// Выдача бонусов на спавнеы
//
public On_Player_Spawn(id){
	if(isLocked || !get_pcvar_num(cvar[CVAR_BONUS_ENABLED]) || !is_user_alive(id))
		return HAM_IGNORED
	
	player_spawn_time[id] = get_gametime()
		
	new player_level = aes_get_player_level(id)
		
	switch(get_pcvar_num(cvar[CVAR_BONUS_SPAWN]))
	{
		case 0: return HAM_IGNORED
		case 2: // запоминаем спавн игрока
		{ 
			// игрок уже заспавнился
			if(player_already_spawned[id])
			{
				return HAM_IGNORED
			}
			
			player_already_spawned[id] = true
		}
	}
	
	new itemData[itemFieldsStruct],actLevel = -1
	new levelValue
		
	// проверяем бонусы на спавне
	for(new i;i < g_SpawnBonusCount ; ++i){
		arrayset(itemData,0,itemFieldsStruct)
		ArrayGetArray(g_SpawnBonusItems,i,itemData)
		
		// считаем шанс выдачи бонуса
		if(itemData[IB_CHANCE]){
			new chanceValue
			
			if(player_level >= ArraySize(itemData[IB_CHANCE])) // :D
				actLevel = ArraySize(itemData[IB_CHANCE]) - 1
			else
				actLevel = player_level
			
			if(itemData[IB_SUMCHANCE]){
				for(new z ; z <= actLevel ; z++)	// складываем общий шанс за все уровни
					chanceValue += ArrayGetCell(itemData[IB_CHANCE],i)
			}else{
				if(actLevel < 0)
					continue
			
				chanceValue = ArrayGetCell(itemData[IB_CHANCE],actLevel)
			}
			// проверяем что это наш шанс
			if(chanceValue * 10 < random_num(0,1000))
				continue	// извини братюнь, в другой раз
		}
		
		// узнаем значение бонуса для определенного уровня
		if(itemData[IB_LEVELS]){
			if(player_level >= ArraySize(itemData[IB_LEVELS])) // :D
				actLevel = ArraySize(itemData[IB_LEVELS]) - 1
			else
				actLevel = player_level
			
			if(itemData[IB_SUMCHANCE]){
				for(new i ; i <= actLevel ; i++)	// складываем значения за все уровни
					levelValue += ArrayGetCell(itemData[IB_LEVELS],i)
			}else{
				if(actLevel < 0)
					continue
				
				levelValue = ArrayGetCell(itemData[IB_LEVELS],actLevel)
			}
		}
		
		if(levelValue > 0)	// выдаем бонус
			GiveBonus(itemData,id,levelValue)
	}
		
	return HAM_IGNORED
}

public Array:parse_levels(levelString[]){
	new Array:which = ArrayCreate(1)
	
	new stPos,ePos,rawPoint[20]
	
	// parse levels entry
	do {
		ePos = strfind(levelString[stPos]," ")
		
		formatex(rawPoint,ePos,levelString[stPos])
		ArrayPushCell(which,str_to_num(rawPoint))
		
		stPos += ePos + 1
	} while (ePos != -1)
	
	return which
}

public aes_get_item_name(itemString[],out[],len,id){
	new l
	
	if(strfind(itemString,"LANG_") == 0){ // формирование по словарю
		replace(itemString,strlen(itemString),"LANG_","")
		
		l = formatex(out,len,"%L",id,itemString)
	}else{
		l = copy(out,len,itemString)
	}
	
	return l
}

//
// Регистрация бонус предмета
//	itemData - данные
//	cfgBlock - конфигурационный блок
//	line - линия
//
public RegisterBonusItem(itemData[itemFieldsStruct],cfgBlock,line){
	if(itemData[IB_TYPE]){	// записываем параметры предедущего бонуса
		new bool:isOk = true
				
		// проверки на валидность
		switch(itemData[IB_TYPE]){
			case ITEM_GIVE:{
				if(!itemData[IB_ITEM][0]){
					log_amx("[ERROR] give item not set on line %d",line)
					isOk = false
				}
			}
		}
				
		if(isOk){
			new Array:itemArray
			
			switch(cfgBlock){
				case BONUS_ITEM_SPAWN: {
					if(!g_SpawnBonusItems)
						g_SpawnBonusItems = ArrayCreate(itemFieldsStruct)
						
					itemArray = g_SpawnBonusItems
				}
				case BONUS_ITEM_MENU: {
					if(!g_PointsBonusItems)
						g_PointsBonusItems = ArrayCreate(itemFieldsStruct)
								
					itemArray = g_PointsBonusItems
				}
			}
					
			if(itemArray)
				ArrayPushArray(itemArray,itemData)
		}
		
		return true
	}
	
	return false
}

public RegisterMenuItem(menuData[menuFieldsStruct],line){
	if(!menuData[MENU_SAYCMD][0] && !menuData[MENU_CONCMD][0])
		return -1
	
	if(!g_BonusMenus)
		g_BonusMenus = ArrayCreate(menuFieldsStruct)
		
	ArrayPushArray(g_BonusMenus,menuData)
	
	return ArraySize(g_BonusMenus) - 1
}

public ResetSpawn()
{
	arrayset(player_already_spawned,false,sizeof player_already_spawned)
	arrayset(_:player_spawn_time,0,sizeof player_spawn_time)
}
/*
//
// API
//
public plugin_natives(){
	register_library("aexperience")
	
	register_native("aes_bonus_resetspawn","ResetSpawn",true)
	
	register_native("aes_bonus_registermenu","_native_register_menu")
	register_native("aes_bonus_registeritem","_native_register_item")
	
}

//
// Регистрация нового меню
//	title[] - заголовок нового меню
//	say[] - команда в чат для вызова этого меню
//	console[] - команда в консоли для вызова этого меню
//
//	@return	- ID нового меню, или -1 если всё плохо
//
// native aes_bonus_registermenu(title[],say[] = "",console[] = "")
//
public _native_register_menu(plugin,params){
	new menuData[menuFieldsStruct]
	get_string(1,menuData[MENU_TITLE],charsmax(menuData[MENU_TITLE]))
	
	if(!menuData[MENU_TITLE][0]){
		log_error(AMX_ERR_NATIVE,"menu title not specifed")
		return -1
	}
	
	new sayCommand[64],consoleCommand[64]
	get_string(2,menuData[MENU_SAYCMD],charsmax(menuData[MENU_SAYCMD]))
	get_string(3,menuData[MENU_CONCMD],charsmax(menuData[MENU_CONCMD]))
	
	return RegisterMenuItem(menuData,plugin)
}

//
// Регистрация нового бонуса
//	name[] - название бонуса
//	style - вызов бонуса
//		ITEM_GIVE - выдача предмета
//		ITEM_CALL - вызов функции из плагина
//		ITEM_FORWARD - регистрация форварда 
//
//	ITEM_GIVE
//		item[] - предмет, который будет выдан игроку
//	ITEM_CALL
//		plugin[] - плагин
//		function[] - функция в плагине
//	ITEM_FORWARD
//		forward[] - форвард функция
//
//	type - тип бонуса
//		BONUS_SPAWN - бонус на спавне
//		BONUS_ITEM - бонус в меню
//
//	BONUS_SPAWN
//		levels[] - значения уровня
//		chance[] - шанс
//		bool:sumchance - суммировать значения
//
//	BONUS_ITEM
//		cost - стоимость предмета в меню
//
//	@return - ID нового предмета, или -1 если всё тлён
//
// native aes_bonus_registeritem(name[],style,any:...)
//
*/
