defmodule Kiq.JobTest do
  use Kiq.Case, async: true

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
end
