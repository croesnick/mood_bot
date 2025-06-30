defmodule MoodBotTest do
  use ExUnit.Case
  doctest MoodBot

  test "greets the world" do
    assert MoodBot.hello() == :world
  end
end
