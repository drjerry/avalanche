
.PHONY: all
all: matrix_test

clean:
	$(RM) *.o
	$(RM) matrix_test

SOURCES = matrix_test.c avalanche.c
HEADERS = avalanche.h

matrix_test: $(SOURCES) $(HEADERS)
	$(CC) $(CFLAGS) -o $@ $(SOURCES)
