
require 'json'

#================================================================================
# GAME
#================================================================================

$player_count = 0

class Game

  attr_accessor :started, :players, :table
  
  def initialize
    self.started  = false
    self.players  = []    # list of Players
    self.deck     = []    # list of Cards
    self.discards = []    # list of Cards
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
    self.not_started? && ! self.at_max_players?
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
  def at_max_players?
    self.player_count == 2
  end

  def at_min_players?
    self.player_count == 2
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

  def has_player?(user)
    found = self.find_player(user)
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

end

#================================================================================
# PLAYER
#================================================================================
class Player
  attr_accessor :user, :hand

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
  @@colors = [:R, :B, :G, :Y, :W]

  def initialize(value, color)
    self.color = color
    self.value = value
  end

  def to_s
    "#{self.color}#{self.value}"
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





