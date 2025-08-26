defmodule MoodBot.Images.Bitmap do
  @moduledoc """
  Image processing and bitmap conversion utilities for the Waveshare 2.9" e-ink display.

  Supports loading various image formats, converting to monochrome, resizing to display
  dimensions (128×296), and saving for visual inspection or display output.
  """

  import Bitwise

  # Waveshare 2.9" e-ink display dimensions and format constants
  @width 128
  @height 296
  @max_size_bytes div(@width * @height, 8)

  @doc """
  Convert raw e-ink display data to PBM (Portable Bitmap) format.

  Formats: `:p1` (ASCII) or `:p4` (binary). Data must be #{@max_size_bytes} bytes.
  """
  @spec to_pbm(binary(), :p1 | :p4) :: {:ok, binary()} | {:error, binary()}
  def to_pbm(data, format \\ :p1) when is_binary(data) and format in [:p1, :p4] do
    case validate_data_size(data) do
      :ok -> convert_to_pbm(data, format)
      error -> error
    end
  end

  @doc "Save raw e-ink display data as a PBM file."
  @spec save_pbm(binary(), binary(), :p1 | :p4) :: :ok | {:error, binary()}
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
  Generate timestamped filename for bitmap data.

  Creates filename: "session_{session_id}_frame_{counter}_timestamp.pbm"
  Session ID is a unique identifier for grouping related frames.
  """
  @spec generate_filename(binary(), non_neg_integer(), binary()) :: binary()
  def generate_filename(session_id, frame_counter, base_dir \\ "priv/bitmaps") do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

    filename =
      "session_#{session_id}_frame_#{String.pad_leading(to_string(frame_counter), 3, "0")}_#{timestamp}.pbm"

    Path.join(base_dir, filename)
  end

  @doc """
  Load PBM file and convert to display format.

  Supports P1 (ASCII) and P4 (binary) PBM formats. Returns #{@max_size_bytes} bytes ready for display.

  ## Examples

      iex> MoodBot.Images.Bitmap.load_pbm("priv/bitmaps/image.pbm")
      {:ok, <<255, 0, 255, ...>>}
  """
  @spec load_pbm(binary()) :: {:ok, binary()} | {:error, binary()}
  def load_pbm(filepath) when is_binary(filepath) do
    with {:ok, content} <- File.read(filepath),
         {:ok, parsed} <- parse_pbm_content(content),
         {:ok, binary} <- convert_pbm_to_display_format(parsed) do
      {:ok, binary}
    else
      {:error, :enoent} -> {:error, "File not found: #{filepath}"}
      {:error, reason} when is_binary(reason) -> {:error, reason}
      {:error, reason} -> {:error, "Failed to load PBM: #{inspect(reason)}"}
    end
  end

  # Note: Image processing functions moved to MoodBot.Images.ImageProcessor (host-only)
  # This module now focuses on PBM format handling and binary manipulation

  # Private functions

  defp validate_data_size(data) do
    actual_size = byte_size(data)

    if actual_size <= @max_size_bytes do
      :ok
    else
      {:error, "Invalid data size: expected #{@max_size_bytes} bytes, got #{actual_size} bytes"}
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

  # PBM parsing functions (made public for ImageProcessor)

  @doc false
  def parse_pbm_content(content) when is_binary(content) do
    case String.split(content, "\n", parts: 4) do
      [magic | rest] when magic in ["P1", "P4"] ->
        parse_pbm_header(magic, rest)

      _ ->
        {:error, "Invalid PBM format: missing or invalid magic number"}
    end
  end

  defp parse_pbm_header(magic, [comment_or_dims | rest]) do
    # Skip comments (lines starting with #)
    {dims_line, remaining} =
      if String.starts_with?(comment_or_dims, "#") do
        case rest do
          [dims | data_rest] -> {dims, data_rest}
          _ -> {:error, "Invalid PBM format: missing dimensions"}
        end
      else
        {comment_or_dims, rest}
      end

    case dims_line do
      {:error, reason} -> {:error, reason}
      _ -> parse_pbm_dimensions(magic, dims_line, remaining)
    end
  end

  defp parse_pbm_dimensions(magic, dims_line, remaining) do
    case String.split(String.trim(dims_line)) do
      [width_str, height_str] ->
        with {_width, ""} <- Integer.parse(width_str),
             {_height, ""} <- Integer.parse(height_str) do
          parse_pbm_data(magic, remaining)
        else
          _ -> {:error, "Invalid dimensions format"}
        end

      _ ->
        {:error, "Invalid dimensions line"}
    end
  end

  defp parse_pbm_data("P1", [data_line]) do
    # P1 format: ASCII pixels (0 and 1)
    pixels =
      data_line
      |> String.split()
      |> Enum.map(fn
        "0" -> 0
        "1" -> 1
        other -> {:error, "Invalid pixel value: #{other}"}
      end)

    case Enum.find(pixels, &match?({:error, _}, &1)) do
      nil ->
        # if length(pixels) == @width * @height do
        {:ok, %{format: :p1, pixels: pixels}}

      # else
      #   {:error, "Invalid pixel count: expected #{@width * @height}, got #{length(pixels)}"}
      # end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_pbm_data("P4", [binary_data]) do
    # P4 format: binary data
    _expected_bytes = div(@width * @height, 8)

    # if byte_size(binary_data) == expected_bytes do
    {:ok, %{format: :p4, data: binary_data}}
    # else
    #   {:error,
    #    "Invalid binary data size: expected #{expected_bytes}, got #{byte_size(binary_data)}"}
    # end
  end

  defp parse_pbm_data(_, _) do
    {:error, "Invalid PBM data format"}
  end

  @doc false
  def convert_pbm_to_display_format(%{format: :p1, pixels: pixels}) do
    # Convert P1 ASCII pixels to packed binary format
    pixels
    |> Enum.chunk_every(8)
    |> Enum.map(&pixels_to_byte/1)
    |> :binary.list_to_bin()
    |> then(&{:ok, &1})
  rescue
    error -> {:error, "P1 conversion failed: #{inspect(error)}"}
  end

  def convert_pbm_to_display_format(%{format: :p4, data: binary_data}) do
    # P4 format is already in the right binary format
    {:ok, binary_data}
  end

  defp pixels_to_byte(pixel_list) when length(pixel_list) <= 8 do
    # Pad with zeros if less than 8 pixels
    padded = pixel_list ++ List.duplicate(0, 8 - length(pixel_list))

    padded
    |> Enum.with_index()
    |> Enum.reduce(0, fn {pixel, index}, acc ->
      # MSB first
      bit_position = 7 - index
      acc ||| pixel <<< bit_position
    end)
  end
end
