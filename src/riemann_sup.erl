% License: Apache License, Version 2.0
%
% Copyright 2013 Aircloak
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%     http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.

%% @author Sebastian Probst Eide <sebastian@aircloak.com>
%% @copyright Copyright 2013 Aircloak
-module(riemann_sup).

-behaviour(supervisor).

%% API
-export([start_link/0,
         next_process/0
        ]).

%% Supervisor callbacks
-export([init/1]).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

-define(TABLE, riemann).

process_name (N) ->
  list_to_atom (lists:flatten(["riemann_",integer_to_list (N)])).

next_process () ->
  % just round robin
  NumProcesses = erlang:system_info(schedulers),
  N = ets:update_counter (?TABLE, count, {2, 1, NumProcesses, 1}),
  process_name (N).

init([]) ->

  % number of processes spawned should probably be config, but
  % this is a dirty hack
  NumProcesses = erlang:system_info(schedulers),

  % very poor form to do this in the supervisor, but this is a
  % quick hack to see if this will work for me, once I figure it
  % out I might do the right thing and have another process
  % hold the table
  ets:new (?TABLE, [set, public, named_table,
                    {keypos, 1}, {write_concurrency, true},
                    {read_concurrency, true}]),
  ets:insert (?TABLE, {count, 1}),

  Processes = [
                begin
                  Name = process_name (N),
                  { Name,
                    {riemann, start_link, [Name]},
                    permanent,
                    5000,
                    worker,
                    [riemann]
                  }
                end
                || N <- lists:seq (1, NumProcesses)
              ],
  {ok, {{one_for_one, 5, 10}, Processes}}.
