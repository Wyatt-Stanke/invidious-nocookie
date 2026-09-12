module Invidious::Videos
  extend self

  struct VideoPreferences
    include JSON::Serializable

    property annotations : Bool
    property autoplay : Bool
    property comments : Array(String)
    property continue : Bool
    property continue_autoplay : Bool
    property controls : Bool
    property preferred_captions : Array(String)
    property region : String?
    property related_videos : Bool
    property video_end : Float64 | Int32
    property video_loop : Bool
    property extend_desc : Bool
    property video_start : Float64 | Int32
  end

  def process_video_params(query, preferences)
    annotations = query["iv_load_policy"]?.try &.to_i?
    autoplay = query["autoplay"]?.try { |q| (q == "true" || q == "1").to_unsafe }
    comments = query["comments"]?.try &.split(",").map(&.downcase)
    continue = query["continue"]?.try { |q| (q == "true" || q == "1").to_unsafe }
    continue_autoplay = query["continue_autoplay"]?.try { |q| (q == "true" || q == "1").to_unsafe }
    preferred_captions = query["subtitles"]?.try &.split(",").map(&.downcase)
    region = query["region"]?
    related_videos = query["related_videos"]?.try { |q| (q == "true" || q == "1").to_unsafe }
    video_loop = query["loop"]?.try { |q| (q == "true" || q == "1").to_unsafe }
    extend_desc = query["extend_desc"]?.try { |q| (q == "true" || q == "1").to_unsafe }

    if preferences
      # region ||= preferences.region
      annotations ||= preferences.annotations.to_unsafe
      autoplay ||= preferences.autoplay.to_unsafe
      comments ||= preferences.comments
      continue ||= preferences.continue.to_unsafe
      continue_autoplay ||= preferences.continue_autoplay.to_unsafe
      preferred_captions ||= preferences.captions
      related_videos ||= preferences.related_videos.to_unsafe
      video_loop ||= preferences.video_loop.to_unsafe
      extend_desc ||= preferences.extend_desc.to_unsafe
    end

    annotations ||= CONFIG.default_user_preferences.annotations.to_unsafe
    autoplay ||= CONFIG.default_user_preferences.autoplay.to_unsafe
    comments ||= CONFIG.default_user_preferences.comments
    continue ||= CONFIG.default_user_preferences.continue.to_unsafe
    continue_autoplay ||= CONFIG.default_user_preferences.continue_autoplay.to_unsafe
    preferred_captions ||= CONFIG.default_user_preferences.captions
    related_videos ||= CONFIG.default_user_preferences.related_videos.to_unsafe
    video_loop ||= CONFIG.default_user_preferences.video_loop.to_unsafe
    extend_desc ||= CONFIG.default_user_preferences.extend_desc.to_unsafe

    annotations = annotations == 1
    autoplay = autoplay == 1
    continue = continue == 1
    continue_autoplay = continue_autoplay == 1
    related_videos = related_videos == 1
    video_loop = video_loop == 1
    extend_desc = extend_desc == 1

    if start = query["t"]? || query["time_continue"]? || query["start"]?
      video_start = decode_time(start)
    end
    video_start ||= 0

    if query["end"]?
      video_end = decode_time(query["end"])
    end
    video_end ||= -1

    controls = query["controls"]?.try &.to_i?
    controls ||= 1
    controls = controls >= 1

    params = VideoPreferences.new({
      annotations:        annotations,
      autoplay:           autoplay,
      comments:           comments,
      continue:           continue,
      continue_autoplay:  continue_autoplay,
      controls:           controls,
      preferred_captions: preferred_captions,
      region:             region,
      related_videos:     related_videos,
      video_end:          video_end,
      video_loop:         video_loop,
      extend_desc:        extend_desc,
      video_start:        video_start,
    })

    return params
  end
end
