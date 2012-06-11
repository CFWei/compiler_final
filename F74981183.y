%{
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<signal.h> 
#include<ctype.h>

//�w�qsymbol table�����c
typedef struct symboltable
{
	char *name;//�x�ssymbol���W��
	int type; // 1:int 2:int array
	int arr_size;//�Y��array �h�x�sarray��size
	int addr;//�x�ssymbol��array address
}SymbolTable;

//�w�q�ǻ���elements�����c
typedef struct element
{
	char *name;//�W��
	int type;//���A

}Elements;
//�w�q instruction�����c
typedef struct instruction
{
	char *operator;//operator
	Elements arg1;//�Ѽ�1
	Elements arg2;//�Ѽ�2
}Instruction;

//�w�qquardruple�����c
typedef struct quadruples  
{
 	int operator;//operator
	//1:+ 2:- 3:* 4:/ 5:< 6:> 7:= 8:input 9:output 10:tempsave
	//11:>= 12:<= 13:== 14:!= 15:[]= 16:=[] 17:goto
	Elements arg1;//�Ѽ�1
	Elements arg2;//�Ѽ�2
	Elements result;//���G
	int branch;//��ڪ�branch��
}Quadruples;

//�w�q�@��array�����c
typedef struct array
{
	int array_size;
	char *name;
}Array;
//�H�U���ܼƪ��ŧi
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

//�H�U���禡���ŧi
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

//�w�q�`�I�����A
%union{
		int dval;
		char *sval;
		struct element *element;
		}
%type<dval> addop mulop type_specifier INT VOID FLOAT CHAR relop
%type<sval> ID factor term number additive_expression simple_expression expression args arg_list identifier 

//�O program��start symbol
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
														//�ܼƫŧi
														int i,repeat=0;
														//�ˬdsymbol�O�_�w�g�ŧi(���symbol table)
														for(i=0;i<s_table_sp;i++)
															{
																if(strcmp($2,s_table[i].name)==0)
																	{
																		repeat=1;
																		break;
																	}
															}
														//�Y�S�� ���ƫŧi �B identifier��array �h����H�U�B�J
														if(repeat==0&&check_array($2))
															{	
																//�Nidentifier���ά��W�٤�array_num�ⳡ��
																//�æs�Ja
																Array a=split_array_word($2);
																//�Nidentifier�s�Jsymbol table
																s_table[s_table_sp].name=a.name;
																s_table[s_table_sp].type=2;//type=2�N��䬰 int array

																s_table[s_table_sp].addr=value_address;//�s�J�_�l��address number
																s_table[s_table_sp].arr_size=a.array_size;//�s��array_size
																
																//�ܰ�value_address					
																value_address+=a.array_size;
																//s_table_sp=s_table_sp+1
																s_table_sp++;
															
															}
														else
															{	
																//�Nidentifier�s�Jsymbol table
																s_table[s_table_sp].name=$2;
																s_table[s_table_sp].type=$1;
																s_table[s_table_sp].addr=value_address;
																//�ܰ�value_address	
																value_address++;
																//s_table_sp=s_table_sp+1
																s_table_sp++;
															}
													}
													
					|type_specifier identifier '=' simple_expression ';' {	
																			int i,repeat=0;
																			//�ˬdsymbol�O�_�w�g�ŧi(���symbol table)
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
																					//�Nidentifier�s�Jsymbol table
																					s_table[s_table_sp].name=$2;
																					s_table[s_table_sp].type=$1;
																					s_table[s_table_sp].addr=value_address;
																					//�ܰ�value_address	
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
					//new�@��char�����Цs��r��
					char *temp=(char*)malloc(50*sizeof(char));
					//�Narray���W�٦s�Jtemp
					strcpy(temp,$1);
					strcat(temp,"[");
					strcat(temp,$3);
					strcat(temp,"]");
					//�O���`�I���Vtemp�æV�W�ǻ�
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
																	//new�@��char������t �s��r��
																	char *t=(char*)malloc(50*sizeof(char));
																	//�Nbranch_count[branch_control][1]�������ഫ���r��
																	sprintf(t,"%d",branch_count[branch_control][1]);
																	//�Nt�����r��ƻs��q_table[branch_instruction[branch_control]].result.name
																	strcpy(q_table[branch_instruction[branch_control]].result.name,t);
																	
																	//���^�h���n�������O��
																	q_table[branch_instruction[branch_control]].branch=branch_count[branch_control][0];
																	
																	//�Nbranch_count�����k�s
																	branch_count[branch_control][0]=0;
																	branch_count[branch_control][1]=0;
																	//branch_control=branch_control-1
																	branch_control--;
																	
																}
			|	IF '(' expression ')' statement ELSE statement	{};				
iteration_stmt:	WHILE '(' expression ')' statement	{
														//new�@��char���}�C
														char temp[50];
														//�Nbranch_count������+2���ন�r��s�Jtemp
														sprintf(temp,"%d",branch_count[branch_control][1]+2);
														
														//insert���O��q_table(���^�P�_�������O)
														q_table_insert(17,NULL,NULL,temp,0,0,0,1);
														q_table[q_table_sp-1].branch=branch_count[branch_control][0]+4;
														
														//���^�h���P�_���n�������O��
														char *t=(char*)malloc(50*sizeof(char));
														sprintf(t,"%d",branch_count[branch_control][1]);
														strcpy(q_table[branch_instruction[branch_control]].result.name,t);
														q_table[branch_instruction[branch_control]].branch=branch_count[branch_control][0];
														
														//�Nbranch_count�����k�s
														branch_count[branch_control][0]=0;
														branch_count[branch_control][1]=0;
														//branch_control=branch_control-1
														branch_control--;	
													};
			|DO compound_stmt  WHILE '(' expression ')'{}
			|FOR '('expression ';' simple_expression ';' identifier addop addop ')' statement
													{	
														//new�@��char������
														char *arg1;
														//���o�i�Ϊ�register
														arg1=register_add();
														
														//�s�W���O�iq_table(�Oidentifier+=1)
														q_table_insert(10,"1",NULL,arg1,0,0,0,1);
														q_table_insert(1,$7,arg1,$7,0,0,0,1);
														
														//�s�W�@��temp���}�C
														char temp[50];
														//�Nbranch_count������+2���ন�r��s�Jtemp
														sprintf(temp,"%d",branch_count[branch_control][1]+2);
														//���^�h�P�_��
														q_table_insert(17,NULL,NULL,temp,0,0,0,1);
														q_table[q_table_sp-1].branch=branch_count[branch_control][0]+4;
														//new�@��char��pointer ��malloc�Ŷ�
														char *t=(char*)malloc(50*sizeof(char));
														//�Nbranch_count�ഫ���r��
														sprintf(t,"%d",branch_count[branch_control][1]);
														//���^�h���n�������O��
														strcpy(q_table[branch_instruction[branch_control]].result.name,t);
														q_table[branch_instruction[branch_control]].branch=branch_count[branch_control][0];
														
														//�Nbranch_count�����k�s
														branch_count[branch_control][0]=0;
														branch_count[branch_control][1]=0;
														//branch_control=branch_control-1
														branch_control--;		
													}

return_stmt:	RETURN ';' 				{}
		|		RETURN expression ';'	{};
expression:	identifier '=' expression	{	
											//�ܼƫŧi
											int i,check=1;
											char *identifier=(char*)malloc(50*sizeof(char));
											int identifier_type,operation=7;
											
											//�P�_ $1 �M $3 �O�_���}�C 
											int check_array_1=check_array($1);
											int check_array_2=check_array($3);
											//�P�_expression�O�_��digit
											for(i=0;i<strlen($3);i++)
												{
													if(isdigit($3[i])==0)
														check=0;
												
												}

											//�Y$1�O�}�C �h����H�U�ʧ@
											
											if(check_array_1==1)
												{	
													//����$1���W�٩M�Ʀr�ⳡ��
													Array a=split_array_word($1);
													//�Nidentifier�אּa.name�����r��
													strcpy(identifier,a.name);
													//����array��num
													identifier_type=a.array_size;
													//�Ooperation��15
													operation=15;
												}
											//�Y$1���O�}�C �h����H�U�ʧ@	
											else
												{
													//�N$1���Ƚƻs�iidentifier
													strcpy(identifier,$1);
													//�O��array num��0
													identifier_type=0;
												}
											//�Y$3���Ʀr �h����H�U�ʧ@
											if(check==1)
												{	
													//���o�@�ӥi�Ϊ�REGISTER
													char *temp=register_add();
													//�N�Ʀr�s�Jregister �A�O�ܼƵ���register
													q_table_insert(10,$3,NULL,temp,0,0,0,1);
													q_table_insert(operation,temp,NULL,identifier,0,0,identifier_type,1);
												}
											//�Y$3�����Ʀr �h����H�U�ʧ@
											else
												{	
													//�Y$3���}�C �B$1�����}�C
													if(check_array_2==1&&check_array_1==0)
														{	
															//�N$3���ά��W�٩M�Ʀr�ⳡ��
															Array b=split_array_word($3);
															//�[�J���O
															q_table_insert(16,b.name,NULL,identifier,b.array_size,0,identifier_type,1);
														}
													//�Y$3���}�C �B$1���}�C	
													else if(check_array_2==1&&check_array_1==1)
														{	
															//�N$3���ά��W�٩M�Ʀr�ⳡ��
															Array b=split_array_word($3);
															//���o�i�Ϊ�register
															char *temp=register_add();
															//���O�ܼƪ��ȵ���$3 �A�O$1���ȵ����ܼ�
															q_table_insert(16,b.name,NULL,temp,b.array_size,0,0,1);
															q_table_insert(operation,temp,NULL,identifier,0,0,identifier_type,1);
															
														}
													else
														{	
															//�����O$1���ȵ���$3
															q_table_insert(operation,$3,NULL,identifier,0,0,identifier_type,1);
														}
												
												}
											

										}
										

													
		|simple_expression	{$$=$1;} ;
		
		
simple_expression:	additive_expression relop additive_expression	{
																		
																		int check1=1,check2=1,i;
																		//�P�_$1�O�_���Ʀr
																		for(i=0;i<strlen($1);i++)
																			{	
																				if(isdigit($1[i])==0)
																					check1=0;
															
																			}
																		//�P�_$3�O�_���Ʀr
																		for(i=0;i<strlen($3);i++)
																			{	
																				if(isdigit($3[i])==0)
																					check2=0;
															
																			}
																		
																		char *arg1,*arg2;
																		int arg1_type=0,arg2_type=0;	
																		//�Y$1�����Ʀr�B����array
																		if(check1==0&&check_array($1)==0)
																			{
																				arg1=$1;
																			}
																		//�Y$1��array
																		else if(check_array($1)==1)
																			{
																				arg1=(char*)malloc(50*sizeof(char));
																				//�N$1���ά��W�٩M�Ʀr�ⳡ��
																				Array a=split_array_word($1);
																				//�Na.name�ƻs��arg1
																				strcpy(arg1,a.name);
																				arg1_type=a.array_size;
																			}
																		
																		else
																			{	
																				//���o�i�Ϊ�register
																				arg1=register_add();
																				//�s�W���O
																				q_table_insert(10,$1,NULL,arg1,0,0,0,1);
																			}
																		//�Y$3�����Ʀr�B����array
																		if(check2==0&&check_array($3)==0)	
																			{	
																				
																				arg2=$3;
																				
																			}
																		//�Y$3��array
																		else if(check_array($3)==1)
																			{
																				arg2=(char*)malloc(50*sizeof(char));
																				//�N$3���ά��W�٩M�Ʀr�ⳡ��
																				Array a=split_array_word($3);
																				//�Na.name�ƻs��arg2
																				strcpy(arg2,a.name);
																				arg2_type=a.array_size;
																			
																			}	
																		else
																			{	
																				//���o�i�Ϊ�register
																				arg2=register_add();
																				//�s�W���O
																				q_table_insert(10,$3,NULL,arg2,0,0,0,1);
																			}
																		//�s�WJUMP�����O��Q_TABLE
																		q_table_insert($2,arg1,arg2,NULL,arg1_type,arg2_type,0,2);
																		//�}��branch_control
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
															//�P�_$1�O�_���Ʀr
															for(i=0;i<strlen($1);i++)
																	{	
																		if(isdigit($1[i])==0)
																			check1=0;
																	}
															//�P�_$3�O�_���Ʀr
															for(i=0;i<strlen($3);i++)
																	{	
																		if(isdigit($3[i])==0)
																			check2=0;
																	}
															//�Y$1���Ʀr�h����H�U�ʧ@	
															if(check1==1)
																{	
																	//���o�@��register
																	arg1=register_add();
																	//$1��s��register
																	q_table_insert(10,$1,NULL,arg1,0,0,0,1);
																
																}
															//�Y$1�Oarray
															else if(check_array($1)==1)
																{	
																	//�N$1���Φ��W�٩M�Ʀr
																	Array a=split_array_word($1);
																	//���o�@��register
																	arg1=register_add();
																	//�N�ƭ���s��register
																	q_table_insert(16,a.name,NULL,arg1,a.array_size,0,0,1);

																}
															//�Y�O��L���p�h����N$1���Ȧs��arg1
															else
																{
																	arg1=$1;
																}
															//�Y$3�O�Ʀr
															if(check2==1)
																{	
																	//���o�@��register
																	arg2=register_add();
																	//$3��s��register
																	q_table_insert(10,$3,NULL,arg2,0,0,0,1);
																
																}
															else if(check_array($3)==1)
																{
																	//�N$3���Φ��W�٩M�Ʀr
																	Array a=split_array_word($3);
																	//���o�@��register
																	arg2=register_add();
																	//�N�ƭ���s��register
																	q_table_insert(16,a.name,NULL,arg2,a.array_size,0,0,1);
																}
															//�Y�O��L���p�h����N$3���Ȧs��arg2	
															else
																{
																	arg2=$3;
																}
															//�[�J���O
															q_table_insert($2,arg1,arg2,NULL,0,0,0,1);
														
															//�N�ȦV�W�ǻ�
															$$=(char*)malloc(strlen(deliever)*sizeof(char));
															strcpy($$,deliever);
															
														}
														
				      |term	{$$=$1;};			
														
addop:	'+'	{$$=1;}	
	|	'-'	{$$=2;};	
			

term:	term mulop factor	{
								
								int check1=1,check2=1,i;
								char *arg1,*arg2;
								//�P�_$1�O�_���Ʀr
								for(i=0;i<strlen($1);i++)
									{	
										if(isdigit($1[i])==0)
											check1=0;
									}
								//�P�_$3�O�_���Ʀr	
								for(i=0;i<strlen($3);i++)
									{	
										if(isdigit($3[i])==0)
											check2=0;
									}
								//�Y$1���Ʀr�h����H�U�ʧ@	
								if(check1==1)
									{
										arg1=register_add();
										q_table_insert(10,$1,NULL,arg1,0,0,0,1);
									
									}
								//�Y$1��array�h����H�U�ʧ@
								else if(check_array($1)==1)
									{	
										//�N$1���Φ��W�٩M�Ʀr
										Array a=split_array_word($1);
										//���o�@��register
										arg1=register_add();
										//�N�ƭ���s��register
										q_table_insert(16,a.name,NULL,arg1,a.array_size,0,0,1);

									}
								//�Y�O��L���p�h����N$1���Ȧs��arg1
								else
									{
										arg1=$1;
									}
									
									
								//�Y$3���Ʀr�h����H�U�ʧ@
								if(check2==1)
									{	
										
										arg2=register_add();
										q_table_insert(10,$3,NULL,arg2,0,0,0,1);
									
									}
								//�Y$3��array�h����H�U�ʧ@
								else if(check_array($3)==1)
									{	
										//�N$3���Φ��W�٩M�Ʀr
										Array a=split_array_word($3);
										//���o�@��register
										arg2=register_add();
										//�N�ƭ���s��register
										q_table_insert(16,a.name,NULL,arg2,a.array_size,0,0,1);
									}
								//�Y�O��L���p�h����N$3���Ȧs��arg2	
								else
									{
										arg2=$3;
									}
								//�[�J���O	
								q_table_insert($2,arg1,arg2,NULL,0,0,0,1);
								//�N�ȦV�W�ǻ�
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
				//�Yidentifier��input �h����H�U�ʧ@
				if(strcmp($1,"input")==0)
					{
						//�Yargs��array
						if(check_array($3)==1)
							{	
								char *temp;
								//���oregister
								temp=register_add();
								//�Ninput���Ȧs��register
								q_table_insert(8,NULL,NULL,temp,0,0,0,1);
								//�Nargs���Φ��W�٩M�Ʀr�ⳡ��
								Array a=split_array_word($3);
								//�Nregister���Ȧs��args��
								q_table_insert(15,temp,NULL,a.name,0,0,a.array_size,1);
								
							}
						//�Y����L���p
						else
							q_table_insert(8,NULL,NULL,$3,0,0,0,1);
							//�����N�ȵ�args
					}
					
				//�Yidentifier��output �h����H�U�ʧ@
				if(strcmp($1,"output")==0)
					{	
						//�Yargs��array
						if(check_array($3)==1)
							{
								char *temp;
								//�N����s��register
								Array a=split_array_word($3);
								temp=register_add();
								q_table_insert(16,a.name,NULL,temp,a.array_size,0,0,1);
								//��Xregister����
								q_table_insert(9,NULL,NULL,temp,0,0,0,1);
								
							}
						//�Y����L���p
						else
							q_table_insert(9,NULL,NULL,$3,0,0,0,1);
							//������Xargs
					
					
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
//����array�����W�٩M�Ʀr��ӳ�����function
Array split_array_word(char *word)
	{	
		//�ŧi�@��Array type��return_value
		Array return_value;
		char *temp,*value[2],*value_1;
		//�H[���Φr�ꦨ��ӳ���
		temp=strtok(word,"[");
		int i=0;
		//�s���}�C
		while (temp != NULL){
				value[i]=(char*)malloc(strlen(temp)*sizeof(char));
				strcpy(value[i],temp);
				i++;
                temp = strtok(NULL,"[");
        }
		
		//�Nname�s�Jreturn_value
		return_value.name=(char*)malloc(strlen(value[0])*sizeof(char));
		strcpy(return_value.name,value[0]);
		
		//�H]���γѤU���r��
		temp=strtok(value[1],"]");
		while (temp != NULL) 
			{
				value_1=(char*)malloc(strlen(temp)*sizeof(char));
				strcpy(value_1,temp);
				temp = strtok(NULL, " ");
			}
		//�N�Ʀr�����s�Jreturn_value.array_size
		return_value.array_size=atoi(value_1);
		//�^�ǭ�
		return return_value;
	}
	
	
//�^�ǥi�Ϊ�register���禡
char *register_add()
	{	
		char *return_value=(char*)malloc(10*sizeof(char));
		//�N$���s�Jreturn_value 
		strcpy(return_value,"$");
		char temp[3];
		//�Ntemp_register_num�ন�r��
		sprintf(temp,"%d",temp_register_num);
		//�����return_value�᭱
		strcat(return_value,temp);
		temp_register_num++;
		
		//���U��symbol table�̭�
		s_table[s_table_sp].name=(char*)malloc(strlen(return_value)*sizeof(char));
		strcpy(s_table[s_table_sp].name,return_value);
		s_table[s_table_sp].type=1;		
		s_table[s_table_sp].addr=value_address;			
		value_address++;
		s_table_sp++;
		
		//�^��
		return return_value;
	}
	
//�W�[���O��quadruple�̭�
void q_table_insert(int op,char *arg1,char *arg2,char *result,int arg1_type,int arg2_type,int result_type,int type)
	{		
			//�g�Joperator
			q_table[q_table_sp].operator=op;
			
			//malloc�Ŷ�
			q_table[q_table_sp].arg1.name=(char*)malloc(50*sizeof(char));
			q_table[q_table_sp].arg1.type=arg1_type;
			q_table[q_table_sp].arg2.name=(char*)malloc(50*sizeof(char));
			q_table[q_table_sp].arg2.type=arg2_type;
			
			//�Yarg1������null �h���w��
			if(arg1!=NULL)
				strcpy(q_table[q_table_sp].arg1.name,arg1);
			//�Yarg1����null �h���wnull	
			else
				q_table[q_table_sp].arg1.name==NULL;
				
			//�Yarg2������null �h���w��
			if(arg2!=NULL)
				strcpy(q_table[q_table_sp].arg2.name,arg2);
			//�Yarg2����null �h���wnull
			else
				q_table[q_table_sp].arg2.name==NULL;
				
			//�Ytype��2�h�u���t�Ŷ�
			if(type==2)
				{
					q_table[q_table_sp].result.name=(char*)malloc(50*sizeof(char));
					q_table_sp++;
					
				}
			//�Yresult����null�Btype������2
			else if(result==NULL&&type!=2)
				{	
					//�гy�Ȧs�ܼ� �榡:$(num)	
					char reigster_name[50]="$";
					char num[50];
					//��s���r��ñN��s��reigster_name
					sprintf(num,"%d",temp_register_num);
					temp_register_num++;
					strcat(reigster_name,num);
					
					//�N�Ȧs��result�̭�
					q_table[q_table_sp].result.name=(char*)malloc(50*sizeof(char));
					q_table[q_table_sp].result.type=0;
					strcpy(q_table[q_table_sp].result.name,reigster_name);
					q_table_sp++;
					
					//���U��symblo�̭�
					s_table[s_table_sp].name=(char*)malloc(strlen(reigster_name)*sizeof(char));					
					strcpy(s_table[s_table_sp].name,reigster_name);
					s_table[s_table_sp].type=type;			
					s_table[s_table_sp].addr=value_address;
					
					value_address++;
					s_table_sp++;
					//�Nreigster_name�s��deliever�̭�
					strcpy(deliever,reigster_name);
				
				}
			//�Y����L���p
			else
				{	
					//�����Nq_table�̭���result���ȫ��w���ǤJ��result
					q_table[q_table_sp].result.name=(char*)malloc(50*sizeof(char));
					strcpy(q_table[q_table_sp].result.name,result);
					q_table[q_table_sp].result.type=result_type;
					
					q_table_sp++;
					
				}
				
			//�H�U�p��n�������O��
			int i;	
			//�Yop���H�U �hbranch_count[i][0]�[�| branch_count[i][1]�[�@
			if((op==1||op==2||op==3||op==4||op==5||op==6||op==11||op==12||op==13||op==14)&&branch_control>=0)
				{
					for(i=0;i<=branch_control;i++)
						{
							branch_count[i][0]+=4;
							branch_count[i][1]++;
						}
					
				}
			//�Yop���H�U �hbranch_count[i][0]�[�G branch_count[i][1]�[�@
			if((op==7||op==10||op==15||op==16||op==9||op==8)&&branch_control>=0)
				{	
			
					for(i=0;i<=branch_control;i++)
						{
							branch_count[i][0]+=2;	
							branch_count[i][1]++;
						}

			
				}
			//�Yop���H�U �hbranch_count[i][0]�[�@ branch_count[i][1]�[�@
			if((op==17)&&branch_control>=0)
				{
					for(i=0;i<=branch_control;i++)
						{
							branch_count[i][0]++;	
							branch_count[i][1]++;
						}
				
				
				}
			
	
	}
//�L�XQuadruples���禡
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
				//���̾�operator�����X �N���ন�r��
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
				
				//�A�̷�q_table�̭��ӭȱo���A �M�w��L�X���榡
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
//�M��ǤJ���Ȧbsymbol table�̭�����m
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
//�N����s��instruction���禡
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
//�ഫinstruction���禡
void convert_instruction()
	{	
		int check=0,i;
		int register_num;
		char arg1[2],arg2[2];
		for(i=0;i<q_table_sp;i++)
			{	
			
				//�̷�operator�N���ഫ��instruction
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
				else if(q_table[i].operator==4)// ���k
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
//�g�Jobj.tm���禡
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
//show�Xsymbol���禡
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
//�Ninstruction�ഫ��obj.tm���禡
void convert_tmcode()
	{
		f=fopen("obj.tm","w+");
		int i;
	
		for(i=0;i<i_table_sp;i++)
			{	
				//�̷�instruction�̭�operator�����P �N���ন���������O
				if(strcmp(i_table[i].operator,"Input")==0)
					{
						print_obj_tm("IN","1","0","0",1);
						int num;
						char temp[10];
						num=search_s_table(i_table[i].arg2.name);
						//�P�_�O�_���}�C�A�Y���}�C�h�[�Woffset
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
						
						//�P�_�O�_���}�C�A�Y���}�C�h�[�Woffset
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
						//�P�_�O�_���}�C�A�Y���}�C�h�[�Woffset
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
						
						//�P�_�O�_���}�C�A�Y���}�C�h�[�Woffset
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
//�L�Xinstruction table���禡
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
//�T�{�ǤJ�ȬO�_��array���禡
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
//���o�i�Ϊ�register���禡
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





