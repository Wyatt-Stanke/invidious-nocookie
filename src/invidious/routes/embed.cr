{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Embed
  def self.redirect(env)
    locale = env.get("preferences").as(Preferences).locale
    if plid = env.params.query["list"]?.try &.gsub(/[^a-zA-Z0-9_-]/, "")
      begin
        playlist = get_playlist(plid)
        offset = env.params.query["index"]?.try &.to_i? || 0
        videos = get_playlist_videos(playlist, offset: offset)
        if videos.empty?
          url = "/playlist?list=#{plid}"
          raise NotFoundException.new(I18n.translate(locale, "error_video_not_in_playlist", url))
        end

        first_playlist_video = videos[0].as(PlaylistVideo)
      rescue ex : NotFoundException
        return error_template(404, ex)
      rescue ex
        return error_template(500, ex)
      end

      url = "/embed/#{first_playlist_video.id}?#{env.params.query}"

      if env.params.query.size > 0
        url += "?#{env.params.query}"
      end
    else
      url = "/"
    end

    env.redirect url
  end

  def self.show(env)
    preferences = env.get("preferences").as(Preferences)
    locale = preferences.locale
    id = env.params.url["id"]

    plid = env.params.query["list"]?.try &.gsub(/[^a-zA-Z0-9_-]/, "")
    continuation = process_continuation(env.params.query, plid, id)

    if md = env.params.query["playlist"]?
         .try &.match(/[a-zA-Z0-9_-]{11}(,[a-zA-Z0-9_-]{11})*/)
      video_series = md[0].split(",")
      env.params.query.delete("playlist")
    end

    if id.includes?("%20") || id.includes?("+") || env.params.query.to_s.includes?("%20") || env.params.query.to_s.includes?("+")
      id = env.params.url["id"].gsub("%20", "").delete("+")

      url = "/embed/#{id}"

      if env.params.query.size > 0
        url += "?#{env.params.query.to_s.gsub("%20", "").delete("+")}"
      end

      return env.redirect url
    end

    # YouTube embed supports `videoseries` with either `list=PLID`
    # or `playlist=VIDEO_ID,VIDEO_ID`
    case id
    when "videoseries"
      url = ""

      if plid
        begin
          playlist = get_playlist(plid)
          offset = env.params.query["index"]?.try &.to_i? || 0
          videos = get_playlist_videos(playlist, offset: offset)
          if videos.empty?
            url = "/playlist?list=#{plid}"
            raise NotFoundException.new(I18n.translate(locale, "error_video_not_in_playlist", url))
          end

          first_playlist_video = videos[0].as(PlaylistVideo)
        rescue ex : NotFoundException
          return error_template(404, ex)
        rescue ex
          return error_template(500, ex)
        end

        url = "/embed/#{first_playlist_video.id}"
      elsif video_series
        url = "/embed/#{video_series.shift}"
        env.params.query["playlist"] = video_series.join(",")
      else
        return env.redirect "/"
      end

      if env.params.query.size > 0
        url += "?#{env.params.query}"
      end

      return env.redirect url
    when "live_stream"
      response = YT_POOL.client &.get("/embed/live_stream?channel=#{env.params.query["channel"]? || ""}")
      video_id = response.body.match(/"video_id":"(?<video_id>[a-zA-Z0-9_-]{11})"/).try &.["video_id"]

      env.params.query.delete_all("channel")

      if !video_id || video_id == "live_stream"
        return error_template(500, "Video is unavailable.")
      end

      url = "/embed/#{video_id}"

      if env.params.query.size > 0
        url += "?#{env.params.query}"
      end

      return env.redirect url
    when id.size > 11
      url = "/embed/#{id[0, 11]}"

      if env.params.query.size > 0
        url += "?#{env.params.query}"
      end

      return env.redirect url
    else nil # Continue
    end

    params = Invidious::Videos.process_video_params(env.params.query, preferences)

    user = env.get?("user").try &.as(User)
    if user
      subscriptions = user.subscriptions
      watched = user.watched
      notifications = user.notifications
    end
    subscriptions ||= [] of String

    begin
      video = get_video(id, region: params.region)
    rescue ex : NotFoundException
      return error_template(404, ex)
    rescue ex
      return error_template(500, ex)
    end

    if preferences.annotations_subscribed &&
       subscriptions.includes?(video.ucid) &&
       (env.params.query["iv_load_policy"]? || "1") == "1"
      params.annotations = true
    end

    # if watched && !watched.includes? id
    #   PG_DB.exec("UPDATE users SET watched = array_append(watched, $1) WHERE email = $2", id, user.as(User).email)
    # end

    if CONFIG.enable_user_notifications && notifications && notifications.includes? id
      Invidious::Database::Users.remove_notification(user.as(User), id)
      env.get("user").as(User).notifications.delete(id)
      notifications.delete(id)
    end

    # Playback is handled by an embedded youtube-nocookie.com player,
    # so no stream URLs are resolved or proxied here.
    captions = video.captions

    preferred_captions = captions.select { |caption|
      params.preferred_captions.includes?(caption.name) ||
        params.preferred_captions.includes?(caption.language_code.split("-")[0])
    }
    preferred_captions.sort_by! { |caption|
      (params.preferred_captions.index(caption.name) ||
        params.preferred_captions.index(caption.language_code.split("-")[0])).not_nil!
    }

    thumbnail = "/vi/#{video.id}/maxres.jpg"

    rendered "embed"
  end
end
