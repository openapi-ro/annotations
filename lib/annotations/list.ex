defmodule Annotations.List do
  alias Annotations.Annotation
  require Logger
  @doc """
    Operations on lists of Annotations
  """
  def tag(str,%Regex{}=re) do
    tag(str,re, [:default])
  end
  def tag(str,%Regex{}=re , fun ) when is_function(fun) do
    scan(str, re, fun, [return: :index])
  end
  def tag(str,%Regex{}=re , tags) when is_list(tags)  do
    scan(str, re, fn [{from,to}] -> Annotation.new(from,to,tags) end, [return: :index])
  end
  def tag(str,%Regex{}=re , tag) do
    tag(str,re, [tag])
  end
  def tag(str,%Regex{}=re , fun, scan_options) when is_function(fun) and is_list(scan_options)do
    scan(str, re, fun, scan_options)
  end
  def tag(str,%Regex{}=re , tags, scan_options) when is_list(tags) and is_list(scan_options) do
    scan(str, re, fn [{from,to}] -> Annotation.new(from,to,tags) end, scan_options)
  end
  def tag(str,%Regex{}=re , tag, scan_options) when is_list(scan_options) do
    tag(str, re, [tag], scan_options)
  end

  def sort([]), do: []
  def sort([%Annotation{}]=list), do: list
  def sort([%Annotation{}|_more_annotations]=list) do
    Enum.sort_by(list, &(&1.from))
  end
  defmacro ranges_overlap(a, b) do
    quote do
      is_tuple(unquote(a)) and is_tuple(unquote(b)) and tuple_size(unquote(a))==2 and tuple_size(unquote(b)) == 2 and
      (
        (
          elem(unquote(a),0) <= elem(unquote(b),0) and elem(unquote(a),1) >= elem(unquote(b),0)
        ) or (
          elem(unquote(a),0) < elem(unquote(b),1) and elem(unquote(a),1) >= elem(unquote(b),1)
        ) or (
          elem(unquote(a),0) >= elem(unquote(b),0) and elem(unquote(a),1) <= elem(unquote(b),1)
        )
      )
    end
  end
  @doc """
    Same as &extract_ranges/2 but for a single range
  """
  def extract_range([%Annotation{}|_rest]=anns,{from,to}=range), do: extract_ranges(anns, [range])
  @doc """
    Extracts the annotations which overlap with any of the ranges supplied in sorted_ranges.

  """
  def extract_ranges(anns, sorted_ranges) do
    {result,_remaining}=
      sorted_ranges
      |>Enum.reduce_while({[], anns}, fn {from,to}=range, {result,remaining}->
        {result,remaining}=
          remaining
          |> Enum.reduce({result, []}, fn
            %Annotation{to: ann_to}, {result, remaining} when ann_to<=from ->
              {result,remaining}
            %Annotation{from: ann_from, to: ann_to}=ann, {result, remaining} when ranges_overlap({ann_from, ann_to}, range) ->
              {[ann|result], remaining}
            %Annotation{from: ann_from, to: ann_to}=ann, {result,remaining} ->
              {result , [ann|remaining]}
            end)
        case remaining do
          [] -> {:halt, {result,[]}}
          remaining -> {:cont, {result,Enum.reverse(remaining)}}
        end
      end)
    result
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
  def scan(str, %Regex{}=re, ann_creator, options \\ [return: :index]) when is_bitstring(str) and is_function(ann_creator) do
    options=
      if is_nil(options) do
        Logger.warn("#{__MODULE__}.scan: Forced options argument to [return: :index] because it was nil")
        [return: :index]
      else
        case Keyword.get( options, :return) do
          :index-> options
          nil->
            Logger.warn("#{__MODULE__}.scan: Force-added options argument {return: :index} because it was missing")
            Keyword.put(options, :return, :index)
        end
      end
    Regex.scan(re, str,options)
    |> Enum.map( fn match_set ->
        match_set
        |>Stream.map( fn match -> grapheme_match_indexes(str,match) end)
        |>Enum.map(fn {from,len}-> {from, from+len} end)
        |>ann_creator.()
      end)
    |> List.flatten()
  end
  def tag_all_except(str,[], tag) when is_atom(tag) and is_bitstring(str) do
    tag_all_except(str,[],[tag])
  end
  def tag_all_except(str,[], tags) when is_list(tags) and is_bitstring(str) do
    [%Annotation{from: 0, to: String.length(str), tags: tags}]
  end
  def tag_all_except(str, [%Annotation{}|_rest]=exclude_ann, tags) when is_list(tags) and is_bitstring(str) do
    annotate_all_except(str,exclude_ann, fn  from,to -> %Annotation{from: from, to: to, tags: tags} end)
  end
  def tag_all_except(str, [%Annotation{}|_rest]=exclude_ann, tag) do
    tag_all_except(str,exclude_ann,[tag])
  end
  def annotate_all_except(str, [%Annotation{}|_rest]=exclude_ann, tag_creator) when is_function(tag_creator) and is_bitstring(str) do
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
        Enum.reverse([{cur,str_len}]++[last|rest])
      _-> Enum.reverse(acc.ranges)
    end
    |> Enum.map( fn {from,to}-> tag_creator.(from,to) end)
  end
  def disjoint?(list) do
    disjoint?(list , fn _-> true end,[])
  end
  def disjoint?(list, any) do
    disjoint?(list , any ,[])
  end
  def disjoint?(list, tag,options) when is_atom(tag) do
    disjoint?(list, fn ann -> Annotation.has_tag?(ann, tag) end)
  end
  def disjoint?(list, tags, options) when is_list(tags) do
    disjoint? list, MapSet.new(tags), []
  end
  def disjoint?(list, %MapSet{}=tags, options)  do
    disjoint?(list,  fn ann->
      case  ann.tags do
        []->false
        [one]-> MapSet.member? tags, one
        many-> MapSet.disjoint? tags, MapSet.new(many)
      end
     end)
  end
  @doc """
    Returns true if no annotation from `list` overlaps with another one.
    `consider_func` returns a truth value. Only annotations for which the result
    of `consider_func(annotation)` is truthish is considered for disjoint testing

    See `Annotation.disjoint?/2` for an explanation of testing whether two annotations
    are disjoint
  """
  def disjoint?(list, consider_func, options) when is_function(consider_func) do
    list=
      if options[:sorted] do
        list
      else
        list|> Enum.sort_by(&(&1.from))
      end
    ret=
      list
      |> Enum.reduce_while( nil, fn
          ann, nil->
            if consider_func.(ann) do
              {:cont,ann}
            else
              {:cont,nil}
            end
          ann , last ->
            if consider_func.(ann) do
              if Annotation.overlaps?(ann, last) do
                {:halt,false}
              else
                {:cont, ann}
              end
            else
              {:cont, last}
            end
      end)
    if ret do
      true
    else
      false
    end
  end
  defp reduce_stack(stack, to) do
    Enum.reduce(stack, {nil, []} , fn ann, {last_to, new_stack} ->
      new_stack=
      if ann.to < to do
        new_stack
      else
        [ann]++new_stack
      end
      if is_nil(last_to) do
        {ann.to,stack}
      else
        {max(ann.to, last_to), stack}
      end
    end)
  end
  def select_annotation_ranges( list, consider? \\ fn _ -> true end , options \\[]) do
    list=
      unless options[:sorted] do
        Enum.sort_by(list, &(&1.from))
      else
        list
      end
    {stack,ranges}=
    Enum.reduce(list, {[], []}, fn
      ann, {stack, ranges}->
        {open, ranges}=
        case ranges do
          []-> {nil,[]}
          [open|ranges] when is_integer(open)-> {open,ranges}
          ranges -> {nil, ranges}
        end
        {prev_last,new_stack}=reduce_stack(stack, ann.from)
        if consider?.(ann) do
          cond do
            is_nil(prev_last) -> {[ann], [ann.from]++ranges}
            prev_last < ann.from ->   {[ann], [ann.from,{open, prev_last}]++ranges}
            true->{new_stack++[ann], [open]++ranges}
          end
        else
          cond do
            is_nil(prev_last)-> {[], ranges}
            prev_last < ann.from -> {[], [{open,prev_last}]++ranges}
            true->{new_stack, [open]++ranges}
          end
        end
    end)
    prev_last = Enum.reduce( stack, 0, fn ann,acc -> max(ann.to, acc) end)
    if prev_last do
      case ranges do
        [open| ranges] when is_integer(open) -> [{open,prev_last}]++ ranges #close last range
        ranges ->
          if prev_last do
            ##when we have a prev_last we must also have an open
            Logger.error("prev_last without a previous open. Error???")
            #require IEx
            #IEx.pry
          end
          ranges  #no open range
      end
    else
      ranges
    end
    |> Enum.reverse()

  end
  defp check_single_tag_fun(tag) do
    fn
      %Annotation{tags: [^tag|_] } -> true
      %Annotation{tags: [] } -> false
      %Annotation{tags: cmp } -> MapSet.member?(MapSet.new(cmp), tag)
    end
  end
  def filter_tags(list, tags) do
    fun=
      case tags do
        tag when is_atom(tags) -> check_single_tag_fun(tag)
        [tag] when is_atom(tag) ->check_single_tag_fun(tag)
        tags ->
            tags= MapSet.new(tags)
            fn
              %Annotation{tags: [] } -> false
              %Annotation{tags: cmp } -> not MapSet.disjoint?(MapSet.new(cmp), tags)
            end
      end
    list
    |> filter( fun )
  end

  def filter(list, fun) do
    list
    |> Enum.filter(fun)
  end
end
