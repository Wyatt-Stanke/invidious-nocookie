require "uri"

module Invidious::HttpServer
  module Utils
    extend self

    def add_params_to_url(url : String | URI, params : URI::Params) : URI
      url = URI.parse(url) if url.is_a?(String)

      url_query = url.query || ""

      # Append the parameters
      url.query = String.build do |str|
        if !url_query.empty?
          str << url_query
          str << '&'
        end

        str << params
      end

      return url
    end
  end
end
