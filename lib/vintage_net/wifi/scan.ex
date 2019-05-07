defmodule VintageNet.WiFi.Scan do
  alias VintageNet.WiFi.AccessPoint
  require Logger

  @moduledoc """

  """

  @doc """
  Scan wireless interface for other access points
  """
  @spec scan(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def scan(ifname, scan_time \\ 5_000) do
    with {:ok, _} <- run_wpa_cli(ifname, "scan"),
         _ <- :timer.sleep(scan_time),
         {:ok, results} <- run_wpa_cli(ifname, "scan_results") do
      {:ok, parse(results)}
    else
      {error, 255} -> {:error, error}
    end
  end

  defp run_wpa_cli(ifname, command) do
    bin_wpa_cli = Application.get_env(:vintage_net, :bin_wpa_cli)
    tmpdir = Application.get_env(:vintage_net, :tmpdir)
    ctrl_interface = Path.join([tmpdir, "wpa_supplicant", ifname])

    case System.cmd(bin_wpa_cli, ["-i", ifname, "-g", ctrl_interface, command]) do
      {results, 0} -> {:ok, results}
      {error, _} -> {:error, error}
    end
  end

  @doc """
  Parse results from wpa_cli into a list of access points
  """
  @spec parse(String.t()) :: [AccessPoint.t()]
  def parse(results) do
    results
    |> String.split("\n", trim: true)
    |> Enum.flat_map(&parse_line/1)
  end

  defp parse_line("bssid / frequency / signal level / flags / ssid"), do: []

  defp parse_line(row) do
    row
    |> String.split("\t")
    |> parse_fields()
  end

  defp parse_fields([bssid, frequency, signal, flags, ssid]) do
    [
      %AccessPoint{
        bssid: bssid,
        frequency: String.to_integer(frequency),
        signal: String.to_integer(signal),
        flags: parse_flags(flags),
        ssid: ssid
      }
    ]
  end

  defp parse_fields(_other), do: []

  defp parse_flags(flags) do
    flags
    |> String.split(["]", "["], trim: true)
    |> Enum.flat_map(&parse_flag/1)
  end

  defp parse_flag("WPA2-PSK-CCMP"), do: [:wpa2_psk_ccmp]
  defp parse_flag("ESS"), do: [:ess]
  defp parse_flag("P2P"), do: [:p2p]

  defp parse_flag(other) do
    _ = Logger.warn("Ignoring unknown WiFi Access Point flag: #{other}")
    []
  end
end
