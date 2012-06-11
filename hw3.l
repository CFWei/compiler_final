%{
#include "y.tab.h"
int lineno=1;
int *token_stack;
int token_stack_sp=0;
void push();
%}

%option noyywrap
%option yylineno
id	[a-zA-Z_][a-zA-Z0-9_]*
integer	[-]?[0-9]+
floating [-]?([0-9]+\.[0-9]+)
whitespace  [ \t\v\f\r]
line \n

%%
{whitespace}    	{ }
{line}				{
						++lineno;
					}
"-"					{ 
					
						return '-';
					}
{integer}			{ 	
						yylval.sval = strdup(yytext);
						return integer; 
					}

{floating}			{

						yylval.sval = strdup(yytext);
						return floating;
					}

'[a-zA-Z0-9]'		{
						yylval.sval = strdup(yytext);
						return char_c;		
					}				
(\/\/).*	|
(\/\*).*(\*\/)		{};
do					{ return DO;}
if					{ return IF; }
else				{ return ELSE; }
float 				{ return FLOAT;}
int					{ 
					  yylval.sval = strdup(yytext);
					  return INT; 
					}
void				{ 
					  yylval.sval = strdup(yytext);
					  return VOID; 
					}
char				{ return CHAR;}
while				{ return WHILE; }
return				{ return RETURN; }
for 				{ return FOR;}	
"=="				{ return EQUAL;}	
">="				{ return BIG_EQU;}
"<="				{ return SMALL_EQU;	}				
"!="				{ return NOT_EQU;}

					
"="					{ return '='; }
"+"					{ return '+';}
"*"					{ return '*'; }
"/"					{ return '/'; }
"("					{ return '('; }
")"					{ return ')';}
"{"					{ return '{';}
"}"					{ return '}';}
"<"					{ return '<'; }
">"					{ return '>';}
";"					{ 
						yylval.dval =1;
						return ';'; 
					}
","					{ return ',';}
"["					{ return '[';}
"]"					{ return ']';}
{id}				{ 
						yylval.sval = strdup(yytext);
						return ID; 
					}

(#)+.* 				{};
%%

