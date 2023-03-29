defmodule Mix.Tasks.Crawl do
  use Mix.Task

  @shortdoc "Run crawler"

  @impl Mix.Task
  def run([file_name]) do
    LoudspeakerCrawling.csv_from_url(file_name)
  end
end
