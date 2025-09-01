defmodule Mix.Tasks.ProcessImage do
  @moduledoc """
  Mix task to process images for the e-ink display.

  Processes images through the complete e-ink display pipeline:
  load → monochrome → resize (128×296) → save as viewable format

  ## Usage

      mix process_image input.png output.png [--mode <mode>]
      mix process_image photo.jpg preview.tiff --mode bw

  ## Modes

  - **bw** (default): True black/white conversion optimized for e-ink display
  - **grayscale**: Grayscale conversion useful for preview/inspection

  ## Supported Formats

  **Input:** PNG, BMP, TIFF, WebP, PBM
  **Output:** PNG, TIFF, JPG, WebP

  The output file will show exactly how the image will appear on the 128×296 e-ink display.
  """

  use Mix.Task

  @shortdoc "Process images for e-ink display (128x296) with mode options"

  def run(args) do
    case parse_args(args) do
      {:ok, input_path, output_path, mode} ->
        Mix.Task.run("app.start")
        process_image(input_path, output_path, mode)

      :help ->
        show_usage()

      :error ->
        IO.puts("❌ Error: Invalid arguments")
        show_usage()
        System.halt(1)
    end
  end

  defp process_image(input_path, output_path, mode) do
    mode_description =
      case mode do
        :bw -> "true black/white (e-ink optimized)"
        :grayscale -> "grayscale (preview mode)"
      end

    IO.puts("🔄 Processing: #{input_path} → #{output_path}")
    IO.puts("📐 Target dimensions: 128×296 (e-ink display)")
    IO.puts("🎨 Converting to #{mode_description}...")

    # Determine output format based on file extension
    output_format =
      case Path.extname(output_path) |> String.downcase() do
        ".pbm" -> :pbm
        _other -> :preview
      end

    result =
      case output_format do
        :pbm ->
          IO.puts("💾 Saving as P1 ASCII PBM format for inspection...")
          # Bypass the broken pack_for_display path and use direct image processing
          case MoodBot.Images.ImageProcessor.process_and_save_for_inspection(input_path, output_path <> ".temp.png", mode) do
            :ok ->
              # Convert the processed PNG to PBM using Image library
              case convert_png_to_pbm(output_path <> ".temp.png", output_path) do
                :ok ->
                  # File.rm(output_path <> ".temp.png")
                  :ok
                error ->
                  File.rm(output_path <> ".temp.png")
                  error
              end
            error -> error
          end

        :preview ->
          IO.puts("🖼️ Saving as preview image...")

          MoodBot.Images.ImageProcessor.process_and_save_for_inspection(
            input_path,
            output_path,
            mode
          )
      end

    case result do
      :ok ->
        case output_format do
          :pbm ->
            IO.puts("✅ Success! P1 ASCII PBM file saved to: #{output_path}")
            IO.puts("📝 Open #{output_path} in a text editor to see the 0s and 1s!")
            IO.puts("🔍 You can also view #{output_path} in any image viewer")

          :preview ->
            IO.puts("✅ Success! Preview image saved to: #{output_path}")

            IO.puts(
              "🖼️ You can now view #{output_path} to see how it will look on the e-ink display"
            )

            IO.puts("⚙️ Mode: #{mode_description}")
        end

      {:error, reason} ->
        IO.puts("❌ Error: #{reason}")
        System.halt(1)
    end
  end

  defp parse_args(args) do
    case args do
      [] ->
        :help

      ["-h"] ->
        :help

      ["--help"] ->
        :help

      [input_path, output_path] ->
        {:ok, input_path, output_path, :bw}

      [input_path, output_path, "--mode", mode_str] ->
        case parse_mode(mode_str) do
          {:ok, mode} -> {:ok, input_path, output_path, mode}
          :error -> :error
        end

      _ ->
        :error
    end
  end

  defp parse_mode(mode_str) do
    case String.downcase(mode_str) do
      "bw" -> {:ok, :bw}
      "grayscale" -> {:ok, :grayscale}
      "gray" -> {:ok, :grayscale}
      _ -> :error
    end
  end

  defp convert_png_to_pbm(png_path, pbm_path) do
    convert_png_to_pbm_direct(png_path, pbm_path)
  end

  # Loads PNG, centers it on 128x296 canvas, extracts pixel data, converts to ASCII 0s and 1s, saves as P1 PBM.
  # Simple threshold: pixel < 128 = '0' (black), pixel >= 128 = '1' (white).
  defp convert_png_to_pbm_direct(png_path, pbm_path) do
    with {:ok, image} <- Image.open(png_path),
         {:ok, centered_image} <- center_image_on_canvas(image),
         {width, height, _bands} <- Image.shape(centered_image),
         {:ok, pixel_data} <- extract_pixel_data(centered_image, width, height),
         pbm_content <- format_as_p1_pbm(pixel_data, width, height, png_path),
         :ok <- File.write(pbm_path, pbm_content) do
      :ok
    else
      {:error, reason} -> {:error, "Direct PNG to PBM conversion failed: #{reason}"}
      error -> {:error, "Direct PNG to PBM conversion failed: #{inspect(error)}"}
    end
  end

  defp center_image_on_canvas(image, canvas_width \\ 128, canvas_height \\ 296) do
    {img_width, img_height, _bands} = Image.shape(image)

    # Calculate centering offsets
    x_offset = div(canvas_width - img_width, 2)
    y_offset = div(canvas_height - img_height, 2)

    with {:ok, centered_image} <- Image.embed(image, 128, 296, background_color: :white, x: x_offset, y: y_offset) do
        Image.write(centered_image, "debug.png")
      {:ok, centered_image}
    else
      error -> {:error, "Failed to center image: #{inspect(error)}"}
    end
    # with {:ok, white_canvas} <- Image.new(canvas_width, canvas_height, color: [255, 255, 255]),
    #      {:ok, centered_image} <- Image.compose(white_canvas, image, blend_mode: :over, x: x_offset, y: y_offset) do
    #     Image.write(centered_image, "debug.png")
    #   {:ok, centered_image}
    # else
    #   error -> {:error, "Failed to center image: #{inspect(error)}"}
    # end
  end

  defp extract_pixel_data(image, width, height) do
    # Convert to grayscale first to get single channel
    with {:ok, gray_image} <- Image.to_colorspace(image, :bw),
         {:ok, pixel_matrix} <- Image.to_list(gray_image) do
      # Extract actual pixel values and apply threshold
      # pixel < 128 = "0" (black), pixel >= 128 = "1" (white)
      pixels =
        pixel_matrix
        |> List.flatten()
        |> Enum.map(fn pixel_value ->
          if pixel_value < 128, do: "0", else: "1"
        end)

      {:ok, pixels}
    else
      error -> {:error, "Failed to extract pixel data: #{inspect(error)}"}
    end
  end

  defp format_as_p1_pbm(pixel_data, width, height, source_path) do
    header = "P1\n# Conversion of #{Path.basename(source_path)} to PBM format\n#{width} #{height}\n"

    # Convert pixel data to rows of space-separated 0s and 1s
    rows =
      pixel_data
      |> Enum.chunk_every(width)
      |> Enum.map(&Enum.join(&1, " "))
      |> Enum.join("\n")

    header <> rows <> "\n"
  end

  defp show_usage do
    IO.puts("""
    📱 MoodBot E-ink Display Image Processor

    Usage:
      mix process_image <input> <output> [--mode <mode>]
      mix process_image -h | --help

    Modes:
      bw        True black/white conversion (default) - optimized for e-ink display
      grayscale Grayscale conversion - useful for preview/inspection

    Examples:
      # Create P1 ASCII PBM file for pixel inspection (default bw mode)
      mix process_image photo.png mood.pbm

      # Create preview image with explicit mode
      mix process_image photo.png preview.png --mode bw
      mix process_image photo.png preview.png --mode grayscale

    Supported input formats:  PNG, BMP, TIFF, WebP, JPG, JPEG, PBM

    Output formats:
      - .pbm  → P1 ASCII PBM format for pixel inspection (view as text or image)
      - .png, .tiff, .jpg, .webp → Preview images for inspection

    The processed images are optimized for the 128×296 e-ink display.
    Use --mode bw (default) for e-ink deployment, --mode grayscale for previewing.
    """)
  end
end
