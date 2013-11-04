require 'logger'

log = Logger.new(STDOUT) 
log.level = Logger::DEBUG

#================================================================================
# GAME
#================================================================================
class Game

  include Cinch::Formatting

  attr_accessor :started, :players, :deck
  
  def initialize
    self.started  = false
    self.players  = []    # list of Players
    self.deck     = []    # list of Cards
    @discards = []    # list of Cards
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
    self.not_started? && ! self.players.count == 2
  end

  def check_game_state
    str = "Scores - "
    self.players.each do |p|
      str += "#{p}: #{self.get_score(p.played)[:total]}"
    end
    str += "Cards remaining: #{self.deck.size}"
    str
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
    self.players[0] == user or self.players[1] == user
  end

  def has_player?(user)
    found = self.find_player(user)
    log.debug("Looking for #{user}. Found: #{found}")
    found.nil? ? false : true
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
  # Game 
  #----------------------------------------------

  # Starts up the game
  #
  def start_game!
    self.started = true
    Card.colors.each do |c|
      Card.values.each do |v|
        self.deck << Card.new(v, c)
      end
    end
    self.deck.shuffle!
    self.players.shuffle!
    self.players[0].hand = self.deck.pop(4)
    self.players[1].hand = self.deck.pop(4)
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
    scores[:total] = score
    scores
  end

  def get_table
    retval = ""
    Card.colors.each do |c|
      retval += Format(c, "%-28s | %28s\n" % [self.players[0].played[c].join(','), 
                                              self.players[1].played[c].join(',')])
    end
    retval += self.get_score
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

  attr_accessor :color, :value, :colors, :values

  # note that 1s are investment cards.
  @@values = [1,1,1,2,3,4,5,6,7,8,9,10]
  # note these should match the colors identifiers in Cinch::Formatting
  @@colors = [:red, :blue, :green, :yellow, :white]

  @cmap = { :red => 'R', :blue => 'B', :green => 'G', :yellow => 'Y', :white => 'W' }

  def initialize(value, color)
    self.color = color
    self.value = value
  end

  def to_s
    Format(self.color, "#{self.cmap[self.color]}#{self.value}")
  end

  def ==(lhs)
    self.color == lhs.color and self.value == lhs.value
  end

  def can_be_next?(c)
    if self.value == 1
      c.value == 1 && self.color == c.color
    else
      self.value < c.value and self.color == c.color
    end
  end

  def is_investment?
    self.value == 1
  end

  def self.colors
    @@colors
  end

  def self.values
    @@values
  end
end





