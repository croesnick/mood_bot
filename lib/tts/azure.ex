defmodule MoodBot.TTS.Azure do
  @moduledoc """
  A module for text-to-speech functionality using Azure Cognitive Services.
  """

  @azure_speech_key System.get_env("AZURE_SPEECH_KEY")
  @azure_speech_region System.get_env("AZURE_SPEECH_REGION")
  @azure_speech_service_url "https://#{@azure_speech_region}.tts.speech.microsoft.com/cognitiveservices/v1"

  @doc """
  Convert text to speech. Stream the response to a callback function.
  """
  @spec stream(String.t(), function()) :: :ok | {:error, String.t()}
  def stream(text, callback) do
    case Req.post(@azure_speech_service_url,
           body: request_body(text),
           headers: request_headers(),
           into: fn {:data, data}, acc ->
             callback.(data)
             {:cont, acc}
           end
         ) do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status_code, body: body}} ->
        {:error, "Azure TTS error (#{status_code}): #{body}"}

      {:error, reason} ->
        {:error, "HTTP error: #{reason}"}
    end
  end

  @spec request_body(String.t()) :: String.t()
  defp request_body(text) do
    """
    <speak version="1.0" xml:lang="de-DE">
      <voice xml:lang="de-DE" xml:gender="Male" name="de-DE-Florian:DragonHDLatestNeural">#{text}</voice>
    </speak>
    """
  end

  @spec request_headers() :: %{String.t() => [binary()]}
  defp request_headers() do
    %{
      "Ocp-Apim-Subscription-Key" => [@azure_speech_key],
      "Content-Type" => ["application/ssml+xml"],
      "X-Microsoft-OutputFormat" => ["riff-24khz-16bit-mono-pcm"]
    }
  end
end
