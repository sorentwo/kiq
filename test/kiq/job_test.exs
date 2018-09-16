defmodule Kiq.JobTest do
  use Kiq.Case, async: true
  use ExUnitProperties

  alias Kiq.Job

  doctest Job

  defp encode(args) do
    args
    |> job()
    |> Job.encode()
  end

  describe "encode/1" do
    test "transient and nil values are omitted" do
      decoded =
        [pid: self(), args: [1, 2], queue: "default"]
        |> job()
        |> Job.encode()
        |> Job.decode()

      assert decoded.queue == "default"
      assert decoded.args == [1, 2]
      assert decoded.jid
      assert decoded.class
      refute decoded.pid
      refute decoded.failed_at
    end

    test "retry_count values are only retained when greater than 0" do
      refute encode(retry_count: 0) =~ "retry_count"
      assert encode(retry_count: 1) =~ "retry_count"
    end
  end

  describe "unique_key/1" do
    property "job with any args can generate a valid unique_key" do
      check all class <- binary(min_length: 1),
                queue <- binary(min_length: 1),
                args <- list_of(one_of([boolean(), integer(), binary()])) do
        job = Job.new(args: args, class: class, queue: queue)

        assert Job.unique_key(job) =~ ~r/\A[a-z0-9]{40}\z/
      end
    end
  end
end
