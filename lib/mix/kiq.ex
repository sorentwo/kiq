defmodule Mix.Kiq do
  @moduledoc false

  def no_umbrella!(task) do
    if Mix.Project.umbrella?() do
      Mix.raise("Cannot run task #{task} from umbrella application")
    end
  end

  def extract_name(args) do
    case args do
      [module] -> Module.concat([module])
      _ -> Mix.raise("kiq.gen.* expects a module name as the first argument")
    end
  end

  def extract_file(name) do
    base = Macro.underscore(name)

    Path.join("lib", base) <> ".ex"
  end
end
