defmodule MollieEx.ListTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.List
  alias MollieEx.Payment
  alias MollieEx.Resources.ListDecoder
  alias MollieEx.Types.{Link, Money}

  @payment_list_fixture Path.expand("../fixtures/mollie/payments/list_success.json", __DIR__)

  test "decodes payment list responses" do
    body = payment_list_fixture()
    response = response(body)

    assert {:ok, %List{} = list} =
             ListDecoder.from_response(
               response,
               "payments",
               :payments_list,
               &Payment.from_response(&1, :payments_list)
             )

    assert list.count == 1
    assert list.raw == body
    assert %Link{href: "https://api.mollie.com/v2/payments?limit=1"} = list.links["self"]

    assert %Link{href: "https://api.mollie.com/v2/payments?from=tr_next&limit=1"} =
             list.links["next"]

    assert list.links["previous"] == nil

    assert [%Payment{} = payment] = list.data
    assert payment.id == "tr_list_123"
    assert payment.status == "open"
    assert payment.created_at == "2026-06-12T10:15:00+00:00"
    assert payment.profile_id == "pfl_123"

    assert payment.amount == %Money{
             currency: "EUR",
             value: "75.00",
             raw: %{"currency" => "EUR", "value" => "75.00"}
           }

    assert %Link{href: "https://www.mollie.com/checkout/select-method/tr_list_123"} =
             payment.links["checkout"]

    assert payment.metadata == %{"order_id" => "12345"}
    assert payment.raw["unexpectedFutureField"] == %{"visible" => true}
  end

  test "decodes empty lists" do
    body = %{
      "count" => 0,
      "_embedded" => %{},
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/payments?limit=50",
          "type" => "application/hal+json"
        }
      }
    }

    assert {:ok, %List{} = list} =
             body
             |> response()
             |> ListDecoder.from_response(
               "payments",
               :payments_list,
               &Payment.from_response(&1, :payments_list)
             )

    assert list.count == 0
    assert list.data == []
    assert list.raw == body
    assert %Link{href: "https://api.mollie.com/v2/payments?limit=50"} = list.links["self"]
  end

  test "returns decode errors for invalid list envelopes" do
    invalid_bodies = [
      %{"_embedded" => %{}, "_links" => %{}},
      %{"count" => -1, "_embedded" => %{}, "_links" => %{}},
      %{"count" => 0, "_embedded" => [], "_links" => %{}},
      %{"count" => 0, "_embedded" => %{}, "_links" => []},
      %{"count" => 1, "_embedded" => %{"payments" => %{}}, "_links" => %{}},
      "not a map"
    ]

    for body <- invalid_bodies do
      assert {:error, %Error{} = error} =
               body
               |> response()
               |> ListDecoder.from_response(
                 "payments",
                 :payments_list,
                 &Payment.from_response(&1, :payments_list)
               )

      assert error.type == :decode
      assert error.status == 200
      assert error.reason == :invalid_list_response
      assert error.operation == :payments_list
      assert error.raw == body
    end
  end

  test "returns decode errors for invalid embedded payments" do
    payment = %{"status" => "open"}

    body = %{
      "count" => 1,
      "_embedded" => %{"payments" => [payment]},
      "_links" => %{}
    }

    assert {:error, %Error{} = error} =
             body
             |> response()
             |> ListDecoder.from_response(
               "payments",
               :payments_list,
               &Payment.from_response(&1, :payments_list)
             )

    assert error.type == :decode
    assert error.status == 200
    assert error.reason == :invalid_payment_response
    assert error.operation == :payments_list
    assert error.raw == payment
  end

  defp payment_list_fixture do
    @payment_list_fixture
    |> File.read!()
    |> Jason.decode!()
  end

  defp response(body) do
    %Response{
      status: 200,
      headers: %{},
      body: body,
      raw: body
    }
  end
end
