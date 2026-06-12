defmodule MollieEx.HTTP.RetryDelay do
  @moduledoc false

  @base_delay 250
  @max_delay 5_000

  @spec jittered_exponential(non_neg_integer()) :: non_neg_integer()
  def jittered_exponential(retry_count) do
    jittered_exponential(retry_count, &:rand.uniform/1)
  end

  @spec jittered_exponential(non_neg_integer(), (pos_integer() -> pos_integer())) ::
          non_neg_integer()
  def jittered_exponential(retry_count, random_fun)
      when is_integer(retry_count) and retry_count >= 0 and is_function(random_fun, 1) do
    delay = exponential_delay(retry_count)
    jitter = random_fun.(delay) - 1

    min(delay + jitter, @max_delay)
  end

  defp exponential_delay(retry_count) do
    @base_delay
    |> Kernel.*(Integer.pow(2, retry_count))
    |> min(@max_delay)
  end
end
