defmodule AnnotatedStringTest do
  alias Annotations.AnnotatedString
  alias Annotations.Annotation
  alias Annotations.List
  use ExUnit.Case
  test "tag_all" do
    str=
      AnnotatedString.new("first second third. fourth fifth sixth.")
      |>AnnotatedString.tag_all(~r/[.]/ , :punctuation)
      |>AnnotatedString.tag_all(~r/[^.[:space:]]+[^.]+/ , :sentence)
      |>AnnotatedString.tag_all(~r/[[:alnum:]]+[[:space:].]/ , :word)
    ex = AnnotatedString.extract_annotations(str, :sentence)
    assert ["first second third" , "fourth fifth sixth"] == Enum.map(ex,&AnnotatedString.to_string/1)
  end
end