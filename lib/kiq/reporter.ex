defmodule Kiq.Reporter do
  @moduledoc """
  Job handling is performed by reporters, which are customized `GenStage`
  consumers.

  This module specifies the reporter behaviour and provies an easy way to
  define new reporters via `use Kiq.Reporter`. The `using` macro defines all
  necessary `GenStage` functions and defines no-op handlers for all events.

  ## Example Custom Reporter

  Custom reporters may be defined within your application. One common use-case
  for custom reporters would be reporting exceptions to a tracking service. Here
  we will define a reporter for [Honeybadger](https://honeybadger.io):

      defmodule MyApp.Reporters.Honeybadger do
        @moduledoc false

        use Kiq.Reporter

        @impl Kiq.Reporter
        def handle_failure(job, error, stacktrace, state) do
          metadata = Map.take(job, [:jid, :class, :args, :queue, :retry_count])

          :ok = Honeybadger.notify(error, metadata, stacktrace)

          state
        end
      end

  Next you'll need to specify the reporter inside your application's `Kiq`
  module, using `extra_reporters`:

      defmodule MyApp.Kiq do
        @moduledoc false

        alias MyApp.Reporters.Honeybadger

        use Kiq, queues: [default: 50], extra_reporters: [Honeybadger]
      end

  This guarantees that your reporter will be supervised by the reporter
  supervisor, and that it will be re-attached to the reporter producer upon
  restart if the reporter crashes.

  ## Notes About State

  Handler functions are always invoked with the current state. The return value
  of each handler function will be used as the updated state after all events
  are processed.
  """

  alias Kiq.{Config, Job}

  @type options :: [config: Config.t(), name: identifier()]
  @type state :: any()

  @doc """
  Emitted when a worker starts processing a job.
  """
  @callback handle_started(job :: Job.t(), state :: state()) :: state()

  @doc """
  Emitted when a worker has completed a job and no failures ocurred.
  """
  @callback handle_success(job :: Job.t(), meta :: Keyword.t(), state :: state()) :: state()

  @doc """
  Emitted when job processing has been intentionally aborted.
  """
  @callback handle_aborted(job :: Job.t(), meta :: Keyword.t(), state :: state()) :: state()

  @doc """
  Emitted when an exception ocurred while processing a job.
  """
  @callback handle_failure(
              job :: Job.t(),
              error :: Exception.t(),
              stack :: list(),
              state :: state()
            ) :: state()

  @doc """
  Emitted when the worker has completed the job, regardless of whether it
  succeded or failed.
  """
  @callback handle_stopped(job :: Job.t(), state :: state()) :: state()

  @doc false
  defmacro __using__(_opts) do
    quote do
      use GenStage

      alias Kiq.Reporter

      @behaviour Reporter

      @doc false
      @spec start_link(opts :: Reporter.options()) :: GenServer.on_start()
      def start_link(opts) do
        {name, opts} = Keyword.pop(opts, :name)

        GenStage.start_link(__MODULE__, opts, name: name)
      end

      @impl GenStage
      def init(opts) do
        opts = Keyword.delete(opts, :config)

        {:consumer, :ok, opts}
      end

      @impl GenStage
      def handle_events(events, _from, state) do
        new_state =
          Enum.reduce(events, state, fn event, state ->
            case event do
              {:started, job} -> handle_started(job, state)
              {:success, job, meta} -> handle_success(job, meta, state)
              {:aborted, job, meta} -> handle_aborted(job, meta, state)
              {:failure, job, error, stack} -> handle_failure(job, error, stack, state)
              {:stopped, job} -> handle_stopped(job, state)
            end
          end)

        {:noreply, [], new_state}
      end

      @impl Reporter
      def handle_started(_job, state), do: state

      @impl Reporter
      def handle_success(_job, _meta, state), do: state

      @impl Reporter
      def handle_aborted(_job, _meta, state), do: state

      @impl Reporter
      def handle_failure(_job, _error, _stack, state), do: state

      @impl Reporter
      def handle_stopped(_job, state), do: state

      defoverridable start_link: 1,
                     init: 1,
                     handle_events: 3,
                     handle_aborted: 3,
                     handle_failure: 4,
                     handle_started: 2,
                     handle_stopped: 2,
                     handle_success: 3
    end
  end
end
