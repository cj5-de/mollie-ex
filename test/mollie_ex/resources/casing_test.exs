defmodule MollieEx.Resources.CasingTest do
  use ExUnit.Case, async: true

  alias MollieEx.Resources.Casing

  describe "to_mollie_body/2" do
    test "converts top-level atom and snake-case binary keys" do
      assert Casing.to_mollie_body(
               %{
                 "webhook_url" => "https://example.test/webhook",
                 redirect_url: "https://example.test/return"
               },
               []
             ) == %{
               "redirectUrl" => "https://example.test/return",
               "webhookUrl" => "https://example.test/webhook"
             }
    end

    test "recursively converts configured structured keys" do
      assert Casing.to_mollie_body(
               %{
                 amount: %{currency: "EUR", value: "10.00"},
                 billing_address: %{given_name: "Ada", street_and_number: "Main 1"}
               },
               ~w(amount billingAddress)
             ) == %{
               "amount" => %{"currency" => "EUR", "value" => "10.00"},
               "billingAddress" => %{"givenName" => "Ada", "streetAndNumber" => "Main 1"}
             }
    end

    test "leaves non-structured nested maps untouched" do
      metadata = %{
        order_id: "123",
        nested_meta: %{line_id: "1"},
        items: [%{sku_id: "sku_123"}]
      }

      assert Casing.to_mollie_body(%{metadata: metadata}, []) == %{"metadata" => metadata}
    end

    test "recursively converts lists inside structured keys" do
      assert Casing.to_mollie_body(
               %{
                 lines: [
                   %{
                     description: "Line",
                     unit_price: %{currency: "EUR", value: "5.00"}
                   }
                 ]
               },
               ~w(lines)
             ) == %{
               "lines" => [
                 %{
                   "description" => "Line",
                   "unitPrice" => %{"currency" => "EUR", "value" => "5.00"}
                 }
               ]
             }
    end
  end
end
