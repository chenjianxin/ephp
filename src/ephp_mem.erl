-module(ephp_mem).
-author('manuel@altenwald.com').
-compile([warnings_as_errors, {no_auto_import, [get/1]}]).

-include("ephp.hrl").

-export([
    start_link/0,
    stop/0,
    get/1,
    remove/1,
    set/2,
    add_link/1,
    add/1
]).

-record(mem, {
    data :: mixed,
    links = 1 :: pos_integer()
}).

-type mem() :: #mem{}.

-type mem_id() :: pos_integer().

-spec start_link() -> {ok, module()}.
%% @doc starts the memory storage system for referenced data.
start_link() ->
    case erlang:get(get_id()) of
        Mem when is_list(Mem) ->
            ok;
        _ ->
            erlang:put(get_id(), array:new({default, free}))
    end,
    {ok, get_id()}.


-spec get_id() -> module().
%% @hidden
%% @doc retrieve the name of the ID in use to storage the information in the
%%      dictionary process.
%% @end
get_id() ->
    ?MODULE.


-spec stop() -> ok.
%% @doc remove the information about the links for the referenced data.
stop() ->
    Ref = get_id(),
    erlang:erase(Ref),
    ok.


-spec get(mem_id()) -> any().
%% @doc get the content for a specific MemId.
get(MemId) ->
    Ref = get_id(),
    Mem = erlang:get(Ref),
    case array:get(MemId, Mem) of
        free -> throw(segmentation_fault);
        #mem{data = Data} -> Data
    end.


-spec remove(mem_id()) -> ok.
%% @doc removes an entry given by MemId in the storage data.
remove(MemId) ->
    Ref = get_id(),
    Mem = erlang:get(Ref),
    NewMem = case array:get(MemId, Mem) of
        free ->
            throw(segmentation_fault);
        #mem{links = Links} when Links =:= 1 ->
            array:set(MemId, free, Mem);
        #mem{links = Links} = MemData ->
            array:set(MemId, MemData#mem{links = Links - 1}, Mem)
    end,
    erlang:put(Ref, NewMem),
    ok.


-spec set(mem_id(), Data :: any()) -> ok.
%% @doc stores the element in the position required.
set(MemId, Data) ->
    Ref = get_id(),
    Mem = erlang:get(Ref),
    MemData = #mem{data = Data},
    NewMem = array:set(MemId, MemData, Mem),
    erlang:put(Ref, NewMem),
    ok.


-spec add_link(mem_id()) -> ok.
%% @doc increase the links attribute for a specific MemId.
add_link(MemId) ->
    Ref = get_id(),
    Mem = erlang:get(Ref),
    NewMem = case array:get(MemId, Mem) of
        free ->
            throw(segmentation_fault);
        #mem{links = Links} = MemData ->
            array:set(MemId, MemData#mem{links = Links + 1}, Mem)
    end,
    erlang:put(Ref, NewMem),
    ok.

-spec add(Data :: any()) -> mem_id().
%% @doc adds information for the storage and returns the MemId to access later
%%      to that information.
%% @end
add(Data) ->
    MemData = #mem{data = Data},
    Ref = get_id(),
    Mem = erlang:get(Ref),
    MemId = search_empty(Mem),
    NewMem = array:set(MemId, MemData, Mem),
    erlang:put(Ref, NewMem),
    MemId.


-spec search_empty(mem()) -> mem_id().
%% @hidden
%% @doc search for a free index inside of the storage.
search_empty(Mem) ->
    search_empty(1, Mem).

-spec search_empty(I :: pos_integer(), mem()) -> mem_id().
%% @hidden
%% @doc search for a free index inside of the storage. Recursive function.
search_empty(I, Mem) ->
    case array:get(I, Mem) of
        free -> I;
        _ -> search_empty(I+1, Mem)
    end.