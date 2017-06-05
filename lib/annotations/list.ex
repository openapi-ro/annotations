defmodule Annotations.List do
  alias Annotations.Annotation
  @doc """
    Operations on lists of Annotations
  """
  def tag(str,%Regex{}=re) do
    tag(str,re, [:default])
  end
  def tag(str,%Regex{}=re , tags) when is_list(tags) do
    scan(str, re, fn [{from,to}] -> Annotation.new(from,to,tags) end)
  end
  def tag(str,%Regex{}=re , tag) do
    tag(str,re, [tag])
  end



  defp get_index(_string, {pos, _len}) when pos < 0 do
    ""
  end
  # taken from https://github.com/elixir-lang/elixir/blob/v1.4.4/lib/elixir/lib/regex.ex##L683
  defp get_index(string, {pos, len}) do
    <<_::size(pos)-binary, res::size(len)-binary, _::binary>> = string
    res
  end
  @doc """
    translates {from,len} tuples in binaty size to {from,len} in Grapheme sizes usable by String.
  """
  defp grapheme_match_indexes(str,{from, len}) when from >=0 and len >=0  do
    <<pre::binary-size(from), match::binary-size(len), _::binary>>=str
          {String.length(pre),
          String.length(match)}
  end
  def scan(str, %Regex{}=re, ann_creator) when is_bitstring(str) and is_function(ann_creator) do
    Regex.scan(re, str, return: :index)
    |> Enum.map( fn match_set -> 
        match_set
        |>Stream.map( fn match -> grapheme_match_indexes(str,match) end)
        |>Enum.map(fn {from,len}-> {from, from+len} end)
        |>ann_creator.()
      end)
    |> List.flatten()
  end
  def tag_all_except(str, [%Annotation{}|_rest]=exclude_ann, tags) when is_list(tags) do
    annotate_all_except(str,exclude_ann, fn  from,to -> %Annotation{from: from, to: to, tags: tags} end)
  end
  def tag_all_except(str, [%Annotation{}|_rest]=exclude_ann, tag) do
    tag_all_except(str,exclude_ann,[tag])
  end
  def annotate_all_except(str, [%Annotation{}|_rest]=exclude_ann, tag_creator) when is_function(tag_creator) do
    str_len = String.length(str)
    acc=
      exclude_ann
      |> Stream.filter( &(Annotation.length(&1)!=0))
      |> Enum.sort_by( &(&1.from))
      |> Enum.reduce( %{cur: 0, ranges: []} , fn 
          %Annotation{from: from, to: to }, 
          %{cur: cur}=acc  when (
            cur<from
            )->
            %{ cur: to,
              ranges: [{cur,from}]++ acc.ranges
            }
          %Annotation{to: to },  %{cur: cur}=acc->
            %{acc| cur: Enum.max([to, cur])}
          _ann, acc-> acc
      end )

    case acc do
      %{ranges: [last| rest], cur: cur} when cur<str_len ->
        Enum.reverse([{cur,str_len}]++last++rest)
      _-> Enum.reverse(acc.ranges)
    end
    |> Enum.map( fn {from,to}-> tag_creator.(from,to) end)
  end
end