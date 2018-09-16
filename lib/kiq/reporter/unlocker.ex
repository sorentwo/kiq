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
  def handle_success(%Job{unique_token: token} = job, _meta, state) when is_binary(token) do
    :ok = Client.unlock_job(state.client, job)

    state
  end
end
