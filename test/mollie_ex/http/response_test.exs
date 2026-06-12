defmodule MollieEx.HTTP.ResponseTest do
  use ExUnit.Case, async: true

  alias MollieEx.HTTP.Response

  test "stores decoded response body and raw payload" do
    raw = %{"id" => "tr_123", "_links" => %{"self" => %{"href" => "https://example.test"}}}

    response = %Response{
      status: 200,
      headers: %{"content-type" => ["application/json"]},
      body: raw,
      raw: raw
    }

    assert response.status == 200
    assert response.body == raw
    assert response.raw == raw
    assert response.headers["content-type"] == ["application/json"]
  end
end
