defmodule Rtmp.Protocol.ChunkIoTest do
  use ExUnit.Case, async: true
  alias Rtmp.Protocol.RawMessage, as: RawMessage
  alias Rtmp.Protocol.ChunkIo, as: ChunkIo

  @previous_chunk_0_binary <<0::2, 50::6, 100::size(3)-unit(8), 100::size(3)-unit(8), 3::8,
                             55::size(4)-unit(8)-little, 152::size(100)-unit(8)>>
  @previous_chunk_1_binary <<1::2, 50::6, 72::size(3)-unit(8), 100::size(3)-unit(8), 3::8,
                             152::size(100)-unit(8)>>

  describe "Deserialization" do
    test "Can read full type 0 chunk with small chunk stream id" do
      binary =
        <<0::2, 50::6, 72::size(3)-unit(8), 100::size(3)-unit(8), 3::8,
          55::size(4)-unit(8)-little, 152::size(100)-unit(8)>>

      result = ChunkIo.new() |> ChunkIo.deserialize(binary)

      assert {_,
              %RawMessage{
                timestamp: 72,
                message_type_id: 3,
                stream_id: 55,
                payload: <<152::100*8>>
              }} = result
    end

    test "Can read full type 0 chunk with medium chunk stream id" do
      binary =
        <<0::2, 0::6, 200::8, 72::size(3)-unit(8), 100::size(3)-unit(8), 3::8,
          55::size(4)-unit(8)-little, 152::size(100)-unit(8)>>

      result = ChunkIo.new() |> ChunkIo.deserialize(binary)

      assert {_,
              %RawMessage{
                timestamp: 72,
                message_type_id: 3,
                stream_id: 55,
                payload: <<152::100*8>>
              }} = result
    end

    test "Can read full type 0 chunk with large chunk stream id" do
      binary =
        <<0::2, 1::6, 60001::16, 72::size(3)-unit(8), 100::size(3)-unit(8), 3::8,
          55::size(4)-unit(8)-little, 152::size(100)-unit(8)>>

      result = ChunkIo.new() |> ChunkIo.deserialize(binary)

      assert {_,
              %RawMessage{
                timestamp: 72,
                message_type_id: 3,
                stream_id: 55,
                payload: <<152::100*8>>
              }} = result
    end

    test "Can read full type 1 chunk" do
      binary =
        <<1::2, 50::6, 72::size(3)-unit(8), 100::size(3)-unit(8), 3::8, 152::size(100)-unit(8)>>

      assert {io, %RawMessage{}} = ChunkIo.new() |> ChunkIo.deserialize(@previous_chunk_0_binary)

      assert {_,
              %RawMessage{
                timestamp: 172,
                message_type_id: 3,
                stream_id: 55,
                payload: <<152::100*8>>
              }} = ChunkIo.deserialize(io, binary)
    end

    test "Can read full type 2 chunk" do
      binary = <<2::2, 50::6, 72::size(3)-unit(8), 152::size(100)-unit(8)>>

      assert {io, %RawMessage{}} = ChunkIo.new() |> ChunkIo.deserialize(@previous_chunk_0_binary)

      assert {_,
              %RawMessage{
                timestamp: 172,
                message_type_id: 3,
                stream_id: 55,
                payload: <<152::100*8>>
              }} = ChunkIo.deserialize(io, binary)
    end

    test "Can read full type 3 chunk" do
      binary = <<3::2, 50::6, 152::size(100)-unit(8)>>

      assert {io, %RawMessage{}} = ChunkIo.new() |> ChunkIo.deserialize(@previous_chunk_0_binary)
      assert {io, %RawMessage{}} = ChunkIo.deserialize(io, @previous_chunk_1_binary)

      assert {_,
              %RawMessage{
                timestamp: 244,
                message_type_id: 3,
                stream_id: 55,
                payload: <<152::100*8>>
              }} = ChunkIo.deserialize(io, binary)
    end

    test "Can read full type 0 chunk with extended timestamp" do
      binary =
        <<0::2, 50::6, 16_777_215::size(3)-unit(8), 100::size(3)-unit(8), 3::8,
          55::size(4)-unit(8)-little, 16_777_216::size(4)-unit(8), 152::size(100)-unit(8)>>

      result = ChunkIo.new() |> ChunkIo.deserialize(binary)

      assert {_,
              %RawMessage{
                timestamp: 16_777_216,
                message_type_id: 3,
                stream_id: 55,
                payload: <<152::100*8>>
              }} = result
    end

    test "Can read full type 1 chunk with extended timestamp" do
      binary =
        <<1::2, 50::6, 16_777_215::size(3)-unit(8), 100::size(3)-unit(8), 3::8,
          16_777_216::size(4)-unit(8), 152::size(100)-unit(8)>>

      assert {io, %RawMessage{}} = ChunkIo.new() |> ChunkIo.deserialize(@previous_chunk_0_binary)

      assert {_,
              %RawMessage{
                timestamp: 16_777_316,
                message_type_id: 3,
                stream_id: 55,
                payload: <<152::100*8>>
              }} = ChunkIo.deserialize(io, binary)
    end

    test "Can read full type 2 chunk with extended timestamp" do
      binary =
        <<2::2, 50::6, 16_777_215::size(3)-unit(8), 16_777_216::size(4)-unit(8),
          152::size(100)-unit(8)>>

      assert {io, %RawMessage{}} = ChunkIo.new() |> ChunkIo.deserialize(@previous_chunk_0_binary)

      assert {_,
              %RawMessage{
                timestamp: 16_777_316,
                message_type_id: 3,
                stream_id: 55,
                payload: <<152::100*8>>
              }} = ChunkIo.deserialize(io, binary)
    end

    test "Incomplete chunk returns incomplete notification" do
      binary = <<0::2, 50::6, 100::size(3)-unit(8), 100::size(3)-unit(8)>>

      assert {_, :incomplete} = ChunkIo.new() |> ChunkIo.deserialize(binary)
    end

    test "Can read message spread across multiple deserialization calls" do
      binary1 = <<0::2, 50::6, 72::size(3)-unit(8), 100::size(3)-unit(8), 3::8>>
      binary2 = <<55::size(4)-unit(8)-little, 0::size(90)-unit(8)>>
      binary3 = <<152::size(10)-unit(8)>>

      io = ChunkIo.new()
      assert {io, :incomplete} = ChunkIo.deserialize(io, binary1)
      assert {io, :incomplete} = ChunkIo.deserialize(io, binary2)

      assert {_,
              %RawMessage{
                timestamp: 72,
                message_type_id: 3,
                stream_id: 55,
                payload: <<152::100*8>>
              }} = ChunkIo.deserialize(io, binary3)
    end

    test "Can read message exceeding maximum chunk size" do
      binary1 =
        <<0::2, 50::6, 72::size(3)-unit(8), 138::size(3)-unit(8), 3::8,
          55::size(4)-unit(8)-little, 0::size(128)-unit(8)>>

      binary2 = <<3::2, 50::6, 152::10*8>>
      assert {io, :split_message} = ChunkIo.new() |> ChunkIo.deserialize(binary1)

      assert {_,
              %RawMessage{
                timestamp: 72,
                message_type_id: 3,
                stream_id: 55,
                payload: <<152::138*8>>
              }} = ChunkIo.deserialize(io, binary2)
    end

    test "Can change receiving maximum chunk size" do
      binary =
        <<0::2, 50::6, 72::size(3)-unit(8), 200::size(3)-unit(8), 3::8,
          55::size(4)-unit(8)-little, 152::size(200)-unit(8)>>

      result =
        ChunkIo.new()
        |> ChunkIo.set_receiving_max_chunk_size(201)
        |> ChunkIo.deserialize(binary)

      assert {_,
              %RawMessage{
                timestamp: 72,
                message_type_id: 3,
                stream_id: 55,
                payload: <<152::200*8>>
              }} = result
    end
  end

  describe "Serialization" do
    test "Serialize: Initial chunk for csid" do
      message = %RawMessage{
        timestamp: 72,
        message_type_id: 3,
        stream_id: 55,
        payload: <<152::size(100)-unit(8)>>
      }

      {_, binary} = ChunkIo.new() |> ChunkIo.serialize(message, 50)

      expected_binary =
        <<0::2, 50::6, 72::size(3)-unit(8), 100::size(3)-unit(8), 3::8,
          55::size(4)-unit(8)-little, 152::size(100)-unit(8)>>

      assert expected_binary == binary
    end

    test "Serialize: 2nd chunk, same sid, different message length" do
      message1 = %RawMessage{
        timestamp: 72,
        message_type_id: 3,
        stream_id: 55,
        payload: <<152::size(100)-unit(8)>>
      }

      message2 = %RawMessage{
        timestamp: 82,
        message_type_id: 3,
        stream_id: 55,
        payload: <<152::size(101)-unit(8)>>
      }

      {serializer, _} = ChunkIo.new() |> ChunkIo.serialize(message1, 50)
      {_, binary} = ChunkIo.serialize(serializer, message2, 50)

      expected_binary =
        <<1::2, 50::6, 10::size(3)-unit(8), 101::size(3)-unit(8), 3::8, 152::size(101)-unit(8)>>

      assert expected_binary == binary
    end

    test "Serialize: 2nd chunk, same sid, message length, and type id" do
      message1 = %RawMessage{
        timestamp: 72,
        message_type_id: 3,
        stream_id: 55,
        payload: <<152::size(100)-unit(8)>>
      }

      message2 = %RawMessage{
        timestamp: 82,
        message_type_id: 3,
        stream_id: 55,
        payload: <<152::size(100)-unit(8)>>
      }

      {serializer, _} = ChunkIo.new() |> ChunkIo.serialize(message1, 50)
      {_, binary} = ChunkIo.serialize(serializer, message2, 50)

      expected_binary = <<2::2, 50::6, 10::size(3)-unit(8), 152::size(100)-unit(8)>>

      assert expected_binary == binary
    end

    test "Serialize: 3rd chunk, same sid, length, typeid, and timestamp delta" do
      message1 = %RawMessage{
        timestamp: 72,
        message_type_id: 3,
        stream_id: 55,
        payload: <<152::size(100)-unit(8)>>
      }

      message2 = %RawMessage{
        timestamp: 82,
        message_type_id: 3,
        stream_id: 55,
        payload: <<152::size(100)-unit(8)>>
      }

      message3 = %RawMessage{
        timestamp: 92,
        message_type_id: 3,
        stream_id: 55,
        payload: <<152::size(100)-unit(8)>>
      }

      {serializer, _} = ChunkIo.new() |> ChunkIo.serialize(message1, 50)
      {serializer, _} = ChunkIo.serialize(serializer, message2, 50)
      {_, binary} = ChunkIo.serialize(serializer, message3, 50)

      expected_binary = <<3::2, 50::6, 152::size(100)-unit(8)>>
      assert expected_binary == binary
    end

    test "Serialize: Messages larger than max chunk size are split" do
      message = %RawMessage{
        timestamp: 72,
        message_type_id: 3,
        stream_id: 55,
        payload: <<152::size(101)-unit(8)>>
      }

      {_, binary} =
        ChunkIo.new()
        |> ChunkIo.set_sending_max_chunk_size(100)
        |> ChunkIo.serialize(message, 50)

      expected_binary =
        <<0::2, 50::6, 72::size(3)-unit(8), 101::size(3)-unit(8), 3::8,
          55::size(4)-unit(8)-little, 0::size(100)-unit(8), 3::2, 50::6, 152::size(1)-unit(8)>>

      assert expected_binary == binary
    end

    test "Serialize: Can force no compression for messages marked as such" do
      message1 = %RawMessage{
        timestamp: 72,
        message_type_id: 3,
        stream_id: 55,
        payload: <<152::size(100)-unit(8)>>
      }

      message2 = %RawMessage{
        timestamp: 82,
        message_type_id: 3,
        stream_id: 55,
        force_uncompressed: true,
        payload: <<152::size(100)-unit(8)>>
      }

      {serializer, _} = ChunkIo.new() |> ChunkIo.serialize(message1, 50)
      {_, binary} = ChunkIo.serialize(serializer, message2, 50)

      expected_binary =
        <<0::2, 50::6, 82::size(3)-unit(8), 100::size(3)-unit(8), 3::8,
          55::size(4)-unit(8)-little, 152::size(100)-unit(8)>>

      assert expected_binary == binary
    end

    test "Serialize: 2nd chunk with negative time serialized as type 0 chunk" do
      message1 = %RawMessage{
        timestamp: 72,
        message_type_id: 3,
        stream_id: 55,
        payload: <<152::size(100)-unit(8)>>
      }

      message2 = %RawMessage{
        timestamp: 62,
        message_type_id: 3,
        stream_id: 55,
        payload: <<152::size(100)-unit(8)>>
      }

      {serializer, _} = ChunkIo.new() |> ChunkIo.serialize(message1, 50)
      {_, binary} = ChunkIo.serialize(serializer, message2, 50)

      expected_binary =
        <<0::2, 50::6, 62::size(3)-unit(8), 100::size(3)-unit(8), 3::8,
          55::size(4)-unit(8)-little, 152::size(100)-unit(8)>>

      assert expected_binary == binary
    end
  end
end
