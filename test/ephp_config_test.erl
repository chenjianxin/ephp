-module(ephp_config_test).
-author('manuel@altenwald.com').
-compile([warnings_as_errors, export_all]).

-include_lib("eunit/include/eunit.hrl").
-include("ephp.hrl").

config_wrong_file_test() ->
    ok = ephp_config:start_link("test/php_test.ini_WRONG"),
    ?assertEqual(14, ephp_config:get(<<"precision">>)),
    ?assertNot(lists:member(ephp_lib_test, ephp_config:get(modules))),
    ?assertEqual(undefined, ephp_config:get(<<"test">>)),
    ok.

config_test() ->
    ok = ephp_config:start_link("test/php_test.ini"),
    ?assertEqual(20, ephp_config:get(<<"precision">>)),
    ?assert(lists:member(ephp_lib_test, ephp_config:get(modules))),
    ?assertEqual(<<"true">>, ephp_config:get(<<"test">>)),
    ok.