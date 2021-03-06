-module(cre_wm_multi).
-export([
         init/1,
         service_available/2,
         allowed_methods/2,
         to_json/2,
         content_types_provided/2,
         resource_exists/2
        ]).

-include_lib("webmachine/include/webmachine.hrl").

-record(ctx, {
          bucket,
          keys,
          objects
         }).

%%% -- webmachine hooks

init(_) ->
    {ok, #ctx{}}.

service_available(ReqData, Context=#ctx{}) ->
    {
      true,
      ReqData,
      Context#ctx{
        bucket = wrq:path_info(bucket, ReqData),
        keys = wrq:path_info(keys, ReqData)
       }
    }.

allowed_methods(ReqData, Context) ->
    {['GET'], ReqData, Context}.

%% For simplicity, we're assuming all objects are json or plain text
content_types_provided(ReqData, Context) ->
    {[{"application/json", to_json}], ReqData, Context}.

to_json(ReqData, Context) ->
    {Context#ctx.objects, ReqData, Context}.

resource_exists(ReqData, Context) ->
    C1 = ensure_objects(Context),
    case C1#ctx.objects of
        undefined -> {false, ReqData, C1};
        _ -> {true, ReqData, C1}
    end.

%%% Internal functions

ensure_objects(Context) ->
    KeyList = string:tokens(Context#ctx.keys, ","),
    Results = build_results(Context#ctx.bucket, KeyList, []),
    Context#ctx{objects = Results}.

build_results(Bucket, [Key|Rest], Results) ->
    Value = case get(client(), list_to_binary(Bucket), list_to_binary(Key)) of
                {value, V} ->
                    binary_to_list(V);
                {error, Reason} ->
                    Reason
            end,

    build_results(Bucket, Rest, [{Key, Value}|Results]);
build_results(_, [], Results) ->
    lists:flatten(mochijson:encode({struct, Results})).

client() ->
    {ok,C} = riak:local_client(),
    C.

get(C, Bucket, Key) ->
    case C:get(Bucket, Key) of
        {ok, O} ->
            {value, riak_object:get_value(O)};
        Other ->
            Other
    end.
