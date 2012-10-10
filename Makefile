all: run_server

luv.so: luv/luv.so
	cp luv/luv.so ./

lhttp_parser.so: lhttp_parser/lhttp_parser.so
	cp lhttp_parser/lhttp_parser.so ./

luv/luv.so: luv/Makefile
	$(MAKE) -C luv

lhttp_parser/Makefile:
	git submodule update --init --recursive lhttp_parser

luv/Makefile:
	git submodule update --init --recursive luv

lhttp_parser/lhttp_parser.so: lhttp_parser/Makefile
	$(MAKE) -C lhttp_parser

run_server: luv.so lhttp_parser.so
	luajit test-web.lua
