defmodule MollieEx.ClientLink do
  @moduledoc """
  Client link resource returned by the Mollie Client Links API.

  Stable fields are exposed as snake_case struct fields. The original decoded
  Mollie response is preserved in `raw` with upstream JSON casing unchanged.
  """
  @moduledoc since: "0.5.0"

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.Link

  @type links :: %{optional(String.t()) => Link.t() | term()}
  @type approval_prompt :: :auto | :force | String.t()
  @type redirect_options :: %{
          required(:client_id) => String.t(),
          required(:state) => String.t(),
          required(:scopes) => [String.t()],
          optional(:approval_prompt) => approval_prompt()
        }

  @type t :: %__MODULE__{
          id: String.t(),
          resource: String.t() | nil,
          links: links(),
          raw: map()
        }

  @enforce_keys [:id, :raw]
  defstruct [
    :id,
    :resource,
    links: %{},
    raw: %{}
  ]

  @doc false
  @spec from_response(Response.t(), atom()) :: {:ok, t()} | {:error, Error.t()}
  def from_response(%Response{body: %{} = body} = response, operation) do
    case Map.get(body, "id") do
      id when is_binary(id) and id != "" ->
        {:ok,
         %__MODULE__{
           id: id,
           resource: Map.get(body, "resource"),
           links: links(Map.get(body, "_links")),
           raw: body
         }}

      _id ->
        invalid_response_error(operation, response)
    end
  end

  def from_response(%Response{} = response, operation),
    do: invalid_response_error(operation, response)

  @doc """
  Builds the customer redirect URL for a client link.

  The Client Links API returns the base `clientLink` URL. Before redirecting a
  customer, callers must append the OAuth application `client_id`, CSRF
  `state`, requested `scopes`, and optional `approval_prompt`.
  """
  @doc since: "0.5.0"
  @spec redirect_url(t(), redirect_options() | keyword()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def redirect_url(%__MODULE__{} = client_link, opts) when is_map(opts) or is_list(opts) do
    with :ok <- validate_redirect_options(opts),
         {:ok, href} <- client_link_href(client_link),
         {:ok, client_id} <- required_redirect_string(opts, :client_id),
         {:ok, state} <- required_redirect_string(opts, :state),
         {:ok, scopes} <- redirect_scopes(opts),
         {:ok, approval_prompt} <- approval_prompt(opts),
         {:ok, uri} <- client_link_uri(href) do
      query =
        encode_query([
          {"client_id", client_id},
          {"state", state},
          {"scope", Enum.join(scopes, " ")},
          {"approval_prompt", approval_prompt}
        ])

      {:ok, uri |> append_query(query) |> URI.to_string()}
    end
  end

  def redirect_url(_client_link, _opts), do: configuration_error(:invalid_client_link)

  defp links(%{} = links) do
    Map.new(links, fn {rel, link} -> {rel, Link.from(link)} end)
  end

  defp links(_links), do: %{}

  defp client_link_href(%__MODULE__{links: %{"clientLink" => %Link{href: href}}}),
    do: non_empty_href(href)

  defp client_link_href(%__MODULE__{links: %{"clientLink" => %{"href" => href}}}),
    do: non_empty_href(href)

  defp client_link_href(%__MODULE__{}), do: configuration_error(:missing_client_link_url)

  defp non_empty_href(href) when is_binary(href) do
    case String.trim(href) do
      "" -> configuration_error(:missing_client_link_url)
      trimmed_href -> {:ok, trimmed_href}
    end
  end

  defp non_empty_href(_href), do: configuration_error(:missing_client_link_url)

  defp validate_redirect_options(opts) when is_list(opts) do
    if Keyword.keyword?(opts), do: :ok, else: configuration_error(:invalid_redirect_options)
  end

  defp validate_redirect_options(%{}), do: :ok

  defp required_redirect_string(opts, key) do
    case fetch_redirect_value(opts, key) do
      {:ok, value} when is_binary(value) ->
        case String.trim(value) do
          "" -> configuration_error({:invalid_option, key})
          trimmed_value -> {:ok, trimmed_value}
        end

      _value ->
        configuration_error({:invalid_option, key})
    end
  end

  defp redirect_scopes(opts) do
    case fetch_redirect_value(opts, :scopes) do
      {:ok, scopes} when is_list(scopes) and scopes != [] -> normalize_scopes(scopes)
      _scopes -> configuration_error({:invalid_option, :scopes})
    end
  end

  defp normalize_scopes(scopes) do
    Enum.reduce_while(scopes, {:ok, []}, fn
      scope, {:ok, normalized_scopes} when is_binary(scope) ->
        case String.trim(scope) do
          "" -> {:halt, configuration_error({:invalid_option, :scopes})}
          normalized_scope -> {:cont, {:ok, [normalized_scope | normalized_scopes]}}
        end

      _scope, _normalized_scopes ->
        {:halt, configuration_error({:invalid_option, :scopes})}
    end)
    |> case do
      {:ok, normalized_scopes} -> {:ok, Enum.reverse(normalized_scopes)}
      {:error, %Error{}} = error -> error
    end
  end

  defp approval_prompt(opts) do
    case fetch_redirect_value(opts, :approval_prompt) do
      :error -> {:ok, "auto"}
      {:ok, :auto} -> {:ok, "auto"}
      {:ok, :force} -> {:ok, "force"}
      {:ok, "auto"} -> {:ok, "auto"}
      {:ok, "force"} -> {:ok, "force"}
      _approval_prompt -> configuration_error({:invalid_option, :approval_prompt})
    end
  end

  defp fetch_redirect_value(%{} = opts, key) when is_atom(key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(opts, key) -> {:ok, Map.fetch!(opts, key)}
      Map.has_key?(opts, string_key) -> {:ok, Map.fetch!(opts, string_key)}
      true -> :error
    end
  end

  defp fetch_redirect_value(opts, key) when is_list(opts) and is_atom(key),
    do: Keyword.fetch(opts, key)

  defp client_link_uri(href) do
    case URI.new(href) do
      {:ok, %URI{scheme: scheme, host: host} = uri} when is_binary(scheme) and is_binary(host) ->
        {:ok, uri}

      {:ok, _uri} ->
        configuration_error(:invalid_client_link_url)

      {:error, _reason} ->
        configuration_error(:invalid_client_link_url)
    end
  end

  defp encode_query(params) do
    Enum.map_join(params, "&", fn {key, value} ->
      encode_query_value(key) <> "=" <> encode_query_value(value)
    end)
  end

  defp encode_query_value(value), do: value |> to_string() |> URI.encode(&URI.char_unreserved?/1)

  defp append_query(%URI{query: nil} = uri, query), do: %URI{uri | query: query}
  defp append_query(%URI{query: ""} = uri, query), do: %URI{uri | query: query}

  defp append_query(%URI{query: existing_query} = uri, query),
    do: %URI{uri | query: existing_query <> "&" <> query}

  defp invalid_response_error(operation, %Response{} = response) do
    {:error,
     Error.exception(
       type: :decode,
       status: response.status,
       headers: response.headers,
       raw: response.raw,
       reason: :invalid_client_link_response,
       operation: operation
     )}
  end

  defp configuration_error(reason) do
    {:error, Error.exception(type: :configuration, reason: reason)}
  end
end
