
defmodule Annotations.AnnotatedString.StringImporter do
  defmacro __using__(funcs) do
    for {name,arity} <-funcs do
      arg_names=
        if arity >1 do
          2..arity
          |>Enum.map( &(String.to_atom("arg#{&1}")))
          |>Enum.map(fn name->{name,[],Elixir} end)
        else
          []
        end
      quote do
        def unquote(name)( arg, unquote_splicing( arg_names)) do
          args =
             [arg,unquote_splicing(arg_names)]
             |> Enum.map(fn
              %Annotations.AnnotatedString{str: arg}->arg
              other->arg
           end)
          case apply(String, unquote(name), args) do
            str when is_bitstring(str)-> %Annotations.AnnotatedString{arg| str: str}
            other-> other
          end
        end
      end
    end
  end
end
defmodule Annotations.AnnotatedString do
  alias Annotations.Annotation
  defstruct str: nil,
    annotations: []
  def md5(%__MODULE__{str: str}) do
    :crypto.hash(:md5, str)
  end
  def md5_str(%__MODULE__{}=ann_str) do
    ann_str
    |> md5()
    |> Base.encode16()
  end
  def new({str,annotations}) do
    %__MODULE__{str: str, annotations: annotations}
  end
  def new(str) when is_bitstring(str) do
    %__MODULE__{str: str, annotations: []}
  end
  def new(str, annotations) do
    annotations =
      case annotations do
         %Annotation{}-> [annotations]
         _ when is_list(annotations)-> annotations
      end
    %__MODULE__{str: str, annotations: annotations}
  end

  def to_string(%__MODULE__{str: str}) do
    str
  end
  def __not_masked__() do
    str_funcs=MapSet.new(String.__info__(:functions))
    MapSet.difference(str_funcs,
      MapSet.new(__MODULE__.__info__(:functions)))
  end
  def scan(%__MODULE__{str: str, annotations: _anns} ,%Regex{}=re, fun) do
    Annotations.List.tag(str,re,fun)
  end
  # A lot of functions must still be implemented
  use Annotations.AnnotatedString.StringImporter, [
    length: 1,
    starts_with?: 2,
    equivalent?: 2,
    ends_with?: 2,
    contains?: 2,
    printable?: 1,
    jaro_distance: 2,
    next_grapheme_size: 1,
    valid?: 1,
    downcase: 1,
    upcase: 1,
    capitalize: 1,
    to_charlist: 1,
    to_integer: 2,
    to_float: 1,
    normalize: 2, #this is ok since annotations use string indices
    #:trim_trailing: 2,
    #:trim: 2,
    #:to_integer: 1,
    #:pad_leading: 2,
    #:replace_suffix: 3,
    #:ljust: 3,
    #:split: 2,
    #:strip: 1,
    #:splitter: 3,
    #:trim_leading: 2,
    #:first: 1,
    #:trim: 1,
    #:rstrip: 2,
    #:slice: 2,
    #:pad_trailing: 3,
    #:valid_character?: 1,
    #:replace: 4,
    #:slice: 3,
    #:myers_difference: 2,
    #:graphemes: 1,
    #:to_char_list: 1,
    #:rjust: 3,
    #:split: 3,
    #:reverse: 1,
    #:last: 1,
    #:lstrip: 2,
    #:chunk: 2,
    #:replace: 3,
    #:match?: 2,
    #:pad_trailing: 2,
    #:replace_leading: 3,
    #:trim_leading: 1,
    #:pad_leading: 3,
    #:replace_prefix: 3,
    #:lstrip: 1,
    #:codepoints: 1,
    #:trim_trailing: 1,
    #:ljust: 2,
    #:splitter: 2,
    #:strip: 2,
    #:at: 2,
    #:split: 1,
    #:replace_trailing: 3,
    #:next_grapheme: 1,
    #:rstrip: 1,
    #:duplicate: 2,
    #:to_atom: 1,
    #:next_codepoint: 1,
    #:rjust: 2,
    #:split_at: 2,
    #:to_existing_atom: 1,
  ]
  def split(%__MODULE__{}=arg) do
    split(arg," ")
  end
  @doc """
    splits the Annotated string in two. Each String keeps the Annotations referring to itsaelf.
    Annotations spanning split boundaries are duplicated to each neighboring chunk
  """
  def split(%__MODULE__{}=ann_str, splitter) , do: split(ann_str,splitter,[])
  def split(%__MODULE__{str: str, annotations: anns}, splitter, orig_options ) when is_bitstring(splitter) do
    splitter_len =String.length(splitter)

    {_,ret,_}=
      String.split(str,splitter,orig_options)
      |>Enum.reduce({0,[], anns}, fn
          str_chunk, {start_idx,result, anns} ->
            chunk_len=String.length(str_chunk)
            chunk_anns =
              anns
              |> Enum.filter(fn %Annotation{to: to} ->
                to<= start_idx + chunk_len
              end)
              |>Enum.map(fn ann ->
                case Annotation.offset(ann, -start_idx) do
                  nil->nil
                  %Annotation{ to: to} = ann when to > chunk_len -> %Annotation{ann| to: chunk_len}
                  %Annotation{}= ann -> ann
                end
              end)
              |>Enum.filter(&(&1)) # nils represent annotations which apply to previous chunks only
            new_start_idx=start_idx+chunk_len+splitter_len
            #filter initial annotations to remove
            anns =
              anns
              |>Enum.filter(&(&1.to > new_start_idx))
            {new_start_idx, [new(str_chunk, chunk_anns)|result], anns}
        end)
    Enum.reverse(ret)
  end
  def split(%__MODULE__{str: str, annotations: anns}, %Regex{}=splitter, orig_options) do
    limits=
      str
      #first scan for the setaratord
      |>Annotations.List.scan(splitter, fn [splitter_pos] -> splitter_pos end)
      #then invert the ranges, selecting those between the separator
      |>Rangex.RangeList.gaps( {0, String.length(str)})
      #then build the Annotated strings
    limits
    |> Enum.map( fn {from,to}=range ->
      chunk_anns=
        anns
        |>Annotations.List.extract_range(range)
        |>Enum.map( fn %Annotation{}=ann ->
            chunk_len=to-from
            case Annotations.Annotation.offset(ann,-from) do
              nil-> nil
              %Annotation{ to: to} = ann when to > chunk_len -> %Annotation{ann| to: chunk_len}
              %Annotation{}= ann -> ann
            end
        end)
        new(
          String.slice(str, from, to-from),
          chunk_anns
          )
      end)
  end
  def split_by_tags(%__MODULE__{}=str,tags) do
    split_by_tags(str,tags,[])
  end
  @doc """
    splits the string at the before or after annotations tagged with any tag in tags
    options: split: (:before | :after)
    For a general function for splitting based on Annotations look  at `split_by_annotation/3`
  """
  def split_by_tags(%__MODULE__{}=str,tags,options) do
    tag_set=
    case tags do
      tag when is_atom(tag) ->MapSet.new [tag]
      tags when is_list(tags)-> MapSet.new tags
      %MapSet{}-> tags
    end
    options = Keyword.put(options, :split, Keyword.get(options,:split, :after))
    match_result = options[:split]
    split_by_annotation(str, fn str, ann ->
      included? =
        case ann.tags do
          []-> false
          [tag]-> MapSet.member?(tag_set, tag)
          other-> not MapSet.disjoint?(tag_set, MapSet.new(other))
        end
      if included? do
        match_result
      else
        nil
      end
    end, options)
  end
  @doc """
    Splits a AnnotatedString at any point within an annotation.
    fun is a fn str, ann-> nil|:before|:after|integer, where integer is between ann.from and ann.to

  """
  def split_by_annotation(%__MODULE__{str: str, annotations: anns}=ann_str, fun, options\\[]) when is_function(fun) do

      split_points=
        Enum.reduce( anns, [] , fn %Annotation{from: from, to: to}=ann, acc->
          case fun.(str,ann) do
            :after -> [ann.to|acc]
            :before -> [ann.from |acc]
            idx when is_integer(idx) and idx <= from and idx >=to-> [idx|acc]
            other when is_integer(other)-> raise "integer #{other} is not between from and to of annotation #{inspect ann}"
            _-> acc
          end
         end)
        |> Enum.sort_by(&(&1*-1))
        |> Enum.uniq()
      {chunks, first}=
      split_points
      |> Enum.reduce( {[],ann_str} , fn  point, {list, str} ->
        {left,right}= __MODULE__.split_at(str, point)
        {[right|list], left}
        end)
      [first| chunks]
  end
  def split_at(%__MODULE__{str: str, annotations: anns}, where) when is_integer(where) do
    [first,last]= Annotation.split_annotated_buffer(str, anns, where)
    { new(first), new(last)}
  end
  @doc """
    Annotates all parts of the string with `tags_to_add` using an inverse map for `tags_to_exclude`
  """
  def tag_all_except(%__MODULE__{}=ann_str, tags_to_exclude, tag_to_add) when not is_list(tag_to_add),
    do: tag_all_except(ann_str,tags_to_exclude, [tag_to_add])
  def tag_all_except(%__MODULE__{}=ann_str, tag_to_exclude, tags_to_add) when not is_list(tag_to_exclude),
    do: tag_all_except(ann_str,[tag_to_exclude], tags_to_add)
  def tag_all_except(%__MODULE__{}=ann_str, tags_to_exclude=[_first|_rest], tags_to_add) do
    annotations_to_exclude =
      ann_str.annotations
      |> Enum.filter( fn
          %Annotation{ tags: tags} ->
            Enum.any?(tags, &(Enum.member?(tags_to_exclude, &1)))
        end)
    new_annotations= Annotations.List.tag_all_except(ann_str.str, annotations_to_exclude,  tags_to_add)
    add_annotations(ann_str,new_annotations)
  end
  def tag_all(%__MODULE__{str: str, annotations: ann}=arg, %Regex{}=re, tag\\:default ) do
      tag_all(arg, re, tag, [return: :index])
  end
  def tag_all(%__MODULE__{str: str, annotations: ann}=arg, %Regex{}=re, tag, scan_options ) do
    anns =
      (ann ++ Annotations.List.tag(str, re, tag, scan_options))
      |>Annotations.List.sort()
    %__MODULE__{arg| annotations: anns}
  end
  def extract_annotations(str,tags) do
    extract_annotations(str, tags, [])
  end
  def extract_annotations(%__MODULE__{}=str,tags, options ) when is_list(tags) do
    extract_annotations(str, MapSet.new(tags), options)

  end

  def extract_annotations(%__MODULE__{str: str, annotations: anns}=arg,%MapSet{}=tags, options)  do
    ret=
      anns
      |> Enum.filter( fn
          %Annotation{ tags: [tag]} -> MapSet.member? tags,tag
          %Annotation{ tags: []} ->false
          %Annotation{ tags: ann_tags} -> not MapSet.disjoint?(MapSet.new(ann_tags), tags)
        end)
      |> Enum.map( fn ann ->
          {_, last} = split_at(arg,ann.from)
          {ret,_} = split_at(last,ann.to-ann.from)
          ret
        end)
    if options[:as]== :string do
      ret
      |> Enum.map(&__MODULE__.to_string/1)
    else
      ret
    end
  end
  def extract_annotations(%__MODULE__{}=str,tag, options) do
    extract_annotations(str, MapSet.new([tag]), options)
  end

  @doc """
    Tests whether the annotations in the `AnnotatedString` are disjoint.
    `consider` can be any of the values allowed by `Annotations.List.disjoint?/2`

  """
  def disjoint?(%__MODULE__{annotations: anns}, consider\\nil) do
    if consider do
      Annotations.List.disjoint?(anns, consider)
    else
      Annotations.List.disjoint?(anns)
    end
  end
  @doc """
    Joins the given enumerable into a binary using joiner as a separator.

    If joiner is not passed at all, it defaults  to %AnnotatedString(" ", Annotation.new(0, 1, :joiner)).

    All items in the enumerable and the joiner must be `AnnotatedString`s or `Strings`, otherwise an error is raised.
  """
  def join(enum, joiner \\ __MODULE__.new(" ", Annotation.new(0, 1, :joiner)) ) do
    joiner=
    if is_bitstring(joiner) do
      joiner = __MODULE__.new(joiner, Annotation.new(0, String.length(joiner), :joiner))
    else
      joiner
    end
    joiner_len= __MODULE__.length(joiner)
    Enum.reduce(enum, __MODULE__.new(""), fn
      add_str, %__MODULE__{str: str, annotations: anns} when is_bitstring(add_str)  ->
          {joiner_str,joiner_len, joiner_anns} =
            case str do
              ""-> {"",0,[]}
              other when joiner_len==0 -> {"",0,[]}
              other -> {joiner.str, __MODULE__.length(joiner), Enum.map(joiner.annotations, &( Annotation.offset(&1,String.length(str))))}
            end
          new( str<> joiner_str <> add_str , anns ++ joiner_anns )
      %__MODULE__{str: add_str , annotations: add_anns}, %__MODULE__{str: str, annotations: anns} when is_bitstring(str)  ->
          cur_len=String.length(str)
          {joiner_str,joiner_len, joiner_anns} =
            case str do
              ""-> {"",0,[]}
              other when joiner_len ==0 -> {"",0,[]}
              other -> {joiner.str, __MODULE__.length(joiner), Enum.map(joiner.annotations, &( Annotation.offset(&1,cur_len)))}
            end
          new( str<> joiner_str <> add_str ,
              anns ++
              joiner_anns++
              Enum.map(add_anns, &( Annotation.offset(&1,cur_len+joiner_len)))
              )
    end)
  end
  def select_annotation_ranges(%__MODULE__{str: str, annotations: annotations}, fun \\nil) do
    if is_nil(fun) do
      Annotations.List.select_annotation_ranges(annotations)
    else
      Annotations.List.select_annotation_ranges(annotations, fn ann -> fun.(ann,str) end)
    end
  end
  def add_annotations(%__MODULE__{}=str, %__MODULE__{annotations: anns}) do
    add_annotations(str, anns)
  end
  def add_annotations(%__MODULE__{annotations: anns}=str, annotations) do
    annotations=
      (anns ++ annotations)
      |> Enum.sort_by(&( &1.from))
    %__MODULE__{str| annotations: annotations}
  end
  def trim_leading(%__MODULE__{str: str, annotations: anns}=ann_str, to_trim \\ nil) do
    trimmed_str=
      if is_nil(to_trim) do
        String.trim_leading(str)
      else
        String.trim_leading(str,to_trim)
      end
    diff = String.length(trimmed_str)- String.length(str)
    if diff == 0 do
      ann_str
    else
      %__MODULE__{ann_str|
        str: trimmed_str,
        annotations: Enum.map(anns , &(Annotation.offset(&1,diff))) |> Enum.filter(&(&1))
      }
    end
  end
  def annotations_for_tags(%__MODULE__{annotations: anns}, tags ) do
    Annotations.List.filter_tags(anns,tags)
  end
  def string_for_annotation(%__MODULE__{str: str}, %Annotation{from: from, to: to} ) do
    String.slice(str, from, to-from)
  end
  @doc """
  trims the annotation range (leading and trailing) for any annotations tagged with a tag in tags

  Note that this function only trims the `Annotation` structs tagged with any tag in `tags`. It does **not** trim the `AnnotatedString` struct itself.
  """
  def trim_annotations(%__MODULE__{str: str, annotations: anns}, tags) do
    trimmed_anns=
      anns
      |> Enum.map(fn %Annotation{from: from, to: to}=ann->
        if is_nil(tags) or Enum.any?(ann.tags , &( Enum.member?(tags, &1))) do
          slice = String.slice(str, from, to-from)
          slice_len=String.length slice
          front_offset= slice_len - String.length( String.trim_leading(slice))
          back_offset = slice_len - String.length( String.trim_trailing(slice))
          %Annotation{ann|from: ann.from+front_offset, to: ann.to-back_offset}
        else
          ann
        end
      end)
    new(str,trimmed_anns)
  end
  defp do_filter_by_tags(anns, nil), do: anns
  defp do_filter_by_tags(anns, tag) when is_bitstring(tag)  or is_atom(tag) do
    Enum.filter(anns, &(Enum.member?(&1.tags, tag)))
  end
  defp do_filter_by_tags(anns, [tag]) when is_bitstring(tag)  or is_atom(tag) do
    do_filter_by_tags(anns,tag)
  end
  defp do_filter_by_tags(anns, tags) when is_list(tags) do
    do_filter_by_tags(anns,MapSet.new(tags))
  end
  defp do_filter_by_tags(anns, %MapSet{}=tags) when is_list(tags) do
    anns
    |> Enum.filter(fn
        %Annotation{tags: [tag]} ->
          MapSet.member?(tags,tag)
        %Annotation{tags: ann_tags} ->
            not MapSet.disjoint?(tags, MapSet.new(ann_tags))
        end)
  end
  @doc """
    maps the list of annotations to the output of fun.
    if tags are non-`nil` only the annotations marked with those `tags` will be supplied to `fun`

    `fun` can receive one or two arguments and will be called as either one of:
    * fun.(annotation)
    * fun.(annotation, string)

    The result is a list with each return value from `fun`.
  """
  def map_tags(%__MODULE__{str: str, annotations: anns}, tags, fun) do
    functor_arity = :erlang.fun_info(fun)[:arity]
    anns
    |> do_filter_by_tags(tags)
    |> Enum.map( fn %Annotation{from: from, to: to}=ann ->
      case functor_arity do
        1-> fun.(ann)
        2-> fun.(ann, String.slice(str, from, to-from))
      end
    end)
  end
end
