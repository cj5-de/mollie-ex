defmodule MollieEx.OnboardingStatusTest do
  use ExUnit.Case, async: true

  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.OnboardingStatus
  alias MollieEx.Types.Link

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "onboarding",
      "name" => "Mollie B.V.",
      "status" => "needs-data",
      "canReceivePayments" => false,
      "canReceiveSettlements" => false,
      "signedUpAt" => "2023-12-20T10:49:08.0Z",
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/onboarding/me",
          "type" => "application/hal+json"
        }
      },
      "futureField" => true
    }

    assert {:ok, %OnboardingStatus{} = status} =
             OnboardingStatus.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :test
             )

    assert status.resource == "onboarding"
    assert status.name == "Mollie B.V."
    assert status.status == "needs-data"
    assert status.can_receive_payments == false
    assert status.can_receive_settlements == false
    assert status.signed_up_at == "2023-12-20T10:49:08.0Z"

    assert %Link{href: "https://api.mollie.com/v2/onboarding/me"} = status.links["self"]

    assert status.raw["futureField"] == true
  end

  test "status helpers match known onboarding states" do
    assert OnboardingStatus.needs_data?(%OnboardingStatus{
             resource: "onboarding",
             status: "needs-data",
             raw: %{}
           })

    assert OnboardingStatus.in_review?(%OnboardingStatus{
             resource: "onboarding",
             status: "in-review",
             raw: %{}
           })

    assert OnboardingStatus.completed?(%OnboardingStatus{
             resource: "onboarding",
             status: "completed",
             raw: %{}
           })

    refute OnboardingStatus.needs_data?(%OnboardingStatus{
             resource: "onboarding",
             status: "completed",
             raw: %{}
           })

    refute OnboardingStatus.completed?(:not_status)
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 200,
      headers: %{},
      body: %{"resource" => "organization"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_onboarding_status_response}} =
             OnboardingStatus.from_response(response, :onboarding_get)
  end
end
