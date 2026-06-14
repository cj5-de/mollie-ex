defmodule MollieEx.ProfileTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Profile
  alias MollieEx.Types.Link

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "profile",
      "id" => "pfl_123",
      "mode" => "test",
      "name" => "Example webshop",
      "website" => "https://example.test",
      "email" => "info@example.test",
      "phone" => "+31208202070",
      "description" => "Example products",
      "countriesOfActivity" => ["NL", "BE"],
      "businessCategory" => "OTHER_MERCHANDISE",
      "status" => "verified",
      "review" => %{"status" => "pending"},
      "createdAt" => "2026-06-14T10:49:08.0Z",
      "_links" => %{
        "dashboard" => %{
          "href" => "https://www.mollie.com/dashboard/org_123/settings/profiles/pfl_123"
        }
      },
      "futureField" => true
    }

    assert {:ok, %Profile{} = profile} =
             Profile.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :test
             )

    assert profile.id == "pfl_123"
    assert profile.name == "Example webshop"
    assert profile.countries_of_activity == ["NL", "BE"]
    assert profile.business_category == "OTHER_MERCHANDISE"
    assert profile.review == %{"status" => "pending"}
    assert %Link{} = profile.links["dashboard"]
    assert profile.raw["futureField"] == true
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{status: 200, headers: %{}, body: %{"resource" => "profile"}, raw: %{}}

    assert {:error, %Error{type: :decode, reason: :invalid_profile_response}} =
             Profile.from_response(response, :profiles_get)
  end
end
