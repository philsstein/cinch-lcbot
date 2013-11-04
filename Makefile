
# Please forgive the $(shell ...) abuse in here. This is pretty hacky, but "it works for me".
FILES=$(shell git ls-files)
GEMSPEC=cinch-lcbot.gemspec
BOT_VERSION=$(shell grep version *.gemspec | cut -d\" -f2)
BOT_NAME=$(shell grep name *.gemspec | cut -d\" -f2)
GEMFILE=$(BOT_NAME)-$(BOT_VERSION).gem
INSTALL_DIR=$(shell gem environment | grep 'INSTALLATION DIRECTORY' | cut -d' ' -f6)
INSTALL_PATH=$(INSTALL_DIR)/gems/$(BOT_NAME)-$(BOT_VERSION)

$(INSTALL_PATH): $(GEMFILE)
	sudo gem install $(GEMFILE)

$(GEMFILE): $(FILES) 
	@echo Building gem $(GEMFILE)
	@gem build $(GEMSPEC)

run: $(INSTALL_PATH)
	@./bin/runbot

clean: 
	echo $(INSTALL_PATH)
	@gem uninstall $(GEMFILE)
	$(RM) $(GEMFILE)
