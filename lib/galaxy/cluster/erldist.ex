defmodule Galaxy.Cluster.Erldist do
  @moduledoc """
  Native Erlang Distribution interface.
  """
  @behaviour Galaxy.Cluster

  def connects(nodes) do
    Enum.each(nodes, &Node.connect(&1))
  end

  def disconnects(nodes) do
    Enum.each(nodes, &Node.disconnect(&1))
  end

  def members do
    Node.list()
  end
end
