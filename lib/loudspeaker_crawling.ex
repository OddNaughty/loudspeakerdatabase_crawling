import Meeseeks.XPath
import Meeseeks.CSS
alias NimbleCSV.RFC4180, as: CSV

require Logger

defmodule LoudspeakerCrawling do
  @base_url "http://www.loudspeakerdatabase.com/"
  @csv_header ~w"brand name impedance size type rms_power qts sensitivity vas freq_range xmax price url miniature_url_1 miniature_url_2"

  @doc """
  This is where we receive the speaker datas
  You could use Meeseeks to get the data you want
  and put it in the return map
  """
  def parse_ls_miniature(ls_div) do
    size_type = Meeseeks.one(ls_div, css("[itemprop='description']")) |> Meeseeks.text()
    [size | type] = size_type |> String.split()
    type = Enum.join(type, "-")
    miniature_url = Meeseeks.one(ls_div, css("img")) |> Meeseeks.attr("src") || ""

    %{
      "price" => Meeseeks.one(ls_div, css("span.price")) |> Meeseeks.text(),
      "brand" => Meeseeks.one(ls_div, css("span[itemprop='brand']")) |> Meeseeks.text(),
      "name" => Meeseeks.one(ls_div, css("span[itemprop='name']")) |> Meeseeks.text(),
      "url" =>
        URI.merge(
          @base_url,
          Meeseeks.one(ls_div, css("a[itemprop='url']")) |> Meeseeks.attr("href")
        )
        |> to_string,
      "impedance" => Meeseeks.one(ls_div, css("td.brand_ref_price")) |> Meeseeks.own_text(),
      "fs" => Meeseeks.one(ls_div, xpath("tr[2]/td[3]/b")) |> Meeseeks.text(),
      "size" => size,
      "type" => type,
      "rms_power" => Meeseeks.one(ls_div, xpath("tr[3]/td[2]/b")) |> Meeseeks.text(),
      "qts" => Meeseeks.one(ls_div, xpath("tr[3]/td[4]/b")) |> Meeseeks.text(),
      "sensitivity" => Meeseeks.one(ls_div, xpath("tr[4]/td[2]/b")) |> Meeseeks.text(),
      "vas" => Meeseeks.one(ls_div, xpath("tr[4]/td[4]/b")) |> Meeseeks.text(),
      "freq_range" => Meeseeks.one(ls_div, xpath("tr[5]/td[2]/b")) |> Meeseeks.text(),
      "xmax" => Meeseeks.one(ls_div, xpath("tr[5]/td[4]/b")) |> Meeseeks.text(),
      "miniature_url_1" => URI.merge(@base_url, miniature_url) |> to_string(),
      "miniature_url_2" =>
        URI.merge(@base_url, miniature_url) |> to_string() |> String.replace("photo", "photo2")
    }
  end

  def stream_to_csv(stream, csv_header \\ @csv_header) do
    # TODO: See if we can use Enum.zip instead of the ugly reduce
    # And check on stream.transform, maybe not adapted for putting headers...
    Stream.transform(stream, :first, fn
      ls_div, :first ->
        parsed = LoudspeakerCrawling.parse_ls_miniature(ls_div)

        to_csv =
          Enum.reduce(Enum.reverse(csv_header), [], fn key, values ->
            [Map.get(parsed, key) | values]
          end)

        {[csv_header | [to_csv]], []}

      ls_div, [] ->
        parsed = LoudspeakerCrawling.parse_ls_miniature(ls_div)

        to_csv =
          Enum.reduce(Enum.reverse(csv_header), [], fn key, values ->
            [Map.get(parsed, key) | values]
          end)

        {[to_csv], []}
    end)
    |> CSV.dump_to_stream()
  end

  def ls_datas_from_csv() do
    File.stream!("lc_simples_datas.csv")
    |> CSV.parse_stream()
    |> Stream.map(&(Enum.zip(@csv_header, &1) |> Enum.into(%{})))
  end

  def ls_datas_from_exports_html() do
    # * Test function with exported LS divs
    File.ls!("exports")
    |> Enum.filter(&(Path.extname(&1) != ".csv"))
    |> Stream.flat_map(fn path ->
      body = Path.join("exports", path) |> File.read!()
      ls_selector = css("div.ui")
      Meeseeks.all(body, ls_selector)
    end)
  end

  def get_ls_datas_from_url() do
    Stream.map(1..100, fn page ->
      IO.puts("Getting page #{page}")
      body = HTTPoison.get!(@base_url, [], params: [page: page]).body
      ls_selector = css("html body div.results div.ui")
      divs = Meeseeks.all(body, ls_selector)

      export =
        Enum.reduce(divs, [], fn div, acc ->
          [Meeseeks.html(div) | acc]
        end)
        |> Enum.reverse()
        |> Enum.join("\n")

      if _debug = false do
        File.write!("exports/export_page_#{page}", export)
      end

      divs
    end)
  end

  def extract_ts_from_ts_param_div(%Meeseeks.Result{} = _ts_param_div) do
    # TODO: extract here
  end

  def get_ts_param_div_from_product_urls(urls) do
    Stream.map(urls, fn url ->
      page = URI.merge(@base_url, url)
      Logger.debug("Getting product page #{page}")
      body = HTTPoison.get!(page).body
      Meeseeks.one(body, css("div.ts_param"))
    end)
  end

  def get_loudspeaker_urls() do
    Stream.map(1..100, fn page ->
      Logger.debug("Getting product page #{page}")
      body = HTTPoison.get!(@base_url, [], params: [page: page]).body
      ls_selector = css("html body div.results div.ui [itemprop=\"url\"]")

      _urls =
        body
        |> Meeseeks.all(ls_selector)
        |> Enum.map(&Meeseeks.attr(&1, "href"))
    end)
  end

  def csv_from_url(_path) do
    LoudspeakerCrawling.get_loudspeaker_urls()
    |> Stream.flat_map(& &1)
    |> LoudspeakerCrawling.get_ts_param_div_from_product_urls()
    |> LoudspeakerCrawling.extract_ts_from_ts_param_div()
    # Here, I say to the stream to take only one element, for testing purpose
    |> Stream.take(1)
    |> Stream.run()

    # |> LoudspeakerCrawling.stream_to_csv()
    # |> Stream.into(File.stream!(path))
    # |> Stream.run()
  end
end
