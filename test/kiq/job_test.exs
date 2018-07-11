defmodule Kiq.JobTest do
  use Kiq.Case, async: true

  alias Kiq.Job

  doctest Job

  describe "encode/1" do
    test "transient and nil values are omitted" do
      decoded =
        [pid: self(), args: [1, 2], queue: "default"]
        |> job()
        |> Job.encode()
        |> Job.decode(keys: :atoms)

      assert %{queue: "default", args: [1, 2]} = decoded

      assert decoded[:jid]
      assert decoded[:class]
      refute decoded[:pid]
      refute decoded[:failed_at]
    end
  end
end
