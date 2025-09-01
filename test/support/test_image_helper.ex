defmodule TestImageHelper do
  @moduledoc """
  Helper functions for creating test images for ImageProcessor tests.
  """

  # Only compile on host target
  if Mix.target() == :host do
    @doc """
    Creates a simple test image file for testing purposes.
    Returns the path to the created test image.
    """
    def create_test_image(filename \\ "test_image.png") do
      test_fixtures_dir = Path.join(["test", "fixtures"])
      File.mkdir_p!(test_fixtures_dir)

      test_image_path = Path.join(test_fixtures_dir, filename)

      # Create a simple 16x16 test image with black and white pattern
      {:ok, image} = Image.new(16, 16, color: [255, 255, 255])

      # Add some black squares to create a pattern
      {:ok, image} = Image.Draw.rect!(image, 0, 0, 8, 8, fill_color: [0, 0, 0])
      {:ok, image} = Image.Draw.rect!(image, 8, 8, 8, 8, fill_color: [0, 0, 0])

      # Save the test image
      case Image.write(image, test_image_path) do
        {:ok, _} -> {:ok, test_image_path}
        {:error, reason} -> {:error, "Failed to create test image: #{inspect(reason)}"}
      end
    end

    @doc """
    Creates a grayscale gradient test image.
    """
    def create_gradient_test_image(filename \\ "gradient_test.png") do
      test_fixtures_dir = Path.join(["test", "fixtures"])
      File.mkdir_p!(test_fixtures_dir)

      test_image_path = Path.join(test_fixtures_dir, filename)

      # Create a gradient image to test binary vs grayscale conversion
      {:ok, image} = Image.new(16, 16, color: [128, 128, 128])

      # Add different gray levels
      # Black
      {:ok, image} = Image.Draw.rect!(image, 0, 0, 4, 16, fill_color: [0, 0, 0])
      # Dark gray  
      {:ok, image} = Image.Draw.rect!(image, 4, 0, 4, 16, fill_color: [64, 64, 64])
      # Light gray
      {:ok, image} = Image.Draw.rect!(image, 8, 0, 4, 16, fill_color: [192, 192, 192])
      # White
      {:ok, image} = Image.Draw.rect!(image, 12, 0, 4, 16, fill_color: [255, 255, 255])

      case Image.write(image, test_image_path) do
        {:ok, _} -> {:ok, test_image_path}
        {:error, reason} -> {:error, "Failed to create gradient test image: #{inspect(reason)}"}
      end
    end

    @doc """
    Cleans up test image files.
    """
    def cleanup_test_images do
      test_fixtures_dir = Path.join(["test", "fixtures"])

      if File.exists?(test_fixtures_dir) do
        File.rm_rf!(test_fixtures_dir)
      end

      :ok
    end
  else
    # Stub functions for embedded targets
    def create_test_image(_filename \\ "test_image.png") do
      {:error, "Test image creation only available on host target"}
    end

    def create_gradient_test_image(_filename \\ "gradient_test.png") do
      {:error, "Test image creation only available on host target"}
    end

    def cleanup_test_images do
      :ok
    end
  end
end
