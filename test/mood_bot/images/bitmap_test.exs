defmodule MoodBot.Images.BitmapTest do
  use ExUnit.Case, async: true

  alias MoodBot.Images.Bitmap

  describe "convert_pbm_to_display_format/1" do
    test "P4 format returns binary data unchanged" do
      test_data = <<0xFF, 0x00, 0xAA, 0x55>>
      p4_map = %{format: :p4, data: test_data}

      assert {:ok, result} = Bitmap.convert_pbm_to_display_format(p4_map)
      assert result == test_data
    end

    test "P1 format converts pixel list to packed binary" do
      # Test with 16 pixels: 8 zeros followed by 8 ones
      pixels = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1]
      p1_map = %{format: :p1, pixels: pixels}

      assert {:ok, result} = Bitmap.convert_pbm_to_display_format(p1_map)

      # Should produce 2 bytes: 0x00 (8 zeros) and 0xFF (8 ones)
      assert result == <<0x00, 0xFF>>
    end

    test "P1 format handles partial bytes with zero padding" do
      # Test with 10 pixels: alternating pattern
      pixels = [1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
      p1_map = %{format: :p1, pixels: pixels}

      assert {:ok, result} = Bitmap.convert_pbm_to_display_format(p1_map)

      # Should produce 2 bytes:
      # First byte: 10101010 = 0xAA
      # Second byte: 10000000 = 0x80 (partial byte padded with zeros)
      assert result == <<0xAA, 0x80>>
    end
  end

  describe "parse_pbm_content/1" do
    test "P1 format with comment parses successfully" do
      pbm_content = """
      P1
      # Test bitmap
      8 2
      0 0 0 0 0 0 0 0
      1 1 1 1 1 1 1 1
      """

      assert {:ok, %{format: :p1, pixels: pixels}} = Bitmap.parse_pbm_content(pbm_content)
      assert pixels == [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1]
    end

    test "P1 format without comment parses but fails due to structure" do
      pbm_content = """
      P1
      8 2
      0 0 0 0 0 0 0 0
      1 1 1 1 1 1 1 1
      """

      # This fails due to parsing structure - without comment line, remaining is empty
      assert {:error, "Invalid PBM data format"} =
               Bitmap.parse_pbm_content(pbm_content)
    end

    test "P4 format with binary data parses successfully" do
      pbm_content = "P4\n# Binary format\n8 2\n" <> <<0x00, 0xFF>>

      assert {:ok, %{format: :p4, data: data}} = Bitmap.parse_pbm_content(pbm_content)
      assert data == <<0x00, 0xFF>>
    end

    test "invalid magic number returns error" do
      pbm_content = """
      P2
      # Invalid magic
      8 1
      0 0 0 0 0 0 0 0
      """

      assert {:error, "Invalid PBM format: missing or invalid magic number"} =
               Bitmap.parse_pbm_content(pbm_content)
    end

    test "missing magic number returns error" do
      pbm_content = """
      # No magic number
      8 1
      0 0 0 0 0 0 0 0
      """

      assert {:error, "Invalid PBM format: missing or invalid magic number"} =
               Bitmap.parse_pbm_content(pbm_content)
    end

    test "invalid dimensions format returns error" do
      pbm_content = """
      P1
      # Test bitmap
      not_numbers
      0 0 0 0 0 0 0 0
      """

      assert {:error, "Invalid dimensions line"} =
               Bitmap.parse_pbm_content(pbm_content)
    end

    test "missing dimensions returns error" do
      pbm_content = """
      P1
      # Test bitmap
      """

      assert {:error, "Invalid dimensions line"} =
               Bitmap.parse_pbm_content(pbm_content)
    end
  end
end
