CC=clang
CFLAGS = -I$(abspath src)
export CFLAGS

AR=libtool
ARFLAGS=-static

libavalanche.a: src/avalanche.o
	$(AR) $(ARFLAGS) -o $@ $<

tests: libavalanche.a
	cd test && $(MAKE)

clean:
	$(RM) *.a
	cd src && $(MAKE) clean
	cd test && $(MAKE) clean
