defmodule Mix.Tasks.Kiq.Gen.ReporterTest do
  use Kiq.Case

  setup do
    on_exit(&delete_tempfiles/0)
  end

  test "geenerate a new reporter" do
    in_tmp("gen.reporter", fn ->
      Mix.Tasks.Kiq.Gen.Reporter.run(["Kiq.Reporters.Custom"])

      assert File.regular?("lib/kiq/reporters/custom.ex")
      assert File.read!("lib/kiq/reporters/custom.ex") =~ "defmodule Kiq.Reporters.Custom do"

      assert_received {:mix_shell, :info, ["* creating lib/kiq/reporters/custom.ex"]}

      ensure_formatted!("lib/kiq/reporters/custom.ex")
    end)
  end
end
