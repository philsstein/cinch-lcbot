require 'logger'

$log = Logger.new(STDOUT) 
$log.level = Logger::DEBUG

#================================================================================
# GAME
#================================================================================
class Game

  include Cinch::Helpers

  attr_accessor :started, :players, :deck, :discards

  def initialize
    self.started  = false
    self.players  = []    # list of Players
    self.deck     = []    # list of Cards
    self.discards = {}        # hash of cards indexed by color.
    @cur_player_index = 0

    Card.colors.each do |c|
      self.discards[c] = []
    end
  end

  #----------------------------------------------
  # Game Status
  #----------------------------------------------
  def started?
    self.started == true
  end

  def not_started?
    self.started == false 
  end

  def accepting_players?
    self.not_started? && ! self.at_min_players?
  end

  def check_game_state
    str = "Scores - "
    self.players.each do |p|
      str += "#{p}: #{self.get_score(p.played)[:total]}"
    end
    str += "Cards remaining: #{self.deck.size}"
    str
  end

  def turn
    "It is #{self.current_player}'s turn."
  end

  #----------------------------------------------
  # Game Setup
  #----------------------------------------------
  # Player handlers
  def at_min_players?
    self.players.count == 2
  end

  def add_player(user)
    added = nil
    unless self.has_player?(user)
      new_player = Player.new(user)
      self.players << new_player
      added = new_player
    end
    added
  end

  def find_player(user)
    self.players.find { |p| p.user == user }
  end

  def current_player
    self.players[@cur_player_index]
  end

  def next_player!
    if @cur_player_index == 0
      @cur_player_index = 1
    else
      @cur_player_index = 0
    end
  end

  def has_player?(user)
    found = self.find_player(user)
    $log.debug { "Looking for #{user} in game. Found: #{found}" }
    found.nil? ? false : true
  end

  def players_turn?(user)
    user == self.current_player.user
  end

  def remove_player(user)
    removed = nil
    player = self.find_player(user)
    unless player.nil?
      self.players.delete(player)
      removed = player
    end
    removed
  end

  #----------------------------------------------
  # Helpers
  #----------------------------------------------
  def hand(user)
    if not self.has_player?(user)
      'You are not in the game.'
    else
      "Your hand is #{self.find_player(user).hand}"
    end
  end

  #----------------------------------------------
  # Game 
  #----------------------------------------------

  # Starts up the game
  #
  def start_game!
    self.started = true
    Card.colors.each do |c|
      Card.values.each do |v|
        self.deck << Card.new(c, v)
      end
    end
    self.deck.shuffle!
    self.players.shuffle!
    self.players[0].hand = self.deck.pop(5)
    self.players[1].hand = self.deck.pop(5)
    @cur_player_index = 0
  end

  def get_score(played)
    scores = {}
    total = 0
    played.each do |color, cards|
      investments, count, color_total = [1, 0, 0]
      score = cards.size > 0 ? -20 : 0
      cards.each do |card|
        if card.is_investment?
          investments += 1
        else
          color_total += card.value
          count += 1
        end
      end
      score += (color_total * investments) + (count >= 8 ? 20 : 0)
      scores[color] = score
      total += score
    end
    scores[:total] = total
    scores
  end

  def get_table
    retval = ""
    self.players.each do |p|
      retval += "#{p} has played: "
      p.played.each do |color, cards| 
        retval += Format(color, cards.join(','))
      end
      retval += "\n"
      retval += "#{p} score: #{self.get_score p.played}\n"
    end
    retval += "Discards: "
    self.discards.each do |color, cards|
      retval += Format(color, cards.join(','))
    end
    retval += "\n"
    retval += self.turn
    retval
  end

  def play_card(user, card)
    retval = valid_turn_and_card?(user, card)
    if not retval.nil?
      return retval
    end
    c = Card.new(card)
    $log.debug("looking for card in hand. card: #{c}, hand: #{self.current_player.hand}")
    if not self.current_player.hand.index(c)
      retval = "You do not have the #{card} in your hand."
    else
      if self.current_player.played[c.color].size == 0 or self.current_player.played[c.color].can_be_next?(c)
        # move the card from player's hand into appropriate played pile
        self.current_player.hand.delete(c)
        self.current_player.played[c.color] << c
        retval = "#{user} played a #{c}. They must now draw a card."
      else
        retval = 'That card is not currently playable.'
      end
    end
    retval
  end

  def discard(user, card)
    retval = valid_turn_and_card?(user, card)
    if not retval.nil?
      return retval
    end
    c = Card.new(card)
    if not self.current_player.hand.index(c)
      retval = "You do not have the #{card} in your hand."
    else
      # move the card from player's hand into appropriate discard pile.
      self.current_player.hand.delete(c)
      self.discards[c.color] << c
      retval = "#{user} discarded a #{c}. They must now draw a card."
    end
    retval
  end

  def draw_card(user, card)
    if not self.players_turn? user
      retval = "It is not your turn. It is #{self.current_player.user.nick}'s turn."
    end
    if card.nil?
      # draw from the deck
      self.current_player.hand << self.deck.pop
      retval = "#{user} drew a card from the deck."
      self.next_player!
    elsif not Card.valid_card? card
      retval = "#{card} is not a valid card."
    else
      c = Card.new(card)
      if c != self.discards[c.color].last
        retval = "#{c} is not on the top of the #{c.color} discard pile."
      else
        self.current_player.hand << self.discards[c.color].pop
        retval = "#{user} drew the #{c} card from the #{c.color} discard pile."
      end
    end 
    retval
  end

  def valid_turn_and_card?(user, card)
    retval = nil
    if not self.players_turn? user
      retval = "It is not your turn. It is #{self.current_player.user.nick}'s turn."
    elsif not Card.valid_card? card
      retval = "#{card} is not a valid card."
    end
    retval
  end
end

#================================================================================
# PLAYER
#================================================================================
class Player
  attr_accessor :user, :hand, :played

  def initialize(user)
    self.user = user
    self.hand = []
    self.played = {}
    Card.colors.each do |c|
      self.played[c] = []
    end
  end 

  def to_s
    self.user.nick
  end
end

#================================================================================
# CARD, Orson Scott is a douche
#================================================================================
class Card

  include Cinch::Helpers

  attr_accessor :color, :value, :colors, :values

  # note that 1s are investment cards.
  @@values = [1,1,1,2,3,4,5,6,7,8,9,10]
  # note these should match the colors identifiers in Cinch::Formatting
  @@colors = [:red, :blue, :green, :yellow, :white]
  @@colmap = { :red => 'R', :blue => 'B', :green => 'G', :yellow => 'Y', :white => 'W' }

  def initialize *args
    $log.debug("creating cards given args: #{args}")
    case args.size
    when 1
      # c = Card.new('R4')
      @color = @@colmap.key(args[0][0])
      i = args[0][1..-1]
      @value = ['+', "2", "3", "4", "5", "6", "7", "8", "9", "10"].select { |v| v==(args[0][1..-1]) }[0]
      if @value == '+'
        @value = 1
      else
        @value = Integer(@value)
      end
    when 2
      # c = Card.new(Card.colors[0], 4)
      @color = args[0]
      @value = args[1]
    else
      raise "bad card #{args}"
    end
  end

  def to_s
    if @value == 1
      Format(@color, "#{@@colmap[@color]}+")
    else
      Format(@color, "#{@@colmap[@color]}#{@value}")
    end
  end

  def ==(lhs)
    $log.debug("Comparing cards #{self} and #{lhs}")
    @color == lhs.color and @value == lhs.value
  end

  def can_be_next?(c)
    if @value == 1
      c.value == 1 && @color == c.color
    else
      @value < c.value and @color == c.color
    end
  end

  def is_investment?
    @value == 1
  end

  def self.colors
    @@colors
  end

  def self.values
    @@values
  end

  def self.valid_card?(str)
    $log.debug("testing card #{str} for validity")
    color = @@colmap.key(str[0])
    value = ['+', '2', '3', '4', '5', '6', '7', '8', '9', '10'].select { |i| i == str[1..-1] }
    $log.debug("found color: #{color}")
    $log.debug("found value: #{value}")
    not (color.nil? or value.nil?)
  end
end





