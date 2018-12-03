defmodule Mix.Tasks.Kiq.Gen.Supervisor do
  use Mix.Task

  import Mix.Kiq
  import Mix.Generator

  @shortdoc "Generates a new supervisor"

  @moduledoc """
  Generates a new supervisor.

  The module will be placed within the `lib` directory.

  ## Examples

      mix kiq.gen.supervisor MyApp.Kiq
  """

  embed_template(:module, """
  defmodule <%= inspect @mod %> do
    @moduledoc false

    use Kiq, pool_size: 5, queues: [default: 25]

    @impl true
    def init(_reason, opts) do
      test_mode = if testing?(), do: :sandbox, else: :disabled

      opts =
        opts
        |> Keyword.put(:client_opts, redis_url: System.get_env("REDIS_URL"))
        |> Keyword.put(:server?, start_server?())
        |> Keyword.put(:test_mode, test_mode)

      {:ok, opts}
    end

    defp console?, do: Code.ensure_loaded?(IEx) and IEx.started?()

    defp testing?, do: Code.ensure_loaded?(Mix) and Mix.env() == :test

    defp start_server?, do: not testing?() and not console?()
  end
  """)

  @doc false
  def run(args) do
    no_umbrella!("kiq.gen.supervisor")

    name = extract_name(args)
    file = extract_file(name)

    create_directory(Path.dirname(file))
    create_file(file, module_template(mod: name))

    Mix.shell().info("""
    Be sure to add the new supervisor to your application's supervision tree:

        {#{inspect(name)}, []}
    """)
  end
end
