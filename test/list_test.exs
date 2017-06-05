defmodule ListTest do

  alias Annotations.Annotation
  alias Annotations.List
  use ExUnit.Case
  doctest Annotations
  @alphabet "abcdefghijklmnopqrstuvwxyz"
  @ro_alphabet "aăâbcdefghiîjklmnopqrsștțuvwxyz"

  test "add tag by regex" do
    str = @alphabet
    annotations= List.tag(str, ~r/[aeiou]/u, :vowel)
    vowels=
      annotations
        |> Enum.map(
        fn ann->
          assert ann.tags==[:vowel]
          Annotation.str(ann,str)
        end)
        |> Enum.join("")
    assert vowels=="aeiou"
  end
  test "invert tags" do
    str = @alphabet <> "012345\n"
    annotations= (
      List.tag(str, ~r/[aeiou]/iu, :vowel)++
      List.tag(str, ~r/[^[:alpha:]]+/iu, :non_alpha)
    )
    consonants=
      List.tag_all_except(str, annotations, :consonant)
      |> Enum.map(&(Annotation.str(&1,str)))
      |> Enum.join("")
    assert String.length(consonants) == 26-5
    assert consonants == "bcdfghjklmnpqrstvwxyz"
  end
  test "UTF8 add tag by regex" do
    str = @ro_alphabet
    annotations= List.tag(str, ~r/[aăâeiîou]/u, :vowel)
    vowels=
      annotations
        |> Enum.map(
        fn ann->
          assert ann.tags==[:vowel]
          Annotation.str(ann,str)
        end)
        |> Enum.join("")
    assert vowels=="aăâeiîou"
  end
  test "UTF8 invert tags" do
    str = @ro_alphabet <> "012345\n"
    annotations= (
      List.tag(str, ~r/[aăâeiîou]/iu, :vowel)++
      List.tag(str, ~r/[^[:alpha:]]+/iu, :non_alpha)
    )
    consonants=
      List.tag_all_except(str, annotations, :consonant)
      |> Enum.map(&(Annotation.str(&1,str)))
      |> Enum.join("")
    assert String.length(consonants) == 31-8
    assert consonants == "bcdfghjklmnpqrsștțvwxyz"
  end
end