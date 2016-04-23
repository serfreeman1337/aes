//
//	Advanced Experience System
//	by serfreeman1337	http://gf.hldm.org/
//

enum _:
{
	AES_RT_NO,
	AES_RT_YES,
	AES_RT_LEVEL_DOWN,
	AES_RT_LEVEL_UP
}

//
// Returns player experience
//	@player - player id
//	
//	@return - player experience or -1.0 if player not tracked yet
//
native Float:aes_get_player_exp(player)

//
// Sets player experience
//	@player - player id
//	@exp - experience value
//	@no_forward - dont trigger forward functions on level up or level down
//	@force - force even if track paused
//
//	@return
//		AES_RT_NO - on track pause or player not tracked yet
//		AES_RT_YES - on success
//		AES_RT_LEVLE_DOWN - on level down
//		AES_RT_LEVEL_UP - on level up
//
native aes_set_player_exp(player,Float:exp,bool:no_forward = false,bool:force = false)

//
// Returns player required experience to next level
//	@player - player id
//
//	@return - required experience value
//
native Float:aes_get_player_reqexp(player)

//
// Returns player bonus points
//	@player - player id
//
//	@return - player bonus points or -1 if player
//
native aes_get_player_bonus(player)

//
// Sets player bonus points
//	@player - player id
//	@bonus - bonus value
//	@force - force even if track paused
//
//	@return
//		AES_RT_NO - on track pause or player not tracked yet
//		AES_RT_YES - on success
//
native aes_set_player_bonus(player,bonus,bool:force = false)

//
// Returns current player level
//	@player - player id
//
//	@return - current player level or -1 if player not tracked yet
//
native aes_get_player_level(player)

//
// Sets player level
//	@player - player id
//	@level - level
//	@force - force even if track paused
//
//	@return
//		AES_RT_NO - on track pause or player not tracked yet
//		AES_RT_YES - on success
//
native aes_set_player_level(player,level,bool:force = false)

//
// Returns maximum level
//
native aes_get_max_level()

//
// Returns level name for level num.
//	
//	@lvlnum - player id
//	@level[] - level name output
//	@len - len
//	@idLang - language id
//	
//	@return - len
//
native aes_get_level_name(level,level_name[],len,idLang = LANG_SERVER)

//
// Returns level for experience
//	@exp - experience value
//	
//	@return - level num or -1 of fail
//
native aes_get_exp_level(Float:exp)

//
// Returns required experience to pass level
//	@lvl - level
//
//	@return - required experience value or -1.0 on fail
//
native Float:aes_get_level_reqexp(level)

//
// Called on player level up.
//
forward aes_player_levelup(id,new_level,old_level)

//
// Called on player level down.
//
forward aes_player_leveldown(id,new_level,old_level)

#define aes_add_player_exp_f(%0,%1) aes_set_player_exp(%0,aes_get_player_exp(%0) + %1)
#define aes_add_player_bonus_f(%0,%1) aes_set_player_bonus(%0,aes_get_player_bonus(%0) + %1)
////
//// AES 0.4 BACKWARD SUPPORT
////

enum _: {
	AES_ST_EXP,
	AES_ST_LEVEL,
	AES_ST_BONUSES,
	AES_ST_NEXTEXP,

	AES_ST_END
}

#pragma deprecated Use aes_add_player_exp_f() instead.
native aes_add_player_exp(id,exp,override = 0)

#pragma deprecated Use aes_add_player_bonus_f() instead.	
native aes_add_player_bonus(id,bonus)

#pragma deprecated Use aes_get_player_*() instead.
native aes_get_player_stats(id,data[4])

#pragma deprecated Use aes_set_player_*() instead.
native aes_set_player_stats(id,stats[3])

#pragma deprecated Use aes_get_exp_level() instead.
native aes_get_level_for_exp(exp)

#pragma deprecated Use aes_get_level_reqexp() instead.
native aes_get_exp_to_next_level(lvl)

native Array:aes_get_stats(Array:trackIds)
forward aes_on_anew_command(id)
native aes_get_exp_for_stats(stats[8],stats2[4])
