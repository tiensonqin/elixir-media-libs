defmodule Rtmp.ClientSession.Handler do
  @moduledoc """
  This module controls the process that processes the busines logic
  of a client in an RTMP connection.

  When RTMP messages come in from the server, it either responds with
  response messages or raises events to be handled by the event
  receiver process.  This allows for consumers to be flexible in how
  they utilize the RTMP client.
  """

  require Logger
  use GenServer

  alias Rtmp.Protocol.DetailedMessage, as: DetailedMessage
  alias Rtmp.Protocol.Messages, as: Messages
  alias Rtmp.ClientSession.Events, as: Events
  alias Rtmp.ClientSession.Configuration, as: Configuration

  @type session_handler_process :: pid
  @type protocol_handler_process :: pid
  @type protocol_handler_module :: module
  @type event_receiver_process :: pid
  @type event_receiver_module :: module
  @type av_type :: :audio | :video
  @type publish_type :: :live

  @behaviour Rtmp.Behaviours.SessionHandler

  defmodule State do
    @moduledoc false

    defstruct connection_id: nil,
              configuration: nil,
              start_time: nil,
              protocol_handler_pid: nil,
              protocol_handler_module: nil,
              event_receiver_pid: nil,
              event_receiver_module: nil,
              current_status: :started,
              connected_app_name: nil,
              last_transaction_id: 0.0,
              open_transactions: %{},
              active_streams: %{},
              stream_key_to_stream_id_map: %{},
              bytes_sent: 0,
              bytes_received: 0,
              byte_count_changed_timer: nil,
              server_ack_size: nil,
              last_ack_sent_at: 0
  end

  defmodule Transaction do
    @moduledoc false

    defstruct id: nil,
              type: nil,
              data: nil
  end

  defmodule ActiveStream do
    @moduledoc false

    defstruct id: nil,
              type: nil,
              state: :created,
              stream_key: nil
  end

  @spec start_link(Rtmp.connection_id(), Configuration.t()) :: {:ok, session_handler_process}
  @doc "Starts a new client session handler process"
  def start_link(connection_id, configuration = %Configuration{}) do
    GenServer.start_link(__MODULE__, [connection_id, configuration])
  end

  @spec set_event_handler(session_handler_process, event_receiver_process, event_receiver_module) ::
          :ok | :handler_already_set
  @doc """
  Specifies the process id and function to use to raise event notifications.

  It is expected that the module passed in implements the `Rtmp.Behaviours.EventReceiver` behaviour.
  """
  def set_event_handler(session_pid, event_pid, event_module) do
    GenServer.call(session_pid, {:set_event_handler, {event_pid, event_module}})
  end

  @spec set_protocol_handler(
          session_handler_process,
          protocol_handler_process,
          protocol_handler_module
        ) ::
          :ok | :handler_already_set
  @doc """
  Specifies the process id and function to send outbound RTMP messages

  It is expected that the module passed in implements the `Rtmp.Behaviours.ProtocolHandler` behaviour.
  """
  def set_protocol_handler(session_pid, protocol_handler_pid, protocol_handler_module) do
    GenServer.call(
      session_pid,
      {:set_protocol_handler, {protocol_handler_pid, protocol_handler_module}}
    )
  end

  @spec handle_rtmp_input(session_handler_process, DetailedMessage.t()) :: :ok
  @doc "Passes an incoming RTMP message to the session handler"
  def handle_rtmp_input(pid, message = %DetailedMessage{}) do
    GenServer.cast(pid, {:rtmp_input, message})
  end

  @spec notify_byte_count(
          Rtmp.Behaviours.SessionHandler.session_handler_pid(),
          Rtmp.Behaviours.SessionHandler.io_count_direction(),
          non_neg_integer
        ) :: :ok
  @doc "Notifies the session handler of new input or output byte totals"
  def notify_byte_count(pid, :bytes_received, total),
    do: GenServer.cast(pid, {:byte_count_update, :bytes_received, total})

  def notify_byte_count(pid, :bytes_sent, total),
    do: GenServer.cast(pid, {:byte_count_update, :bytes_sent, total})

  @spec request_connection(session_handler_process, Rtmp.app_name()) :: :ok
  @doc """
  Executes a request to send an RTMP connection request for the specified application name.  The
  response will come as a `Rtmp.ClientSession.Events.ConnectionResponseReceived` event.
  """
  def request_connection(pid, app_name) do
    GenServer.cast(pid, {:connect, app_name})
  end

  @spec request_playback(session_handler_process, Rtmp.stream_key()) :: :ok
  @doc """
  Sends a request to play from the specified stream key.  The response will come back as
  a `Rtmp.ClientSession.Events.PlayResponseReceived` event.
  """
  def request_playback(pid, stream_key) do
    GenServer.cast(pid, {:request_playback, stream_key})
  end

  @spec stop_playback(session_handler_process, Rtmp.stream_key()) :: :ok
  @doc """
  Attempts to stop playback for the specified stream key.  Does nothing if we do not have an active
  playback session on the specified stream key
  """
  def stop_playback(pid, stream_key) do
    GenServer.cast(pid, {:stop_playback, stream_key})
  end

  @spec request_publish(session_handler_process, Rtmp.stream_key(), publish_type) :: :ok
  @doc """
  Sends a request to the server that the client wishes to publish data on the specified stream key.
  The response will come as a `Rtmp.ClientSession.Events.PublishResponseReceived` response being raised
  """
  def request_publish(pid, stream_key, :live),
    do: GenServer.cast(pid, {:request_publish, stream_key, :live})

  def set_chunk_size(pid, chunk_size),
    do: GenServer.cast(pid, {:set_chunk_size, chunk_size})

  @spec publish_metadata(session_handler_process, Rtmp.stream_key(), Rtmp.StreamMetadata.t()) ::
          :ok
  @doc """
  Sends new metadata to the server over the specified stream key.  This is ignored if we are not
  in an active publishing session on that stream key
  """
  def publish_metadata(pid, stream_key, metadata = %Rtmp.StreamMetadata{}) do
    GenServer.cast(pid, {:publish_metadata, stream_key, metadata})
  end

  @spec publish_av_data(
          session_handler_process,
          Rtmp.stream_key(),
          av_type,
          Rtmp.timestamp(),
          binary
        ) :: :ok
  @doc """
  Sends audio or video data to the server over the specified stream key.  This is ignored if we are not
  in an active publishing session for that stream key.
  """
  def publish_av_data(pid, stream_key, :video, timestamp, data) do
    GenServer.cast(pid, {:publish_av_data, stream_key, :video, timestamp, data})
  end

  def publish_av_data(pid, stream_key, :audio, timestamp, data) do
    GenServer.cast(pid, {:publish_av_data, stream_key, :audio, timestamp, data})
  end

  @spec stop_publish(session_handler_process, Rtmp.stream_key()) :: :ok
  @doc """
  Attempts to stop publishing on the specified stream key.  This is ignored if we are not actively
  publishing on that stream key.
  """
  def stop_publish(pid, stream_key) do
    GenServer.cast(pid, {:stop_publish, stream_key})
  end

  def init([connection_id, configuration]) do
    state = %State{
      connection_id: connection_id,
      configuration: configuration,
      start_time: :os.system_time(:milli_seconds)
    }

    {:ok, state}
  end

  def handle_call({:set_event_handler, {event_pid, event_receiver_module}}, _from, state) do
    handler_set = state.event_receiver_pid != nil
    function_set = state.event_receiver_module != nil

    case handler_set && function_set do
      true ->
        {:reply, :event_handler_already_set, state}

      false ->
        state = %{
          state
          | event_receiver_pid: event_pid,
            event_receiver_module: event_receiver_module
        }

        {:reply, :ok, state}
    end
  end

  def handle_call(
        {:set_protocol_handler, {protocol_handler_pid, protocol_handler_module}},
        _from,
        state
      ) do
    handler_set = state.protocol_handler_pid != nil
    function_set = state.protocol_handler_module != nil

    case handler_set && function_set do
      true ->
        {:reply, :event_handler_already_set, state}

      false ->
        state = %{
          state
          | protocol_handler_pid: protocol_handler_pid,
            protocol_handler_module: protocol_handler_module
        }

        {:reply, :ok, state}
    end
  end

  def handle_cast({:rtmp_input, message}, state) do
    cond do
      state.event_receiver_pid == nil ->
        raise("No event handler set")

      state.event_receiver_module == nil ->
        raise("No event handler set")

      state.protocol_handler_pid == nil ->
        raise("No protocol handler set")

      state.protocol_handler_module == nil ->
        raise("No protocol handler set")

      true ->
        state = do_handle_rtmp_input(state, message)
        {:noreply, state}
    end
  end

  def handle_cast({:connect, app_name}, state) do
    case state.current_status do
      :started ->
        state = send_connect_command(state, app_name)
        {:noreply, state}

      _ ->
        _ =
          Logger.warn(
            "#{state.connection_id}: Attempted connection while in #{state.current_status} state, ignoring..."
          )

        {:noreply, state}
    end
  end

  def handle_cast({:request_playback, stream_key}, state) do
    case state.current_status do
      :connected ->
        state = send_create_stream_command(state, :playback, stream_key)
        {:noreply, state}

      _ ->
        _ =
          Logger.warn(
            "#{state.connection_id}: Attempted requesting playback while in #{
              state.current_status
            } state, ignoring..."
          )

        {:noreply, state}
    end
  end

  def handle_cast({:stop_playback, stream_key}, state) do
    case Map.fetch(state.stream_key_to_stream_id_map, stream_key) do
      {:ok, stream_id} ->
        {delete_stream_transaction, state} = form_transaction(state, :delete_stream, stream_id)

        delete_stream = %Messages.Amf0Command{
          command_name: "deleteStream",
          transaction_id: delete_stream_transaction,
          command_object: nil,
          additional_values: [stream_id]
        }

        :ok = send_output_message(state, delete_stream, stream_id, false)

        active_stream = Map.fetch!(state.active_streams, stream_id)
        active_stream = %{active_stream | state: :deleted}

        state = %{
          state
          | active_streams: Map.put(state.active_streams, stream_id, active_stream),
            stream_key_to_stream_id_map: Map.delete(state.stream_key_to_stream_id_map, stream_key)
        }

        {:noreply, state}

      :error ->
        # we aren't doing anything on this stream key, so just ignore
        {:noreply, state}
    end
  end

  def handle_cast({:request_publish, stream_key, publish_type}, state) do
    case state.current_status do
      :connected ->
        state = send_create_stream_command(state, {:publish, publish_type}, stream_key)
        {:noreply, state}

      _ ->
        _ =
          Logger.warn(
            "#{state.connection_id}: Attempted requesting publishing while in #{
              state.current_status
            } state, ignoring..."
          )

        {:noreply, state}
    end
  end

  def handle_cast({:set_chunk_size, chunk_size}, state) do
    case state.current_status do
      :connected ->
        # send set chunk size
        message = %Messages.SetChunkSize{size: chunk_size}
        :ok = send_output_message(state, message, 0, false)
        {:noreply, state}

      _ ->
        _ =
          Logger.warn(
            "#{state.connection_id}: Attempted to set chunk size while in #{
            state.current_status
            } state, ignoring..."
          )

        {:noreply, state}
    end
  end

  def handle_cast({:publish_metadata, stream_key, metadata}, state) do
    stream_id = Map.fetch!(state.stream_key_to_stream_id_map, stream_key)
    active_stream = Map.fetch!(state.active_streams, stream_id)

    case active_stream.state do
      :publishing ->
        data = %{}

        data =
          if metadata.video_width != nil,
            do: Map.put(data, "width", metadata.video_width),
            else: data

        data =
          if metadata.video_height != nil,
            do: Map.put(data, "height", metadata.video_height),
            else: data

        data =
          if metadata.video_codec != nil,
            do: Map.put(data, "videocodecid", metadata.video_codec),
            else: data

        data =
          if metadata.video_frame_rate != nil,
            do: Map.put(data, "framerate", metadata.video_frame_rate),
            else: data

        data =
          if metadata.video_bitrate_kbps != nil,
            do: Map.put(data, "videodatarate", metadata.video_bitrate_kbps),
            else: data

        data =
          if metadata.audio_codec != nil,
            do: Map.put(data, "audiocodecid", metadata.audio_codec),
            else: data

        data =
          if metadata.audio_bitrate_kbps != nil,
            do: Map.put(data, "audiodatarate", metadata.audio_bitrate_kbps),
            else: data

        data =
          if metadata.audio_sample_rate != nil,
            do: Map.put(data, "audiosamplerate", metadata.audio_sample_rate),
            else: data

        data =
          if metadata.audio_channels != nil,
            do: Map.put(data, "audiochannels", metadata.audio_channels),
            else: data

        data =
          if metadata.audio_is_stereo != nil,
            do: Map.put(data, "stereo", metadata.audio_is_stereo),
            else: data

        data =
          if metadata.encoder != nil, do: Map.put(data, "encoder", metadata.encoder), else: data

        message = %Messages.Amf0Data{
          parameters: ["@setDataFrame", "onMetaData", data]
        }

        send_output_message(state, message, stream_id, false)
        {:noreply, state}

      _ ->
        _ =
          Logger.debug(
            "#{state.connection_id}: Attempted to send metadata via a stream in the #{
              active_stream.state
            }"
          )

        {:noreply, state}
    end
  end

  def handle_cast({:publish_av_data, stream_key, av_type, timestamp, data}, state) do
    stream_id = Map.fetch!(state.stream_key_to_stream_id_map, stream_key)
    active_stream = Map.fetch!(state.active_streams, stream_id)

    case active_stream.state do
      :publishing ->
        inner_message =
          case av_type do
            :audio -> %Messages.AudioData{data: data}
            :video -> %Messages.VideoData{data: data}
          end

        outer_message = %DetailedMessage{
          stream_id: stream_id,
          timestamp: timestamp,
          content: inner_message
        }

        :ok =
          state.protocol_handler_module.send_message(state.protocol_handler_pid, outer_message)

        {:noreply, state}

      _ ->
        _ =
          Logger.debug(
            "#{state.connection_id}: Attempted to send metadata via a stream in the #{
              active_stream.state
            }"
          )

        {:noreply, state}
    end
  end

  def handle_cast({:stop_publish, stream_key}, state) do
    case Map.fetch(state.stream_key_to_stream_id_map, stream_key) do
      {:ok, stream_id} ->
        {fc_unpublish_transaction, state} = form_transaction(state, :fc_unpublish, stream_key)
        {delete_stream_transaction, state} = form_transaction(state, :delete_stream, stream_id)

        fc_unpublish = %Messages.Amf0Command{
          command_name: "FCUnpublish",
          transaction_id: fc_unpublish_transaction,
          command_object: nil,
          additional_values: [stream_key]
        }

        delete_stream = %Messages.Amf0Command{
          command_name: "deleteStream",
          transaction_id: delete_stream_transaction,
          command_object: nil,
          additional_values: [stream_id]
        }

        :ok = send_output_message(state, [fc_unpublish, delete_stream], stream_id, false)

        active_stream = Map.fetch!(state.active_streams, stream_id)
        active_stream = %{active_stream | state: :deleted}

        state = %{
          state
          | active_streams: Map.put(state.active_streams, stream_id, active_stream),
            stream_key_to_stream_id_map: Map.delete(state.stream_key_to_stream_id_map, stream_key)
        }

        {:noreply, state}

      :error ->
        # we aren't doing anything on this stream key, so just ignore
        {:noreply, state}
    end
  end

  def handle_cast({:byte_count_update, in_or_out, total}, state) do
    state =
      case in_or_out do
        :bytes_sent ->
          %{state | bytes_sent: total}

        :bytes_received ->
          %{state | bytes_received: state.bytes_received + total} |> send_ack_if_required()
      end

    state =
      case state.byte_count_changed_timer do
        nil ->
          :erlang.send_after(500, self(), :send_io_notifications)
          %{state | byte_count_changed_timer: :active}

        _ ->
          state
      end

    {:noreply, state}
  end

  def handle_info(:send_io_notifications, state) do
    event = %Events.NewByteIOTotals{
      bytes_sent: state.bytes_sent,
      bytes_received: state.bytes_received
    }

    state = %{state | byte_count_changed_timer: nil}
    raise_event(state, event)
    {:noreply, state}
  end

  def handle_info(message, state) do
    _ =
      Logger.info(
        "#{state.connection_id}: Session handler process received unknown erlang message: #{
          inspect(message)
        }"
      )

    {:noreply, state}
  end

  defp do_handle_rtmp_input(state, message = %DetailedMessage{content: %Messages.AudioData{}}) do
    # Note: some servers return audio/video data prior to the playback request
    # to be officially confirmed.  So we need to allow a/v data to be returned
    # both when in a confirmed playback state or in a requeted playback state

    active_stream = Map.fetch!(state.active_streams, message.stream_id)

    cond do
      active_stream.state == :closed ->
        # Assume this just came in as we closed the stream, so ignore it
        state

      active_stream.state != :playing && active_stream.state != :playback_requested ->
        error_message = "Client received audio data on stream in the #{active_stream.state} state"
        raise("#{state.connection_id}: #{error_message}")

      true ->
        event = %Events.AudioVideoDataReceived{
          stream_key: active_stream.stream_key,
          data_type: :audio,
          data: message.content.data,
          timestamp: message.timestamp,
          received_at_timestamp: message.deserialization_system_time
        }

        raise_event(state, event)
        state
    end
  end

  defp do_handle_rtmp_input(state, message = %DetailedMessage{content: %Messages.Amf0Command{}}) do
    handle_command(
      state,
      message.stream_id,
      message.content.command_name,
      message.content.transaction_id,
      message.content.command_object,
      message.content.additional_values
    )
  end

  defp do_handle_rtmp_input(state, message = %DetailedMessage{content: %Messages.Amf0Data{}}) do
    active_stream = Map.fetch!(state.active_streams, message.stream_id)
    handle_data(state, active_stream, message.content.parameters)
  end

  defp do_handle_rtmp_input(state, %DetailedMessage{content: %Messages.SetPeerBandwidth{}}) do
    # Ignore for now
    state
  end

  defp do_handle_rtmp_input(state, message = %DetailedMessage{content: %Messages.UserControl{}}) do
    case message.content.type do
      # ignore
      :stream_begin ->
        state

      _ ->
        _ =
          Logger.debug(
            "#{state.connection_id}: Unhandleable user control message received with type #{
              message.content.type
            }"
          )

        state
    end
  end

  defp do_handle_rtmp_input(state, %DetailedMessage{
         content: %Messages.WindowAcknowledgementSize{size: size}
       }) do
    state = %{state | server_ack_size: size}
    state
  end

  defp do_handle_rtmp_input(state, message = %DetailedMessage{content: %Messages.VideoData{}}) do
    # Note: some servers return audio/video data prior to the playback request
    # to be officially confirmed.  So we need to allow a/v data to be returned
    # both when in a confirmed playback state or in a requeted playback state

    active_stream = Map.fetch!(state.active_streams, message.stream_id)

    cond do
      active_stream.state == :closed ->
        # Assume this just came in as we closed the stream, so ignore it
        state

      active_stream.state != :playing && active_stream.state != :playback_requested ->
        error_message = "Client received audio data on stream in state #{active_stream.state}"
        raise("#{state.connection_id}: #{error_message}")

      true ->
        event = %Events.AudioVideoDataReceived{
          stream_key: active_stream.stream_key,
          data_type: :video,
          data: message.content.data,
          timestamp: message.timestamp,
          received_at_timestamp: message.deserialization_system_time
        }

        raise_event(state, event)
        state
    end
  end

  defp do_handle_rtmp_input(
         state,
         message = %DetailedMessage{content: %{__struct__: message_type}}
       ) do
    simple_name = String.replace(to_string(message_type), "Elixir.Rtmp.Protocol.Messages.", "")

    _ =
      Logger.warn(
        "#{state.connection_id}: Unable to handle #{simple_name} message on stream id #{
          message.stream_id
        }"
      )

    state
  end

  defp handle_command(
         state,
         _stream_id,
         "_result",
         transaction_id,
         command_object,
         additional_values
       ) do
    case Map.get(state.open_transactions, transaction_id) do
      nil ->
        _ =
          Logger.warn(
            "#{state.connection_id}: Received result for unknown transaction id #{transaction_id}"
          )

        state

      transaction ->
        state = %{state | open_transactions: Map.delete(state.open_transactions, transaction_id)}

        case transaction.type do
          :connect ->
            handle_connect_result(state, transaction, command_object, additional_values)

          :create_stream ->
            handle_create_stream_result(state, transaction, command_object, additional_values)
        end
    end
  end

  defp handle_command(state, stream_id, "onStatus", _transaction_id, _command_object, [
         arguments = %{}
       ]) do
    handle_onStatus_message(state, stream_id, arguments)
  end

  defp handle_command(state, stream_id, command_name, transaction_id, _command_obj, _args) do
    unless is_ignorable_command(command_name) do
      _ =
        Logger.warn(
          "#{state.connection_id}: Unable to handle command '#{command_name}' " <>
            "(stream id '#{stream_id}', transaction_id: #{transaction_id})"
        )
    end

    state
  end

  defp handle_connect_result(state, transaction, _command_object, [arguments = %{}]) do
    case arguments["code"] do
      "NetConnection.Connect.Success" ->
        state = %{state | current_status: :connected, connected_app_name: transaction.data}

        event = %Events.ConnectionResponseReceived{
          was_accepted: true,
          response_text: arguments["description"]
        }

        message = %Messages.WindowAcknowledgementSize{size: state.configuration.window_ack_size}

        :ok = raise_event(state, event)
        :ok = send_output_message(state, message, 0, false)
        state
    end
  end

  defp handle_data(state, _stream = %ActiveStream{state: :closed}, ['onMetaData', _metadata = %{}]) do
    state
  end

  defp handle_data(state, stream = %ActiveStream{state: :playing}, ['onMetaData', metadata = %{}]) do
    event = %Events.StreamMetaDataReceived{
      stream_key: stream.stream_key,
      meta_data: %Rtmp.StreamMetadata{
        video_width: metadata["width"],
        video_height: metadata["height"],
        video_codec: metadata["videocodecid"],
        video_frame_rate: metadata["framerate"],
        video_bitrate_kbps: metadata["videodatarate"],
        audio_codec: metadata["audiocodecid"],
        audio_bitrate_kbps: metadata["audiodatarate"],
        audio_sample_rate: metadata["audiosamplerate"],
        audio_channels: metadata["audiochannels"],
        audio_is_stereo: metadata["stereo"],
        encoder: metadata["encoder"]
      }
    }

    raise_event(state, event)
    state
  end

  defp handle_data(state, _stream, ["|RtmpSampleAccess" | _]) do
    # ignore
    state
  end

  defp handle_data(state, stream_id, ["onStatus", arguments = %{}]) do
    handle_onStatus_message(state, stream_id, arguments)
  end

  defp handle_data(state, stream, data) do
    _ =
      Logger.info(
        "#{state.connection_id}: No known way to handle incoming data on stream id '#{stream.id}' " <>
          "in state #{stream.state}.  Data: #{inspect(data)}"
      )

    state
  end

  defp send_connect_command(state, app_name) do
    {transaction, state} = form_transaction(state, :connect, app_name)

    command = %Messages.Amf0Command{
      command_name: "connect",
      transaction_id: transaction.id,
      command_object: %{
        "app" => app_name,
        "flashVer" => state.configuration.flash_version,
        "objectEncoding" => 0
      },
      additional_values: []
    }

    :ok = send_output_message(state, command, 0, false)

    %{
      state
      | current_status: :connecting,
        open_transactions: Map.put(state.open_transactions, transaction.id, transaction)
    }
  end

  defp send_create_stream_command(state, purpose, stream_key) do
    {transaction, state} =
      form_transaction(state, :create_stream, {purpose, %{:stream_key => stream_key}})

    command = %Messages.Amf0Command{
      command_name: "createStream",
      transaction_id: transaction.id
    }

    :ok = send_output_message(state, command, 0, false)

    %{
      state
      | current_status: :connecting,
        open_transactions: Map.put(state.open_transactions, transaction.id, transaction)
    }
  end

  defp handle_create_stream_result(state, transaction, _, [stream_id]) do
    # ints are required for stream ids due to serialization
    stream_id = trunc(stream_id)

    if Map.has_key?(state.active_streams, stream_id) do
      raise(
        "#{state.connection_id}: Server created stream #{stream_id} but we were already tracking a stream with that id"
      )
    end

    {purpose, %{:stream_key => stream_key}} = transaction.data

    active_stream = %ActiveStream{
      id: stream_id,
      type: purpose,
      stream_key: stream_key
    }

    state = upsert_active_stream(state, active_stream)

    case purpose do
      :playback ->
        active_stream = %{active_stream | state: :playback_requested}
        state = upsert_active_stream(state, active_stream)

        buffer_length_message = %Messages.UserControl{
          type: :set_buffer_length,
          buffer_length: state.configuration.playback_buffer_length_ms,
          stream_id: stream_id
        }

        {transaction, state} = form_transaction(state, :play, stream_key)

        play_message = %Messages.Amf0Command{
          command_name: "play",
          transaction_id: transaction.id,
          command_object: nil,
          additional_values: [stream_key]
        }

        :ok = send_output_message(state, buffer_length_message, 0, false)
        :ok = send_output_message(state, play_message, stream_id, false)

        state

      {:publish, type} ->
        type_as_string = if type == :live, do: "live", else: ""

        {transaction, state} = form_transaction(state, :publish, stream_key)

        publish_message = %Messages.Amf0Command{
          command_name: "publish",
          transaction_id: transaction.id,
          command_object: nil,
          additional_values: [stream_key, type_as_string]
        }

        :ok = send_output_message(state, publish_message, stream_id, false)
        state
    end
  end

  defp handle_play_start(state, stream_id, status_text) do
    case Map.get(state.active_streams, stream_id) do
      nil ->
        _ =
          Logger.debug(
            "#{state.connection_id}: Play start command received for non-tracked stream id #{
              stream_id
            }"
          )

        state

      active_stream = %ActiveStream{} ->
        case active_stream.state do
          x when x == :created or x == :playback_requested ->
            active_stream = %{active_stream | state: :playing}
            state = upsert_active_stream(state, active_stream)

            event = %Rtmp.ClientSession.Events.PlayResponseReceived{
              was_accepted: true,
              response_text: status_text,
              stream_key: active_stream.stream_key
            }

            :ok = raise_event(state, event)
            state
        end
    end
  end

  defp handle_play_reset(state, stream_id, description) do
    case Map.get(state.active_streams, stream_id) do
      nil ->
        _ =
          Logger.debug(
            "#{state.connection_id}: Play reset command received for non-tracked stream id #{
              stream_id
            }"
          )

        state

      active_stream = %ActiveStream{} ->
        case active_stream.state do
          x when x == :created or x == :playback_requested or x == :playing ->
            event = %Rtmp.ClientSession.Events.PlayResetReceived{
              description: description,
              stream_key: active_stream.stream_key
            }

            :ok = raise_event(state, event)
            state
        end
    end
  end

  defp handle_publish_start(state, stream_id, status_text) do
    case Map.get(state.active_streams, stream_id) do
      nil ->
        _ =
          Logger.debug(
            "#{state.connection_id}: Publish start command received for non-tracked stream id #{
              stream_id
            }"
          )

        state

      active_stream = %ActiveStream{} ->
        case active_stream.state do
          :created ->
            active_stream = %{active_stream | state: :publishing}
            all_active_streams = Map.put(state.active_streams, stream_id, active_stream)
            state = %{state | active_streams: all_active_streams}

            event = %Rtmp.ClientSession.Events.PublishResponseReceived{
              stream_key: active_stream.stream_key,
              was_accepted: true,
              response_text: status_text
            }

            :ok = raise_event(state, event)
            state
        end
    end
  end

  defp send_ack_if_required(state) do
    case state.server_ack_size do
      nil ->
        state

      size ->
        case state.bytes_received - state.last_ack_sent_at > size do
          false ->
            state

          true ->
            ack = %Messages.Acknowledgement{sequence_number: state.bytes_received}
            :ok = send_output_message(state, ack, 0, false)
            %{state | last_ack_sent_at: state.bytes_received}
        end
    end
  end

  defp handle_onStatus_message(state, stream_id, arguments) do
    case arguments["code"] do
      "NetStream.Play.Start" ->
        handle_play_start(state, stream_id, arguments["description"])

      "NetStream.Play.Reset" ->
        handle_play_reset(state, stream_id, arguments["description"])

      "NetStream.Publish.Start" ->
        handle_publish_start(state, stream_id, arguments["description"])

      # ignore
      "NetStream.Data.Start" ->
        state

      nil ->
        _ = Logger.warn("#{state.connection_id}: onStatus sent by server with no code argument")
        state

      command ->
        _ =
          Logger.warn(
            "#{state.connection_id}: onStatus command of '#{command}' received but no known way to handle it"
          )

        state
    end
  end

  defp form_transaction(state, type, data) do
    transaction = %Transaction{
      id: state.last_transaction_id + 1.0,
      type: type,
      data: data
    }

    state = %{state | last_transaction_id: transaction.id}
    {transaction, state}
  end

  defp form_output_message(state, message_content, stream_id, force_uncompressed) do
    %DetailedMessage{
      timestamp: get_current_rtmp_epoch(state),
      stream_id: stream_id,
      content: message_content,
      force_uncompressed: force_uncompressed
    }
  end

  defp get_current_rtmp_epoch(state) do
    time_since_start = :os.system_time(:milli_seconds) - state.start_time
    Rtmp.Protocol.RtmpTime.to_rtmp_timestamp(time_since_start)
  end

  defp send_output_message(_, [], _, _) do
    :ok
  end

  defp send_output_message(state, [message | rest], stream_id, force_uncompressed) do
    response = form_output_message(state, message, stream_id, force_uncompressed)
    :ok = state.protocol_handler_module.send_message(state.protocol_handler_pid, response)
    send_output_message(state, rest, stream_id, force_uncompressed)
  end

  defp send_output_message(state, message, stream_id, force_uncompressed) do
    send_output_message(state, [message], stream_id, force_uncompressed)
  end

  defp raise_event(_, []) do
    :ok
  end

  defp raise_event(state, [event | rest]) do
    :ok = state.event_receiver_module.send_event(state.event_receiver_pid, event)
    raise_event(state, rest)
  end

  defp raise_event(state, event) do
    raise_event(state, [event])
  end

  defp upsert_active_stream(state, active_stream) do
    all_active_streams = Map.put(state.active_streams, active_stream.id, active_stream)

    stream_key_to_stream_id_map =
      Map.put(state.stream_key_to_stream_id_map, active_stream.stream_key, active_stream.id)

    %{
      state
      | active_streams: all_active_streams,
        stream_key_to_stream_id_map: stream_key_to_stream_id_map
    }
  end

  defp is_ignorable_command("onBWDone"), do: true
  defp is_ignorable_command(_), do: false
end
