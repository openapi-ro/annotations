defmodule Annotations.Persistence do
  alias Annotations.AnnotatedString
  @provider Application.get_env(:annotations, :persistence_provider, Annotations.Schema)
  def save(%AnnotatedString{}=ann, options \\[]) do
    apply @provider , :save, [ann, options]
  end

  def load(md5) do
    load(md5, [])
  end
  def load(md5_list, options) when is_list(md5_list) do
    apply @provider , :load, [md5_list, options]
  end
  def load(md5, options) do
    load([md5], options)
  end
end