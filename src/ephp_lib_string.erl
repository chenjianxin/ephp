-module(ephp_lib_string).
-author('manuel@altenwald.com').
-compile([warnings_as_errors]).

-behaviour(ephp_func).

-export([
    init_func/0,
    init_config/0,
    init_const/0,
    strlen/3,
    ord/3,
    chr/3,
    implode/3,
    implode/4,
    explode/4,
    explode/5,
    print/3,
    printf/3,
    sprintf/3,
    str_replace/5,
    str_replace/6,
    strtolower/3,
    strtoupper/3,
    str_split/3,
    str_split/4
]).

-include("ephp.hrl").

-spec init_func() -> ephp_func:php_function_results().

init_func() -> [
    strlen, ord, chr,
    implode,
    {implode, [{alias, <<"join">>}]},
    explode,
    %% FIXME: split is deprecated, should be removed?
    {explode, [{alias, <<"split">>}]},
    print,
    {print, [{alias, <<"echo">>}]},
    {printf, [pack_args]},
    {sprintf, [pack_args]},
    str_replace,
    strtolower,
    strtoupper,
    str_split
].

-spec init_config() -> ephp_func:php_config_results().

init_config() -> [].

-spec init_const() -> ephp_func:php_const_results().

init_const() -> [].

-spec strlen(context(), line(), String :: var_value()) -> integer().

strlen(_Context, _Line, {_,String}) when is_binary(String) ->
    byte_size(String);

strlen(Context, Line, {_, Var}) ->
    File = ephp_context:get_active_file(Context),
    Data = {<<"strlen">>, 1, <<"string">>, ephp_data:gettype(Var), File},
    ephp_error:handle_error(Context, {error, ewrongarg, Line,
        ?E_WARNING, Data}),
    undefined.

-spec ord(context(), line(), String :: var_value()) -> integer().

ord(_Context, _Line, {_,<<I:8/integer,_/binary>>}) ->
    I;

ord(Context, Line, {_, Var}) ->
    File = ephp_context:get_active_file(Context),
    Data = {<<"ord">>, 1, <<"string">>, ephp_data:gettype(Var), File},
    ephp_error:handle_error(Context, {error, ewrongarg, Line,
        ?E_WARNING, Data}),
    undefined.

-spec chr(context(), line(), Integer :: var_value()) -> binary().

chr(_Context, _Line, {_,C}) when is_integer(C) ->
    <<C:8/integer>>;

chr(_Context, _Line, _Var) ->
    undefined.

-spec implode(context(), line(),
    Glue :: var_value(), Pieces :: var_value()) -> binary().

implode(Context, Line, {_,Glue}=VarGlue, _Pieces) when ?IS_ARRAY(Glue) ->
    File = ephp_context:get_active_file(Context),
    Data = {File, <<"string">>},
    ephp_error:handle_error(Context, {error, earrayconv, Line, ?E_NOTICE, Data}),
    implode(Context, Line, {undefined, <<"Array">>}, VarGlue);

implode(Context, Line, {_,RawGlue}, {_,Pieces}) ->
    Glue = ephp_data:to_bin(Context, Line, RawGlue),
    ListOfPieces = ephp_array:fold(fun(_Key, Piece, SetOfPieces) ->
        SetOfPieces ++ [ephp_data:to_bin(Context, Line, Piece)]
    end, [], Pieces),
    case ListOfPieces of
        [] -> <<>>;
        [H|T] -> <<H/binary, (<< <<Glue/binary,X/binary>> || X <- T >>)/binary>>
    end.

-spec implode(context(), line(), Pieces :: var_value()) -> binary().

implode(Context, Line, Pieces) ->
    implode(Context, Line, {undefined, <<>>}, Pieces).

-spec explode(context(), line(), Delimiter :: var_value(), String :: var_value())
    -> ephp_array().

explode(_Context, _Line, {_,Delimiter}, {_,String}) ->
    Pieces = binary:split(String, Delimiter, [global]),
    lists:foldl(fun(Piece, Explode) ->
        ephp_array:store(auto, Piece, Explode)
    end, ephp_array:new(), Pieces).

-spec explode(
    context(), line(),
    Delimiter :: var_value(),
    String :: var_value(),
    Limit :: var_value()) -> ephp_array().

explode(Context, Line, _Delimiter, _String, {_,Limit})
        when not is_integer(Limit) ->
    File = ephp_context:get_active_file(Context),
    Data = {<<"explode">>, 3, <<"long">>, ephp_data:gettype(Limit), File},
    ephp_error:handle_error(Context, {error, ewrongarg, Line,
        ?E_WARNING, Data}),
    undefined;

explode(_Context, _Line, _Delimiter, {_,String}, {_,0}) ->
    String;

explode(_Context, _Line, {_,Delimiter}, {_,String}, {_,Limit}) ->
    split_limit(Delimiter, String, ephp_array:new(), Limit-1, 0).

-spec printf(context(), line(), [var_value()]) -> pos_integer().

printf(Context, Line, Values) when length(Values) < 2 ->
    File = ephp_context:get_active_file(Context),
    Data = {<<"printf">>, File},
    ephp_error:handle_error(Context, {error, efewargs, Line, ?E_WARNING, Data}),
    undefined;

printf(Context, _Line, [{_,Format}|Values]) ->
    Text = print_format(Format, Values),
    ephp_context:set_output(Context, Text),
    byte_size(Text).

-spec sprintf(context(), line(), [var_value()]) -> binary().

sprintf(Context, Line, Values) when length(Values) < 2 ->
    File = ephp_context:get_active_file(Context),
    Data = {<<"sprintf">>, File},
    ephp_error:handle_error(Context, {error, efewargs, Line, ?E_WARNING, Data}),
    undefined;

sprintf(_Context, _Line, [{_,Format}|Values]) ->
    print_format(Format, Values).

-spec str_replace(context(), line(),
    Search :: var_value(), Replace :: var_value(),
    Subject :: var_value()) -> binary().

str_replace(_Context, _Line, {_, Search}, {_, Replace}, {_, Subject})
        when ?IS_ARRAY(Search) andalso is_binary(Replace) ->
    ephp_array:fold(fun(_,V,Sub) ->
        binary:replace(Sub, V, Replace, [global])
    end, Subject, Search);

str_replace(_Context, _Line, {_, Search}, {_, Replace}, {_, Subject})
        when ?IS_ARRAY(Search) andalso ?IS_ARRAY(Replace) ->
    A = ephp_array:to_list(Search),
    B = ephp_array:to_list(Replace),
    Lists = lists:zipwith(fun({_,V1}, {_,V2}) -> {V1,V2} end, A, B),
    lists:foldl(fun({Source, Target}, Sub) ->
        binary:replace(Sub, Source, Target, [global])
    end, Subject, Lists);

str_replace(_Context, _Line, {_, Search}, {_, Replace}, {_, Subject}) ->
    binary:replace(Subject, Search, Replace, [global]).

-spec str_replace(context(), line(),
    Search :: var_value(), Replace :: var_value(),
    Subject :: var_value(), Count :: var_value()) -> binary().

str_replace(Context, _Line, {_, Search}, {_, Replace}, {_, Subject},
            {Count,_}) ->
    ephp_context:set(Context, Count, length(binary:matches(Subject, Search))),
    binary:replace(Subject, Search, Replace, [global]).

-spec strtolower(context(), line(), Text :: var_value()) -> binary().

strtolower(Context, Line, {_, Text}) ->
    ephp_string:to_lower(ephp_data:to_bin(Context, Line, Text)).

-spec strtoupper(context(), line(), Text :: var_value()) -> binary().

strtoupper(Context, Line, {_, Text}) ->
    ephp_string:to_upper(ephp_data:to_bin(Context, Line, Text)).

-spec str_split(context(), line(), Text :: var_value()) -> ephp_array().

str_split(Context, Line, Text) ->
    str_split(Context, Line, Text, {1, 1}).

-spec str_split(context(), line(),
    Text :: var_value(), Size :: var_value()) -> ephp_array() | undefined.

str_split(Context, Line, _Text, {_, Size}) when not is_integer(Size) ->
    File = ephp_context:get_active_file(Context),
    Data = {<<"str_split">>, 2, <<"long">>, ephp_data:gettype(Size), File},
    ephp_error:handle_error(Context, {error, ewrongarg, Line,
        ?E_WARNING, Data}),
    undefined;

str_split(_Context, _Line, {_, Text}, {_, Size}) ->
    split_chars(Text, ephp_array:new(), 0, Size).

-spec print(context(), line(), var_value()) -> 1.

print(Context, _Line, {_,Value}) ->
    ValueStr = ephp_data:to_bin(Value),
    ephp_context:set_output(Context, ValueStr),
    1.

%% ----------------------------------------------------------------------------
%% Internal functions
%% ----------------------------------------------------------------------------

split_chars(<<>>, Parts, _I, _Size) ->
    Parts;

split_chars(String, Parts, I, Size) ->
    case String of
        <<Text:Size/binary,Rest/binary>> ->
            split_chars(Rest, ephp_array:store(I, Text, Parts), I+1, Size);
        <<Text/binary>> ->
            ephp_array:store(I, Text, Parts)
    end.

split_limit(Delimiter, String, Parts, Limit, 0) when Limit < 0 ->
    BinParts = binary:split(String, Delimiter, [global]),
    case length(BinParts) + Limit of
        NumParts when NumParts >= 0 ->
            {_,NewParts} = lists:foldl(fun
                (Part, {I,NP}) when I =< NumParts ->
                    {I+1, ephp_array:store(auto, Part, NP)};
                (_Part, Result) ->
                    Result
            end, {0,Parts}, BinParts),
            NewParts;
        _ ->
            Parts
    end;

split_limit(_Delimiter, String, Parts, Limit, Limit) ->
    ephp_array:store(Limit, String, Parts);

split_limit(Delimiter, String, Parts, Limit, Index) ->
    case binary:split(String, Delimiter) of
        [Part,RestString] ->
            NewParts = ephp_array:store(Index, Part, Parts),
            split_limit(Delimiter, RestString, NewParts, Limit, Index+1);
        [LastPart] ->
            ephp_array:store(Index, LastPart, Parts)
    end.

print_format(Format, Values) ->
    print_format(Format, {1, Values}, <<>>).

print_format(<<>>, _Values, Result) ->
    Result;
print_format(<<"%%",Rest/binary>>, Values, Result) ->
    print_format(Rest, Values, <<Result/binary, "%">>);
print_format(<<"%",_/binary>> = Text, Values, Result) ->
    E = "^%(\\d+\\$)?([+-]?)([ 0]|'.{1})?(-)?(\\d*)(\\.\\d+)?(.)",
    {NewValues, Output, Catched} =
    case re:run(Text, E, [{capture, all, binary}]) of
        {match, [Catched0,Order,Sign,Pad,Justify,Size,Decimal,Cmd]} ->
            {Value, Values0} = select_value(Order, Values),
            P = get_pad(Pad),
            J = get_justify(Justify),
            S = get_size(Size),
            D = get_decimal(Decimal),
            G = get_sign(Sign),
            Output0 = format(Cmd, G, P, J, S, D, Value),
            {Values0, Output0, Catched0}
    end,
    CatchedSize = byte_size(Catched),
    <<Catched:CatchedSize/binary,Rest/binary>> = Text,
    print_format(Rest, NewValues, <<Result/binary, Output/binary>>);
print_format(<<A/utf8,Rest/binary>>, Values, Result) ->
    print_format(Rest, Values, <<Result/binary,A/utf8>>).

select_value(<<>>, {I, Values}) ->
    {_, Val} = lists:nth(I, Values),
    {Val, {I+1, Values}};
select_value(Pos, {I, Values}) ->
    NPos = ephp_data:bin_to_number(Pos),
    {_, Val} = lists:nth(NPos, Values),
    {Val, {I, Values}}.

get_pad(<<>>) -> 32;
get_pad(<<Pad:8>>) -> Pad;
get_pad(<<"'",Pad:8>>) -> Pad.

get_decimal(<<>>) -> undefined;
get_decimal(<<".",Precision/binary>>) -> ephp_data:bin_to_number(Precision).

get_size(<<>>) -> ?PHP_INF;
get_size(Size) -> ephp_data:bin_to_number(Size).

get_justify(<<>>) -> right;
get_justify(<<"-">>) -> left.

get_sign(<<"+">>) -> true;
get_sign(_) -> false.

adjust(Text, _Pad, _Justify, ?PHP_INF) ->
    Text;
adjust(Text, Pad, Justify, Size) ->
    case Size - byte_size(Text) of
        PadSize when PadSize > 0 ->
            Padding = list_to_binary(lists:duplicate(PadSize, Pad)),
            case Justify of
                left -> <<Text/binary, Padding/binary>>;
                right -> <<Padding/binary, Text/binary>>
            end;
        _ ->
            Text
    end.

add_sign(true, Number, Binary) when Number >= 0 -> <<"+",Binary/binary>>;
add_sign(_, _, Binary) -> Binary.

format(<<"b">>, _Sign, Pad, Justify, Size, _Decimal, Value) ->
    Number = ephp_data:to_int(Value),
    Binary = integer_to_binary(trunc(Number), 2),
    adjust(Binary, Pad, Justify, Size);
format(<<"c">>, _Sign, _Pad, _Justify, _Size, _Decimal, Value) ->
    Number = ephp_data:to_int(Value),
    <<Number:8>>;
format(<<"d">>, Sign, Pad, Justify, Size, _Decimal, Value) ->
    Number = ephp_data:to_int(Value),
    Binary = integer_to_binary(Number),
    adjust(add_sign(Sign, Number, Binary), Pad, Justify, Size);
format(<<"e">>, Sign, Pad, Justify, Size, undefined, Value) ->
    Precision = ephp_config:get(<<"precision">>),
    Number = ephp_data:to_float(Value),
    Binary = float_to_binary(Number, [{scientific, Precision}, compact]),
    adjust(add_sign(Sign, Number, Binary), Pad, Justify, Size);
format(<<"e">>, Sign, Pad, Justify, Size, Precision, Value) ->
    Number = ephp_data:to_float(Value),
    Binary = float_to_binary(Number, [{scientific, Precision}, compact]),
    adjust(add_sign(Sign, Number, Binary), Pad, Justify, Size);
format(<<"E">>, Sign, Pad, Justify, Size, Decimal, Value) ->
    Result = format(<<"e">>, Sign, Pad, Justify, Size, Decimal, Value),
    ephp_string:to_upper(Result);
format(<<"f">>, Sign, Pad, Justify, Size, undefined, Value) ->
    Precision = ephp_config:get(<<"precision">>),
    Number = ephp_data:to_float(Value),
    Binary = float_to_binary(Number, [{decimals, Precision}]),
    adjust(add_sign(Sign, Number, Binary), Pad, Justify, Size);
format(<<"f">>, Sign, Pad, Justify, Size, Precision, Value) ->
    Number = ephp_data:to_float(Value),
    Binary = float_to_binary(Number, [{decimals, Precision}]),
    adjust(add_sign(Sign, Number, Binary), Pad, Justify, Size);
format(<<"F">>, Sign, Pad, Justify, Size, Decimal, Value) ->
    Result = format(<<"f">>, Sign, Pad, Justify, Size, Decimal, Value),
    ephp_string:to_upper(Result);
format(<<"g">>, Sign, Pad, Justify, Size, undefined, Value) ->
    Precision = ephp_config:get(<<"precision">>),
    Number = ephp_data:to_float(Value),
    Binary = float_to_binary(Number, [{decimals, Precision}, compact]),
    adjust(add_sign(Sign, Number, Binary), Pad, Justify, Size);
format(<<"g">>, Sign, Pad, Justify, Size, Precision, Value) ->
    Number = ephp_data:to_float(Value),
    Binary = float_to_binary(Number, [{decimals, Precision}, compact]),
    adjust(add_sign(Sign, Number, Binary), Pad, Justify, Size);
format(<<"G">>, Sign, Pad, Justify, Size, Decimal, Value) ->
    Result = format(<<"g">>, Sign, Pad, Justify, Size, Decimal, Value),
    ephp_string:to_upper(Result);
format(<<"o">>, _Sign, Pad, Justify, Size, _Decimal, Value) ->
    Number = ephp_data:to_int(Value),
    Binary = integer_to_binary(trunc(Number), 8),
    adjust(Binary, Pad, Justify, Size);
format(<<"s">>, _Sign, Pad, Justify, Size, _Decimal, Value) ->
    adjust(ephp_data:to_bin(Value), Pad, Justify, Size);
format(<<"u">>, _Sign, Pad, Justify, Size, _Decimal, Value) ->
    Number = ephp_data:to_int(Value),
    SNumber = if
        Number < 0 -> abs(?PHP_INT_MIN - Number);
        true -> Number
    end,
    Binary = integer_to_binary(SNumber),
    adjust(Binary, Pad, Justify, Size);
format(<<"X">>, _Sign, Pad, Justify, Size, _Decimal, Value) ->
    Number = ephp_data:to_int(Value),
    Binary = integer_to_binary(trunc(Number), 16),
    adjust(Binary, Pad, Justify, Size);
format(<<"x">>, Sign, Pad, Just, Size, Dec, Value) ->
    ephp_string:to_lower(format(<<"X">>, Sign, Pad, Just, Size, Dec, Value));
format(_Cmd, _Sign, _Pad, _Just, _Size, _Dec, _Value) ->
    <<>>.
