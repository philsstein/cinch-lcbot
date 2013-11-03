require 'cinch'
require 'yaml'

require File.expand_path(File.dirname(__FILE__)) + '/core'

module Cinch
  module Plugins

    CHANGELOG_FILE = File.expand_path(File.dirname(__FILE__)) + "/changelog.yml"

    class LostCitiesGame
      include Cinch::Plugin

      def initialize(*args)
        super
        @game = Game.new
 
        @changelog     = self.load_changelog

        @mods          = config[:mods]
        @channel_name  = config[:channel]
        @settings_file = config[:settings]
        @games_dir     = config[:games_dir]

        @idle_timer_length    = config[:allowed_idle]
        @invite_timer_length  = config[:invite_reset]

        @idle_timer   = self.start_idle_timer
      end

      # start
      match /join/i,             :method => :join
      match /leave/i,            :method => :leave
      match /start/i,            :method => :start_game

      # game
      #match /whoami/i,           :method => :whoami

      match /status/i,            :method => :status

      # match /invite/i,              :method => :invite
      # match /subscribe/i,           :method => :subscribe
      # match /unsubscribe/i,         :method => :unsubscribe
      match /help ?(.+)?/i,         :method => :help
      match /intro/i,               :method => :intro
      match /rules ?(.+)?/i,        :method => :rules
      match /changelog$/i,          :method => :changelog_dir
      match /changelog (\d+)/i,     :method => :changelog
      # match /about/i,               :method => :about
   
      # mod only commands
      match /reset/i,              :method => :reset_game
      match /replace (.+?) (.+)/i, :method => :replace_user
      match /kick (.+)/i,          :method => :kick_user
      match /room (.+)/i,          :method => :room_mode

      listen_to :join,          :method => :voice_if_in_game
      listen_to :leaving,       :method => :remove_if_not_started
      listen_to :op,            :method => :devoice_everyone_on_start

      #--------------------------------------------------------------------------------
      # Listeners & Timers
      #--------------------------------------------------------------------------------
      def voice_if_in_game(m)
        if @game.has_player?(m.user)
          Channel(@channel_name).voice(m.user)
        end
      end

      def remove_if_not_started(m, user)
        if @game.not_started?
          self.remove_user_from_game(user)
        end
      end

      def devoice_everyone_on_start(m, user)
        if user == bot
          self.devoice_channel
        end
      end

      def start_idle_timer
        Timer(300) do
          @game.players.map{|p| p.user }.each do |user|
            user.refresh
            if user.idle > @idle_timer_length
              self.remove_user_from_game(user)
              user.send "You have been removed from the #{@channel_name} game due to inactivity."
            end
          end
        end
      end

      #--------------------------------------------------------------------------------
      # Helpers
      #--------------------------------------------------------------------------------

      def help(m, page)
        if page.to_s.downcase == "mod" && self.is_mod?(m.user.nick)
          User(m.user).send "--- HELP PAGE MOD ---"
          User(m.user).send "!reset - completely resets the game to brand new"
          User(m.user).send "!replace nick1 nick1 - replaces a player in-game with a player "\
                            "out-of-game"
          User(m.user).send "!kick nick1 - removes a presumably unresponsive user from an "\
                            "unstarted game"
          User(m.user).send "!room silent|vocal - switches the channel from voice only users "\
                            "and back"
        else 
          # case page
          # when "2"
          #   User(m.user).send "--- HELP PAGE 2/3 ---"
          # when "3"
          #   User(m.user).send "--- HELP PAGE 3/3 ---"
          #   User(m.user).send "!rules - provides rules for the game"
          # else
            User(m.user).send "--- HELP PAGE 1/3 ---"
            User(m.user).send "!play card - where card is R5, W3, etc."
            User(m.user).send "!discard card - where card is R5, W3, etc."
            User(m.user).send "!join - joins the game"
            User(m.user).send "!leave - leaves the game"
            User(m.user).send "!start - starts the game"
            User(m.user).send "!rules - provides rules for the game"
          # end
        end
      end

      def intro(m)
        User(m.user).send "Welcome to the Lost Cities Bot. You can join a game if there's "\
                          "one getting started with the command \"!join\". For more commands, "\
                          "type \"!help\". If you don't know how to play, you can read a rules "\
                          "summary with \"!rules\". If already know how to play, great."
      end

      def rules(m, section)
        case section.to_s.downcase
          User(m.user).send "Errr. So I kinda lied about the rules thing. Read the rules on BGG."
        end
      end

      def list_players(m)
        if @game.players.empty?
          m.reply "No one has joined the game yet."
        else
          m.reply @game.players.map{ |p| p == @game.hammer ? "#{dehighlight_nick(p.user.nick)}*" : dehighlight_nick(p.user.nick) }.join(' ')
        end
      end

      def status(m)
        m.reply @game.check_game_state
      end

      def changelog_dir(m)
        @changelog.first(5).each_with_index do |changelog, i|
          User(m.user).send "#{i+1} - #{changelog["date"]} - #{changelog["changes"].length} changes" 
        end
      end

      def changelog(m, page = 1)
        changelog_page = @changelog[page.to_i-1]
        User(m.user).send "Changes for #{changelog_page["date"]}:"
        changelog_page["changes"].each do |change|
          User(m.user).send "- #{change}"
        end
      end

      #--------------------------------------------------------------------------------
      # Main IRC Interface Methods
      #--------------------------------------------------------------------------------
      def join(m)
        # self.reset_timer(m)
        if Channel(@channel_name).has_user?(m.user)
          if @game.accepting_players? 
            added = @game.add_player(m.user)
            unless added.nil?
              Channel(@channel_name).send "#{m.user.nick} has joined the game "\
                "(#{@game.players.count}/2)"
              Channel(@channel_name).voice(m.user)
            end
          else
            if @game.started?
              Channel(@channel_name).send "#{m.user.nick}: Game has already started."
            elsif @game.at_max_players?
              Channel(@channel_name).send "#{m.user.nick}: Game is at max players."
            else
              Channel(@channel_name).send "#{m.user.nick}: You cannot join."
            end
          end
        else
          User(m.user).send "You need to be in #{@channel_name} to join the game."
        end
      end

      def leave(m)
        if @game.not_started?
          left = @game.remove_player(m.user)
          unless left.nil?
            Channel(@channel_name).send "#{m.user.nick} has left the game "\
              "(#{@game.players.count}/2)"
            Channel(@channel_name).devoice(m.user)
          end
        else
          if @game.started?
            m.reply "Game is in progress.", true
          end
        end
      end

      def start_game(m)
        unless @game.started?
          if @game.at_min_players?
            if @game.has_player?(m.user)
              @idle_timer.stop
              @game.start_game!
              self.start_game
              Channel(@channel_name).send "The game has started."
            else
              m.reply "You are not in the game.", true
            end
          else
            m.reply "Need 2 players to start a game.", true
          end
        end
      end

      #--------------------------------------------------------------------------------
      # Game interaction methods
      #--------------------------------------------------------------------------------
      def start_game
        Channel(@channel_name).send("#{@game.players[0]} goes first.")
      end

      def status(m)
        m.reply @game.check_game_state
      end

      def start_new_game
        Channel(@channel_name).moderated = false
        @game.players.each do |p|
          Channel(@channel_name).devoice(p.user)
        end
        @game = Game.new
        @idle_timer.start
      end

      def devoice_channel
        Channel(@channel_name).voiced.each do |user|
          Channel(@channel_name).devoice(user)
        end
      end

      def remove_user_from_game(user)
        if @game.not_started?
          left = @game.remove_player(user)
          unless left.nil?
            Channel(@channel_name).send "#{user.nick} has left the game "\
              "(#{@game.players.count}/2)"
            Channel(@channel_name).devoice(user)
          end
        end
      end

      def dehighlight_nick(nickname)
        nickname.scan(/.{2}|.+/).join(8203.chr('UTF-8'))
      end

      #--------------------------------------------------------------------------------
      # Mod commands
      #--------------------------------------------------------------------------------

      def is_mod?(nick)
        # make sure that the nick is in the mod list and the user in authenticated 
        user = User(nick) 
        user.authed? && @mods.include?(user.authname)
      end

      def reset_game(m)
        if self.is_mod? m.user.nick
          if @game.started?
            #spies, resistance = get_loyalty_info
            #Channel(@channel_name).send "The spies were: #{spies.join(", ")}"
            #Channel(@channel_name).send "The resistance were: #{resistance.join(", ")}"
          end
          @game = Game.new
          self.devoice_channel
          Channel(@channel_name).send "The game has been reset."
          @idle_timer.start
        end
      end

      def kick_user(m, nick)
        if self.is_mod? m.user.nick
          if @game.not_started?
            user = User(nick)
            left = @game.remove_player(user)
            unless left.nil?
              Channel(@channel_name).send "#{user.nick} has left the game (#{@game.players.count}/#{Game::MAX_PLAYERS})"
              Channel(@channel_name).devoice(user)
            end
          else
            User(m.user).send "You can't kick someone while a game is in progress."
          end
        end
      end

      def replace_user(m, nick1, nick2)
        if self.is_mod? m.user.nick
          # find irc users based on nick
          user1 = User(nick1)
          user2 = User(nick2)
          
          # replace the users for the players
          player = @game.find_player(user1)
          player.user = user2

          # devoice/voice the players
          Channel(@channel_name).devoice(user1)
          Channel(@channel_name).voice(user2)

          # inform channel
          Channel(@channel_name).send "#{user1.nick} has been replaced with #{user2.nick}"

          # tell loyalty to new player
          User(player.user).send "="*40
          self.tell_loyalty_to(player)
        end
      end

      def room_mode(m, mode)
        if self.is_mod? m.user.nick
          case mode
          when "silent"
            Channel(@channel_name).moderated = true
          when "vocal"
            Channel(@channel_name).moderated = false
          end
        end
      end

      def what_roles(m)
        if self.is_mod? m.user.nick
          if @game.started?
            if @game.has_player?(m.user)
              User(m.user).send "You are in the game, goof!"
            else
              roles_msg = @game.players.map do |player|
                "#{player} - #{player.role.upcase}"
              end.join(', ')
              User(m.user).send "Starting Roles: #{roles_msg}"
              if @game.day?
                roles_msg = @game.players.map{ |player| player.new_role.nil? ? "#{player} - #{player.role.upcase}" : Format(:bold, "#{player} - #{player.new_role.upcase}")}.join(', ')
                User(m.user).send "Current Roles: #{roles_msg}"
                player = @game.find_player_by_role(:seer)
                unless player.nil?
                  if player.seer_view.has_key?(:player)
                    User(m.user).send "Seer looked at #{player.seer_view[:player]} and saw: #{player.seer_view[:player].role.upcase}"
                  elsif player.seer_view.has_key?(:table)
                    User(m.user).send "Seer looked at the table and saw: #{player.seer_view[:table]}"
                  end
                end
              end
            end
          else
            User(m.user).send "There is no game going on."
          end
        end
      end


      #--------------------------------------------------------------------------------
      # Settings
      #--------------------------------------------------------------------------------
      
      def save_settings(settings)
        output = File.new(@settings_file, 'w')
        output.puts YAML.dump(settings)
        output.close
      end

      def load_settings
        output = File.new(@settings_file, 'r')
        settings = YAML.load(output.read)
        output.close

        settings
      end

      def load_changelog
        output = File.new(CHANGELOG_FILE, 'r')
        changelog = YAML.load(output.read)
        output.close

        changelog
      end
      

    end
    
  end
end