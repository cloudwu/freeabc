pipe.dll : pipe.c
	gcc -g -Wall --shared -o $@ $^ -I/usr/local/include -L/usr/local/bin -llua53

clean :
	rm pipe.dll
