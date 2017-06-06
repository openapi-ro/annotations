defmodule AnnotatedStringTest do
  alias Annotations.AnnotatedString
  alias Annotations.Annotation
  alias Annotations.List
  use ExUnit.Case
  @sentence_string "first second third. fourth fifth sixth."
  def test_sentence do
    AnnotatedString.new(@sentence_string)
      |>AnnotatedString.tag_all(~r/[.]/ , :punctuation)
      |>AnnotatedString.tag_all(~r/[^.[:space:]]+[^.]+/ , :sentence)
      |>AnnotatedString.tag_all(~r/[[:alnum:]]+[[:space:].]/ , :word)
  end
  test "tag_all" do
    str= test_sentence
    ex = AnnotatedString.extract_annotations(str, :sentence)
    assert ["first second third" , "fourth fifth sixth"] == Enum.map(ex,&AnnotatedString.to_string/1)
  end
  test "disjoint?" do
    str= test_sentence
    assert AnnotatedString.disjoint?(str, :word)
    assert AnnotatedString.disjoint?(str, :sentence)
    assert AnnotatedString.disjoint?(str, [:sentence, :word]) ==false
  end
  test "split with regex" do
    str= test_sentence
    fragments= AnnotatedString.split test_sentence, ~r/[[:space:]]/
    assert String.split(@sentence_string) == Enum.map(fragments , &AnnotatedString.to_string/1)

  end
  test "split with string" do
    str= test_sentence
    fragments= AnnotatedString.split test_sentence
    assert String.split(@sentence_string) == Enum.map(fragments , &AnnotatedString.to_string/1)

  end
end