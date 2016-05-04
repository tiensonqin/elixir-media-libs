defmodule RtmpCommon.Messages.SerializationTest do
  use ExUnit.Case, async: true
  
  test "Can convert abort message to serialized message" do
    message = %RtmpCommon.Messages.Types.Abort{stream_id: 525}
    
    expected = {:ok, %RtmpCommon.Messages.SerializedMessage{
      message_type_id: 2, 
      data: <<525::32>>}
    }
    
    assert expected == RtmpCommon.Messages.Types.Abort.serialize(message)
  end
  
  test "Can convert acknowledgement message to serialized message" do
    message = %RtmpCommon.Messages.Types.Acknowledgement{sequence_number: 9321}
    
    expected = {:ok, %RtmpCommon.Messages.SerializedMessage{
      message_type_id: 3,
      data: <<9321::32>>
    }}
    
    assert expected == RtmpCommon.Messages.Types.Acknowledgement.serialize(message)
  end 
  
  test "Can convert set chunk size message to serialized message" do
    message = %RtmpCommon.Messages.Types.SetChunkSize{size: 4096}
    
    expected = {:ok, %RtmpCommon.Messages.SerializedMessage{
      message_type_id: 1,
      data: <<0::1, 4096::31>>
    }}
    
    assert expected == RtmpCommon.Messages.Types.SetChunkSize.serialize(message)
  end 
  
  test "Can convert set peer bandwidth message to serialized message" do
    message = %RtmpCommon.Messages.Types.SetPeerBandwidth{
      window_size: 4096,
      limit_type: :soft
    }
    
    expected = {:ok, %RtmpCommon.Messages.SerializedMessage{
      message_type_id: 6,
      data: <<4096::32, 1::8>>
    }}
    
    assert expected == RtmpCommon.Messages.Types.SetPeerBandwidth.serialize(message)
  end 
  
  test "Can convert window acknowledgement size message to serialized message" do
    message = %RtmpCommon.Messages.Types.WindowAcknowledgementSize{
      size: 5022
    }
    
    expected = {:ok, %RtmpCommon.Messages.SerializedMessage{
      message_type_id: 5,
      data: <<5022::32>>
    }}
    
    assert expected == RtmpCommon.Messages.Types.WindowAcknowledgementSize.serialize(message)
  end
end