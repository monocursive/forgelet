defmodule Mix.Tasks.Forgelet.Demo do
  @moduledoc """
  Runs the Forgelet demo workflow.

  ## Usage

      mix forgelet.demo
  """

  use Mix.Task

  @shortdoc "Runs the Forgelet collaboration demo"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")
    Forgelet.Demo.run()
  end
end
