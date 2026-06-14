defmodule MollieEx.MandateTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Mandate
  alias MollieEx.Types.Link

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "mandate",
      "id" => "mdt_123",
      "mode" => "test",
      "status" => "valid",
      "method" => "directdebit",
      "details" => %{"consumerName" => "Example Customer"},
      "mandateReference" => "EXAMPLE-CORP-MD13804",
      "signatureDate" => "2026-06-14",
      "scopes" => ["customer-not-present"],
      "customerId" => "cst_123",
      "createdAt" => "2026-06-14T10:49:08.0Z",
      "_links" => %{
        "customer" => %{"href" => "https://api.mollie.com/v2/customers/cst_123"}
      },
      "futureField" => true
    }

    assert {:ok, %Mandate{} = mandate} =
             Mandate.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :test
             )

    assert mandate.id == "mdt_123"
    assert mandate.mode == "test"
    assert mandate.status == "valid"
    assert mandate.method == "directdebit"
    assert mandate.details == %{"consumerName" => "Example Customer"}
    assert mandate.mandate_reference == "EXAMPLE-CORP-MD13804"
    assert mandate.signature_date == "2026-06-14"
    assert mandate.scopes == ["customer-not-present"]
    assert mandate.customer_id == "cst_123"
    assert %Link{href: "https://api.mollie.com/v2/customers/cst_123"} = mandate.links["customer"]
    assert mandate.raw["futureField"] == true
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{status: 200, headers: %{}, body: %{"resource" => "mandate"}, raw: %{}}

    assert {:error, %Error{type: :decode, reason: :invalid_mandate_response}} =
             Mandate.from_response(response, :mandates_get)
  end
end
