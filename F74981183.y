%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<signal.h> 
#include<ctype.h>

//定義symbol table的結構
typedef struct symboltable
{
	char *name;//儲存symbol的名稱
	int type; // 1:int 2:int array
	int arr_size;//若為array 則儲存array的size
	int addr;//儲存symbol的array address
}SymbolTable;

//定義傳遞的elements的結構
typedef struct element
{
	char *name;//名稱
	int type;//型態

}Elements;
//定義 instruction表的結構
typedef struct instruction
{
	char *operator;//operator
	Elements arg1;//參數1
	Elements arg2;//參數2
}Instruction;

//定義quardruple的結構
typedef struct quadruples  
{
 	int operator;//operator
	//1:+ 2:- 3:* 4:/ 5:< 6:> 7:= 8:input 9:output 10:tempsave
	//11:>= 12:<= 13:== 14:!= 15:[]= 16:=[] 17:goto
	Elements arg1;//參數1
	Elements arg2;//參數2
	Elements result;//結果
	int branch;//實際的branch數
}Quadruples;

//定義一個array的結構
typedef struct array
{
	int array_size;
	char *name;
}Array;
//以下為變數的宣告
SymbolTable s_table[500];
Quadruples  q_table[500];
Instruction i_table[500];
int q_table_sp=0;
int s_table_sp=0;
int i_table_sp=0;
int value_address=5;
int scope=0;
int temp_register_num=50;
int tm_code_linenum=0;
char deliever[3];
int register_table[7];
int branch_count[20][2];
int branch_control=-1;
int branch_instruction[20];
FILE *f;

//以下為函式的宣告
void q_table_insert(int op,char *arg1,char *arg2,char *result,int arg1_type,int arg2_type,int result_type,int type);
void print_q_table();
Array split_array_word(char *);
int get_register();
int check_array(char *);
int search_s_table(char *s);
char *register_add();
%}
 /*************/
 /* token set */
 /*************/
%token ID integer floating trivial HEADFILE char_c BIG_EQU FOR DO
%token IF ELSE INT VOID WHILE RETURN FLOAT CHAR EQUAL NOT_EQU SMALL_EQU
%token '=' '+' '-' '*' '/' '<' '>' ';' '(' ')' '{' '}' '[' ']'  

//定義節點的型態
%union{
		int dval;
		char *sval;
		struct element *element;
		}
%type<dval> addop mulop type_specifier INT VOID FLOAT CHAR relop
%type<sval> ID factor term number additive_expression simple_expression expression args arg_list identifier 

//令 program為start symbol
%start program 
%%
 /***********/
 /* grammar */
 /***********/
program:	declaration_list{};							
declaration_list:	declaration_list declaration{}						
					|declaration{};	
declaration:	var_declaration	{}
			   |fun_declaration	{};
var_declaration:type_specifier identifier ';'	{		
														//變數宣告
														int i,repeat=0;
														//檢查symbol是否已經宣告(比對symbol table)
														for(i=0;i<s_table_sp;i++)
															{
																if(strcmp($2,s_table[i].name)==0)
																	{
																		repeat=1;
																		break;
																	}
															}
														//若沒有 重複宣告 且 identifier為array 則執行以下步驟
														if(repeat==0&&check_array($2))
															{	
																//將identifier分割為名稱及array_num兩部分
																//並存入a
																Array a=split_array_word($2);
																//將identifier存入symbol table
																s_table[s_table_sp].name=a.name;
																s_table[s_table_sp].type=2;//type=2代表其為 int array

																s_table[s_table_sp].addr=value_address;//存入起始的address number
																s_table[s_table_sp].arr_size=a.array_size;//存放array_size
																
																//變動value_address					
																value_address+=a.array_size;
																//s_table_sp=s_table_sp+1
																s_table_sp++;
															
															}
														else
															{	
																//將identifier存入symbol table
																s_table[s_table_sp].name=$2;
																s_table[s_table_sp].type=$1;
																s_table[s_table_sp].addr=value_address;
																//變動value_address	
																value_address++;
																//s_table_sp=s_table_sp+1
																s_table_sp++;
															}
													}
													
					|type_specifier identifier '=' simple_expression ';' {	
																			int i,repeat=0;
																			//檢查symbol是否已經宣告(比對symbol table)
																			for(i=0;i<s_table_sp;i++)
																				{
																					if(strcmp($2,s_table[i].name)==0)
																						{
																							repeat=1;
																							break;
																						}
																				}
																			if(repeat==0)
																				{	
																					//將identifier存入symbol table
																					s_table[s_table_sp].name=$2;
																					s_table[s_table_sp].type=$1;
																					s_table[s_table_sp].addr=value_address;
																					//變動value_address	
																					value_address++;
																					//s_table_sp=s_table_sp+1
																					s_table_sp++;
																				}
																			};
					

type_specifier:	INT		{$$=1;}	
				|VOID	{$$=2;}
				|FLOAT	{$$=3;}
				|CHAR	{$$=4;};	
						
identifier :ID '[' number']'
				{	
					//new一個char的指標存放字串
					char *temp=(char*)malloc(50*sizeof(char));
					//將array的名稱存入temp
					strcpy(temp,$1);
					strcat(temp,"[");
					strcat(temp,$3);
					strcat(temp,"]");
					//令此節點指向temp並向上傳遞
					$$=temp;
					
			}
			|ID {$$=$1;};

fun_declaration:type_specifier identifier '(' type_specifier ')' compound_stmt{}														
				|type_specifier identifier '(' ')' compound_stmt{};															

compound_stmt:	'{' local_declarations statement_list  '}'	{};
local_declarations:	local_declarations var_declaration	{}			
					|empty {};
				
statement_list:	statement_list statement	{}
				|empty 						{};	

statement:	expression_stmt {}	
		|	compound_stmt 	{}					
		|	selection_stmt	{}
		|	iteration_stmt	{}
		|	return_stmt 	{};	
							
expression_stmt:	expression ';'	{}
			|		';' 			{};
selection_stmt:	IF '(' expression ')' statement					{	
																	//new一個char的指標t 存放字串
																	char *t=(char*)malloc(50*sizeof(char));
																	//將branch_count[branch_control][1]內的值轉換成字串
																	sprintf(t,"%d",branch_count[branch_control][1]);
																	//將t內的字串複製到q_table[branch_instruction[branch_control]].result.name
																	strcpy(q_table[branch_instruction[branch_control]].result.name,t);
																	
																	//跳回去更改要跳的指令數
																	q_table[branch_instruction[branch_control]].branch=branch_count[branch_control][0];
																	
																	//將branch_count的值歸零
																	branch_count[branch_control][0]=0;
																	branch_count[branch_control][1]=0;
																	//branch_control=branch_control-1
																	branch_control--;
																	
																}
			|	IF '(' expression ')' statement ELSE statement	{};				
iteration_stmt:	WHILE '(' expression ')' statement	{
														//new一個char的陣列
														char temp[50];
														//將branch_count內的值+2後轉成字串存入temp
														sprintf(temp,"%d",branch_count[branch_control][1]+2);
														
														//insert指令到q_table(跳回判斷式的指令)
														q_table_insert(17,NULL,NULL,temp,0,0,0,1);
														q_table[q_table_sp-1].branch=branch_count[branch_control][0]+4;
														
														//跳回去更改判斷式要跳的指令數
														char *t=(char*)malloc(50*sizeof(char));
														sprintf(t,"%d",branch_count[branch_control][1]);
														strcpy(q_table[branch_instruction[branch_control]].result.name,t);
														q_table[branch_instruction[branch_control]].branch=branch_count[branch_control][0];
														
														//將branch_count的值歸零
														branch_count[branch_control][0]=0;
														branch_count[branch_control][1]=0;
														//branch_control=branch_control-1
														branch_control--;	
													};
			|DO compound_stmt  WHILE '(' expression ')'{}
			|FOR '('expression ';' simple_expression ';' identifier addop addop ')' statement
													{	
														//new一個char的指標
														char *arg1;
														//取得可用的register
														arg1=register_add();
														
														//新增指令進q_table(令identifier+=1)
														q_table_insert(10,"1",NULL,arg1,0,0,0,1);
														q_table_insert(1,$7,arg1,$7,0,0,0,1);
														
														//新增一個temp的陣列
														char temp[50];
														//將branch_count內的值+2後轉成字串存入temp
														sprintf(temp,"%d",branch_count[branch_control][1]+2);
														//跳回去判斷式
														q_table_insert(17,NULL,NULL,temp,0,0,0,1);
														q_table[q_table_sp-1].branch=branch_count[branch_control][0]+4;
														//new一個char的pointer 並malloc空間
														char *t=(char*)malloc(50*sizeof(char));
														//將branch_count轉換成字串
														sprintf(t,"%d",branch_count[branch_control][1]);
														//跳回去更改要跳的指令數
														strcpy(q_table[branch_instruction[branch_control]].result.name,t);
														q_table[branch_instruction[branch_control]].branch=branch_count[branch_control][0];
														
														//將branch_count的值歸零
														branch_count[branch_control][0]=0;
														branch_count[branch_control][1]=0;
														//branch_control=branch_control-1
														branch_control--;		
													}

return_stmt:	RETURN ';' 				{}
		|		RETURN expression ';'	{};
expression:	identifier '=' expression	{	
											//變數宣告
											int i,check=1;
											char *identifier=(char*)malloc(50*sizeof(char));
											int identifier_type,operation=7;
											
											//判斷 $1 和 $3 是否為陣列 
											int check_array_1=check_array($1);
											int check_array_2=check_array($3);
											//判斷expression是否為digit
											for(i=0;i<strlen($3);i++)
												{
													if(isdigit($3[i])==0)
														check=0;
												
												}

											//若$1是陣列 則執行以下動作
											
											if(check_array_1==1)
												{	
													//分割$1為名稱和數字兩部分
													Array a=split_array_word($1);
													//將identifier改為a.name內的字串
													strcpy(identifier,a.name);
													//更改其array的num
													identifier_type=a.array_size;
													//令operation為15
													operation=15;
												}
											//若$1不是陣列 則執行以下動作	
											else
												{
													//將$1的值複製進identifier
													strcpy(identifier,$1);
													//令其array num為0
													identifier_type=0;
												}
											//若$3為數字 則執行以下動作
											if(check==1)
												{	
													//取得一個可用的REGISTER
													char *temp=register_add();
													//將數字存入register 再令變數等於register
													q_table_insert(10,$3,NULL,temp,0,0,0,1);
													q_table_insert(operation,temp,NULL,identifier,0,0,identifier_type,1);
												}
											//若$3不為數字 則執行以下動作
											else
												{	
													//若$3為陣列 且$1不為陣列
													if(check_array_2==1&&check_array_1==0)
														{	
															//將$3分割為名稱和數字兩部分
															Array b=split_array_word($3);
															//加入指令
															q_table_insert(16,b.name,NULL,identifier,b.array_size,0,identifier_type,1);
														}
													//若$3為陣列 且$1為陣列	
													else if(check_array_2==1&&check_array_1==1)
														{	
															//將$3分割為名稱和數字兩部分
															Array b=split_array_word($3);
															//取得可用的register
															char *temp=register_add();
															//先令變數的值等於$3 再令$1的值等於變數
															q_table_insert(16,b.name,NULL,temp,b.array_size,0,0,1);
															q_table_insert(operation,temp,NULL,identifier,0,0,identifier_type,1);
															
														}
													else
														{	
															//直接令$1的值等於$3
															q_table_insert(operation,$3,NULL,identifier,0,0,identifier_type,1);
														}
												
												}
											

										}
										

													
		|simple_expression	{$$=$1;} ;
		
		
simple_expression:	additive_expression relop additive_expression	{
																		
																		int check1=1,check2=1,i;
																		//判斷$1是否為數字
																		for(i=0;i<strlen($1);i++)
																			{	
																				if(isdigit($1[i])==0)
																					check1=0;
															
																			}
																		//判斷$3是否為數字
																		for(i=0;i<strlen($3);i++)
																			{	
																				if(isdigit($3[i])==0)
																					check2=0;
															
																			}
																		
																		char *arg1,*arg2;
																		int arg1_type=0,arg2_type=0;	
																		//若$1不為數字且不為array
																		if(check1==0&&check_array($1)==0)
																			{
																				arg1=$1;
																			}
																		//若$1為array
																		else if(check_array($1)==1)
																			{
																				arg1=(char*)malloc(50*sizeof(char));
																				//將$1分割為名稱和數字兩部分
																				Array a=split_array_word($1);
																				//將a.name複製到arg1
																				strcpy(arg1,a.name);
																				arg1_type=a.array_size;
																			}
																		
																		else
																			{	
																				//取得可用的register
																				arg1=register_add();
																				//新增指令
																				q_table_insert(10,$1,NULL,arg1,0,0,0,1);
																			}
																		//若$3不為數字且不為array
																		if(check2==0&&check_array($3)==0)	
																			{	
																				
																				arg2=$3;
																				
																			}
																		//若$3為array
																		else if(check_array($3)==1)
																			{
																				arg2=(char*)malloc(50*sizeof(char));
																				//將$3分割為名稱和數字兩部分
																				Array a=split_array_word($3);
																				//將a.name複製到arg2
																				strcpy(arg2,a.name);
																				arg2_type=a.array_size;
																			
																			}	
																		else
																			{	
																				//取得可用的register
																				arg2=register_add();
																				//新增指令
																				q_table_insert(10,$3,NULL,arg2,0,0,0,1);
																			}
																		//新增JUMP類指令到Q_TABLE
																		q_table_insert($2,arg1,arg2,NULL,arg1_type,arg2_type,0,2);
																		//開啟branch_control
																		branch_control++;
																		branch_instruction[branch_control]=(q_table_sp-1);																		
																		
																	}
																	
				|	additive_expression		{$$=$1;};		
																	
relop:	'<'			{$$=5;}
	|	'>'			{$$=6;}
	|	SMALL_EQU	{$$=12;}
	|	BIG_EQU		{$$=11;}
	|	EQUAL		{$$=13;}
	|	NOT_EQU		{$$=14;};			
			
additive_expression:	additive_expression addop term	{	
															
															int check1=1,check2=1,i;
															char *arg1,*arg2;
															//判斷$1是否為數字
															for(i=0;i<strlen($1);i++)
																	{	
																		if(isdigit($1[i])==0)
																			check1=0;
																	}
															//判斷$3是否為數字
															for(i=0;i<strlen($3);i++)
																	{	
																		if(isdigit($3[i])==0)
																			check2=0;
																	}
															//若$1為數字則執行以下動作	
															if(check1==1)
																{	
																	//取得一個register
																	arg1=register_add();
																	//$1轉存成register
																	q_table_insert(10,$1,NULL,arg1,0,0,0,1);
																
																}
															//若$1是array
															else if(check_array($1)==1)
																{	
																	//將$1分割成名稱和數字
																	Array a=split_array_word($1);
																	//取得一個register
																	arg1=register_add();
																	//將數值轉存到register
																	q_table_insert(16,a.name,NULL,arg1,a.array_size,0,0,1);

																}
															//若是其他狀況則執行將$1的值存到arg1
															else
																{
																	arg1=$1;
																}
															//若$3是數字
															if(check2==1)
																{	
																	//取得一個register
																	arg2=register_add();
																	//$3轉存成register
																	q_table_insert(10,$3,NULL,arg2,0,0,0,1);
																
																}
															else if(check_array($3)==1)
																{
																	//將$3分割成名稱和數字
																	Array a=split_array_word($3);
																	//取得一個register
																	arg2=register_add();
																	//將數值轉存到register
																	q_table_insert(16,a.name,NULL,arg2,a.array_size,0,0,1);
																}
															//若是其他狀況則執行將$3的值存到arg2	
															else
																{
																	arg2=$3;
																}
															//加入指令
															q_table_insert($2,arg1,arg2,NULL,0,0,0,1);
														
															//將值向上傳遞
															$$=(char*)malloc(strlen(deliever)*sizeof(char));
															strcpy($$,deliever);
															
														}
														
				      |term	{$$=$1;};			
														
addop:	'+'	{$$=1;}	
	|	'-'	{$$=2;};	
			

term:	term mulop factor	{
								
								int check1=1,check2=1,i;
								char *arg1,*arg2;
								//判斷$1是否為數字
								for(i=0;i<strlen($1);i++)
									{	
										if(isdigit($1[i])==0)
											check1=0;
									}
								//判斷$3是否為數字	
								for(i=0;i<strlen($3);i++)
									{	
										if(isdigit($3[i])==0)
											check2=0;
									}
								//若$1為數字則執行以下動作	
								if(check1==1)
									{
										arg1=register_add();
										q_table_insert(10,$1,NULL,arg1,0,0,0,1);
									
									}
								//若$1為array則執行以下動作
								else if(check_array($1)==1)
									{	
										//將$1分割成名稱和數字
										Array a=split_array_word($1);
										//取得一個register
										arg1=register_add();
										//將數值轉存到register
										q_table_insert(16,a.name,NULL,arg1,a.array_size,0,0,1);

									}
								//若是其他狀況則執行將$1的值存到arg1
								else
									{
										arg1=$1;
									}
									
									
								//若$3為數字則執行以下動作
								if(check2==1)
									{	
										
										arg2=register_add();
										q_table_insert(10,$3,NULL,arg2,0,0,0,1);
									
									}
								//若$3為array則執行以下動作
								else if(check_array($3)==1)
									{	
										//將$3分割成名稱和數字
										Array a=split_array_word($3);
										//取得一個register
										arg2=register_add();
										//將數值轉存到register
										q_table_insert(16,a.name,NULL,arg2,a.array_size,0,0,1);
									}
								//若是其他狀況則執行將$3的值存到arg2	
								else
									{
										arg2=$3;
									}
								//加入指令	
								q_table_insert($2,arg1,arg2,NULL,0,0,0,1);
								//將值向上傳遞
								$$=(char*)malloc(strlen(deliever)*sizeof(char));
								strcpy($$,deliever);


							}
		|factor				{$$=$1;};

mulop:	'*'	{$$=3;}
	|	'/'	{$$=4;};
			
factor:	'(' expression ')'	{$$=$2;}
		|identifier			{$$=$1;}
		|number				{$$=$1;}
		|char_seq			{};
		|call	 			{};
call:identifier '(' args ')' 
		{
				//若identifier為input 則執行以下動作
				if(strcmp($1,"input")==0)
					{
						//若args為array
						if(check_array($3)==1)
							{	
								char *temp;
								//取得register
								temp=register_add();
								//將input的值存到register
								q_table_insert(8,NULL,NULL,temp,0,0,0,1);
								//將args分割成名稱和數字兩部分
								Array a=split_array_word($3);
								//將register的值存到args裡
								q_table_insert(15,temp,NULL,a.name,0,0,a.array_size,1);
								
							}
						//若為其他狀況
						else
							q_table_insert(8,NULL,NULL,$3,0,0,0,1);
							//直接將值給args
					}
					
				//若identifier為output 則執行以下動作
				if(strcmp($1,"output")==0)
					{	
						//若args為array
						if(check_array($3)==1)
							{
								char *temp;
								//將值轉存到register
								Array a=split_array_word($3);
								temp=register_add();
								q_table_insert(16,a.name,NULL,temp,a.array_size,0,0,1);
								//輸出register的值
								q_table_insert(9,NULL,NULL,temp,0,0,0,1);
								
							}
						//若為其他狀況
						else
							q_table_insert(9,NULL,NULL,$3,0,0,0,1);
							//直接輸出args
					
					
					}
		};
args:arg_list		{$$ = $1;}
	|	/*empty*/	{};
arg_list:	arg_list ',' expression	{}
		|	expression				{$$=$1;}
char_seq: char_c	{};
number: integer		{}	
		|floating	{};

empty:		{};
			


			
%%
//切割array成為名稱和數字兩個部分的function
Array split_array_word(char *word)
	{	
		//宣告一個Array type的return_value
		Array return_value;
		char *temp,*value[2],*value_1;
		//以[分割字串成兩個部分
		temp=strtok(word,"[");
		int i=0;
		//存成陣列
		while (temp != NULL){
				value[i]=(char*)malloc(strlen(temp)*sizeof(char));
				strcpy(value[i],temp);
				i++;
                temp = strtok(NULL,"[");
        }
		
		//將name存入return_value
		return_value.name=(char*)malloc(strlen(value[0])*sizeof(char));
		strcpy(return_value.name,value[0]);
		
		//以]分割剩下的字串
		temp=strtok(value[1],"]");
		while (temp != NULL) 
			{
				value_1=(char*)malloc(strlen(temp)*sizeof(char));
				strcpy(value_1,temp);
				temp = strtok(NULL, " ");
			}
		//將數字部分存入return_value.array_size
		return_value.array_size=atoi(value_1);
		//回傳值
		return return_value;
	}
	
	
//回傳可用的register的函式
char *register_add()
	{	
		char *return_value=(char*)malloc(10*sizeof(char));
		//將$先存入return_value 
		strcpy(return_value,"$");
		char temp[3];
		//將temp_register_num轉成字串
		sprintf(temp,"%d",temp_register_num);
		//接續到return_value後面
		strcat(return_value,temp);
		temp_register_num++;
		
		//註冊到symbol table裡面
		s_table[s_table_sp].name=(char*)malloc(strlen(return_value)*sizeof(char));
		strcpy(s_table[s_table_sp].name,return_value);
		s_table[s_table_sp].type=1;		
		s_table[s_table_sp].addr=value_address;			
		value_address++;
		s_table_sp++;
		
		//回傳
		return return_value;
	}
	
//增加指令到quadruple裡面
void q_table_insert(int op,char *arg1,char *arg2,char *result,int arg1_type,int arg2_type,int result_type,int type)
	{		
			//寫入operator
			q_table[q_table_sp].operator=op;
			
			//malloc空間
			q_table[q_table_sp].arg1.name=(char*)malloc(50*sizeof(char));
			q_table[q_table_sp].arg1.type=arg1_type;
			q_table[q_table_sp].arg2.name=(char*)malloc(50*sizeof(char));
			q_table[q_table_sp].arg2.type=arg2_type;
			
			//若arg1不等於null 則指定值
			if(arg1!=NULL)
				strcpy(q_table[q_table_sp].arg1.name,arg1);
			//若arg1等於null 則指定null	
			else
				q_table[q_table_sp].arg1.name==NULL;
				
			//若arg2不等於null 則指定值
			if(arg2!=NULL)
				strcpy(q_table[q_table_sp].arg2.name,arg2);
			//若arg2等於null 則指定null
			else
				q_table[q_table_sp].arg2.name==NULL;
				
			//若type為2則只分配空間
			if(type==2)
				{
					q_table[q_table_sp].result.name=(char*)malloc(50*sizeof(char));
					q_table_sp++;
					
				}
			//若result等於null且type不等於2
			else if(result==NULL&&type!=2)
				{	
					//創造暫存變數 格式:$(num)	
					char reigster_name[50]="$";
					char num[50];
					//轉存成字串並將其存到reigster_name
					sprintf(num,"%d",temp_register_num);
					temp_register_num++;
					strcat(reigster_name,num);
					
					//將值存到result裡面
					q_table[q_table_sp].result.name=(char*)malloc(50*sizeof(char));
					q_table[q_table_sp].result.type=0;
					strcpy(q_table[q_table_sp].result.name,reigster_name);
					q_table_sp++;
					
					//註冊到symblo裡面
					s_table[s_table_sp].name=(char*)malloc(strlen(reigster_name)*sizeof(char));					
					strcpy(s_table[s_table_sp].name,reigster_name);
					s_table[s_table_sp].type=type;			
					s_table[s_table_sp].addr=value_address;
					
					value_address++;
					s_table_sp++;
					//將reigster_name存到deliever裡面
					strcpy(deliever,reigster_name);
				
				}
			//若為其他狀況
			else
				{	
					//直接將q_table裡面的result的值指定為傳入的result
					q_table[q_table_sp].result.name=(char*)malloc(50*sizeof(char));
					strcpy(q_table[q_table_sp].result.name,result);
					q_table[q_table_sp].result.type=result_type;
					
					q_table_sp++;
					
				}
				
			//以下計算要跳的指令數
			int i;	
			//若op為以下 則branch_count[i][0]加四 branch_count[i][1]加一
			if((op==1||op==2||op==3||op==4||op==5||op==6||op==11||op==12||op==13||op==14)&&branch_control>=0)
				{
					for(i=0;i<=branch_control;i++)
						{
							branch_count[i][0]+=4;
							branch_count[i][1]++;
						}
					
				}
			//若op為以下 則branch_count[i][0]加二 branch_count[i][1]加一
			if((op==7||op==10||op==15||op==16||op==9||op==8)&&branch_control>=0)
				{	
			
					for(i=0;i<=branch_control;i++)
						{
							branch_count[i][0]+=2;	
							branch_count[i][1]++;
						}

			
				}
			//若op為以下 則branch_count[i][0]加一 branch_count[i][1]加一
			if((op==17)&&branch_control>=0)
				{
					for(i=0;i<=branch_control;i++)
						{
							branch_count[i][0]++;	
							branch_count[i][1]++;
						}
				
				
				}
			
	
	}
//印出Quadruples的函式
void print_q_table()
	{	
		int i;
		char opcode[10];
		printf("=========================================\n");
		printf("                Quadruples               \n");
		printf("=========================================\n");
		printf("Operator\tArg1\tArg2\tResult\n"); 
		for(i=0;i<q_table_sp;i++)
			{	
				//先依據operator的號碼 將其轉成字串
				strcpy(opcode,"");
				if(q_table[i].operator==1)
					strcat(opcode,"+");
				else if(q_table[i].operator==2)
					strcat(opcode,"-");
				else if(q_table[i].operator==3)
					strcat(opcode,"*");
				else if(q_table[i].operator==4)
					strcat(opcode,"/");
				else if(q_table[i].operator==5)
					strcat(opcode,"<");
				else if(q_table[i].operator==6)
					strcat(opcode,">");
				else if(q_table[i].operator==7)
					strcat(opcode,"=");
				else if(q_table[i].operator==8)
					strcat(opcode,"input");
				else if(q_table[i].operator==9)
					strcat(opcode,"output");
				else if(q_table[i].operator==10)
					strcat(opcode,"tempSave");
				else if(q_table[i].operator==11)
					strcat(opcode,">=");
				else if(q_table[i].operator==12)
					strcat(opcode,"<=");
				else if(q_table[i].operator==13)
					strcat(opcode,"==");
				else if(q_table[i].operator==14)
					strcat(opcode,"!=");
				else if(q_table[i].operator==15)
					strcat(opcode,"[]=");
				else if(q_table[i].operator==16)
					strcat(opcode,"=[]");
				else if(q_table[i].operator==17)
					strcat(opcode,"goto");
				else				
				;
				
				//再依照q_table裡面個值得型態 決定其印出的格式
				if(q_table[i].operator==10)
					printf("%s\t%s\t(null)\t%s\n",opcode,q_table[i].arg1.name,q_table[i].result.name);
				else if(q_table[i].operator==15)
					printf("%s\t\t%s\t%d\t%s\n",opcode,q_table[i].arg1.name,q_table[i].result.type,q_table[i].result.name);
				else if(q_table[i].operator==16)
					printf("%s\t\t%s\t%d\t%s\n",opcode,q_table[i].arg1.name,q_table[i].arg1.type,q_table[i].result.name);
				else if(strcmp(q_table[i].arg2.name,"")==0&&strcmp(q_table[i].arg1.name,"")!=0)
					printf("%s\t\t%s\t(null)\t%s\n",opcode,q_table[i].arg1.name,q_table[i].result.name);
				else if(strcmp(q_table[i].arg2.name,"")==0&&strcmp(q_table[i].arg1.name,"")==0)
					printf("%s\t\t(null)\t(null)\t%s\n",opcode,q_table[i].result.name);
				else if(strcmp(q_table[i].arg2.name,"")!=0&&strcmp(q_table[i].arg1.name,"")==0)
					printf("%s\t\t(null)\t%s\t%s\n",opcode,q_table[i].arg2.name,q_table[i].result.name);
				
				else
					printf("%s\t\t%s\t%s\t%s\n",opcode,q_table[i].arg1.name,q_table[i].arg2.name,q_table[i].result.name);
				

			}
	
	}
//尋找傳入的值在symbol table裡面的位置
int search_s_table(char s[])
	{
		int i;
		for(i=0;i<s_table_sp;i++)
			{
				if(strcmp(s_table[i].name,s)==0)
					return i;
			}
		return -1;
	}
//將值轉存成instruction的函式
void insert_instruction(char *operator,char *arg1,char *arg2,int arg1_type,int arg2_type)
	{	
		i_table[i_table_sp].operator=(char*)malloc(5*sizeof(char));
		strcpy(i_table[i_table_sp].operator,operator);
		i_table[i_table_sp].arg1.name=(char*)malloc(5*sizeof(char));
		strcpy(i_table[i_table_sp].arg1.name,arg1);
		i_table[i_table_sp].arg2.name=(char*)malloc(5*sizeof(char));
		strcpy(i_table[i_table_sp].arg2.name,arg2);
		i_table[i_table_sp].arg1.type=arg1_type;
		i_table[i_table_sp].arg2.type=arg2_type;
		i_table_sp++;
	}
//轉換instruction的函式
void convert_instruction()
	{	
		int check=0,i;
		int register_num;
		char arg1[2],arg2[2];
		for(i=0;i<q_table_sp;i++)
			{	
			
				//依照operator將其轉換成instruction
				if(q_table[i].operator==1)// +
					{
						insert_instruction("Load","1",q_table[i].arg1.name,0,q_table[i].arg1.type);
						insert_instruction("Load","2",q_table[i].arg2.name,0,q_table[i].arg2.type);
						insert_instruction("Add","1","2",0,0);
						insert_instruction("Stor","1",q_table[i].result.name,0,q_table[i].result.type);
					}
				else if(q_table[i].operator==2)// -
					{
						insert_instruction("Load","1",q_table[i].arg1.name,0,q_table[i].arg1.type);
						insert_instruction("Load","2",q_table[i].arg2.name,0,q_table[i].arg2.type);
						insert_instruction("Sub","1","2",0,0);
						insert_instruction("Stor","1",q_table[i].result.name,0,q_table[i].result.type);
					
					}
				else if(q_table[i].operator==3)// *
					{	
						insert_instruction("Load","1",q_table[i].arg1.name,0,q_table[i].arg1.type);
						insert_instruction("Load","2",q_table[i].arg2.name,0,q_table[i].arg2.type);
						insert_instruction("Mul","1","2",0,0);
						insert_instruction("Stor","1",q_table[i].result.name,0,q_table[i].result.type);
					
					}
				else if(q_table[i].operator==4)// 除法
					{
						insert_instruction("Load","1",q_table[i].arg1.name,0,q_table[i].arg1.type);
						insert_instruction("Load","2",q_table[i].arg2.name,0,q_table[i].arg2.type);
						insert_instruction("Div","1","2",0,0);
						insert_instruction("Stor","1",q_table[i].result.name,0,q_table[i].result.type);
					
					}
				else if(q_table[i].operator==5)//<
					{
						insert_instruction("Load","1",q_table[i].arg1.name,0,q_table[i].arg1.type);
						insert_instruction("Load","2",q_table[i].arg2.name,0,q_table[i].arg2.type);
						insert_instruction("Sub","1","2",0,0);
						char *temp;
						temp=(char*)malloc(10*sizeof(char));
						sprintf(temp,"%d",q_table[i].branch);
						insert_instruction("Jge","1",temp,0,0);
					}
				else if(q_table[i].operator==6)//>
					{
						insert_instruction("Load","1",q_table[i].arg1.name,0,q_table[i].arg1.type);
						insert_instruction("Load","2",q_table[i].arg2.name,0,q_table[i].arg2.type);
						insert_instruction("Sub","1","2",0,0);
						char *temp;
						temp=(char*)malloc(10*sizeof(char));
						sprintf(temp,"%d",q_table[i].branch);
						insert_instruction("Jle","1",temp,0,0);
					}
				else if(q_table[i].operator==7||q_table[i].operator==15||q_table[i].operator==16)//=
					{
						insert_instruction("Load","1",q_table[i].arg1.name,0,q_table[i].arg1.type);
						insert_instruction("Stor","1",q_table[i].result.name,0,q_table[i].result.type);
					}
				else if(q_table[i].operator==8)//input
					{
						insert_instruction("Input","NULL",q_table[i].result.name,0,q_table[i].result.type);
			
					}
				else if(q_table[i].operator==9)//output
					{
						
						insert_instruction("Output","NULL",q_table[i].result.name,0,q_table[i].result.type);
					}	
				else if(q_table[i].operator==10)//loadc
					{
						insert_instruction("Loadc","1",q_table[i].arg1.name,0,q_table[i].arg1.type);
						insert_instruction("Stor","1",q_table[i].result.name,0,q_table[i].result.type);
					}
				else if(q_table[i].operator==11)//>=
					{
						insert_instruction("Load","1",q_table[i].arg1.name,0,q_table[i].arg1.type);
						insert_instruction("Load","2",q_table[i].arg2.name,0,q_table[i].arg2.type);
						insert_instruction("Sub","1","2",0,0);
						char *temp;
						temp=(char*)malloc(10*sizeof(char));
						sprintf(temp,"%d",q_table[i].branch);
						insert_instruction("Jlt","1",temp,0,0);
					
					}
				else if(q_table[i].operator==12)//<=
					{
						insert_instruction("Load","1",q_table[i].arg1.name,0,q_table[i].arg1.type);
						insert_instruction("Load","2",q_table[i].arg2.name,0,q_table[i].arg2.type);
						insert_instruction("Sub","1","2",0,0);
						char *temp;
						temp=(char*)malloc(10*sizeof(char));
						sprintf(temp,"%d",q_table[i].branch);
						insert_instruction("Jgt","1",temp,0,0);
					}
				else if(q_table[i].operator==13)//==
					{
						insert_instruction("Load","1",q_table[i].arg1.name,0,q_table[i].arg1.type);
						insert_instruction("Load","2",q_table[i].arg2.name,0,q_table[i].arg2.type);
						insert_instruction("Sub","1","2",0,0);
						char *temp;
						temp=(char*)malloc(10*sizeof(char));
						sprintf(temp,"%d",q_table[i].branch);
						insert_instruction("Jne","1",temp,0,0);
					}
				else if(q_table[i].operator==14)//!=
					{
						insert_instruction("Load","1",q_table[i].arg1.name,0,q_table[i].arg1.type);
						insert_instruction("Load","2",q_table[i].arg2.name,0,q_table[i].arg2.type);
						insert_instruction("Sub","1","2",0,0);
						char *temp;
						temp=(char*)malloc(10*sizeof(char));
						sprintf(temp,"%d",q_table[i].branch);
						insert_instruction("Jeq","1",temp,0,0);
					}
				else if(q_table[i].operator==17)
					{	
						char *temp;
						temp=(char*)malloc(10*sizeof(char));
						sprintf(temp,"-%d",q_table[i].branch);
						insert_instruction("Lda","7",temp,0,0);
					}
				else
					;
				
			
			}
			
			

	}
//寫入obj.tm的函式
void print_obj_tm(char operator[],char rs[],char rt[],char rd[],int type)
	{	
		
		if(type==1)
			{
				fprintf(f,"%d: %s %s,%s,%s\n",tm_code_linenum,operator,rs,rt,rd);
				tm_code_linenum++;
			}
		else if(type==2)
			{
				fprintf(f,"%d: %s %s,%s(%s)\n",tm_code_linenum,operator,rs,rt,rd);
				tm_code_linenum++;
			}
		else 
			;
	}
//show出symbol的函式
void show_symbol_table()
	{	
		printf("=========================================\n");
		printf("                SymbolTable              \n");
		printf("=========================================\n");
		int i;
		printf("NAME\tADR\tSIZE\n");
		for(i=0;i<s_table_sp;i++)
			{
				printf("%s\t%d ",s_table[i].name,s_table[i].addr);
				if(s_table[i].type==2)
					printf("\t%d",s_table[i].arr_size);
				printf("\n");
			}
	
	}
//將instruction轉換成obj.tm的函式
void convert_tmcode()
	{
		f=fopen("obj.tm","w+");
		int i;
	
		for(i=0;i<i_table_sp;i++)
			{	
				//依照instruction裡面operator的不同 將其轉成對應的指令
				if(strcmp(i_table[i].operator,"Input")==0)
					{
						print_obj_tm("IN","1","0","0",1);
						int num;
						char temp[10];
						num=search_s_table(i_table[i].arg2.name);
						//判斷是否為陣列，若為陣列則加上offset
						if(i_table[i].arg2.type==0)
							sprintf(temp,"%d",s_table[num].addr);
						else
							sprintf(temp,"%d",(s_table[num].addr+i_table[i].arg2.type));
						print_obj_tm("ST","1",temp,"0",2);
					}
				else if(strcmp(i_table[i].operator,"Load")==0)
					{	
						int num;
						char temp[10];
						num=search_s_table(i_table[i].arg2.name);
						
						//判斷是否為陣列，若為陣列則加上offset
						if(i_table[i].arg2.type==0)
							sprintf(temp,"%d",s_table[num].addr);
						else
							sprintf(temp,"%d",(s_table[num].addr+i_table[i].arg2.type));
						print_obj_tm("LD",i_table[i].arg1.name,temp,"0",2);
					}
				else if(strcmp(i_table[i].operator,"Stor")==0)
					{
						int num;
						char temp[10];
						num=search_s_table(i_table[i].arg2.name);
						//判斷是否為陣列，若為陣列則加上offset
						if(i_table[i].arg2.type==0)
							sprintf(temp,"%d",s_table[num].addr);
						else
							sprintf(temp,"%d",(s_table[num].addr+i_table[i].arg2.type));
						print_obj_tm("ST",i_table[i].arg1.name,temp,"0",2);
					}
				else if(strcmp(i_table[i].operator,"Mul")==0)
					{	
						
						print_obj_tm("MUL",i_table[i].arg1.name,i_table[i].arg1.name,i_table[i].arg2.name,1);
					}
				else if(strcmp(i_table[i].operator,"Sub")==0)
					{
					
						print_obj_tm("SUB",i_table[i].arg1.name,i_table[i].arg1.name,i_table[i].arg2.name,1);
					}
				else if(strcmp(i_table[i].operator,"Add")==0)
					{
			
						print_obj_tm("ADD",i_table[i].arg1.name,i_table[i].arg1.name,i_table[i].arg2.name,1);
					
					}
				else if(strcmp(i_table[i].operator,"Div")==0)
					{

						print_obj_tm("DIV",i_table[i].arg1.name,i_table[i].arg1.name,i_table[i].arg2.name,1);
					}
				else if(strcmp(i_table[i].operator,"Loadc")==0)
					{
					
						print_obj_tm("LDC",i_table[i].arg1.name,i_table[i].arg2.name,"0",1);
					
					}
				else if(strcmp(i_table[i].operator,"Output")==0)	
					{
						int num;
						char temp[10];
						num=search_s_table(i_table[i].arg2.name);
						
						//判斷是否為陣列，若為陣列則加上offset
						if(i_table[i].arg2.type==0)
							sprintf(temp,"%d",s_table[num].addr);
						else
							sprintf(temp,"%d",(s_table[num].addr+i_table[i].arg2.type));
						print_obj_tm("LD","1",temp,"0",2);
						print_obj_tm("OUT","1","0","0",1);
					}
				else if(strcmp(i_table[i].operator,"Jle")==0)	
					{
						print_obj_tm("JLE",i_table[i].arg1.name,i_table[i].arg2.name,"7",2);
					}
				else if(strcmp(i_table[i].operator,"Jge")==0)
					{
						print_obj_tm("JGE",i_table[i].arg1.name,i_table[i].arg2.name,"7",2);
					}
				else if(strcmp(i_table[i].operator,"Jlt")==0)
						print_obj_tm("JLT",i_table[i].arg1.name,i_table[i].arg2.name,"7",2);
				else if(strcmp(i_table[i].operator,"Jgt")==0)
						print_obj_tm("JGT",i_table[i].arg1.name,i_table[i].arg2.name,"7",2);
				else if(strcmp(i_table[i].operator,"Jeq")==0)
						print_obj_tm("JEQ",i_table[i].arg1.name,i_table[i].arg2.name,"7",2);
				else if(strcmp(i_table[i].operator,"Jne")==0)
						print_obj_tm("JNE",i_table[i].arg1.name,i_table[i].arg2.name,"7",2);
				else if(strcmp(i_table[i].operator,"Lda")==0)
					print_obj_tm("LDA",i_table[i].arg1.name,i_table[i].arg2.name,"7",2);
				else
				;
			}
		fprintf(f,"%d: HALT 1,0,0\n",tm_code_linenum);	
		fclose(f);
	
	}
//印出instruction table的函式
void print_i_table()
	{	
		printf("\n");
		printf("=========================================\n");
		printf("                Instruction              \n");
		printf("=========================================\n");
		printf("OPER\tARG1\tARG2\tA1TP\tA2TP\n");
		int i;
		for(i=0;i<i_table_sp;i++)
			{
				printf("%s\t%s\t%s\t%d\t%d\n",i_table[i].operator,i_table[i].arg1.name,i_table[i].arg2.name,i_table[i].arg1.type,i_table[i].arg2.type);
			}

	}
//確認傳入值是否為array的函式
int check_array(char *word)	
	{	
		int i,l_para=0,r_para=0;
		for(i=0;i<strlen(word);i++)
			{
					if(word[i]=='[')
						l_para=1;
					if(word[i]==']')	
						r_para=1;
			
			}
		if(l_para==1&&r_para==1)
			return 1;
		else 
			return 0;
	}
//取得可用的register的函式
int get_register()
		{
			int i;
			for(i=0;i<7;i++)
				{
					if(register_table[i]==0)
						{
							register_table[i]=1;
							return i;
						}
				
				}
		
		}
int main()
	{
		int i;
		for(i=0;i<7;i++)
			{
				register_table[i]=0;
			
			}
		for(i=0;i<10;i++)
			{
				branch_count[i][0]=0;
				branch_count[i][1]=0;
			}	
		yyparse();
		print_q_table();
		convert_instruction();
		//print_i_table();
		//show_symbol_table();
		convert_tmcode();
		return 0;	
	 }
int yyerror(const char *msg)
	{	
		printf(msg);
		printf("\n");
		return 0;
	}





