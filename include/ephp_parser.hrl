%% Author: Manuel Rubio <manuel@altenwald.com>

-define(IS_SPACE(X),
    erlang:'or'(X =:= 32,
                erlang:'or'(X =:= $\t,
                            X =:= $\r)
               )
).
-define(IS_NEWLINE(X),
    X =:= $\n
).
-define(IS_NUMBER(X),
    erlang:'and'(X >= $0, X =< $9)
).
-define(IS_ALPHA(X),
    erlang:'or'(
        erlang:'and'(X >= $A, X =< $Z),
        erlang:'and'(X >= $a, X =< $z)
    )
).
-define(IS_ALPHANUM(X), erlang:'or'(?IS_NUMBER(X), ?IS_ALPHA(X))).
-define(IS_HEX(X),
    erlang:'or'(
        ?IS_NUMBER(X),
        erlang:'or'(
            erlang:'and'(X >= $A, X =< $F),
            erlang:'and'(X >= $a, X =< $f)
        )
    )
).
-define(IS_OCT(X), erlang:'and'(X >= $0, X =< $7)).

-define(OR(I,X,Y), erlang:'or'(I =:= X, I =:= Y)).

-define(IS_OP1_ARITH(X),
    X =:= <<"*">> orelse
    X =:= <<"/">> orelse
    X =:= <<"%">> orelse
    X =:= <<"+">> orelse
    X =:= <<"-">> orelse
    X =:= <<".">> orelse
    X =:= <<"&">> orelse
    X =:= <<"^">> orelse
    X =:= <<"|">>
).
-define(IS_OP1(X),
    X =:= <<126>> orelse
    X =:= <<"@">> orelse
    X =:= <<"!">> orelse
    X =:= <<"*">> orelse
    X =:= <<"/">> orelse
    X =:= <<"%">> orelse
    X =:= <<"+">> orelse
    X =:= <<"-">> orelse
    X =:= <<".">> orelse
    X =:= <<"<">> orelse
    X =:= <<">">> orelse
    X =:= <<"&">> orelse
    X =:= <<"^">> orelse
    X =:= <<"|">> orelse
    X =:= <<"=">>
).
-define(IS_OP2(X),
    X =:= <<"**">> orelse
    X =:= <<"++">> orelse
    X =:= <<"--">> orelse
    X =:= <<"<<">> orelse
    X =:= <<">>">> orelse
    X =:= <<"<=">> orelse
    X =:= <<">=">> orelse
    X =:= <<"==">> orelse
    X =:= <<"!=">> orelse
    X =:= <<"<>">> orelse
    X =:= <<"&&">> orelse
    X =:= <<"||">> orelse
    X =:= <<"??">> orelse
    X =:= <<"+=">> orelse
    X =:= <<"-=">> orelse
    X =:= <<"*=">> orelse
    X =:= <<"/=">> orelse
    X =:= <<".=">> orelse
    X =:= <<"%=">> orelse
    X =:= <<"&=">> orelse
    X =:= <<"|=">> orelse
    X =:= <<"^=">> orelse
    X =:= <<"->">> orelse
    X =:= <<"::">>
).
-define(IS_OP3(X),
    X =:= <<"===">> orelse
    X =:= <<"!==">> orelse
    X =:= <<"<=>">> orelse
    X =:= <<"**=">> orelse
    X =:= <<"<<=">> orelse
    X =:= <<">>=">>
).

-type parser_levels() :: root |
                         literal |
                         if_old_block |
                         for_old_block |
                         foreach_old_block |
                         while_old_block |
                         switch_old_block |
                         if_block |
                         for_block |
                         foreach_block |
                         while_block |
                         switch_block |
                         switch_label |
                         code |
                         code_block |
                         code_value |
                         code_statement |
                         arg |
                         array |
                         array_curly |
                         {array_def, pos_integer()} |
                         enclosed |
                         unclosed |
                         {term(), abstract} |
                         {public | private | protected, static | abstract, boolean()}.

-record(parser, {
    level = root :: parser_levels(),
    row = 1 :: pos_integer(),
    col = 1 :: pos_integer(),
    namespace = <<>> :: class_namespace(),
    namespace_row :: pos_integer()
}).
