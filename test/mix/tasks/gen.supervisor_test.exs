defmodule Mix.Tasks.Kiq.Gen.SupervisorTest do
  use Kiq.Case

  setup do
    on_exit(&delete_tempfiles/0)
  end

  test "generating a new supervisor" do
    in_tmp("gen.supervisor", fn ->
      Mix.Tasks.Kiq.Gen.Supervisor.run(["MyApp.Kiq"])

      assert File.regular?("lib/my_app/kiq.ex")
      assert File.read!("lib/my_app/kiq.ex") =~ "defmodule MyApp.Kiq do"

      assert_received {:mix_shell, :info, ["* creating lib/my_app/kiq.ex"]}

      ensure_formatted!("lib/my_app/kiq.ex")
    end)
  end
end
