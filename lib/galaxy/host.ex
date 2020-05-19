defmodule Galaxy.Host do
  @moduledoc """
  This topologying strategy relies on Erlang's built-in distribution protocol by
  using a `.hosts.erlang` file (as used by the `:net_adm` module).

  Please see [the net_adm docs](http://erlang.org/doc/man/net_adm.html) for more details.

  In short, the following is the gist of how it works:

  > File `.hosts.erlang` consists of a number of host names written as Erlang terms. It is looked for in the current work
  > directory, the user's home directory, and $OTP_ROOT (the root directory of Erlang/OTP), in that order.

  This looks a bit like the following in practice:

  ```erlang
  'super.eua.ericsson.se'.
  'renat.eua.ericsson.se'.
  'grouse.eua.ericsson.se'.
  'gauffin1.eua.ericsson.se'.

  ```

  An optional timeout can be specified in the config. This is the timeout that
  will be used in the GenServer to connect the nodes. This defaults to
  `:infinity` meaning that the connection process will only happen when the
  worker is started. Any integer timeout will result in the connection process
  being triggered. In the example above, it has been configured for 30 seconds.
  """
  use GenServer
  require Logger

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options) do
    case :net_adm.host_file() do
      {:error, _} ->
        :ignore

      hosts ->
        topology = Keyword.fetch!(options, :topology)
        polling_interval = Keyword.fetch!(options, :polling_interval)

        state = %{
          topology: topology,
          polling_interval: polling_interval,
          hosts: hosts
        }

        send(self(), :poll)

        {:ok, state}
    end
  end

  @impl true
  def handle_info(:poll, state) do
    state.hosts
    |> :net_adm.world_list()
    |> state.topology.connect_nodes()

    Process.send_after(self(), :poll, state.polling_interval)

    {:noreply, state}
  end
end
