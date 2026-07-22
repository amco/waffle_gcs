defmodule Waffle.Storage.Google.CloudStorage do
  @moduledoc """
  The main storage integration for Waffle. To use this module with Waffle,
  simply set your `:storage` config appropriately:

  ```elixir
  config :waffle, storage: Waffle.Storage.Google.CloudStorage
  ```

  Ensure you have a valid bucket set, either through the configs or as an
  environment variable, otherwise all calls will fail. The credentials available
  through `Goth` must have the appropriate level of access to the bucket,
  otherwise some (or all) calls may fail.
  """

  alias Req.Response
  alias Waffle.Types
  alias Waffle.Storage.Google.Util

  @doc """
  Put a Waffle file in a Google Cloud Storage bucket.
  """
  @spec put(Types.definition, Types.version, Types.meta) :: {:ok, Response.t() | {:error, term()}}
  def put(definition, version, meta) do
    bucket = bucket(definition)
    path = path_for(definition, version, meta)
    {:ok, %{token: token}} = Goth.fetch(definition.goth_module())
    url = "https://storage.googleapis.com/upload/storage/v1/b/#{bucket}/o"
    params = [uploadType: "multipart", name: path]
    headers = [{"Authorization", "Bearer #{token}"}]
    Req.post(url, params: params, headers: headers, body: data(meta))
  end

  @doc """
  Delete a file from a Google Cloud Storage bucket.
  """
  @spec put(Types.definition, Types.version, Types.meta) :: {:ok, Response.t() | {:error, term()}}
  def delete(definition, version, meta) do
    bucket = bucket(definition)
    path = path_for(definition, version, meta)
    object = URI.encode_www_form(path)
    {:ok, %{token: token}} = Goth.fetch(definition.goth_module())
    url = "https://storage.googleapis.com/storage/v1/b/#{bucket}/o/#{object}"
    headers = [{"Authorization", "Bearer #{token}"}]
    Req.delete(url, headers: headers)
  end

  @doc """
  Retrieve the public URL for a file in a Google Cloud Storage bucket. Uses
  `Waffle.Storage.Google.UrlV4` by default, which uses v2 signing if a signed
  URL is requested, but this can be overriden in the options list or in the
  application configs by setting `:url_builder` to any module that imlements the
  behavior of `Waffle.Storage.Google.Url`.
  """
  @spec url(Types.definition, Types.version, Types.meta, Keyword.t) :: String.t
  def url(definition, version, meta, opts \\ []) do
    signer = Util.option(opts, :url_builder, Waffle.Storage.Google.UrlV4)
    signer.build(definition, version, meta, opts)
  end

  @doc """
  Returns the bucket for file uploads.
  """
  @spec bucket(Types.definition) :: String.t
  def bucket(definition), do: Util.var(definition.bucket())

  @doc """
  Returns the storage directory **within a bucket** to store the file under.
  """
  @spec storage_dir(Types.definition, Types.version, Types.meta) :: String.t
  def storage_dir(definition, version, meta) do
    version
    |> definition.storage_dir(meta)
    |> Util.var()
  end

  @doc """
  Returns the full file path for the upload destination.
  """
  @spec path_for(Types.definition, Types.version, Types.meta) :: String.t
  def path_for(definition, version, meta) do
    definition
    |> storage_dir(version, meta)
    |> Path.join(fullname(definition, version, meta))
  end

  @doc """
  A wrapper for `Waffle.Definition.Versioning.resolve_file_name/3`.
  """
  @spec fullname(Types.definition, Types.version, Types.meta) :: String.t
  def fullname(definition, version, meta) do
    Waffle.Definition.Versioning.resolve_file_name(definition, version, meta)
  end

  @spec data(Types.file) :: {:file | :binary, String.t}
  defp data({%{binary: nil, path: path}, _}), do: File.read!(path)
  defp data({%{binary: data}, _}), do: data
end
