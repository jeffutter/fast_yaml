%%%-------------------------------------------------------------------
%%% @author Evgeniy Khramtsov <>
%%% @copyright (C) 2013, Evgeniy Khramtsov
%%% @doc
%%%
%%% @end
%%% Created :  7 Aug 2013 by Evgeniy Khramtsov <>
%%%-------------------------------------------------------------------
-module(p1_yaml).

%% API
-export([load_nif/0, load_nif/1, decode/1, decode/2, start/0, stop/0,
         decode_file/1, decode_file/2]).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-type option() :: {plain_as_atom, boolean()}.
-type options() :: [option()].

-define(PLAIN_AS_ATOM, 1).

%%%===================================================================
%%% API
%%%===================================================================
start() ->
    application:start(p1_yaml).

stop() ->
    application:stop(p1_yaml).

load_nif() ->
    load_nif(get_so_path()).

load_nif(LibDir) ->
    SOPath = filename:join(LibDir, "p1_yaml"),
    case catch erlang:load_nif(SOPath, 0) of
        ok ->
            ok;
        Err ->
            error_logger:warning_msg("unable to load p1_yaml NIF: ~p~n", [Err]),
            Err
    end.

-spec decode(iodata()) -> {ok, term()} | {error, binary()}.

decode(Data) ->
    decode(Data, []).

-spec decode_file(string()) -> {ok, term()} | {error, binary()}.

decode_file(File) ->
    decode_file(File, []).

-spec decode_file(string(), options()) -> {ok, term()} | {error, binary()}.

decode_file(File, Opts) ->
    case file:read_file(File) of
        {ok, Data} ->
            decode(Data, Opts);
        Err ->
            Err
    end.

-spec decode(iodata(), options()) -> {ok, term()} | {error, binary()}.

decode(Data, Opts) ->
    nif_decode(Data, make_flags(Opts)).

%%%===================================================================
%%% Internal functions
%%%===================================================================
get_so_path() ->
    case os:getenv("EJABBERD_SO_PATH") of
        false ->
            case code:priv_dir(p1_yaml) of
                {error, _} ->
                    filename:join(["priv", "lib"]);
                Path ->
                    filename:join([Path, "lib"])
            end;
        Path ->
            Path
    end.

make_flags([{plain_as_atom, true}|Opts]) ->
    ?PLAIN_AS_ATOM bor make_flags(Opts);
make_flags([{plain_as_atom, false}|Opts]) ->
    make_flags(Opts);
make_flags([plain_as_atom|Opts]) ->
    ?PLAIN_AS_ATOM bor make_flags(Opts);
make_flags([Opt|Opts]) ->
    error_logger:warning_msg("p1_yaml: unknown option ~p", [Opt]),
    make_flags(Opts);
make_flags([]) ->
    0.

nif_decode(_Data, _Flags) ->
    error_logger:error_msg("p1_yaml NIF not loaded", []),
    erlang:nif_error(nif_not_loaded).

%%%===================================================================
%%% Unit tests
%%%===================================================================
-ifdef(TEST).

load_nif_test() ->
    ?assertEqual(ok, load_nif(filename:join(["..", "priv", "lib"]))).

decode_file1_test() ->
    FileName = filename:join(["..", "test", "test1.yml"]),
    ?assertEqual(
       {ok,[[{<<"Time">>,<<"2001-11-23 15:01:42 -5">>},
             {<<"User">>,<<"ed">>},
             {<<"Warning">>,
              <<"This is an error message for the log file">>}],
            [{<<"Time">>,<<"2001-11-23 15:02:31 -5">>},
             {<<"User">>,<<"ed">>},
             {<<"Warning">>,<<"A slightly different error message.">>}],
            [{<<"Date">>,<<"2001-11-23 15:03:17 -5">>},
             {<<"User">>,<<"ed">>},
             {<<"Fatal">>,<<"Unknown variable \"bar\"">>},
             {<<"Stack">>,
              [[{<<"file">>,<<"TopClass.py">>},
                {<<"line">>,23},
                {<<"code">>,<<"x = MoreObject(\"345\\n\")\n">>}],
               [{<<"file">>,<<"MoreClass.py">>},
                {<<"line">>,58},
                {<<"code">>,<<"foo = bar">>}]]}]]},
       decode_file(FileName)).

decode_test2_test() ->
    FileName = filename:join(["..", "test", "test2.yml"]),
    ?assertEqual(
       {ok,[[[{step,[{instrument,<<"Lasik 2000">>},
                     {pulseEnergy,5.4},
                     {pulseDuration,12},
                     {repetition,1000},
                     {spotSize,<<"1mm">>}]}],
             [{step,[{instrument,<<"Lasik 2000">>},
                     {pulseEnergy,5.0},
                     {pulseDuration,10},
                     {repetition,500},
                     {spotSize,<<"2mm">>}]}],
             [{step,<<"id001">>}],
             [{step,<<"id002">>}],
             [{step,<<"id001">>}],
             [{step,<<"id002">>}]]]},
       decode_file(FileName, [plain_as_atom])).

decode_test3_test() ->
    FileName = filename:join(["..", "test", "test3.yml"]),
    ?assertEqual(
       {ok,[[{<<"a">>,123},
             {<<"b">>,<<"123">>},
             {<<"c">>,123.0},
             {<<"d">>,123},
             {<<"e">>,123},
             {<<"f">>,<<"Yes">>},
             {<<"g">>,<<"Yes">>},
             {<<"h">>,<<"Yes we have No bananas">>}]]},
       decode_file(FileName)).

decode_test4_test() ->
    FileName = filename:join(["..", "test", "test4.yml"]),
    ?assertEqual(
       {ok,[[{<<"picture">>,
              <<"R0lGODlhDAAMAIQAAP//9/X\n17unp5WZmZgAAAOfn515eXv\n"
                "Pz7Y6OjuDg4J+fn5OTk6enp\n56enmleECcgggoBADs=mZmE\n">>}]]},
       decode_file(FileName)).

-endif.
