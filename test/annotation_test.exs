defmodule AnnotationsTest do
  alias Annotations.Annotation
  alias Annotations.List
  use ExUnit.Case
  doctest Annotations
  @alphabet "abcdefghijklmnopqrstuvwxyz"
  @ro_alphabet "aăâbcdefghiîjklmnopqrsștțuvwxyz"
  test "test annotation construction and extraction" do
    str=@alphabet
    ann=Annotation.new(1,3,:first_three)
    assert Annotation.str(ann,str) == "bc"
  end

  test "split before Annotation range" do
    str = "1,2,3"
    [ann] = List.tag(str, ~r/2,3/)
    [ {"1",[]} ,{second_str,[second_ann]}
    ]= Annotation.split_annotated_buffer(str, [ann], 1)
    assert  Annotation.str(second_ann,second_str) == Annotation.str(ann,str)
  end

  test "split after Annotation range" do
    str = "1,2,3,4"
    [ann] = List.tag(str, ~r/2,3/)
    [ {first_str,[first_ann]},{"4",[]}
    ]= Annotation.split_annotated_buffer(str, [ann], 6)
    assert Annotation.str(first_ann,first_str) == Annotation.str(ann,str)
  end
  test "split in Annotation range" do
    str = "1,2,3"
    [ann] = List.tag(str, ~r/2,3/)

    [{first_str,[first_ann]},
     {second_str,[second_ann]},
     ]= Annotation.split_annotated_buffer(str, [ann], 3)
    assert Annotation.str(first_ann,first_str) <> Annotation.str(second_ann,second_str) == Annotation.str(ann,str)
  end
end
