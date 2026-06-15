defmodule MollieEx.CapabilityTest do
  use ExUnit.Case, async: true

  alias MollieEx.Capability
  alias MollieEx.Error
  alias MollieEx.HTTP.Response
  alias MollieEx.Types.Link

  test "hydrates stable fields and preserves raw response data" do
    body = %{
      "resource" => "capability",
      "name" => "payments",
      "requirements" => [
        %{
          "id" => "legal-representatives",
          "dueDate" => nil,
          "status" => "requested",
          "_links" => %{"dashboard" => %{"href" => "https://my.mollie.com/dashboard"}}
        }
      ],
      "status" => "enabled",
      "statusReason" => nil,
      "organizationId" => "org_12345678",
      "_links" => %{
        "self" => %{
          "href" => "https://api.mollie.com/v2/capabilities/payments",
          "type" => "application/hal+json"
        }
      },
      "futureField" => true
    }

    assert {:ok, %Capability{} = capability} =
             Capability.from_response(
               %Response{status: 200, headers: %{}, body: body, raw: body},
               :test
             )

    assert capability.resource == "capability"
    assert capability.name == "payments"
    assert capability.status == "enabled"
    assert capability.status_reason == nil
    assert capability.organization_id == "org_12345678"
    assert [%{"id" => "legal-representatives"}] = capability.requirements

    assert %Link{href: "https://api.mollie.com/v2/capabilities/payments"} =
             capability.links["self"]

    assert capability.raw["futureField"] == true
  end

  test "status helpers match known capability states" do
    assert Capability.enabled?(%Capability{
             resource: "capability",
             name: "payments",
             status: "enabled",
             raw: %{}
           })

    assert Capability.pending?(%Capability{
             resource: "capability",
             name: "payments",
             status: "pending",
             raw: %{}
           })

    assert Capability.disabled?(%Capability{
             resource: "capability",
             name: "payments",
             status: "disabled",
             raw: %{}
           })

    refute Capability.enabled?(%Capability{
             resource: "capability",
             name: "payments",
             status: "disabled",
             raw: %{}
           })

    refute Capability.pending?(:not_capability)
  end

  test "returns a decode error for invalid response shape" do
    response = %Response{
      status: 200,
      headers: %{},
      body: %{"resource" => "capability"},
      raw: %{}
    }

    assert {:error, %Error{type: :decode, reason: :invalid_capability_response}} =
             Capability.from_response(response, :capabilities_list)
  end
end
