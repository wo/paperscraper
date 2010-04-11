.PHONY: all
all clean rebuild install:
	@if [ ! -e config.status ]; then \
	    echo "Could you please start with \"./configure\"?"; \
	    echo "You can probably proceed with \"jam\","; \
	    echo "but running ./configure first would be cleaner."; \
	elif [ x`which jam` = x ]; then \
	    echo "We use Jam instead of Make for the build. Please install Jam."; \
	else \
	    jam $(MAKECMDGOALS); \
	fi
