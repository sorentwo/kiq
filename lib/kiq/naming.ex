defmodule Kiq.Naming do
  @moduledoc false

  @spec queue_name(binary()) :: binary()
  def queue_name(queue), do: "queue:#{queue}"

  @spec backup_name(binary(), binary()) :: binary()
  def backup_name(id, queue), do: "queue:backup|#{id}|#{queue}"

  @spec unlock_name(binary()) :: binary()
  def unlock_name(token), do: "unique:#{token}"
end
