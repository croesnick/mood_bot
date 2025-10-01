defmodule MoodBot.MediaPlayground.AudioStreaming do
  @moduledoc false

  use Membrane.Pipeline

  def handle_init(_ctx) do
    mp3_url =
      "https://raw.githubusercontent.com/membraneframework/membrane_demo/master/simple_pipeline/sample.mp3"

    spec =
      child(%Membrane.Hackney.Source{location: mp3_url, hackney_opts: [follow_redirect: true]})
      |> child(Membrane.MP3.MAD.Decoder)
      |> child(Membrane.PortAudio.Sink)

    {[spec: spec], %{}}
  end
end
