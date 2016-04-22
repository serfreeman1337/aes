/*
	Advanced Experience System
	by serfreeman1337	http://gf.hldm.org/
*/

enum _: {
	AES_ST_EXP,
	AES_ST_LEVEL,
	AES_ST_BONUSES,
	AES_ST_NEXTEXP,

	AES_ST_END
}

/*
	Adds experience to player.

	@id - player id
	@exp - experience value
	
	@return - 
		0 on fail
		1 on success
		2 on level up
*/
native aes_add_player_exp(id,exp,override = 0)

/*	
	Adds bonus points to player.
	
	@id - player id
	@bonus - bonus points value
	
	@return -
		0 - on fail
		1 - on success
		2 - on overset
*/		
native aes_add_player_bonus(id,bonus)

/*
	Returns player experience stats.
	
	@id - player id
	@data - array with player stats
		data[0] - player experience
		data[1] - player level
		data[2] - player bonuses
		data[3] - player next level experience
	
	@return - 
		0 on fail
		1 on success
*/
native aes_get_player_stats(id,data[4])

/*
	Sets player experience stats.
	
	@id - player id
	@stats - stats array
		[0] - experience
		[1] - level
		[2] - bonuses
		
	native aes_set_player_stats(id,stats[3])
*/
native aes_set_player_stats(id,stats[3])

/*
	Returns level name for level num.
	
	@lvlnum - player id
	@level[] - level name output
	@len - len
	
	#idLang - return level name in idLang player language
	
	@return -
		0 - on fail
		1 - on success
*/
native aes_get_level_name(lvlnum,level[],len,idLang = 0)

/*
	Returns experience to next level.
	
	@exp - exeprience
	@return - level num
*/
native aes_get_level_for_exp(exp)

/*
	Returns max level.
*/
native aes_get_max_level()

/*
	Gets experience to next level for given level num.
	
	@lvl - level
	
	@return 
		level experience on success
		-1 on fail
*/
native aes_get_exp_to_next_level(lvl)

/*
	Returns offline stats for given trackIds.
	
	@trackIds - dynamic array with trackIds.
	@return - dynamic array with stats for gived tackIds.
*/
native Array:aes_get_stats(Array:trackIds)

/* FORWARDS */

/*
	Called on player level up.
*/
forward aes_player_levelup(id,newlevel,oldlevel)

/*
	Called on player level down.
*/
forward aes_player_leveldown(id,newlevel,oldlevel)

/* aes_bonus_system.amxx */

/*
	Called on opening anew menu.
	return PLUGI_HANDLED if you want block menu.
*/

forward aes_on_anew_command(id)

/* aes_exp_cstrike.amxx */

/*
	Returns exp value for given stats.
	
	stats[8] = get_user_stats
	bprelated[4] = get_user_stats2
	
	@return - exp for given stats
*/
	
native aes_get_exp_for_stats(stats[8],stats2[4])
