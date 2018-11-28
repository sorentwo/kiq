defmodule Mix.Tasks.Kiq.Gen.Worker do
  use Mix.Task

  import Mix.Kiq
  import Mix.Generator

  @shortdoc "Generates a new worker"

  @moduledoc """
  Generates a new worker.

  The module will be nested within the `lib` directory.

  ## Examples

    mix kiq.gen.worker MyApp.Workers.Business
    mix kiq.gen.worker MyApp.Workers.Essential -q critical
    mix kiq.gen.worker MyApp.Workers.Unimportant -r 3
    mix kiq.gen.worker MyApp.Workers.Lifeless --no-dead

  ## Command Line Options

    * `-d`, `--dead`, `--no-dead` — whether the job will be pushed to the dead set when retries are exhausted
    * `-q`, `--queue` — the queue this worker's jobs will run in
    * `-r`, `--retry` — the number of times jobs will be retried
  """

  embed_template(:worker, """
  defmodule <%= inspect(@mod) %> do
    @moduledoc false

    use Kiq.Worker<%= for {key, val} <- @opts do %>, <%= key %>: <%= inspect(val) %><% end %>

    @impl true
    def perform(args) do
      IO.inspect(args)
    end
  end
  """)

  @doc false
  def run(args) do
    no_umbrella!("kiq.gen.reporter")

    {name, opts} = extract_opts(args)

    file = extract_file(name)

    create_directory(Path.dirname(file))
    create_file(file, worker_template(mod: name, opts: opts))
  end

  @aliases [d: :dead, q: :queue, r: :retry]
  @switches [dead: :boolean, queue: :string, retry: :integer]

  defp extract_opts([name | args]) do
    {opts, _rest, _invalid} = OptionParser.parse(args, aliases: @aliases, switches: @switches)

    {Module.concat([name]), Keyword.put_new(opts, :queue, "default")}
  end

  defp extract_opts([]) do
    Mix.raise("kiq.gen.worker expects a module name as the first argument")
  end
end
