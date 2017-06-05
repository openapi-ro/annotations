defmodule Annotations.Annotation do
  @doc """
  Module defining annotations for a String buffer.

  Use this to annotate Strings
  """
  defstruct from: nil,
    to: nil,
    tags: [],
    info: nil

  def new(from,to, tags \\:default, info \\nil) do
    unless is_list(tags) do
      tags=[tags]
    end
    %__MODULE__{from: from, to: to, tags: tags, info: info}
  end
  def length(%__MODULE__{}=ann) do
    ann.to-ann.from
  end
  def offset(%__MODULE__{}=ann, new_start) when is_integer(new_start) and new_start>=0 do
    if new_start >=ann.to do
      nil
    else
      %__MODULE__{ann| from: Enum.max([ann.from-new_start, 0]), to: Enum.max([ann.to-new_start, 0]) }
    end
  end
  def intersects?(%__MODULE__{from: from, to: to}, cmp_from, cmp_to) do
    cond do
      cmp_to <= from -> false
      cmp_from >= to -> false
      true-> true
    end
  end
  def crop_overlap(%__MODULE__{from: from, to: to}=ann, cmp_from, cmp_to) do
    if intersects?(ann,cmp_from, cmp_to) do
      %__MODULE__{ ann|
        from: Enum.min([Enum.max([cmp_from,from]), Enum.min([cmp_to, from])]),
        to: Enum.min([Enum.max([cmp_from,to]), Enum.min([cmp_to, to])]),
      }
    else
      nil
    end
  end
  def str(%__MODULE__{}=ann, str) when is_bitstring(str) do
    {chunk,_} = String.split_at(str,ann.to)
    {_,chunk} = String.split_at(chunk,ann.from)
    chunk
  end


  def split_annotated_buffer(buffer, annotations, split_pos) when is_bitstring(buffer) and is_integer(split_pos) do
    buf_len=String.length(buffer)
    if split_pos==0 or split_pos>buf_len-1 do
      if split_pos == 0 do
        [{"", []},{buffer,annotations}]
      else
        [{buffer,annotations},{"", []}]
      end
    else
      {first,last}=String.split_at(buffer, split_pos)
      [first_ann,last_ann] =
        [{first, 0, split_pos} ,{last,split_pos,buf_len}]
        |> Enum.map( fn {_str, f, t} -> 
            annotations
            |> Stream.map( fn ann ->
              crop_overlap(ann, f,t)
            end)
            |> Stream.filter(&(&1))
            |> Stream.map(fn ann -> 
              offset(ann,f)
            end)
            |> Enum.to_list()
          end)
      [{first,first_ann}, {last, last_ann}]
    end
  end
end