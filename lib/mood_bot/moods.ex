defmodule MoodBot.Moods do
  @moduledoc """
  Centralized mood sentiment definitions and robot face file mappings.

  This module provides the single source of truth for MoodBot's sentiment
  categories and their corresponding robot face image files. It ensures
  consistency across the application when displaying moods.
  """

  @typedoc "MoodBot sentiment categories"
  @type sentiment :: :happy | :affirmation | :skeptic | :surprised | :angry | :crying | :error

  @doc """
  Returns the file path for a given mood's robot face image.

  ## Parameters
  - `mood` - The sentiment to get the file path for

  ## Returns
  - String path to the PBM file for the mood
  - Defaults to happy face for unknown moods

  ## Examples

      iex> MoodBot.Moods.file_path(:happy)
      "assets/moods/robot-face-happy.pbm"

      iex> MoodBot.Moods.file_path(:angry)
      "assets/moods/robot-face-angry.pbm"
  """
  @spec file_path(sentiment()) :: String.t()
  def file_path(:happy), do: Path.join(:code.priv_dir(:mood_bot), "assets/moods/robot-face-happy.pbm")
  def file_path(:affirmation), do: Path.join(:code.priv_dir(:mood_bot), "assets/moods/robot-face-approval.pbm")
  def file_path(:skeptic), do: Path.join(:code.priv_dir(:mood_bot), "assets/moods/robot-face-skeptic.pbm")
  def file_path(:surprised), do: Path.join(:code.priv_dir(:mood_bot), "assets/moods/robot-face-surprise.pbm")
  def file_path(:crying), do: Path.join(:code.priv_dir(:mood_bot), "assets/moods/robot-face-crying.pbm")
  def file_path(:angry), do: Path.join(:code.priv_dir(:mood_bot), "assets/moods/robot-face-angry.pbm")
  def file_path(:error), do: Path.join(:code.priv_dir(:mood_bot), "assets/moods/robot-face-shocked.pbm")
  def file_path(_), do: Path.join(:code.priv_dir(:mood_bot), "assets/moods/robot-face-approval.pbm")

  @doc """
  Returns a list of all valid sentiment atoms.

  ## Examples

      iex> MoodBot.Moods.all_sentiments()
      [:happy, :affirmation, :skeptic, :surprised, :angry, :crying, :error]
  """
  @spec all_sentiments() :: [sentiment()]
  def all_sentiments do
    [:happy, :affirmation, :skeptic, :surprised, :angry, :crying, :error]
  end
end
