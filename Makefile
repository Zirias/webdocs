DOCS:=c/beginners-guide-away-from-scanf

PANDOC?=pandoc
OUTDIR?=html

OUTDOCS:=$(addprefix $(OUTDIR)/,$(addsuffix .html,$(DOCS)))
DIRS:=$(sort $(addprefix $(OUTDIR)/,$(dir $(DOCS))))

all: $(OUTDOCS)

$(DIRS):
	mkdir -p $(DIRS)

$(OUTDIR)/%.html: %.md Makefile style.html | $(DIRS)
	@echo "  [PANDOC] $@"
	@$(PANDOC) -s -H style.html -f markdown -t html5 <$< >$@

clean:
	rm -fr $(OUTDIR)

.PHONY: all clean
