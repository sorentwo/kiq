defmodule Mix.Tasks.Kiq.Gen.Reporter do
  use Mix.Task

  import Mix.Kiq
  import Mix.Generator

  @shortdoc "Generates a new reporter"

  @moduledoc """
  Generates a new reporter.

  The module will be nested within the `lib` directory. Custom reporters
  must be listed as `:extra_reporters` in your configuration.

  ## Examples

      mix kiq.gen.reporter Kiq.Reporters.Custom
  """

  embed_template(:reporter, """
  defmodule <%= inspect @mod %> do
    @moduledoc false

    use Kiq.Reporter

    @impl true
    def handle_started(job, state) do
      state
    end

    @impl true
    def handle_success(job, meta, state) do
      state
    end

    @impl true
    def handle_aborted(job, meta, state) do
      state
    end

    @impl true
    def handle_failure(job, error, stacktrace, state) do
      state
    end
  end
  """)

  @doc false
  def run(args) do
    no_umbrella!("kiq.gen.reporter")

    name = extract_name(args)
    file = extract_file(name)

    create_directory(Path.dirname(file))
    create_file(file, reporter_template(mod: name))

    Mix.shell().info("""
    Be sure to add your custom reporter to the supervisor's configuration:

        use Kiq, extra_reporters: [#{inspect(name)}], ...
    """)
  end
end
