LDLIBS = ../libavalanche.a

tests := $(patsubst %.c, %, $(wildcard *.c))

all: $(tests)

%: %.c
	$(CC) $(CFLAGS) $(LDLIBS) -o $@ $<

clean:
	$(RM) $(tests)
