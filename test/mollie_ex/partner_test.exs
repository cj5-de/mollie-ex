defmodule MollieEx.PartnerTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Partner
  alias MollieEx.Types.Link

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "partner",
      "partnerType" => "oauth",
      "isCommissionPartner" => true,
      "userAgentTokens" => [%{"token" => "ua_123"}],
      "partnerContractSignedAt" => "2026-01-01T00:00:00.0Z",
      "partnerContractUpdateAvailable" => false,
      "partnerContractExpiresAt" => "2027-01-01T00:00:00.0Z",
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/organizations/me/partner",
          "type" => "application/hal+json"
        }
      },
      "futureField" => true
    }

    assert {:ok, %Partner{} = partner} =
             Partner.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :test
             )

    assert partner.resource == "partner"
    assert partner.partner_type == "oauth"
    assert partner.is_commission_partner == true
    assert partner.user_agent_tokens == [%{"token" => "ua_123"}]
    assert partner.partner_contract_signed_at == "2026-01-01T00:00:00.0Z"
    assert partner.partner_contract_update_available == false
    assert partner.partner_contract_expires_at == "2027-01-01T00:00:00.0Z"

    assert %Link{href: "https://api.mollie.com/v2/organizations/me/partner"} =
             partner.links["self"]

    assert partner.raw["futureField"] == true
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 200,
      headers: %{},
      body: %{"resource" => "organization"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_partner_response}} =
             Partner.from_response(response, :organizations_partner_status)
  end
end
