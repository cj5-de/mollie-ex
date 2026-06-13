defmodule MollieEx.CustomerTest do
  use ExUnit.Case, async: true

  alias MollieEx.Customer
  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.Link

  @customer_fixture Path.expand("../fixtures/mollie/customers/get_success.json", __DIR__)

  test "decodes stable customer fields and preserves raw response data" do
    body = @customer_fixture |> File.read!() |> Jason.decode!()
    response = %Response{status: 200, headers: %{}, body: body, raw: body}

    assert {:ok, %Customer{} = customer} = Customer.from_response(response, :customers_get)

    assert customer.id == "cst_123"
    assert customer.resource == "customer"
    assert customer.mode == "test"
    assert customer.name == "Jane Doe"
    assert customer.email == "jane@example.org"
    assert customer.locale == "en_US"
    assert customer.created_at == "2026-06-13T10:15:30+00:00"

    assert customer.metadata == %{
             "crm_id" => "customer-123",
             "nested_value" => %{"kept_value" => true}
           }

    assert %Link{href: "https://api.mollie.com/v2/customers/cst_123"} =
             customer.links["self"]

    assert %Link{href: "https://api.mollie.com/v2/customers/cst_123/payments"} =
             customer.links["payments"]

    assert customer.raw["events"] == [
             %{"type" => "customer.created", "createdAt" => "2026-06-13T10:15:30+00:00"}
           ]

    assert customer.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "returns decode error for invalid customer response shape" do
    raw = %{"resource" => "customer"}
    response = %Response{status: 200, headers: %{}, body: raw, raw: raw}

    assert {:error, %Error{} = error} = Customer.from_response(response, :customers_get)
    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_customer_response
    assert error.operation == :customers_get
    assert error.raw == raw
  end
end
