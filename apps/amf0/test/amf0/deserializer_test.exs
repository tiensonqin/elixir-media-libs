defmodule Amf0.DeserializerTest do
  use ExUnit.Case, async: true

  test "Can deserialize number" do
    binary = <<0::8, 532::float-64>>

    assert {:ok, [532.0]} = Amf0.deserialize(binary)
  end

  test "Can deserialize true boolean" do
    binary = <<1::8, 1::8>>

    assert {:ok, [true]} = Amf0.deserialize(binary)
  end

  test "Can deserialize false boolean" do
    binary = <<1::8, 0::8>>

    assert {:ok, [false]} = Amf0.deserialize(binary)
  end

  test "Can deserialize UTF8-1 string" do
    binary = <<2::8, 4::16>> <> "test"

    assert {:ok, ["test"]} = Amf0.deserialize(binary)
  end

  test "Can deserialize null" do
    binary = <<5::8>>

    assert {:ok, [nil]} = Amf0.deserialize(binary)
  end

  test "Can deserialize object" do
    binary = <<3::8, 4::16>> <> "test" <> <<2::8, 5::16>> <> "value" <> <<0, 0, 9>>

    assert {:ok, [%{"test" => "value"}]} = Amf0.deserialize(binary)
  end

  test "Can deserialize consecutive values" do
    binary = <<0::8, 532::float-64, 1::8, 1::8>>

    assert {:ok, [532.0, true]} = Amf0.deserialize(binary)
  end

  test "Can deserialize object with multiple properties (rtmp connect object)" do
    binary =
      <<0x03, 0x00, 0x03, 0x61, 0x70, 0x70, 0x02, 0x00, 0x04, 0x6C, 0x69, 0x76, 0x65, 0x00, 0x04,
        0x74, 0x79, 0x70, 0x65, 0x02, 0x00, 0x0A, 0x6E, 0x6F, 0x6E, 0x70, 0x72, 0x69, 0x76, 0x61,
        0x74, 0x65, 0x00, 0x08, 0x66, 0x6C, 0x61, 0x73, 0x68, 0x56, 0x65, 0x72, 0x02, 0x00, 0x1F,
        0x46, 0x4D, 0x4C, 0x45, 0x2F, 0x33, 0x2E, 0x30, 0x20, 0x28, 0x63, 0x6F, 0x6D, 0x70, 0x61,
        0x74, 0x69, 0x62, 0x6C, 0x65, 0x3B, 0x20, 0x46, 0x4D, 0x53, 0x63, 0x2F, 0x31, 0x2E, 0x30,
        0x29, 0x00, 0x06, 0x73, 0x77, 0x66, 0x55, 0x72, 0x6C, 0x02, 0x00, 0x16, 0x72, 0x74, 0x6D,
        0x70, 0x3A, 0x2F, 0x2F, 0x31, 0x36, 0x39, 0x2E, 0x35, 0x35, 0x2E, 0x38, 0x2E, 0x34, 0x2F,
        0x6C, 0x69, 0x76, 0x65, 0x00, 0x05, 0x74, 0x63, 0x55, 0x72, 0x6C, 0x02, 0x00, 0x16, 0x72,
        0x74, 0x6D, 0x70, 0x3A, 0x2F, 0x2F, 0x31, 0x36, 0x39, 0x2E, 0x35, 0x35, 0x2E, 0x38, 0x2E,
        0x34, 0x2F, 0x6C, 0x69, 0x76, 0x65, 0x00, 0x00, 0x09>>

    assert {:ok,
            [
              %{
                "app" => "live",
                "type" => "nonprivate",
                "flashVer" => "FMLE/3.0 (compatible; FMSc/1.0)",
                "swfUrl" => "rtmp://169.55.8.4/live",
                "tcUrl" => "rtmp://169.55.8.4/live"
              }
            ]} = Amf0.deserialize(binary)
  end

  test "Can deserialize EMCA array" do
    binary =
      <<0x08, 0x00, 0x00, 0x00, 0x0E, 0x00, 0x08, 0x64, 0x75, 0x72, 0x61, 0x74, 0x69, 0x6F, 0x6E,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x66, 0x69, 0x6C, 0x65,
        0x53, 0x69, 0x7A, 0x65, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05,
        0x77, 0x69, 0x64, 0x74, 0x68, 0x00, 0x40, 0x94, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x06, 0x68, 0x65, 0x69, 0x67, 0x68, 0x74, 0x00, 0x40, 0x86, 0x80, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x0C, 0x76, 0x69, 0x64, 0x65, 0x6F, 0x63, 0x6F, 0x64, 0x65, 0x63, 0x69, 0x64,
        0x02, 0x00, 0x04, 0x61, 0x76, 0x63, 0x31, 0x00, 0x0D, 0x76, 0x69, 0x64, 0x65, 0x6F, 0x64,
        0x61, 0x74, 0x61, 0x72, 0x61, 0x74, 0x65, 0x00, 0x40, 0x8C, 0x20, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x09, 0x66, 0x72, 0x61, 0x6D, 0x65, 0x72, 0x61, 0x74, 0x65, 0x00, 0x40, 0x3E,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0C, 0x61, 0x75, 0x64, 0x69, 0x6F, 0x63, 0x6F,
        0x64, 0x65, 0x63, 0x69, 0x64, 0x02, 0x00, 0x04, 0x6D, 0x70, 0x34, 0x61, 0x00, 0x0D, 0x61,
        0x75, 0x64, 0x69, 0x6F, 0x64, 0x61, 0x74, 0x61, 0x72, 0x61, 0x74, 0x65, 0x00, 0x40, 0x64,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0F, 0x61, 0x75, 0x64, 0x69, 0x6F, 0x73, 0x61,
        0x6D, 0x70, 0x6C, 0x65, 0x72, 0x61, 0x74, 0x65, 0x00, 0x40, 0xE5, 0x88, 0x80, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x0F, 0x61, 0x75, 0x64, 0x69, 0x6F, 0x73, 0x61, 0x6D, 0x70, 0x6C, 0x65,
        0x73, 0x69, 0x7A, 0x65, 0x00, 0x40, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0D,
        0x61, 0x75, 0x64, 0x69, 0x6F, 0x63, 0x68, 0x61, 0x6E, 0x6E, 0x65, 0x6C, 0x73, 0x00, 0x40,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x73, 0x74, 0x65, 0x72, 0x65, 0x6F,
        0x01, 0x01, 0x00, 0x07, 0x65, 0x6E, 0x63, 0x6F, 0x64, 0x65, 0x72, 0x02, 0x00, 0x29, 0x6F,
        0x62, 0x73, 0x2D, 0x6F, 0x75, 0x74, 0x70, 0x75, 0x74, 0x20, 0x6D, 0x6F, 0x64, 0x75, 0x6C,
        0x65, 0x20, 0x28, 0x6C, 0x69, 0x62, 0x6F, 0x62, 0x73, 0x20, 0x76, 0x65, 0x72, 0x73, 0x69,
        0x6F, 0x6E, 0x20, 0x30, 0x2E, 0x31, 0x34, 0x2E, 0x32, 0x29, 0x00, 0x00, 0x09>>

    assert {:ok,
            [
              %{
                "duration" => 0,
                "fileSize" => 0,
                "width" => 1280,
                "height" => 720,
                "videocodecid" => "avc1",
                "videodatarate" => 900,
                "framerate" => 30,
                "audiocodecid" => "mp4a",
                "audiodatarate" => 160,
                "audiosamplerate" => 44100,
                "audiosamplesize" => 16,
                "audiochannels" => 2,
                "stereo" => true,
                "encoder" => "obs-output module (libobs version 0.14.2)"
              }
            ]} == Amf0.deserialize(binary)
  end
end
