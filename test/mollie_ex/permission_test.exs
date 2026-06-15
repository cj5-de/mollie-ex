defmodule MollieEx.PermissionTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Permission
  alias MollieEx.Types.Link

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "permission",
      "id" => "payments.read",
      "description" => "View your payments",
      "granted" => true,
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/permissions/payments.read",
          "type" => "application/hal+json"
        }
      },
      "futureField" => true
    }

    assert {:ok, %Permission{} = permission} =
             Permission.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :test
             )

    assert permission.id == "payments.read"
    assert permission.resource == "permission"
    assert permission.description == "View your payments"
    assert permission.granted == true

    assert %Link{href: "https://api.mollie.com/v2/permissions/payments.read"} =
             permission.links["self"]

    assert permission.raw["futureField"] == true
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{status: 200, headers: %{}, body: %{"resource" => "permission"}, raw: %{}}

    assert {:error, %Error{type: :decode, reason: :invalid_permission_response}} =
             Permission.from_response(response, :permissions_get)
  end
end
