defmodule Annotations do
  alias Annotations.AnnotatedString
  @moduledoc """
  `Annotations` is a package for augmenting plain strings with information on ranges of that `String`.
  Let's create an `AnnotatedString`:

    iex(2)> AnnotatedString.new("first second third. fourth fifth sixth.")
    %Annotations.AnnotatedString{annotations: [],
     str: "first second third. fourth fifth sixth."}


  `Annotation`s store information inȘ

  * `tags`
  * the `info` member

## Example
  Let's tag each word, sentence and punctuation using `Regex` expressions:

    iex> alias Annotations.{AnnotatedString,Annotations}
    iex> ann_str = AnnotatedString.new("first second third. fourth fifth sixth.")
    iex> ann_str = ann_str |> AnnotatedString.tag_all(~r/[.]/ , :punctuation) \
    ...> |> AnnotatedString.tag_all(~r/[^.[:space:]]+[^.]+/ , :sentence) \
    ...> |> AnnotatedString.tag_all(~r/[[:alnum:]]+/ , :word)
    %Annotations.AnnotatedString{annotations: [%Annotations.Annotation{from: 18,
     info: nil, tags: [:punctuation], to: 19},
    %Annotations.Annotation{from: 38, info: nil, tags: [:punctuation], to: 39},
    %Annotations.Annotation{from: 0, info: nil, tags: [:sentence], to: 18},
    %Annotations.Annotation{from: 20, info: nil, tags: [:sentence], to: 38},
    %Annotations.Annotation{from: 0, info: nil, tags: [:word], to: 5},
    %Annotations.Annotation{from: 6, info: nil, tags: [:word], to: 12},
    %Annotations.Annotation{from: 13, info: nil, tags: [:word], to: 18},
    %Annotations.Annotation{from: 20, info: nil, tags: [:word], to: 26},
    %Annotations.Annotation{from: 27, info: nil, tags: [:word], to: 32},
    %Annotations.Annotation{from: 33, info: nil, tags: [:word], to: 38}],
    str: "first second third. fourth fifth sixth."}
  Now Let's grab a list of words:
    iex> AnnotatedString.extract_annotations(ann_str, :word, as: :string)
    ["first", "second", "third", "fourth", "fifth", "sixth"]
"""

end
