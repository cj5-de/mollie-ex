defmodule MollieEx.HTTP.RetryDelayTest do
  use ExUnit.Case, async: true

  alias MollieEx.HTTP.RetryDelay

  test "first retry jitter starts at base delay and stays below double base delay" do
    assert RetryDelay.jittered_exponential(0, fn 250 -> 1 end) == 250
    assert RetryDelay.jittered_exponential(0, fn 250 -> 250 end) == 499
  end

  test "later retry delays are capped at the maximum delay" do
    assert RetryDelay.jittered_exponential(5, fn 5_000 -> 5_000 end) == 5_000
  end

  test "uses injected random values for deterministic jitter" do
    assert RetryDelay.jittered_exponential(2, fn 1_000 -> 126 end) == 1_125
  end
end
