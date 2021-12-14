LUA_CLIB_PATH ?= luaclib
CSERVICE_PATH ?= cservice
SKYNET_DEFINES :=-DNOUSE_JEMALLOC -DFD_SETSIZE=4096

CC = gcc -std=gnu99
PLAT ?= mingw

SKYNET_BUILD_PATH ?= .

# lua
WS_STATICLIB := C:/MinGW/lib/libws2_32.a
LUA_STATICLIB := 3rd/lua/liblua.a
LUA_LIB ?= $(LUA_STATICLIB)
LUA_INC ?= 3rd/lua
WS_LIB ?= $(WS_STATICLIB)

PLATFORM_INC ?= platform

# TLS_MODULE=ltls
TLS_LIB=
TLS_INC=

CFLAGS := -g -O2 -Wall -I$(PLATFORM_INC) -I$(LUA_INC) $(MYCFLAGS)  
# CFLAGS += -DUSE_PTHREAD_LOCK
#CFLAGS_win32=//I "$(LUAINC)" $(DEF) //O2 //Ot //MD //W3 //nologo

# link
LDFLAGS := -llua54 -lplatform -lpthread -lws2_32 -L$(SKYNET_BUILD_PATH)
SHARED := --shared
EXPORT := -Wl,-E
SHAREDLDFLAGS := -llua54 -lskynet -lplatform -lws2_32 -L$(SKYNET_BUILD_PATH)

# skynet

CSERVICE = snlua logger gate harbor
LUA_CLIB = skynet \
  client \
  bson md5 sproto lpeg luaxxtea luaprotobuf luasocket $(TLS_MODULE)

LUA_CLIB_SKYNET = \
  lua-skynet.c lua-seri.c \
  lua-socket.c \
  lua-mongo.c \
  lua-netpack.c \
  lua-memory.c \
  lua-multicast.c \
  lua-cluster.c \
  lua-crypt.c lsha1.c \
  lua-sharedata.c \
  lua-stm.c \
  lua-debugchannel.c \
  lua-datasheet.c \
  lua-sharetable.c \
  \

SKYNET_EXE_SRC = skynet_main.c

SKYNET_SRC = skynet_handle.c skynet_module.c skynet_mq.c \
  skynet_server.c skynet_start.c skynet_timer.c skynet_error.c \
  skynet_harbor.c skynet_env.c skynet_monitor.c skynet_socket.c socket_server.c \
  malloc_hook.c skynet_daemon.c skynet_log.c

all : \
	$(LUA_STATICLIB) \
   	$(SKYNET_BUILD_PATH)/platform.dll \
  	$(SKYNET_BUILD_PATH)/skynet.dll \
  	$(SKYNET_BUILD_PATH)/skynet.exe \
	$(foreach v, $(CSERVICE), $(CSERVICE_PATH)/$(v).so) \
	$(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)

$(SKYNET_BUILD_PATH)/platform.dll : platform/platform.c platform/epoll.c platform/socket_poll.c platform/socket_extend.c
	$(CC) $(CFLAGS) $(SHARED) $^ -lws2_32 -lwsock32 -o $@ -DDONOT_USE_IO_EXTEND -DFD_SETSIZE=1024

$(SKYNET_BUILD_PATH)/skynet.dll : $(foreach v, $(SKYNET_SRC), skynet-src/$(v)) | $(LUA_LIB) $(SKYNET_BUILD_PATH)/platform.dll
	$(CC) -includeplatform.h $(CFLAGS) $(SHARED) -o $@ $^ -Iskynet-src $(LDFLAGS) $(SKYNET_LIBS) $(SKYNET_DEFINES)

$(SKYNET_BUILD_PATH)/skynet.exe : $(foreach v, $(SKYNET_EXE_SRC), skynet-src/$(v))  | $(SKYNET_BUILD_PATH)/skynet.dll
	$(CC) -includeplatform.h $(CFLAGS) -o $@ $^ -Iskynet-src $(EXPORT) $(LDFLAGS) $(SHAREDLDFLAGS) $(SKYNET_DEFINES)	

# lua
$(LUA_STATICLIB) :
	cd 3rd/lua && $(MAKE) CC='$(CC)' $(PLAT)  && cd - && cp -f $(LUA_INC)/lua54.dll $(SKYNET_BUILD_PATH)/lua54.dll

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

define CSERVICE_TEMP
  $$(CSERVICE_PATH)/$(1).so : service-src/service_$(1).c | $$(CSERVICE_PATH)
	$$(CC) -includeplatform.h $$(CFLAGS) $$(SHARED) $$< -o $$@ -Iskynet-src $$(SHAREDLDFLAGS) 
endef

$(foreach v, $(CSERVICE), $(eval $(call CSERVICE_TEMP,$(v))))

$(LUA_CLIB_PATH)/skynet.so : $(addprefix lualib-src/,$(LUA_CLIB_SKYNET)) | $(LUA_CLIB_PATH)
	$(CC) -includeplatform.h $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src -Iservice-src -Ilualib-src  $(SHAREDLDFLAGS)

$(LUA_CLIB_PATH)/bson.so : lualib-src/lua-bson.c | $(LUA_CLIB_PATH)
	$(CC) -includeplatform.h $(CFLAGS) $(SHARED) -Iskynet-src $^ -o $@ -I$(PLATFORM_INC)  $(SHAREDLDFLAGS)

$(LUA_CLIB_PATH)/md5.so : 3rd/lua-md5/md5.c 3rd/lua-md5/md5lib.c 3rd/lua-md5/compat-5.2.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-md5 $^ -o $@  $(SHAREDLDFLAGS)

$(LUA_CLIB_PATH)/client.so : lualib-src/lua-clientsocket.c lualib-src/lua-crypt.c lualib-src/lsha1.c | $(LUA_CLIB_PATH)
	$(CC) -includeplatform.h $(CFLAGS) $(SHARED) $^ -o $@ -lpthread  $(SHAREDLDFLAGS)

$(LUA_CLIB_PATH)/sproto.so : lualib-src/sproto/sproto.c lualib-src/sproto/lsproto.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Ilualib-src/sproto $^ -o $@  $(SHAREDLDFLAGS) 

$(LUA_CLIB_PATH)/ltls.so : lualib-src/ltls.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet-src -L$(TLS_LIB) -I$(TLS_INC) $^ -o $@ -lssl $(SHAREDLDFLAGS) 

$(LUA_CLIB_PATH)/lpeg.so : 3rd/lpeg/lpcap.c 3rd/lpeg/lpcode.c 3rd/lpeg/lpprint.c 3rd/lpeg/lptree.c 3rd/lpeg/lpvm.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lpeg  $^ -o $@  $(SHAREDLDFLAGS) 

#luasocket
$(LUA_CLIB_PATH)/luasocket.so : \
	3rd/lua-socket/luasocket.c	\
	3rd/lua-socket/auxiliar.c	\
	3rd/lua-socket/timeout.c	\
    3rd/lua-socket/buffer.c	\
    3rd/lua-socket/except.c	\
	3rd/lua-socket/wsocket.c	\
	 3rd/lua-socket/io.c	\
    3rd/lua-socket/inet.c	\
    #3rd/lua-socket/luasocket_scripts.c	\
	#3rd/lua-socket/mime.c	\
	3rd/lua-socket/select.c	\
    3rd/lua-socket/options.c	\
    3rd/lua-socket/tcp.c	\
    3rd/lua-socket/udp.c 	\
	#3rd/lua-socket/serial.c	\
	| $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $(WS_LIB) -I3rd/luasocket -DLUASOCKET_API='__attribute__((visibility("default")))' $^ -o  $@  $(SHAREDLDFLAGS) 

$(LUA_CLIB_PATH)/luaxxtea.so : \
	3rd/lua-xxtea/src/lua_xxtea.c	\
    3rd/lua-xxtea/src/xxtea.c	\
	| $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/luaxxtea $^ -o $@  $(SHAREDLDFLAGS) 

$(LUA_CLIB_PATH)/luaprotobuf.so : \
	3rd/lua-protobuf/pb.c	\
	| $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/luaprotobuf $^ -o $@  $(SHAREDLDFLAGS) 

clean :
	rm -f $(SKYNET_BUILD_PATH)/skynet.exe $(SKYNET_BUILD_PATH)/skynet.dll $(SKYNET_BUILD_PATH)/platform.dll $(CSERVICE_PATH)/*.so $(LUA_CLIB_PATH)/*.so

cleanall: clean
	cd 3rd/lua && $(MAKE) clean
	rm -f $(LUA_STATICLIB)

