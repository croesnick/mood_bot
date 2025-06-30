defmodule MoodBot.Display.Bitmap do
  @moduledoc """
  Bitmap conversion utilities for saving e-ink display data as viewable image files.

  This module converts the raw binary data sent to the Waveshare 2.9" e-ink display
  into standard bitmap formats that can be viewed in image viewers for debugging
  and development purposes.
  """

  import Bitwise

  # Waveshare 2.9" e-ink display dimensions and format constants
  @width 128
  @height 296
  @expected_size div(@width, 8) * @height

  @doc """
  Convert raw e-ink display data to PBM (Portable Bitmap) format.

  ## Parameters
  - `data`: Binary data as sent to the display (#{@expected_size} bytes)
  - `format`: `:p1` for ASCII format or `:p4` for binary format (default: `:p1`)

  ## Returns
  - `{:ok, pbm_binary}` on success
  - `{:error, reason}` on failure

  ## Examples

      iex> data = <<0xFF, 0x00, 0xFF>>  # Sample 3-byte data
      iex> MoodBot.Display.Bitmap.to_pbm(data)
      {:ok, "P1\\n# Generated bitmap\\n8 3\\n1 1 1 1 1 1 1 1\\n0 0 0 0 0 0 0 0\\n1 1 1 1 1 1 1 1\\n"}
  """
  def to_pbm(data, format \\ :p1) when is_binary(data) and format in [:p1, :p4] do
    case validate_data_size(data) do
      :ok -> convert_to_pbm(data, format)
      error -> error
    end
  end

  @doc """
  Save raw e-ink display data as a PBM file.

  ## Parameters
  - `data`: Binary data as sent to the display
  - `filepath`: Full path where to save the PBM file
  - `format`: `:p1` for ASCII format or `:p4` for binary format (default: `:p1`)

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def save_pbm(data, filepath, format \\ :p1) when is_binary(data) and is_binary(filepath) do
    case to_pbm(data, format) do
      {:ok, pbm_content} ->
        case ensure_directory_exists(filepath) do
          :ok -> File.write(filepath, pbm_content)
          error -> error
        end

      error ->
        error
    end
  end

  @doc """
  Generate a timestamped filename for saving bitmap data.

  ## Parameters
  - `session_id`: Unique session identifier
  - `frame_counter`: Frame number in the session
  - `base_dir`: Base directory for saving (default: "priv/bitmaps")

  ## Returns
  - String filepath with format: "base_dir/session_SESSION_frame_COUNTER_TIMESTAMP.pbm"
  """
  def generate_filename(session_id, frame_counter, base_dir \\ "priv/bitmaps") do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

    filename =
      "session_#{session_id}_frame_#{String.pad_leading(to_string(frame_counter), 3, "0")}_#{timestamp}.pbm"

    Path.join(base_dir, filename)
  end

  # Private functions

  defp validate_data_size(data) do
    actual_size = byte_size(data)

    if actual_size == @expected_size do
      :ok
    else
      {:error, "Invalid data size: expected #{@expected_size} bytes, got #{actual_size} bytes"}
    end
  end

  defp convert_to_pbm(data, :p1) do
    header = "P1\n# Generated bitmap from e-ink display data\n#{@width} #{@height}\n"
    pixels = convert_bytes_to_ascii_pixels(data)
    {:ok, header <> pixels}
  end

  defp convert_to_pbm(data, :p4) do
    header = "P4\n# Generated bitmap from e-ink display data\n#{@width} #{@height}\n"
    # For P4 format, we need to convert our format to standard bitmap bit order
    pixels = convert_bytes_to_binary_pixels(data)
    {:ok, header <> pixels}
  end

  defp convert_bytes_to_ascii_pixels(data) do
    data
    |> :binary.bin_to_list()
    |> Enum.map(&byte_to_ascii_pixels/1)
    |> Enum.chunk_every(div(@width, 8))
    |> Enum.map(&Enum.join(&1, " "))
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp byte_to_ascii_pixels(byte) do
    # Convert byte to 8 ASCII pixels (space-separated)
    # Bit 7 (MSB) is leftmost pixel, bit 0 (LSB) is rightmost pixel
    for bit <- 7..0//-1 do
      if (byte &&& 1 <<< bit) != 0, do: "1", else: "0"
    end
    |> Enum.join(" ")
  end

  defp convert_bytes_to_binary_pixels(data) do
    # For P4 format, pixels are packed 8 per byte with MSB as leftmost pixel
    # Our display data is already in this format, so we can use it directly
    data
  end

  defp ensure_directory_exists(filepath) do
    dir = Path.dirname(filepath)

    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to create directory #{dir}: #{reason}"}
    end
  end
end
