defmodule MollieEx.ClientLinkTest do
  use ExUnit.Case, async: true

  alias MollieEx.ClientLink
  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.Link

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "client-link",
      "id" => "cl_vZCnNQsV2UtfXxYifWKWH",
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/client-links/cl_vZCnNQsV2UtfXxYifWKWH",
          "type" => "application/hal+json"
        },
        "clientLink" => %{
          "href" => "https://my.mollie.com/dashboard/client-link/cl_vZCnNQsV2UtfXxYifWKWH",
          "type" => "text/html"
        }
      },
      "futureField" => true
    }

    assert {:ok, %ClientLink{} = client_link} =
             ClientLink.from_response(
               %Response{status: 201, headers: %{}, body: body, raw: body},
               :client_links_create
             )

    assert client_link.id == "cl_vZCnNQsV2UtfXxYifWKWH"
    assert client_link.resource == "client-link"

    assert %Link{href: "https://my.mollie.com/dashboard/client-link/cl_vZCnNQsV2UtfXxYifWKWH"} =
             client_link.links["clientLink"]

    assert client_link.raw["futureField"] == true
  end

  test "builds redirect URLs with RFC3986 query encoding" do
    client_link = %ClientLink{
      id: "cl_vZCnNQsV2UtfXxYifWKWH",
      links: %{
        "clientLink" => %Link{
          href: "https://my.mollie.com/dashboard/client-link/cl_vZCnNQsV2UtfXxYifWKWH"
        }
      },
      raw: %{}
    }

    assert {:ok, redirect_url} =
             ClientLink.redirect_url(client_link,
               client_id: "app_abc123qwerty",
               state: "state with spaces",
               scopes: ["onboarding.read", "onboarding.write"],
               approval_prompt: :force
             )

    assert redirect_url ==
             "https://my.mollie.com/dashboard/client-link/cl_vZCnNQsV2UtfXxYifWKWH?client_id=app_abc123qwerty&state=state%20with%20spaces&scope=onboarding.read%20onboarding.write&approval_prompt=force"
  end

  test "builds redirect URLs from string-key maps and defaults approval prompt" do
    client_link = %ClientLink{
      id: "cl_existing_query",
      links: %{
        "clientLink" => %Link{
          href: "https://my.mollie.com/dashboard/client-link/cl_existing_query?existing=1"
        }
      },
      raw: %{}
    }

    assert {:ok, redirect_url} =
             ClientLink.redirect_url(client_link, %{
               "client_id" => "app_abc123qwerty",
               "state" => "state-123",
               "scopes" => ["onboarding.read", "onboarding.write"]
             })

    assert redirect_url ==
             "https://my.mollie.com/dashboard/client-link/cl_existing_query?existing=1&client_id=app_abc123qwerty&state=state-123&scope=onboarding.read%20onboarding.write&approval_prompt=auto"
  end

  test "returns configuration errors for invalid redirect URL inputs" do
    client_link = %ClientLink{
      id: "cl_missing_url",
      links: %{"clientLink" => %Link{href: ""}},
      raw: %{}
    }

    valid_opts = %{
      client_id: "app_abc123qwerty",
      state: "state-123",
      scopes: ["onboarding.read"]
    }

    assert {:error, %Error{reason: :missing_client_link_url}} =
             ClientLink.redirect_url(client_link, valid_opts)

    client_link = %ClientLink{
      id: "cl_invalid_url",
      links: %{"clientLink" => %Link{href: "/relative-client-link"}},
      raw: %{}
    }

    assert {:error, %Error{reason: :invalid_client_link_url}} =
             ClientLink.redirect_url(client_link, valid_opts)

    client_link = %ClientLink{
      id: "cl_valid",
      links: %{
        "clientLink" => %Link{href: "https://my.mollie.com/dashboard/client-link/cl_valid"}
      },
      raw: %{}
    }

    assert {:error, %Error{reason: {:invalid_option, :client_id}}} =
             ClientLink.redirect_url(client_link, Map.delete(valid_opts, :client_id))

    assert {:error, %Error{reason: {:invalid_option, :state}}} =
             ClientLink.redirect_url(client_link, %{valid_opts | state: ""})

    assert {:error, %Error{reason: {:invalid_option, :scopes}}} =
             ClientLink.redirect_url(client_link, %{valid_opts | scopes: []})

    assert {:error, %Error{reason: {:invalid_option, :scopes}}} =
             ClientLink.redirect_url(client_link, %{valid_opts | scopes: [""]})

    assert {:error, %Error{reason: {:invalid_option, :approval_prompt}}} =
             ClientLink.redirect_url(client_link, Map.put(valid_opts, :approval_prompt, "always"))

    assert {:error, %Error{reason: :invalid_redirect_options}} =
             ClientLink.redirect_url(client_link, [:not_a_keyword])

    assert {:error, %Error{reason: :invalid_client_link}} =
             ClientLink.redirect_url(:not_a_client_link, valid_opts)
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 201,
      headers: %{},
      body: %{"resource" => "client-link"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_client_link_response}} =
             ClientLink.from_response(response, :client_links_create)
  end
end
