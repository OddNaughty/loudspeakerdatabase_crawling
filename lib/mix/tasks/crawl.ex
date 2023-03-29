defmodule Mix.Tasks.Crawl do
  use Mix.Task

  @shortdoc "Run crawler"

  @impl Mix.Task
  def run([file_name]) do
    Mix.Task.run("app.start")
    LoudspeakerCrawling.csv_from_url(file_name)
  end
end
