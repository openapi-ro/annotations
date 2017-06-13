defmodule Annotations.Persistence do
  alias Annotations.AnnotatedString
  @provider Application.get_env(:annotations, :persistence_provider, Annotations.Schema)
  def save(%AnnotatedString{}=ann, options \\[]) do
    apply @provider , :save, [ann, options]
  end
end