defmodule MollieEx.MethodTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Method
  alias MollieEx.Types.{Link, Money}

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "method",
      "id" => "ideal",
      "description" => "iDEAL",
      "minimumAmount" => %{"currency" => "EUR", "value" => "0.01"},
      "maximumAmount" => %{"currency" => "EUR", "value" => "50000.00"},
      "image" => %{"svg" => "https://example.test/ideal.svg"},
      "status" => "activated",
      "issuers" => [%{"id" => "ideal_INGBNL2A", "name" => "ING"}],
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/methods/ideal",
          "type" => "application/hal+json"
        }
      },
      "futureField" => true
    }

    assert {:ok, %Method{} = method} =
             Method.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :test
             )

    assert method.id == "ideal"
    assert method.description == "iDEAL"

    assert method.minimum_amount == %Money{
             currency: "EUR",
             value: "0.01",
             raw: body["minimumAmount"]
           }

    assert method.maximum_amount == %Money{
             currency: "EUR",
             value: "50000.00",
             raw: body["maximumAmount"]
           }

    assert method.image == %{"svg" => "https://example.test/ideal.svg"}
    assert method.status == "activated"
    assert method.issuers == [%{"id" => "ideal_INGBNL2A", "name" => "ING"}]
    assert %Link{href: "https://api.mollie.com/v2/methods/ideal"} = method.links["self"]
    assert method.raw["futureField"] == true
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{status: 200, headers: %{}, body: %{"resource" => "method"}, raw: %{}}

    assert {:error, %Error{type: :decode, reason: :invalid_method_response}} =
             Method.from_response(response, :methods_get)
  end
end
