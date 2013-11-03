# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = "cinch-lcbot"
  s.version     = "0.0.1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Phil S. Stein"]
  s.email       = ["phil.s.stein@gmail.com"]
  s.homepage    = "https://github.com/philsstein/cinch-lcbot"
  s.summary     = %q{IRC Bot for playing Lost Cities}
  s.description = %q{Cinch-based IRC bot for playing the Lost Cities card game.}

  s.add_dependency("cinch", "~> 2.0")
  s.files         = `git ls-files`.split("\n")
  s.require_paths = ["lib"]
end
