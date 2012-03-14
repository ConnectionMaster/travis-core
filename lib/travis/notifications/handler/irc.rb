require 'travis/notifications/handler/template'
require 'core_ext/module/include'
require 'irc_client'

module Travis
  module Notifications
    module Handler
      # Publishes a build notification to IRC channels as defined in the
      # configuration (`.travis.yml`).
      class Irc
        attr_reader :build

        EVENTS = 'build:finished'

        include Logging

        include do
          def notify(event, object, *args)
            @build = object
            send_irc_notifications if object.send_irc_notifications?
          end

          protected
            def send_irc_notifications
              # Notifications to the same host are grouped so that they can be sent with a single connection
              build.irc_channels.each do |server, channels|
                host, port = *server
                send_notifications(host, port, channels)
              end
            end

            def send_notifications(host, port, channels)
              use_notice = notice?
              join_channel = join?

              messages = template.map { |message| Template.new(message, build).interpolate }

              irc(host, nick, :port => port) do |irc|
                channels.each do |channel|
                  join(channel) if join_channel
                  messages.each do |message|
                    say("[travis-ci] #{message}", channel, use_notice)
                  end
                  leave(channel) if join_channel
                end
              end
              # TODO somehow log whether or not the irc message was sent successfully
            end

            def irc(host, nick, options, &block)
              IrcClient.new(host, nick, options).tap do |irc|
                irc.run(&block) if block_given?
                irc.quit
              end
            end

            def nick
              Travis.config.irc.try(:nick) || 'travis-ci'
            end

            def irc_config
              build.config[:notifications][:irc]
            end

            def notice?
              if irc_config.is_a?(Hash)
                irc_config[:use_notice] || false
              else
                false
              end
            end

            def join?
              if irc_config.is_a?(Hash)
                !irc_config[:skip_join]
              else
                true
              end
            end

            def template
              @template ||= begin
                template = (build.config[:notifications] && build.config[:notifications][:irc].is_a?(Hash) && build.config[:notifications][:irc][:template]) 
                Array(template || default_template)
              end
            end

            def default_template
              ["%{repository_url}#%{build_number} (%{branch} - %{commit_short} : %{author}): %{message}",
                "Change view : %{compare_url}",
                "Build details : %{build_url}"]
            end
        end
      end
    end
  end
end
