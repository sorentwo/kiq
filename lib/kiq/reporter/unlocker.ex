defmodule Kiq.Reporter.Unlocker do
  @moduledoc false

  use Kiq.Reporter

  alias Kiq.{Client, Job, Reporter}

  defmodule State do
    @moduledoc false

    defstruct client: nil
  end

  # Callbacks

  @impl GenStage
  def init(opts) do
    {conf, opts} = Keyword.pop(opts, :config)

    {:consumer, %State{client: conf.client_name}, opts}
  end

  @impl Reporter
  def handle_started(job, state) do
    maybe_unlock(job, "start", state)
  end

  @impl Reporter
  def handle_success(%Job{unique_until: until} = job, _meta, state) do
    maybe_unlock(%Job{job | unique_until: until || "success"}, "success", state)
  end

  # Helpers

  defp maybe_unlock(%Job{unique_token: token, unique_until: until} = job, until, state)
       when is_binary(token) do
    :ok = Client.unlock_job(state.client, job)

    state
  end

  defp maybe_unlock(_job, _until, state), do: state
end
