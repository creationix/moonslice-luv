all: run_server

luv.so: luv/luv.so
	cp luv/luv.so ./

lhttp_parser.so: lhttp_parser/lhttp_parser.so
	cp lhttp_parser/lhttp_parser.so ./

luv/luv.so:
	$(MAKE) -C luv

lhttp_parser/lhttp_parser.so:
	$(MAKE) -C lhttp_parser

run_server: luv.so lhttp_parser.so
	luajit test-web.lua
