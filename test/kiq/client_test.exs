defmodule Kiq.ClientTest do
  use Kiq.Case, async: true

  alias Kiq.Client

  describe "using with testing in :sandbox mode" do
    setup do
      {:ok, client} = start_supervised({Client, config: config(test_mode: :sandbox)})

      {:ok, client: client}
    end

    test "stored jobs may be fetched by the enqueueing process", %{client: client} do
      {:ok, job_a} = Client.store(client, job())
      {:ok, job_b} = Client.store(client, job())

      fn ->
        {:ok, job_c} = Client.store(client, job())
        {:ok, job_d} = Client.store(client, job())

        assert [^job_c, ^job_d] = Client.fetch(client)
      end
      |> Task.async()
      |> Task.await()

      assert [^job_a, ^job_b] = Client.fetch(client)
      assert [_job_a, _job_b, _job_c, _job_d] = Client.fetch(client, :shared)

      :ok = stop_supervised(Client)
    end
  end
end
