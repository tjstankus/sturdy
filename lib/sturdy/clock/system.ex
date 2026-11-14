defmodule Sturdy.Clock.System do
  @moduledoc """
  The real clock.
  """

  @behaviour Sturdy.Clock

  @impl Sturdy.Clock
  @spec utc_now() :: DateTime.t()
  def utc_now, do: DateTime.utc_now()
end
