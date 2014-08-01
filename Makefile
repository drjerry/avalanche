CC=clang
CFLAGS = -I$(abspath src)

.PHONY:all
# list all TARGETS here:
all: bin bin/fnv_32 bin/fnv_mw

SOURCES = src/avalanche.c
HEADERS = src/avalanche.h

bin:
	mkdir -p bin

bin/fnv_32: examples/fnv_1a.c $(SOURCES) $(HEADERS)
	$(CC) $(CFLAGS) -o $@ $< $(SOURCES)

bin/fnv_mw: examples/fnv_1a.c $(SOURCES) $(HEADERS)
	$(CC) $(CFLAGS) -DMULTI_WORD -o $@ $< $(SOURCES)

clean:
	cd src && $(MAKE) clean
	$(RM) bin/*
