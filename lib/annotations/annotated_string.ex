
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
  def split(%__MODULE__{str: str, annotations: ann}, splitter, orig_options \\[]) do
    options=
      orig_options
      |> Keyword.merge([include_captures: true])
    with_captures=String.split(str, splitter, options)
    str_chunks =
      if orig_options[:include_captures] do
        with_captures
      else
        String.split(str,splitter,orig_options)
      end
    {_,ret,_}=
    str_chunks
    |>Enum.reduce({with_captures,[], ann}, fn
        str_chunk, {with_captures,result, ann} ->
          {last_chunk, idx, result, annotations} =
          with_captures
          |>Stream.with_index()
          |>Enum.reduce_while( {str_chunk,result,ann},fn
            {first,idx},{ str_chunk, result, annotations} when first == str_chunk->
              str_chunk_len = String.length(first)
              chunk_annotations=
                annotations
                |> Stream.map( &(Annotation.crop_overlap(&1, 0, str_chunk_len)))
                |> Enum.filter(&(&1))
              prev_ann = annotations
              annotations =
                annotations
                |> Stream.filter(&(&1.to > str_chunk_len)) # remove annotations only applying to previous chunks
                |> Stream.map(&(Annotation.offset(&1,str_chunk_len)))
                |> Enum.filter(&(&1)) #take out nils
              new_ann= %__MODULE__{str: first, annotations: chunk_annotations }
              {:halt,{str_chunk,idx+1,result++[new_ann], annotations}}
            {first,idx},{ str_chunk, result, annotations}->
              str_chunk_len = String.length(first)
              annotations =
                annotations
                |> Stream.filter(&(&1.to > str_chunk_len)) # remove annotations only applying to previous chunks
                |> Stream.map(&(Annotation.offset(&1,str_chunk_len)))
                |> Enum.filter(&(&1)) #take out nils
              {:cont ,{str_chunk,result, annotations}}
          end)
          {_,with_captures}=Enum.split(with_captures,idx)
          {with_captures, result, annotations}
      end)
    ret
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
  def tag_all(%__MODULE__{str: str, annotations: ann}=arg, %Regex{}=re, tag\\:default ) do
      %__MODULE__{arg| annotations: ann++ Annotations.List.tag(str, re, tag)}
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
      Annotations.List.disjoint(anns)
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
end