THISDIR = $(shell pwd)

all:

romfs:
	$(ROMFSINST) -p +x $(THISDIR)/src/mihomo.sh /usr/bin/mihomo.sh
	$(ROMFSINST) -p +x $(THISDIR)/src/update_mihomo_sub.sh /usr/bin/update_mihomo_sub.sh

clean:
