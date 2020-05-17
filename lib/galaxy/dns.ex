defmodule Galaxy.DNS do
  @moduledoc """
  This topologying strategy works by loading all your Erlang nodes (within Pods) in the current [DNS
  namespace](https://kubernetes.io/docs/concepts/service-networking/dns-pod-service/).
  It will fetch the targets of all pods under a shared headless service and attempt to connect.
  It will continually monitor and update its connections every 5s.

  It assumes that all Erlang nodes were launched under a base name, are using longnames, and are unique
  based on their FQDN, rather than the base hostname. In other words, in the following
  longname, `<basename>@<ip>`, `basename` would be the value configured through
  `application_name`.
  """
  use GenServer
  require Logger

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options) do
    services = Keyword.fetch!(options, :services)
    topology = Keyword.fetch!(options, :topology)
    dns_mode = Keyword.fetch!(options, :dns_mode)
    epmd_port = Keyword.fetch!(options, :epmd_port)
    polling_interval = Keyword.fetch!(options, :polling_interval)

    state = %{
      topology: topology,
      polling_interval: polling_interval,
      services: services,
      epmd_port: epmd_port,
      dns_mode: dns_mode
    }

    send(self(), :poll)

    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    state.services
    |> resolve_service_nodes(state.dns_mode)
    |> filter_epmdless_services(state.epmd_port)
    |> normalize_node_hosts()
    |> :net_adm.world_list()
    |> state.topology.connect_nodes()

    Process.send_after(self(), :poll, state.polling_interval)

    {:noreply, state}
  end

  defp resolve_service_nodes(services, dns_mode) do
    Enum.flat_map(services, fn service ->
      case :inet_res.getbyname(service |> to_charlist(), dns_mode) do
        {:ok, {:hostent, _, _, _, _, hosts}} ->
          hosts

        {:error, :nxdomain} ->
          Logger.error(["Can't resolve DNS for ", service])
          []

        {:error, :timeout} ->
          Logger.error(["DNS timeout for ", service])
          []

        _ ->
          []
      end
    end)
  end

  defp filter_epmdless_services(services, port),
    do: Enum.filter(services, &match?({_, _, ^port, _}, &1))

  defp normalize_node_hosts(hosts),
    do: Enum.map(hosts, &(elem(&1, 3) |> List.to_atom()))
end
