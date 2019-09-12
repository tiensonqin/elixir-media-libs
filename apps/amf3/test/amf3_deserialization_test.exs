defmodule Amf3DeserializationTest do
  use ExUnit.Case, async: true

  test "Undefined marker deserializes to nil" do
    assert [nil] == Amf3.deserialize(<<0x00>>)
  end

  test "Null marker deserializes to nil" do
    assert [nil] == Amf3.deserialize(<<0x01>>)
  end

  test "False marker deserializes to false" do
    assert [false] == Amf3.deserialize(<<0x02>>)
  end

  test "True marker deserializes to true" do
    assert [true] == Amf3.deserialize(<<0x03>>)
  end

  test "Integer marker with value deserializes to number" do
    assert [127] == Amf3.deserialize(<<0x04, 0x7F>>)
    assert [127] == Amf3.deserialize(<<0x04, 0x80, 0x7F>>)
    assert [16383] == Amf3.deserialize(<<0x04, 0x80, 0xFF, 0x7F>>)
    assert [4_194_303] == Amf3.deserialize(<<0x04, 0x80, 0xFF, 0xFF, 0xFF>>)
    assert [-26] == Amf3.deserialize(<<0x04, 0xFF, 0xFF, 0xFF, 0xE6>>)
  end

  test "Double marker with value deserializes to number" do
    assert [532.5] == Amf3.deserialize(<<0x05, 532.5::float-64>>)
  end
end
