defmodule MollieExTest do
  use ExUnit.Case, async: true

  test "placeholder module loads" do
    assert Code.ensure_loaded?(MollieEx)
  end
end
