
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
  @doc """
    splits the Annotated string in two. Each String keeps the Annotations referring to itsaelf.
    Annotations spanning split boundaries are duplicated to each neighboring chunk
  """
  def split(%__MODULE__{str: str, annotations: ann}, %Regex{}=re, orig_options \\[]) do
    options=
      orig_options
      |> Keyword.merge([include_captures: true])
    with_captures=String.split(str, re, options)
    str_chunks =
      if orig_options[:include_captures] do
        with_captures
      else
        String.split(orig_options)
      end
    str_chunks
    |> Enum.reduce({with_captures,[], ann}, fn
          str_chunk, {with_captures,result, ann} ->
            Enum.reduce_while( with_captures, {str_chunk,result,ann},fn
              [first|rest],{ str_chunk, result, annotations} when first == str_chunk->
                str_chunk_len = String.length(str_chunk)
                chunk_annotations=
                  annotations
                  |> Stream.map( &(Annotation.crop_overlap(&1, 0, str_chunk_len)))
                  |> Enum.filter(&(&1))
                annotations =
                  annotations
                  |> Stream.filter(&(&1.to < str_chunk_len)) # remove annotations only applying to previous chunks
                  |> Stream.map(&(Annotations.offset(&1,str_chunk_len)))
                  |> Enum.filter(&(&1)) #take out nils
                new_ann= %__MODULE__{str: first, annotations: chunk_annotations }
                {:halt,{rest,result, annotations}}
              [first|rest],{ str_chunk, result, annotations}->
                str_chunk_len = String.length(str_chunk)
                annotations =
                  annotations
                  |> Stream.filter(&(&1.to < str_chunk_len)) # remove annotations only applying to previous chunks
                  |> Stream.map(&(Annotations.offset(&1,str_chunk_len)))
                  |> Enum.filter(&(&1)) #take out nils
                {:cont ,{rest,result, annotations}}
            end)
    end)
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
          %Annotation{ tags: ann_tags} -> not MapSet.disjoint?(ann_tags, tags)
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
  
end