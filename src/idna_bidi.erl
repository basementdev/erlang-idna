%%%-------------------------------------------------------------------
%%% @author benoitc
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 08. Aug 2018 14:50
%%%-------------------------------------------------------------------
-module(idna_bidi).
-author("benoitc").

%% API
-export([check_bidi/1, check_bidi/2]).

check_bidi(Label) -> check_bidi(Label, false).

check_bidi(Label, CheckLtr) ->
  %% Bidi rules should only be applied if string contains RTL characters
  case {check_rtl(Label, Label), CheckLtr} of
    {false, false}  -> true;
    _ ->
      [C | Rest] = Label,
      % bidi rule 1
      RTL = rtl(C, Label),
      check_bidi1(Rest, RTL, false, undefined)
  end.

check_rtl([C | Rest], Label) ->
  case idna_data:lookup(C) of
    false ->
      erlang:exit(bidi_error("unknown directionality in label=~p c=~w~n", [Label, C]));
    {_, Dir} ->
      case lists:member(Dir, ["R", "AL", "AN"]) of
        true -> check_rtl(Rest, Label);
        false -> false
      end
  end.

rtl(C, Label) ->
  case idna_data:lookup(C) of
    {_, "R"} -> true;
    {_, "AL"} -> true;
    {_, "L"} -> false;
    _ ->
      erlang:exit(bidi_error("first codepoint in label ~p must be directionality L, R or AL ", [Label]))
  end.


check_bidi1([C | Rest], true, ValidEnding, NumberType) ->
  {_, Dir} =  idna_data:lookup(C),
  %% bidi rule 2
  ValidEnding2 = case lists:member(C,  ["R", "AL", "AN", "EN", "ES", "CS", "ET", "ON", "BN", "NSM"]) of
                  true ->
                    % bidi rule 3
                    case lists:member(C, ["R", "AL", "AN", "EN"]) of
                      true  -> true;
                      false when Dir =/= "NSM" -> false;
                      false -> ValidEnding
                    end;
                  false ->
                    erlang:exit({bad_label, {bidi, "Invalid direction for codepoint  in a right-to-left label"}})
                end,
  % bidi rule 4
  NumberType2 = case {Dir, NumberType} of
                 {"AN", undefined} -> Dir;
                 {"EN", undefined} -> Dir;
                 {NumberType, NumberType} -> NumberType;
                 _ ->
                   erlang:exit({bad_label, {bidi, "Can not mix numeral types in a right-to-left label"}})
               end,
  check_bidi1(Rest, true, ValidEnding2, NumberType2);
check_bidi1([C | Rest], false, ValidEnding, NumberType) ->
  {_, Dir} =  idna_data:lookup(C),
  % bidi rule 5
  ValidEnding2 = case lists:member(Dir, ["L", "EN", "ES", "CS", "ET", "ON", "BN", "NSM"]) of
                   true ->
                     % bidi rule 6
                     case Dir of
                       "L" -> true;
                       "EN" -> true;
                       _ when Dir /= "NSM" -> false;
                       _ -> ValidEnding
                     end;
                   false ->
                     erlang:exit({bad_label, {bidi, "Invalid direction for codepoint in a left-to-right label"}})
                 end,
  check_bidi1(Rest, false, ValidEnding2, NumberType);
check_bidi1([], _, false, _) ->
  erlang:exit({bad_label, {bidi, "Label ends with illegal codepoint directionality"}});
check_bidi1([], _, true, _) ->
  ok.

bidi_error(Msg, Fmt) ->
  ErrorMsg = lists:flatten(io_lib:format(Msg, Fmt)),
  {bad_label, {bidi, ErrorMsg}}.
