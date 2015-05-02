// Copyright 2015 Nashwan Azhari.
// Licensed under the GPLv2. See LICENSE for details.
//
// Please build this with the command:
// $ gcc -Wall -shared -o utils.so utils.c
// in the directory of the project.

#include<unistd.h>
#include<lauxlib.h>

// l_sleep blocks for the given amount of microseconds.
static int l_sleep(lua_State *L) {
	double d = luaL_checknumber(L, 1);
	usleep(d);
	return 0;
}

// register the functions of this module:
static const struct luaL_Reg utils[2] = {
	{"sleep", l_sleep},
	{NULL, NULL},
};

// main library entry point:
int luaopen_utils(lua_State *L) {
	lua_newtable(L);
	luaL_setfuncs(L, utils, 0);
	return 1;
}

