defmodule Sturdy.Acceptance.MovementsSpecTest do
  use Sturdy.AcceptanceCase

  setup %{sturdy: s} do
    s |> given_tags("muscle", ["pecs", "quads"]) |> given_tags("modality", ["isometric"])
    :ok
  end

  test "a movement carries notes, tags, and videos", %{sturdy: s} do
    s
    |> add_movement("Push-up",
      notes: "elbows at 45°",
      tags: ["pecs", "isometric"],
      videos: [{"cues", "https://example.com/push-up?t=10"}]
    )
    |> expect_movement("Push-up",
      notes: "elbows at 45°",
      tags: ["modality: isometric", "muscle: pecs"],
      videos: [{"cues", "https://example.com/push-up?t=10"}]
    )
  end

  test "movement names are unique, ignoring case", %{sturdy: s} do
    s
    |> add_movement("Push-up")
    |> expect_movement_rejected("push-up")
    |> expect_movements(["Push-up"])
  end

  test "movements are listed alphabetically and can be filtered by tag", %{sturdy: s} do
    s
    |> add_movement("Squat", tags: ["quads"])
    |> add_movement("Push-up", tags: ["pecs"])
    |> add_movement("Bench press", tags: ["pecs"])
    |> expect_movements(["Bench press", "Push-up", "Squat"])
    |> expect_movements_tagged("pecs", ["Bench press", "Push-up"])
  end
end
