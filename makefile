all:lex.yy.o y.tab.o
	cc -o output lex.yy.o y.tab.o -lfl
	./output <test.txt
lex.yy.o y.tab.o:lex.yy.c y.tab.c
	cc -c lex.yy.c y.tab.c
lex.yy.c:F74981183.l
	flex F74981183.l
y.tab.c y.tab.h:F74981183.y
	yacc -d F74981183.y
clean:
	rm lex.yy.o lex.yy.c output.exe obj.tm
	rm y.tab.c y.tab.h y.tab.o output.exe.stackdump
obj:
	./TM.exe obj.tm
