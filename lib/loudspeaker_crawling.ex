import Meeseeks.XPath
import Meeseeks.CSS
alias NimbleCSV.RFC4180, as: CSV


defmodule LoudspeakerCrawling do

  @base_url "http://www.loudspeakerdatabase.com/"
  @csv_header ~w"brand name impedance size type rms_power qts sensitivity vas freq_range xmax price url"

  def parse_ls_miniature(ls_div) do
    size_type = Meeseeks.one(ls_div, css("[itemprop='description']")) |> Meeseeks.text
    [size | type] = size_type |> String.split()
    type = Enum.join(type, "-")
    %{
      "price" => Meeseeks.one(ls_div, css("span.price")) |> Meeseeks.text,
      "brand" => Meeseeks.one(ls_div, css("span[itemprop='brand']")) |> Meeseeks.text,
      "name" => Meeseeks.one(ls_div, css("span[itemprop='name']")) |> Meeseeks.text,
      "url" =>
        URI.merge(@base_url, (Meeseeks.one(ls_div, css("a[itemprop='url']")) |> Meeseeks.attr("href")))
        |> to_string,
      "impedance" => Meeseeks.one(ls_div, css("td.brand_ref_price")) |> Meeseeks.own_text,
      "fs" => Meeseeks.one(ls_div, xpath("tr[2]/td[3]/b")) |> Meeseeks.text,
      "size" => size,
      "type" => type,
      "rms_power" => Meeseeks.one(ls_div, xpath("tr[3]/td[2]/b")) |> Meeseeks.text,
      "qts" => Meeseeks.one(ls_div, xpath("tr[3]/td[4]/b")) |> Meeseeks.text,
      "sensitivity" => Meeseeks.one(ls_div, xpath("tr[4]/td[2]/b")) |> Meeseeks.text,
      "vas" => Meeseeks.one(ls_div, xpath("tr[4]/td[4]/b")) |> Meeseeks.text,
      "freq_range" => Meeseeks.one(ls_div, xpath("tr[5]/td[2]/b")) |> Meeseeks.text,
      "xmax" => Meeseeks.one(ls_div, xpath("tr[5]/td[4]/b")) |> Meeseeks.text,
    }
  end

  def parse_ls_product(product_div) do
    # TODO: It's a table, with a lot of incrementals, we can find a way to do this more clearly
    ts_params = Meeseeks.one(product_div, css("div.ts_param"))
    ts_keys = [
      "fs", "qes", "qms", "qts", "vas", "re", "le", "bl", "rms",
      "cms", "mmd", "mms", "sd", "diameter", "xmax", "vd", "n0", "ebp"
    ]
    ts_map = Enum.reduce(Enum.with_index(keys, 1), %{}, fn {key, i}, acc ->
      IO.inspect("Key: #{key}, index: #{i}")
      Map.put(acc, key, Meeseeks.one(ts_params, xpath("tbody/tr[#{i}]/td[3]")) |> Meeseeks.text)
      |> Map.put(key <> "_unit", Meeseeks.one(ts_params, xpath("tbody/tr[#{i}]/td[4]")) |> Meeseeks.text)
    end)
    params =
      Meeseeks.one(product_div, css("div.summary"))
      |> Meeseeks.all(css("div.ui"))
    params_map =
      Enum.zip(["size_in", "size_mm", "rms_power", "max_power", "spl", "freq_range", "impedance", "re"], params)
      |> Enum.into(%{})
      |> Map.merge(ts_map)
    
  end

  def stream_to_csv(stream, csv_header \\ @csv_header) do
    # TODO: See if we can use Enum.zip instead of the ugly reduce
    # And check on stream.transform, maybe not adapted for putting headers...
    Stream.transform(stream, :first, fn
      ls_div, :first ->
        parsed = LoudspeakerCrawling.parse_ls_miniature(ls_div)
        to_csv = Enum.reduce(Enum.reverse(csv_header), [], fn key, values ->
          [Map.get(parsed, key) | values]
        end)
        {[csv_header | [to_csv]], []}
      ls_div, [] ->
        parsed = LoudspeakerCrawling.parse_ls_miniature(ls_div)
        to_csv = Enum.reduce(Enum.reverse(csv_header), [], fn key, values ->
          [Map.get(parsed, key) | values]
        end)
        {[to_csv], []}
    end)
    |> CSV.dump_to_stream()
  end

  def ls_datas_from_csv() do
    File.stream!("lc_simples_datas.csv")
    |> CSV.parse_stream
    |> Stream.map(& Enum.zip(@csv_header, &1) |> Enum.into(%{}))
  end

  def ls_datas_from_exports_html() do
    # * Test function with exported LS divs
    File.ls!("exports")
    |> Enum.filter(& Path.extname(&1) != ".csv")
    |> Stream.flat_map(fn path ->
      body = Path.join("exports", path) |> File.read!
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
      export = Enum.reduce(divs, [], fn div, acc ->
        [Meeseeks.html(div) | acc]
      end) |> Enum.reverse |> Enum.join("\n")
      File.write!("exports/export_page_#{page}", export)
      divs
    end)
  end

  def csv_from_url(path) do
    LoudspeakerCrawling.get_ls_datas_from_url()
    |> LoudspeakerCrawling.stream_to_csv()
    |> Stream.into(File.stream!(path))
    |> Stream.run()
  end

  def complete_data_from_ls_url(url, model) do
    body = HTTPoison.get!(url).body
    _ls = Meeseeks.one(body, css("div##{model}"))
  end
end
