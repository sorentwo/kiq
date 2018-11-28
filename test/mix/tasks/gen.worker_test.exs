defmodule Mix.Tasks.Kiq.Gen.WorkerTest do
  use Kiq.Case

  setup do
    on_exit(&delete_tempfiles/0)
  end

  test "geenerate a new worker" do
    in_tmp("gen.worker", fn ->
      args = ["MyApp.Workers.Business", "-q", "events", "--retry", "10", "--no-dead"]

      Mix.Tasks.Kiq.Gen.Worker.run(args)

      assert File.regular?("lib/my_app/workers/business.ex")

      content = File.read!("lib/my_app/workers/business.ex")
      assert content =~ "defmodule MyApp.Workers.Business do"
      assert content =~ "use Kiq.Worker, queue: \"events\", retry: 10, dead: false"

      assert_received {:mix_shell, :info, ["* creating lib/my_app/workers/business.ex"]}

      ensure_formatted!("lib/my_app/workers/business.ex")
    end)
  end
end
