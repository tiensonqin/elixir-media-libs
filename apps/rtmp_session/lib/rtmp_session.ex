defmodule RtmpSession do
  @moduledoc """
  Tracks a singe RTMP session, representing a single peer (server or client) at 
  one end of an RTMP conversation.

  The API allows passing in raw RTMP data packets for processing which
  can generate events the caller can choose to handle.

  It is assumed that the RTMP handshake client has already been processed, that 
  the created `RtmpSession` will be processing every RTMP packet sent by its
  peer, and that the first bytes sent to the `RtmpSession` instance is the 
  first post-handshake bytes sent by the peer (so important data like the peer'send
  maximum chunk size are not missed). 
  """

  alias RtmpSession.ChunkIo, as: ChunkIo
  alias RtmpSession.SessionResults, as: SessionResults
  alias RtmpSession.RawMessage, as: RawMessage
  alias RtmpSession.DetailedMessage, as: DetailedMessage
  alias RtmpSession.Processor, as: Processor
  alias RtmpSession.Events, as: RtmpEvents

  require Logger

  @type deserialized_message :: RtmpSession.Messages.SetChunkSize.t |
    RtmpSession.Messages.Abort.t |
    RtmpSession.Messages.Acknowledgement.t |
    RtmpSession.Messages.UserControl.t |
    RtmpSession.Messages.WindowAcknowledgementSize.t |
    RtmpSession.Messages.SetPeerBandwidth.t |
    RtmpSession.Messages.AudioData.t |
    RtmpSession.Messages.VideoData.t |
    RtmpSession.Messages.Amf0Command.t |
    RtmpSession.Messages.Amf0Data.t

  defmodule State do
    defstruct self_epoch: nil,
              peer_initial_time: nil,
              chunk_io: nil,
              processor: nil
  end

  @spec new(pos_integer()) :: %State{}
  def new(peer_initial_time) do
    %State{
      peer_initial_time: peer_initial_time,
      self_epoch: :erlang.system_time(:milli_seconds),
      chunk_io: ChunkIo.new(),
      processor: Processor.new()
    }
  end

  @spec process_bytes(%State{}, <<>>) :: {%State{}, %RtmpSession.SessionResults{}}
  def process_bytes(state = %State{}, binary) when is_binary(binary) do
    {state, results} = do_process_bytes(state, binary, %SessionResults{})
    results = %{results | events: Enum.reverse(results.events)}

    {state, results}
  end

  defp do_process_bytes(state, binary, results_so_far) do
    {chunk_io, chunk_result} = ChunkIo.deserialize(state.chunk_io, binary)
    state = %{state | chunk_io: chunk_io}

    case chunk_result do
      :incomplete -> return_incomplete_result(state, results_so_far, byte_size(binary))
      :split_message -> repeat_process_bytes(state, results_so_far, byte_size(binary))
      raw_message = %RawMessage{} -> act_on_message(state, raw_message, results_so_far, byte_size(binary))
    end
  end

  defp return_incomplete_result(state, session_results, bytes_received) do
    {processor, proc_results} = Processor.notify_bytes_received(state.processor, bytes_received)
    state = %{state | processor: processor}

    handle_proc_result(state, session_results, proc_results)
  end

  defp repeat_process_bytes(state, session_results, bytes_received) do
    {processor, proc_results} = Processor.notify_bytes_received(state.processor, bytes_received)
    state = %{state | processor: processor}

    {state, session_results} = handle_proc_result(state, session_results, proc_results)
    
    do_process_bytes(state, <<>>, session_results)
  end

  defp act_on_message(state, raw_message, results_so_far, bytes_received) do
    case RawMessage.unpack(raw_message) do
      {:error, :unknown_message_type} ->
        _ = Logger.error "Received message of type #{raw_message.message_type_id} but we have no known way to unpack it!"

      {:ok, message} ->
        {processor, notify_results} = Processor.notify_bytes_received(state.processor, bytes_received)
        {processor, processor_results} = Processor.handle(processor, message)
        state = %{state | processor: processor}
      
        handle_proc_result(state, results_so_far, processor_results ++ notify_results)
    end
  end

  defp handle_proc_result(state, results_so_far, []) do
    {state, results_so_far}
  end

  defp handle_proc_result(state, results_so_far, [proc_result_head | proc_result_tail]) do
    case proc_result_head do
      {:response, message = %DetailedMessage{}} ->
        raw_message = RawMessage.pack(message) 
        {chunk_io, data} = ChunkIo.serialize(state.chunk_io, message, 0, false)
        state = %{state | chunk_io: chunk_io}
        results_so_far = %{results_so_far | bytes_to_send: [results_so_far.bytes_to_send | data] }
        handle_proc_result(state, results_so_far, proc_result_tail)

      {:event, %RtmpEvents.PeerChunkSizeChanged{new_chunk_size: size}} ->
        _ = Logger.debug "New peer chunk size #{size}"
        chunk_io = ChunkIo.set_receiving_max_chunk_size(state.chunk_io, size)
        state = %{state | chunk_io: chunk_io}
        results_so_far = %{results_so_far | events: [%RtmpEvents.PeerChunkSizeChanged{new_chunk_size: size} | results_so_far.events]}
        handle_proc_result(state, results_so_far, proc_result_tail)

      {:event, event} ->
        results_so_far = %{results_so_far | events: [event | results_so_far.events]}
        handle_proc_result(state, results_so_far, proc_result_tail)
    end
  end
end
