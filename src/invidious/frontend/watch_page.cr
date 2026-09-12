module Invidious::Frontend::WatchPage
  extend self

  # Origin of the privacy-enhanced YouTube embed used for all playback.
  EMBED_ORIGIN = "https://www.youtube-nocookie.com"

  # Build the URL of the youtube-nocookie.com iframe for a given video.
  #
  # Every player-related preference that has an equivalent embed parameter
  # is mapped here. See: https://developers.google.com/youtube/player_parameters
  def embed_player_url(
    video : Video,
    params : Invidious::Videos::VideoPreferences,
    preferred_captions : Array(Invidious::Videos::Captions::Metadata),
    locale : String,
  ) : String
    query = URI::Params.new

    # Needed so the parent page can receive player events (e.g. "ended")
    # over postMessage without loading any third-party script.
    query["enablejsapi"] = "1"
    query["origin"] = HOST_URL if !HOST_URL.empty?

    query["autoplay"] = "1" if params.autoplay
    query["controls"] = "0" if !params.controls
    query["playsinline"] = "1"

    # Do not let YouTube suggest videos from other channels at the end,
    # Invidious already provides its own "related videos" sidebar.
    query["rel"] = "0"

    if params.video_loop
      # YouTube only loops single videos when they are given as a playlist
      query["loop"] = "1"
      query["playlist"] = video.id
    end

    video_start = params.video_start.to_i
    video_end = params.video_end.to_i
    query["start"] = video_start.to_s if video_start > 0
    query["end"] = video_end.to_s if video_end > 0

    query["iv_load_policy"] = params.annotations ? "1" : "3"

    if caption = preferred_captions[0]?
      query["cc_load_policy"] = "1"
      query["cc_lang_pref"] = caption.language_code
    end

    query["hl"] = locale

    return "#{EMBED_ORIGIN}/embed/#{video.id}?#{query}"
  end
end
