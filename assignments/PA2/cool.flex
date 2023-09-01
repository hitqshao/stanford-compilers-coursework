/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;


static int comment_layer = 0;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

%}

/*
 *  Definition Define names for regular expressions here.
 */

CLASS           ?i:class
ELSE			?i:else
FI				?i:fi
IF				?i:if
IN				?i:in
INHERITS		?i:inherits
ISVOID			?i:isvoid
LET				?i:let
LOOP			?i:loop
POOL			?i:pool
THEN			?i:then
WHILE			?i:while
CASE			?i:case
ESAC			?i:esac
NEW				?i:new
OF				?i:of
NOT				?i:not
INT             [0-9]+
 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  * can be found at Page16 10.4 Keywords in cool_manual.pfg
  */
TRUE			t(?i:rue)
FALSE			f(?i:alse)
TYPEID			[A-Z][a-zA-Z0-9_]*
OBJECTID		[a-z][a-zA-Z0-9_]*
DARROW          =>
LE			    <=
ASSIGN	    	<-
 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
WHITESPACE	    [ \f\r\t\v]+
NEWLINE		    \n
SYMBOLS		    [+/\-*=<.~,;:()@{}]

%x INLINE_COMMENT
%x STRING
%x COMMENT

%%

 /*
  *  Rules
  */


 /* =========
  * operators
  * =========
  */

{CLASS}			{ return (CLASS); }
{ELSE}			{ return (ELSE); }
{FI}			{ return (FI); }
{IF}			{ return (IF); }
{IN}			{ return (IN); }
{INHERITS}	    { return (INHERITS); }
{ISVOID}		{ return (ISVOID); }
{LET}		    { return (LET); }
{LOOP}			{ return (LOOP); }
{POOL}			{ return (POOL); }
{THEN}			{ return (THEN); }
{WHILE}			{ return (WHILE); }
{CASE}			{ return (CASE); }
{ESAC}			{ return (ESAC); }
{NEW}			{ return (NEW); }
{OF}			{ return (OF); }
{NOT}			{ return (NOT); }
{INT} {
	cool_yylval.symbol = inttable.add_string(yytext);
	return INT_CONST;
}
{TRUE} {
	cool_yylval.boolean = true;
	return BOOL_CONST;
}
{FALSE} {
	cool_yylval.boolean = false;
	return BOOL_CONST;
}
{DARROW}		{ return (DARROW); }
{LE}		    { return (LE); }
{ASSIGN}	    { return (ASSIGN); }
{WHITESPACE}    {}
{NEWLINE}	    { curr_lineno++; }
{SYMBOLS} 	    { return int(yytext[0]); }

{TYPEID} {
	cool_yylval.symbol = idtable.add_string(yytext);
	return (TYPEID);
}
{OBJECTID} {
	cool_yylval.symbol = idtable.add_string(yytext);
	return (OBJECTID);
}

 /* ===============
  * inline comments
  * ===============
  */

 /* if seen "--", start inline comment */
<INITIAL>"--" { BEGIN INLINE_COMMENT; }

 /* any character other than '\n' is a nop in inline comments */ 
<INLINE_COMMENT>[^\n]* { }

 /* if seen '\n' in inline comment, the comment ends */
<INLINE_COMMENT>\n {
    curr_lineno++;
    BEGIN 0;
}

 /*
  *  Nested comments
  */

<INITIAL,COMMENT,INLINE_COMMENT>"(*"    { 
    comment_layer++;
    BEGIN COMMENT; 
}

<COMMENT>[^\n(*]* { }

<COMMENT>[()*] { }

<COMMENT>\n {
    curr_lineno++;
}

<COMMENT>"*)" {
    comment_layer--;
    if (comment_layer == 0) {
        BEGIN INITIAL;
    }
}

<COMMENT><<EOF>> {
	cool_yylval.error_msg = "EOF in comment";
	BEGIN 0;
	return ERROR;
}


"*)" {
	cool_yylval.error_msg = "Unmatched *)";
	return ERROR;
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for
  *  \n \t \b \f, the result is c.
  *
  */

 /* if seen '\"', start string */
<INITIAL>(\") {
    BEGIN STRING;
    yymore();
}

 /* Cannot read '\\' '\"' '\n' */
<STRING>[^\\\"\n]* { yymore(); }

 /* normal escape characters, not \n */
<STRING>\\[^\n] { yymore(); }

 /* seen a '\\' at the end of a line, the string continues */
<STRING>\\\n {
    curr_lineno++;
    yymore();
}

 /* meet EOF in the middle of a string, error */
<STRING><<EOF>> {
    yylval.error_msg = "EOF in string constant";
    BEGIN 0;
    yyrestart(yyin);
    return ERROR;
}

 /* meet a '\n' in the middle of a string without a '\\', error */
<STRING>\n {
    yylval.error_msg = "Unterminated string constant";
    BEGIN 0;
    curr_lineno++;
    return ERROR;
}

 /* meet a "\\0" */
<STRING>\\0 {
    yylval.error_msg = "Unterminated string constant";
    BEGIN 0;
    return ERROR;
}

 /* string ends, we need to deal with some escape characters */
<STRING>\" {
    std::string input(yytext, yyleng);

    // remove the '\"'s on both sizes.
    input = input.substr(1, input.length() - 2);

    std::string output = "";
    std::string::size_type pos;
    
    if (input.find_first_of('\0') != std::string::npos) {
        yylval.error_msg = "String contains null character";
        BEGIN 0;
        return ERROR;    
    }

    while ((pos = input.find_first_of("\\")) != std::string::npos) {
        output += input.substr(0, pos);

        switch (input[pos + 1]) {
        case 'b':
            output += "\b";
            break;
        case 't':
            output += "\t";
            break;
        case 'n':
            output += "\n";
            break;
        case 'f':
            output += "\f";
            break;
        default:
            output += input[pos + 1];
            break;
        }

        input = input.substr(pos + 2, input.length() - 2);
    }

    output += input;

    if (output.length() > 1024) {
        yylval.error_msg = "String constant too long";
        BEGIN 0;
        return ERROR;    
    }

    cool_yylval.symbol = stringtable.add_string((char*)output.c_str());
    BEGIN 0;
    return STR_CONST;

}



[^\n] {
    yylval.error_msg = yytext;
    return ERROR;
}


%%
