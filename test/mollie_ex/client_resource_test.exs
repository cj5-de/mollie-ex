defmodule MollieEx.ClientResourceTest do
  use ExUnit.Case, async: true

  alias MollieEx.ClientResource
  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.Link

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "client",
      "id" => "org_12345678",
      "organizationCreatedAt" => "2023-04-06T13:10:19+00:00",
      "commission" => %{"count" => 3},
      "_embedded" => %{
        "organization" => %{
          "resource" => "organization",
          "id" => "org_12345678",
          "name" => "Example Client"
        }
      },
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/clients/org_12345678",
          "type" => "application/hal+json"
        }
      },
      "futureField" => true
    }

    assert {:ok, %ClientResource{} = client_resource} =
             ClientResource.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :test
             )

    assert client_resource.id == "org_12345678"
    assert client_resource.resource == "client"
    assert client_resource.organization_created_at == "2023-04-06T13:10:19+00:00"
    assert client_resource.commission == %{"count" => 3}
    assert client_resource.embedded["organization"]["name"] == "Example Client"

    assert %Link{href: "https://api.mollie.com/v2/clients/org_12345678"} =
             client_resource.links["self"]

    assert client_resource.raw["futureField"] == true
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 200,
      headers: %{},
      body: %{"resource" => "client"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_client_response}} =
             ClientResource.from_response(response, :clients_get)
  end
end
