defmodule AnnotatedStringTest do
  alias Annotations.AnnotatedString
  alias Annotations.Annotation
  alias Annotations.List
  use ExUnit.Case
  @sentence_string "first second third. fourth fifth sixth."
  def test_sentence(str \\ @sentence_string) do
    AnnotatedString.new(str)
      |>AnnotatedString.tag_all(~r/[.]/ , :punctuation)
      |>AnnotatedString.tag_all(~r/(?:[^.[:space:]]+[^.]+(?:[.]|$))+/ , :sentence)
      |>AnnotatedString.tag_all(~r/[[:alnum:]]+/ , :word)
  end
  test "tag_all" do
    str= test_sentence()
    ex = AnnotatedString.extract_annotations(str, :sentence)
    assert ["first second third." , "fourth fifth sixth."] == Enum.map(ex,&AnnotatedString.to_string/1)
  end
  test "disjoint?" do
    str= test_sentence
    assert AnnotatedString.disjoint?(str, :word)
    assert AnnotatedString.disjoint?(str, :sentence)
    assert AnnotatedString.disjoint?(str, [:sentence, :word]) ==false
  end
  test "split with regex" do
    str= test_sentence()
    fragments= AnnotatedString.split test_sentence, ~r/[[:space:]]/
    assert String.split(@sentence_string) == Enum.map(fragments , &AnnotatedString.to_string/1)

  end
  test "Annotations reindexed on split" do
    ann_str = AnnotatedString.new "a,b,c", [
      Annotation.new({0,1}, :letter),
      Annotation.new({2,3}, :letter),
      Annotation.new({4,5}, :letter)
    ]
    AnnotatedString.split(ann_str, ",")
    |> Enum.each( fn %{annotations: anns} ->
        assert Enum.count(anns) == 1

        [ann] = anns
        assert ann.tags == [:letter]
        assert ann.from == 0
        assert ann.to == 1
      end)

  end
  test "split with string" do
    str= test_sentence
    fragments= AnnotatedString.split test_sentence
    assert String.split(@sentence_string) == Enum.map(fragments , &AnnotatedString.to_string/1)

  end
  test "join two AnnotatedString" do
    str= test_sentence()
    addition= test_sentence "just added another sentence."
    ret = AnnotatedString.join [str, addition]
    x=AnnotatedString.to_string(ret)
    assert Enum.join([str.str, addition.str], " ") ==x
  end

  test "join AnnotatedString with string" do
    str= test_sentence()
    addition= "just added another sentence."
    ret = AnnotatedString.join [str, addition]
    assert Enum.join([str.str, addition], " ") ==AnnotatedString.to_string(ret)
  end
  test "join string with string" do
    str= @sentence_string
    addition= "just added another sentence."
    ret = AnnotatedString.join [str, addition]
    assert Enum.join([str, addition], " ") ==AnnotatedString.to_string(ret)
    assert [%Annotation{tags: [:joiner]}] = ret.annotations
  end
  test "join with empty joiner" do
    str= @sentence_string
    addition= "just added another sentence."
    ret = AnnotatedString.join [str, addition], ""
    assert Enum.join([str, addition]) ==AnnotatedString.to_string(ret)
    assert [] == ret.annotations
  end
  test "split_at" do
    str= @sentence_string
    addition= "just added another sentence."
    ann_str = test_sentence str<>addition
    ann_str= AnnotatedString.add_annotations(ann_str, [Annotation.new(0, AnnotatedString.length(ann_str), :all)])
    {left, right} = AnnotatedString.split_at(ann_str, String.length(str))
    assert left.annotations == Enum.filter(left.annotations, &(&1)) # no nils
    assert right.annotations == Enum.filter(right.annotations, &(&1)) # no nils
    assert ann_str.annotations == Enum.filter(ann_str.annotations, &(&1)) # no nils


    assert Enum.count(ann_str.annotations, &(Enum.member?(&1.tags, :word))) ==10
    assert Enum.count(left.annotations, &(Enum.member?(&1.tags, :word))) ==6
    assert Enum.count(right.annotations, &(Enum.member?(&1.tags, :word))) ==4

    assert Enum.count(ann_str.annotations, &(Enum.member?(&1.tags, :all))) == 1
    assert Enum.count(left.annotations, &(Enum.member?(&1.tags, :all))) == 1
    assert Enum.count(right.annotations, &(Enum.member?(&1.tags, :all))) == 1


    #test that the annotation :all has been correctly split
    [left_all_ann]=Enum.filter(left.annotations, &(Enum.member?(&1.tags, :all)))
    [right_all_ann]=Enum.filter(right.annotations, &(Enum.member?(&1.tags, :all)))
    [ann_str_all_ann]= Enum.filter(ann_str.annotations, &(Enum.member?(&1.tags, :all)))
    assert AnnotatedString.length(ann_str)== AnnotatedString.length(left) + AnnotatedString.length(right)
    assert left_all_ann.to == AnnotatedString.length(left)
    assert left_all_ann.from == 0
    assert right_all_ann.to == AnnotatedString.length(right)
    assert right_all_ann.from == 0
    assert ann_str_all_ann.to == AnnotatedString.length(ann_str)
    assert ann_str_all_ann.from == 0
  end
  test "split_by_tags" do
    str= @sentence_string
    addition= " just added another sentence."
    ann_str = test_sentence str<>addition
    ann_str= AnnotatedString.add_annotations(ann_str, [Annotation.new(0, AnnotatedString.length(ann_str), :all)])
    [first, second,third|_]=AnnotatedString.split_by_tags(ann_str, :sentence)
    assert first.annotations == Enum.filter(first.annotations, &(&1)) # no nils
    assert second.annotations == Enum.filter(second.annotations, &(&1)) # no nils
    assert third.annotations == Enum.filter(third.annotations, &(&1)) # no nils

    assert ann_str.annotations == Enum.filter(ann_str.annotations, &(&1)) # no nils


    assert Enum.count(ann_str.annotations, &(Enum.member?(&1.tags, :word))) ==10
    assert Enum.count(first.annotations, &(Enum.member?(&1.tags, :word))) ==3
    assert Enum.count(second.annotations, &(Enum.member?(&1.tags, :word))) ==3
    assert Enum.count(third.annotations, &(Enum.member?(&1.tags, :word))) ==4

    assert Enum.count(ann_str.annotations, &(Enum.member?(&1.tags, :all))) == 1
    assert Enum.count(first.annotations, &(Enum.member?(&1.tags, :all))) == 1
    assert Enum.count(second.annotations, &(Enum.member?(&1.tags, :all))) == 1
    assert Enum.count(third.annotations, &(Enum.member?(&1.tags, :all))) == 1

    #test that the annotation :all has been correctly split
    [first_all_ann]=Enum.filter(first.annotations, &(Enum.member?(&1.tags, :all)))
    [second_all_ann]=Enum.filter(second.annotations, &(Enum.member?(&1.tags, :all)))
    [third_all_ann]=Enum.filter(third.annotations, &(Enum.member?(&1.tags, :all)))

    [ann_str_all_ann]= Enum.filter(ann_str.annotations, &(Enum.member?(&1.tags, :all)))
    assert AnnotatedString.length(ann_str)== AnnotatedString.length(first) + AnnotatedString.length(second)  + AnnotatedString.length(third)
    assert first_all_ann.to == AnnotatedString.length(first)
    assert first_all_ann.from == 0

    assert second_all_ann.to == AnnotatedString.length(second)
    assert second_all_ann.from == 0

    assert third_all_ann.to == AnnotatedString.length(third)
    assert third_all_ann.from == 0

    assert ann_str_all_ann.to == AnnotatedString.length(ann_str)
    assert ann_str_all_ann.from == 0
  end

end