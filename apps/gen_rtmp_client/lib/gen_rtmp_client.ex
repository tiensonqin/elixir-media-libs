defmodule GenRtmpClient do
  @moduledoc """
  A behaviour for creating RTMP clients.

  A `GenRtmpClient` abstracts out the functionality and RTMP message flow
  so that modules that implement this behaviour can focus on the high level
  business logic of how their RTMP client should behave. 
  """

  @behaviour Rtmp.Behaviours.EventReceiver
  @behaviour Rtmp.Behaviours.SocketHandler

  require Logger
  use GenServer

  alias Rtmp.ClientSession.Events, as: SessionEvents

  @type adopter_module :: module
  @type adopter_state :: any
  @type adopter_args :: any
  @type adopter_response :: {:ok, adopter_state}
  @type rtmp_client_pid :: pid
  @type disconnection_reason :: :stopping | :closed | :inet.posix()

  @callback init(GenRtmpClient.ConnectionInfo.t(), adopter_args) :: {:ok, adopter_state}
  @callback handle_connection_response(
              SessionEvents.ConnectionResponseReceived.t(),
              adopter_state
            ) :: adopter_response
  @callback handle_play_response(SessionEvents.PlayResponseReceived.t(), adopter_state) ::
              adopter_response
  @callback handle_play_reset(SessionEvents.PlayResetReceived.t(), adopter_state) ::
              adopter_response
  @callback handle_publish_response(SessionEvents.PublishResponseReceived.t(), adopter_state) ::
              adopter_response
  @callback handle_metadata_received(SessionEvents.StreamMetaDataReceived.t(), adopter_state) ::
              adopter_response
  @callback handle_av_data_received(SessionEvents.AudioVideoDataReceived.t(), adopter_state) ::
              adopter_response
  @callback handle_disconnection(disconnection_reason, adopter_state) ::
              {:stop, adopter_state} | {:reconnect, adopter_state}
  @callback byte_io_totals_updated(SessionEvents.NewByteIOTotals.t(), adopter_state) ::
              adopter_response
  @callback handle_message(any, adopter_state) :: adopter_response

  defmodule State do
    @moduledoc false

    defstruct connection_status: :disconnected,
              adopter_module: nil,
              adopter_state: nil,
              connection_info: nil,
              socket: nil,
              handshake_state: nil,
              protocol_handler_pid: nil,
              session_handler_pid: nil,
              is_being_stopped: false,
              total_bytes_sent: 0,
              total_packets_sent: 0,
              total_bytes_dropped: 0,
              total_packets_dropped: 0
  end

  @spec start_link(adopter_module, GenRtmpClient.ConnectionInfo.t(), adopter_args) ::
          GenServer.on_start()
  @doc """
  Starts a new RTMP connection to the specified server.  The client's logic is managed by the module
  specified by the adopter_module, which is expected to adopt the `GenRtmpClient` behaviour.
  """
  def start_link(adopter_module, connection_info = %GenRtmpClient.ConnectionInfo{}, adopter_args) do
    GenServer.start_link(__MODULE__, [adopter_module, connection_info, adopter_args])
  end

  @spec stop_client(rtmp_client_pid) :: :ok
  @doc "Tells an RTMP client to disconnect without retrying and permanently stop"
  def stop_client(pid) do
    GenServer.cast(pid, :stop_client)
  end

  @spec start_playback(rtmp_client_pid, Rtmp.stream_key()) :: :ok
  @doc "Requests playback capabilities on the specified stream key"
  def start_playback(rtmp_client_pid, stream_key) do
    GenServer.cast(rtmp_client_pid, {:start_playback, stream_key})
  end

  @spec stop_playback(rtmp_client_pid, Rtmp.stream_key()) :: :ok
  @doc "Stops playback on the specified stream key"
  def stop_playback(rtmp_client_pid, stream_key) do
    GenServer.cast(rtmp_client_pid, {:stop_playback, stream_key})
  end

  @spec start_publish(
          rtmp_client_pid,
          Rtmp.stream_key(),
          Rtmp.ClientSession.Handler.publish_type()
        ) :: :ok
  @doc "Requests publish capabilities for the specified stream key"
  def start_publish(rtmp_client_pid, stream_key, type) do
    GenServer.cast(rtmp_client_pid, {:start_publish, stream_key, type})
  end

  @spec stop_publish(rtmp_client_pid, Rtmp.stream_key()) :: :ok
  @doc "Stops publishing on the specified stream key"
  def stop_publish(rtmp_client_pid, stream_key) do
    GenServer.cast(rtmp_client_pid, {:stop_publish, stream_key})
  end

  @spec publish_metadata(rtmp_client_pid, Rtmp.stream_key(), Rtmp.StreamMetadata.t()) :: :ok
  @doc "Sends new metadata information to the server for the specified stream key"
  def publish_metadata(rtmp_client_pid, stream_key, metadata) do
    GenServer.cast(rtmp_client_pid, {:publish_metadata, stream_key, metadata})
  end

  @spec publish_av_data(
          rtmp_client_pid,
          Rtmp.stream_key(),
          Rtmp.ClientSession.Handler.av_type(),
          Rtmp.timestamp(),
          binary
        ) :: :ok
  @doc "Sends audio or video data to the server for the specified stream key"
  def publish_av_data(rtmp_client_pid, stream_key, type, timestamp, data) do
    GenServer.cast(rtmp_client_pid, {:publish_av_data, stream_key, type, timestamp, data})
  end

  @doc false
  def send_event(pid, event) do
    GenServer.cast(pid, {:session_event, event})
  end

  @doc false
  def send_data(pid, binary, packet_type) do
    GenServer.cast(pid, {:rtmp_output, binary, packet_type})
  end

  def init([adopter_module, connection_info, adopter_args]) do
    {:ok, adopter_state} = adopter_module.init(connection_info, adopter_args)

    state = %State{
      adopter_module: adopter_module,
      adopter_state: adopter_state,
      connection_info: connection_info
    }

    case connect_to_server(state) do
      {:permanently_disconnected, _state} -> {:stop, :permanently_disconnected}
      {:ok, state} -> {:ok, state}
    end
  end

  def handle_cast({:rtmp_output, binary, packet_type}, state) do
    # If the network buffer becomes full due to a connection that can't handle the amount
    # of audio/video data going out to the server, we need to compensate by dropping 
    # audio/video data as necessary in order to not back everything up.  All non-audio/video
    # messages should not be dropped though.

    # TODO: Should probably make sure sequence header packets are never dropped. 
    # Otherwise the video is useless.

    can_be_dropped =
      case packet_type do
        :audio -> true
        :video -> true
        _ -> false
      end

    state =
      case can_be_dropped do
        false -> send_undroppable_packet(state, binary)
        true -> send_droppable_packet(state, binary)
      end

    {:noreply, state}
  end

  def handle_cast({:start_playback, stream_key}, state) do
    :ok = Rtmp.ClientSession.Handler.request_playback(state.session_handler_pid, stream_key)
    {:noreply, state}
  end

  def handle_cast({:start_publish, stream_key, type}, state) do
    :ok = Rtmp.ClientSession.Handler.request_publish(state.session_handler_pid, stream_key, type)
    {:noreply, state}
  end

  def handle_cast({:publish_metadata, stream_key, metadata}, state) do
    :ok =
      Rtmp.ClientSession.Handler.publish_metadata(state.session_handler_pid, stream_key, metadata)

    {:noreply, state}
  end

  def handle_cast({:publish_av_data, stream_key, type, timestamp, data}, state) do
    :ok =
      Rtmp.ClientSession.Handler.publish_av_data(
        state.session_handler_pid,
        stream_key,
        type,
        timestamp,
        data
      )

    {:noreply, state}
  end

  def handle_cast({:session_event, event}, state) do
    state = handle_event(event, state)
    {:noreply, state}
  end

  def handle_cast(:stop_client, state) do
    state = %{state | is_being_stopped: true}
    :gen_tcp.shutdown(state.socket, :read_write)

    {:noreply, state}
  end

  def handle_info({:tcp, _, binary}, state = %State{connection_status: :handshaking}) do
    :inet.setopts(state.socket, get_socket_options())

    case Rtmp.Handshake.process_bytes(state.handshake_state, binary) do
      {handshake_state, result = %Rtmp.Handshake.ParseResult{current_state: :waiting_for_data}} ->
        if byte_size(result.bytes_to_send) > 0,
          do: :gen_tcp.send(state.socket, result.bytes_to_send)

        new_state = %{state | handshake_state: handshake_state}
        :inet.setopts(state.socket, get_socket_options())
        {:noreply, new_state}

      {handshake_state, result = %Rtmp.Handshake.ParseResult{current_state: :success}} ->
        if byte_size(result.bytes_to_send) > 0,
          do: :gen_tcp.send(state.socket, result.bytes_to_send)

        {_, %Rtmp.Handshake.HandshakeResult{remaining_binary: remaining_binary}} =
          Rtmp.Handshake.get_handshake_result(handshake_state)

        {:ok, protocol_pid} =
          Rtmp.Protocol.Handler.start_link(
            state.connection_info.connection_id,
            self(),
            __MODULE__
          )

        {:ok, session_pid} =
          Rtmp.ClientSession.Handler.start_link(
            state.connection_info.connection_id,
            %Rtmp.ClientSession.Configuration{}
          )

        :ok =
          Rtmp.Protocol.Handler.set_session(protocol_pid, session_pid, Rtmp.ClientSession.Handler)

        :ok =
          Rtmp.ClientSession.Handler.set_protocol_handler(
            session_pid,
            protocol_pid,
            Rtmp.Protocol.Handler
          )

        :ok = Rtmp.ClientSession.Handler.set_event_handler(session_pid, self(), __MODULE__)
        :ok = Rtmp.Protocol.Handler.notify_input(protocol_pid, remaining_binary)

        state = %{
          state
          | handshake_state: nil,
            connection_status: :open,
            protocol_handler_pid: protocol_pid,
            session_handler_pid: session_pid
        }

        _ = Logger.info("#{state.connection_info.connection_id}: handshake complete")

        :ok = send_connect_command(state)
        {:noreply, state}

      {_, %Rtmp.Handshake.ParseResult{current_state: :failure}} ->
        _ =
          Logger.info(
            "#{state.connection_info.connection_id}: Client failed the handshake, disconnecting..."
          )

        :gen_tcp.close(state.socket)
        {:noreply, state}
    end
  end

  def handle_info({:tcp, _, binary}, state) do
    :ok = Rtmp.Protocol.Handler.notify_input(state.protocol_handler_pid, binary)
    :inet.setopts(state.socket, get_socket_options())
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _}, state) do
    reason = if state.is_being_stopped, do: :stopping, else: :closed

    case notify_disconnection(state, reason) do
      {:permanently_disconnected, state} ->
        {:stop, :normal, state}

      {:ok, state} ->
        # reconnected
        {:noreply, state}
    end
  end

  def handle_info({:inet_reply, _socket, _status}, state) do
    {:noreply, state}
  end

  def handle_info(message, state) do
    {:ok, adopter_state} = state.adopter_module.handle_message(message, state.adopter_state)
    state = %{state | adopter_state: adopter_state}

    {:noreply, state}
  end

  defp send_connect_command(state) do
    Rtmp.ClientSession.Handler.request_connection(
      state.session_handler_pid,
      state.connection_info.app_name
    )
  end

  defp connect_to_server(state) do
    case :gen_tcp.connect(
           String.to_charlist(state.connection_info.host),
           state.connection_info.port,
           get_socket_options()
         ) do
      {:error, reason} ->
        notify_disconnection(state, reason)

      {:ok, socket} ->
        {handshake_state, %Rtmp.Handshake.ParseResult{bytes_to_send: bytes_to_send}} =
          Rtmp.Handshake.new(:digest)

        :ok = :gen_tcp.send(socket, bytes_to_send)

        state = %{
          state
          | socket: socket,
            handshake_state: handshake_state,
            connection_status: :handshaking
        }

        {:ok, state}
    end
  end

  defp notify_disconnection(state, reason) do
    state = %{state | connection_status: :disconnected}

    case state.adopter_module.handle_disconnection(reason, state.adopter_state) do
      {:stop, adopter_state} ->
        {:permanently_disconnected, %{state | adopter_state: adopter_state}}

      {:retry, adopter_state} ->
        connect_to_server(%{state | adopter_state: adopter_state})
    end
  end

  defp handle_event(event = %SessionEvents.AudioVideoDataReceived{}, state) do
    {:ok, adopter_state} =
      state.adopter_module.handle_av_data_received(event, state.adopter_state)

    %{state | adopter_state: adopter_state}
  end

  defp handle_event(event = %SessionEvents.NewByteIOTotals{}, state) do
    {:ok, adopter_state} = state.adopter_module.byte_io_totals_updated(event, state.adopter_state)
    %{state | adopter_state: adopter_state}
  end

  defp handle_event(event = %SessionEvents.ConnectionResponseReceived{}, state) do
    {:ok, adopter_state} =
      state.adopter_module.handle_connection_response(event, state.adopter_state)

    %{state | adopter_state: adopter_state}
  end

  defp handle_event(event = %SessionEvents.PlayResetReceived{}, state) do
    {:ok, adopter_state} = state.adopter_module.handle_play_reset(event, state.adopter_state)
    %{state | adopter_state: adopter_state}
  end

  defp handle_event(event = %SessionEvents.PlayResponseReceived{}, state) do
    {:ok, adopter_state} = state.adopter_module.handle_play_response(event, state.adopter_state)
    %{state | adopter_state: adopter_state}
  end

  defp handle_event(event = %SessionEvents.PublishResponseReceived{}, state) do
    {:ok, adopter_state} =
      state.adopter_module.handle_publish_response(event, state.adopter_state)

    %{state | adopter_state: adopter_state}
  end

  defp send_undroppable_packet(state, binary) do
    :gen_tcp.send(state.socket, binary)
    mark_packet_as_sent(state, binary)
  end

  defp send_droppable_packet(state, binary) do
    case :erlang.port_command(state.socket, binary, [:nosuspend]) do
      true ->
        mark_packet_as_sent(state, binary)

      false ->
        # Port is too busy to send, drop the packet
        mark_packet_as_dropped(state, binary)
    end
  end

  defp mark_packet_as_sent(state, binary) do
    %{
      state
      | total_bytes_sent: state.total_bytes_sent + byte_size(binary),
        total_packets_sent: state.total_packets_sent + 1
    }
  end

  defp mark_packet_as_dropped(state, binary) do
    %{
      state
      | total_bytes_dropped: state.total_bytes_dropped + byte_size(binary),
        total_packets_dropped: state.total_packets_dropped + 1
    }
  end

  defp get_socket_options(),
    do: [:binary | Keyword.new(active: :once, packet: :raw, buffer: 4096)]
end
