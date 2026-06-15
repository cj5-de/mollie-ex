defmodule MollieEx.OrganizationTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Organization
  alias MollieEx.Types.Link

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "organization",
      "id" => "org_12345678",
      "name" => "Mollie B.V.",
      "email" => "info@mollie.com",
      "locale" => "nl_NL",
      "address" => %{"city" => "Amsterdam"},
      "registrationNumber" => "30204462",
      "vatNumber" => "NL815839091B01",
      "vatRegulation" => "shifted",
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/organizations/org_12345678",
          "type" => "application/hal+json"
        }
      },
      "futureField" => true
    }

    assert {:ok, %Organization{} = organization} =
             Organization.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :test
             )

    assert organization.id == "org_12345678"
    assert organization.resource == "organization"
    assert organization.name == "Mollie B.V."
    assert organization.email == "info@mollie.com"
    assert organization.locale == "nl_NL"
    assert organization.address == %{"city" => "Amsterdam"}
    assert organization.registration_number == "30204462"
    assert organization.vat_number == "NL815839091B01"
    assert organization.vat_regulation == "shifted"

    assert %Link{href: "https://api.mollie.com/v2/organizations/org_12345678"} =
             organization.links["self"]

    assert organization.raw["futureField"] == true
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 200,
      headers: %{},
      body: %{"resource" => "organization"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_organization_response}} =
             Organization.from_response(response, :organizations_get)
  end
end
