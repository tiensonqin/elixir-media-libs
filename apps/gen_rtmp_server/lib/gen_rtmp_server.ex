defmodule GenRtmpServer do
  @moduledoc """
  A behaviour module for implementing an RTMP server.

  A GenRtmpServer abstracts out the the handling of RTMP connection handling
  and data so that modules that implement this behaviour can focus on 
  the business logic of the actual RTMP events that are received and
  should be sent.

  Each client that connects is placed in it's own process.
  """

  require Logger

  @type session_id :: String.t()
  @type client_ip :: String.t()
  @type adopter_state :: any
  @type command :: :ignore | :disconnect
  @type request_result :: :accepted | {:rejected, command, String.t()}
  @type outbound_data :: GenRtmpServer.AudioVideoData.t() | GenRtmpServer.MetaData.t()
  @type stream_id :: non_neg_integer
  @type forced_timestamp :: non_neg_integer | nil
  @type adopter_arguments :: [...]

  @doc "Called when a new RTMP client connects"
  @callback init(session_id, client_ip, adopter_arguments) :: {:ok, adopter_state}

  @doc "Called when the client is requesting a connection to the specified application name"
  @callback connection_requested(Rtmp.ServerSession.Events.ConnectionRequested.t(), adopter_state) ::
              {request_result, adopter_state}

  @doc """
  Called when a client wants to publish a stream to the specified application name
  and stream key combination
  """
  @callback publish_requested(Rtmp.ServerSession.Events.PublishStreamRequested.t(), adopter_state) ::
              {request_result, adopter_state}

  @doc """
  Called when the client is no longer publishing to the specified application name
  and stream key
  """
  @callback publish_finished(Rtmp.ServerSession.Events.PublishingFinished.t(), adopter_state) ::
              {:ok, adopter_state}

  @doc """
  Called when the client is wanting to play a stream from the specified application
  name and stream key combination
  """
  @callback play_requested(Rtmp.ServerSession.Events.PlayStreamRequested.t(), adopter_state) ::
              {request_result, adopter_state}

  @doc """
  Called when the client no longer wants to play the stream from the specified
  application name and stream key combination
  """
  @callback play_finished(Rtmp.ServerSession.Events.PlayStreamFinished.t(), adopter_state) ::
              {:ok, adopter_state}

  @doc """
  Called when a client publishing a stream has changed the metadata information
  for that stream.
  """
  @callback metadata_received(Rtmp.ServerSession.Events.StreamMetaDataChanged.t(), adopter_state) ::
              {:ok, adopter_state}

  @doc """
  Called when audio or video data has been received on a published stream
  """
  @callback audio_video_data_received(
              Rtmp.ServerSession.Events.AudioVideoDataReceived.t(),
              adopter_state
            ) ::
              {:ok, adopter_state}

  @doc """
  Called when the number of bytes sent and received to the client changes
  """
  @callback byte_io_totals_updated(Rtmp.ServerSession.Events.NewByteIOTotals.t(), adopter_state) ::
              {:ok, adopter_state}

  @doc """
  Called when the client sends an acknowledgement of bytes received
  """
  @callback acknowledgement_received(
              Rtmp.ServerSession.Events.AcknowledgementReceived.t(),
              adopter_state
            ) ::
              {:ok, adopter_state}

  @doc """
  Called when the server has successfully sent a ping request.  This is needed to be handled
  if the server implementation wants track how long it's been since a ping request has gone
  unresponded to, or if the server wants to get an idea of latency
  """
  @callback ping_request_sent(Rtmp.ServerSession.Events.PingRequestSent.t(), adopter_state) ::
              {:ok, adopter_state}

  @doc """
  Called when the server has received a response to a ping request.  Note that unsolicited
  ping responses may come through, and it's up to the behavior implementor to decide how to
  react to it.
  """
  @callback ping_response_received(
              Rtmp.ServerSession.Events.PingResponseReceived.t(),
              adopter_state
            ) ::
              {:ok, adopter_state}

  @doc "Called when an code change is ocurring"
  @callback code_change(any, adopter_state) :: {:ok, adopter_state} | {:error, String.t()}

  @doc """
  Called when any BEAM message is received that is not handleable by the generic RTMP server,
  and is thus being passed along to the module adopting this behaviour.
  """
  @callback handle_message(any, adopter_state) :: {:ok, adopter_state}

  @doc """
  Called when the TCP socket is closed.  Allows for any last minute cleanup before
  the process is killed
  """
  @callback handle_disconnection(adopter_state) :: {:ok, adopter_state}

  @spec start_link(module(), %GenRtmpServer.RtmpOptions{}, adopter_arguments) ::
          Supervisor.on_start()
  @doc """
  Starts the generic RTMP server using the provided RTMP options
  """
  def start_link(module, options = %GenRtmpServer.RtmpOptions{}, additional_args \\ []) do
    {:ok, _} = Application.ensure_all_started(:ranch)

    _ = Logger.info("Starting RTMP listener on port #{options.port}")

    :ranch.start_listener(
      module,
      10,
      :ranch_tcp,
      [port: options.port],
      GenRtmpServer.Protocol,
      [module, options, additional_args]
    )
  end

  @spec send_message(pid, outbound_data, stream_id, forced_timestamp) :: :ok
  @doc """
  Signals a specific RTMP server process to send an RTMP message to its client
  """
  def send_message(pid, outbound_data, stream_id, forced_timestamp \\ nil) do
    send(pid, {:rtmp_send, outbound_data, stream_id, forced_timestamp})
  end

  @spec send_ping_request(pid) :: :ok
  @doc """
  Sends a ping request to the client
  """
  def send_ping_request(pid) do
    send(pid, :send_ping_request)
  end
end
