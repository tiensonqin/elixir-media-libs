defmodule Rtmp.Protocol.Handler do
  @moduledoc """
  This module controls the process that is responsible for serializing
  and deserializing RTMP chunk streams for a single peer in an RTMP
  connection.  Input bytes come in, get deserialized into RTMP messages,
  and then get sent off to the specified session handling process.  It can
  receive outbound RTMP messages that will then be serialized and sent off
  to the peer.

  Due to the way RTMP header compression works, it is expected that the
  protocol handler will receive every input byte of network communication
  after a successful handshake, and it will be the only system serializing
  and sending outbound RTMP messages to the peer.  If these assumptions are
  broken then there is a large chance the client or server will crash due
  to not being able to properly parse an RTMP chunk correctly.
  """

  require Logger
  use GenServer

  alias Rtmp.Protocol.ChunkIo, as: ChunkIo
  alias Rtmp.Protocol.RawMessage, as: RawMessage
  alias Rtmp.Protocol.DetailedMessage, as: DetailedMessage
  alias Rtmp.Protocol.Messages.SetChunkSize, as: SetChunkSize
  alias Rtmp.Protocol.Messages.VideoData, as: VideoData
  alias Rtmp.Protocol.Messages.AudioData, as: AudioData

  @type protocol_handler :: pid
  @type socket_transport_module :: module
  @type session_process :: pid
  @type session_handler_module :: module

  @behaviour Rtmp.Behaviours.ProtocolHandler

  defmodule State do
    @moduledoc false

    defstruct connection_id: nil,
              socket: nil,
              socket_module: nil,
              # nil,
              chunk_io_state: ChunkIo.new(),
              session_process: nil,
              session_module: nil,
              bytes_received: 0,
              bytes_sent: 0,
              last_bytes_sent_notification_at: 0,
              last_bytes_received_notification_at: 0,
              io_notification_timer: nil
  end

  @spec start_link(
          Rtmp.connection_id(),
          Rtmp.Behaviours.SocketHandler.socket_handler_pid(),
          socket_transport_module
        ) :: {:ok, protocol_handler}
  @doc "Starts a new protocol handler process"
  def start_link(connection_id, socket, socket_module) do
    GenServer.start_link(__MODULE__, [connection_id, socket, socket_module])
  end

  @spec set_session(protocol_handler, session_process, session_handler_module) ::
          :ok | :session_already_set
  @doc """
  Specifies the session handler process and function to use to send deserialized
  RTMP messages to for the session handler.

  It is expected that the module that is passed in implements the
  `Rtmp.Behaviours.SessionHandler` behaviour.
  """
  def set_session(pid, session_process, session_module) do
    GenServer.call(pid, {:set_session, {session_process, session_module}})
  end

  @spec notify_input(protocol_handler, binary) :: :ok
  @doc """
  Notifies the protocol handler of incoming binary coming in from the socket
  """
  def notify_input(pid, binary) when is_binary(binary) do
    GenServer.cast(pid, {:socket_input, binary})
  end

  @spec send_message(protocol_handler, DetailedMessage.t()) :: :ok
  @doc """
  Notifies the protocol handler of an rtmp message that should be serialized
  and sent to the peer.
  """
  def send_message(pid, message = %DetailedMessage{}) do
    GenServer.cast(pid, {:send_message, message})
  end

  def init([connection_id, socket, socket_module]) do
    state = %State{
      connection_id: connection_id,
      socket: socket,
      socket_module: socket_module,
      chunk_io_state: ChunkIo.new()
    }

    {:ok, state}
  end

  def handle_call({:set_session, {pid, session_module}}, _from, state) do
    state = %{state | session_process: pid, session_module: session_module}

    {:reply, :ok, state}
  end

  def handle_cast({:socket_input, binary}, state) do
    if state.session_process == nil || state.session_module == nil do
      raise "Input received, but session process and notification functions are not set yet"
    end

    state = process_bytes(state, binary)
    state = %{state | bytes_received: state.bytes_received + byte_size(binary)}
    state = trigger_io_notification_timer(state)

    {:noreply, state}
  end

  def handle_cast({:send_message, message}, state) do
    raw_message = RawMessage.pack(message)
    csid = get_csid_for_message_type(raw_message.message_type_id)

    {chunk_io_state, data} = ChunkIo.serialize(state.chunk_io_state, raw_message, csid)
    state = %{state | chunk_io_state: chunk_io_state}

    state =
      case message.content do
        %SetChunkSize{size: size} ->
          chunk_io_state = ChunkIo.set_sending_max_chunk_size(state.chunk_io_state, size)
          %{state | chunk_io_state: chunk_io_state}

        _ ->
          state
      end

    packet_type =
      case message.content do
        %VideoData{} -> :video
        %AudioData{} -> :audio
        _ -> :misc
      end

    :ok = state.socket_module.send_data(state.socket, data, packet_type)
    state = %{state | bytes_sent: state.bytes_sent + byte_size(data)}
    state = trigger_io_notification_timer(state)

    {:noreply, state}
  end

  def handle_info(:send_io_notifications, state) do
    if state.bytes_sent > state.last_bytes_sent_notification_at do
      :ok =
        state.session_module.notify_byte_count(
          state.session_process,
          :bytes_sent,
          state.bytes_sent
        )
    end

    if state.bytes_received > state.last_bytes_received_notification_at do
      :ok =
        state.session_module.notify_byte_count(
          state.session_process,
          :bytes_received,
          state.bytes_received
        )
    end

    state = %{
      state
      | io_notification_timer: nil,
        last_bytes_received_notification_at: state.bytes_received,
        last_bytes_sent_notification_at: state.bytes_sent
    }

    {:noreply, state}
  end

  defp process_bytes(state, binary) do
    {chunk_io_state, chunk_result} = ChunkIo.deserialize(state.chunk_io_state, binary)
    state = %{state | chunk_io_state: chunk_io_state}

    case chunk_result do
      :incomplete -> state
      :split_message -> process_bytes(state, <<>>)
      raw_message = %RawMessage{} -> act_on_message(state, raw_message)
    end
  end

  defp act_on_message(state, raw_message) do
    case RawMessage.unpack(raw_message) do
      {:error, :unknown_message_type} ->
        _ =
          Logger.error(
            "#{state.connection_id}: Received message of type #{raw_message.message_type_id} but we have no known way to unpack it!"
          )

        state

      {:ok, message = %DetailedMessage{content: %SetChunkSize{size: size}}} ->
        chunk_io_state = ChunkIo.set_receiving_max_chunk_size(state.chunk_io_state, size)
        state = %{state | chunk_io_state: chunk_io_state}

        :ok = state.session_module.handle_rtmp_input(state.session_process, message)
        process_bytes(state, <<>>)

      {:ok, message = %DetailedMessage{}} ->
        :ok = state.session_module.handle_rtmp_input(state.session_process, message)
        process_bytes(state, <<>>)
    end
  end

  defp trigger_io_notification_timer(state) do
    case state.io_notification_timer do
      nil ->
        :erlang.send_after(500, self(), :send_io_notifications)
        %{state | io_notification_timer: :active}

      _ ->
        state
    end
  end

  # Csid seems to mostly be for better utilizing compression by spreading
  # different message types among different chunk stream ids.  It also allows
  # video and audio data to track different timestamps then other messages.
  # These numbers are just based on observations of current client-server activity
  defp get_csid_for_message_type(message_type_id) do
    cond do
      message_type_id in [1, 2, 3, 4, 5, 6] -> 2
      message_type_id in [18, 19] -> 3
      message_type_id in [9] -> 4
      message_type_id in [8] -> 5
      true -> 6
    end
  end
end
