# Executable specifications run as their own stage: `mix acceptance`.
ExUnit.start(exclude: [:acceptance])
Ecto.Adapters.SQL.Sandbox.mode(Sturdy.Repo, :manual)
